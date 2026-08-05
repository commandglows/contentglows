import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_config.dart';
import 'core/app_language.dart';
import 'core/app_diagnostics.dart';
import 'core/app_theme_preference.dart';
import 'core/shared_preferences_provider.dart';
import 'data/models/auth_session.dart';
import 'data/models/offline_sync.dart';
import 'l10n/app_localizations.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/in_app_tour_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final diagnostics = AppDiagnostics();

  Future<void> appRunner() async {
    _installGlobalErrorHandlers(diagnostics);
    _runAppWithDiagnostics(prefs: prefs, diagnostics: diagnostics);
  }

  if (AppConfig.sentryDsn.isEmpty) {
    await appRunner();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = AppConfig.sentryDsn;
    options.environment = AppConfig.effectiveSentryEnvironment;
    options.tracesSampleRate = AppConfig.sentryTracesSampleRate;
    options.sendDefaultPii = AppConfig.sentrySendDefaultPii;
    options.debug = AppConfig.sentryDebug;
    options.enableLogs = false;
    options.attachScreenshot = false;
    options.replay.sessionSampleRate = 0.0;
    options.replay.onErrorSampleRate = 0.0;

    final release = AppConfig.effectiveSentryRelease;
    if (release.isNotEmpty) {
      options.release = release;
    }

    final dist = AppConfig.effectiveSentryDist;
    if (dist.isNotEmpty) {
      options.dist = dist;
    }
  }, appRunner: appRunner);
}

void _installGlobalErrorHandlers(AppDiagnostics diagnostics) {
  FlutterError.onError = (details) {
    diagnostics.error(
      scope: 'flutter.framework',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: {
        'library': details.library,
        'context': details.context?.toDescription(),
      },
    );
    _captureWithSentry(details.exception, details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    diagnostics.error(
      scope: 'flutter.platform_dispatcher',
      message: 'Unhandled platform error.',
      error: error,
      stackTrace: stackTrace,
    );
    _captureWithSentry(error, stackTrace);
    return true;
  };
}

void _runAppWithDiagnostics({
  required SharedPreferences prefs,
  required AppDiagnostics diagnostics,
}) {
  runZonedGuarded(
    () {
      Widget app = ProviderScope(
        observers: [AppDiagnosticsObserver(diagnostics)],
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appDiagnosticsProvider.overrideWithValue(diagnostics),
        ],
        child: const ContentGlowsApp(),
      );
      if (AppConfig.sentryDsn.isNotEmpty) {
        app = SentryWidget(child: app);
      }
      runApp(app);
    },
    (error, stackTrace) {
      diagnostics.error(
        scope: 'dart.zone',
        message: 'Unhandled zone error.',
        error: error,
        stackTrace: stackTrace,
      );
      _captureWithSentry(error, stackTrace);
    },
  );
}

void _captureWithSentry(Object error, StackTrace? stackTrace) {
  if (AppConfig.sentryDsn.isEmpty) {
    return;
  }

  unawaited(Sentry.captureException(error, stackTrace: stackTrace));
}

class ContentGlowsApp extends ConsumerWidget {
  const ContentGlowsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localePreference = normalizeAppLanguagePreference(
      ref.watch(appLanguagePreferenceProvider),
    );
    final themePreference = normalizeAppThemePreference(
      ref.watch(appThemePreferenceProvider),
    );
    final useAppTheme = themePreference == appThemeApp;

    return MaterialApp.router(
      onGenerateTitle: (context) => context.tr('ContentGlows'),
      debugShowCheckedModeBanner: false,
      theme: useAppTheme ? AppTheme.appTheme : AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeModeFromPreference(themePreference),
      routerConfig: router,
      locale: appLocaleFromPreference(localePreference),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (locales, supportedLocales) =>
          resolveSupportedAppLocale(locales),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned.fill(child: _OfflineSyncBridge()),
            const Positioned.fill(child: InAppTourOverlay()),
          ],
        );
      },
    );
  }
}

class _OfflineSyncBridge extends ConsumerStatefulWidget {
  const _OfflineSyncBridge();

  @override
  ConsumerState<_OfflineSyncBridge> createState() => _OfflineSyncBridgeState();
}

class _OfflineSyncBridgeState extends ConsumerState<_OfflineSyncBridge>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(offlineQueueControllerProvider);
      unawaited(_triggerReplay(refreshAccess: true));
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      unawaited(_triggerReplay(refreshAccess: false));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _triggerReplay(
          refreshAccess: true,
          refreshMode: AppAccessRefreshMode.silentResume,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSession>(authSessionProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) != next.isAuthenticated &&
          next.isAuthenticated) {
        unawaited(
          _triggerReplay(
            refreshAccess: true,
            refreshMode: AppAccessRefreshMode.interactive,
          ),
        );
      }
    });
    ref.listen<OfflineSyncState>(offlineSyncStateProvider, (previous, next) {
      if ((previous?.requiresReauth ?? false) && !next.requiresReauth) {
        unawaited(
          _triggerReplay(
            refreshAccess: true,
            refreshMode: AppAccessRefreshMode.interactive,
          ),
        );
      }
    });
    return const SizedBox.shrink();
  }

  Future<void> _triggerReplay({
    required bool refreshAccess,
    AppAccessRefreshMode refreshMode = AppAccessRefreshMode.interactive,
  }) async {
    final scope = ref.read(offlineStorageScopeProvider);
    final queue = await ref.read(offlineQueueStoreProvider).load(scope);
    if (queue.isEmpty) {
      if (refreshAccess) {
        await ref
            .read(appAccessStateProvider.notifier)
            .refresh(mode: refreshMode);
      }
      return;
    }
    if (refreshAccess) {
      await ref
          .read(appAccessStateProvider.notifier)
          .refresh(mode: refreshMode);
    }
    await ref.read(offlineQueueControllerProvider.notifier).retryAll();
  }
}
