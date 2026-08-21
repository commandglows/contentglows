import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

import '../core/app_config.dart';
import '../core/app_diagnostics.dart';
import '../core/app_language.dart';
import '../core/app_theme_preference.dart';
import '../core/shared_preferences_provider.dart';
import '../data/demo/demo_seed.dart';
import '../data/models/affiliate_link.dart';
import '../data/models/ai_runtime.dart';
import '../data/models/ai_usage.dart';
import '../data/models/drip_plan.dart';
import '../data/models/app_access_state.dart';
import '../data/models/app_bootstrap.dart';
import '../data/models/app_settings.dart';
import '../data/models/auth_session.dart';
import '../data/models/content_item.dart';
import '../data/models/brand_profile.dart';
import '../data/models/creator_profile.dart';
import '../data/models/feedback_entry.dart';
import '../data/models/email_source.dart';
import '../data/models/idea.dart';
import '../data/models/link_webhook.dart';
import '../data/models/utm_template.dart';
import '../data/models/offline_sync.dart';
import '../data/models/openrouter_credential.dart';
import '../data/models/persona.dart';
import '../data/models/project.dart';
import '../data/models/project_asset.dart';
import '../data/models/project_intelligence.dart';
import '../data/models/ritual.dart';
import '../data/models/search_console.dart';
import '../data/models/social_placement.dart';
import '../data/services/api_service.dart';
import '../data/services/clerk_auth_service.dart';
import '../data/services/feedback_local_store.dart';
import '../data/services/feedback_service.dart';
import '../data/services/offline_storage_service.dart';

const _apiBaseUrlKey = 'api_base_url';
const _appLanguagePreferenceKey = 'app_language_preference';
const _appThemePreferenceKey = 'app_theme_preference';
const _demoModeKey = 'demo_mode_enabled';
const _demoOnboardingKey = 'demo_onboarding_complete';

final apiBaseUrlProvider = StateNotifierProvider<ApiBaseUrlNotifier, String>((
  ref,
) {
  return ApiBaseUrlNotifier(ref);
});

final appLanguagePreferenceProvider =
    StateNotifierProvider<AppLanguagePreferenceNotifier, String>((ref) {
      return AppLanguagePreferenceNotifier(ref);
    });

final projectAssetCategoryLocaleProvider = Provider<String>((ref) {
  final preference = ref.watch(appLanguagePreferenceProvider);
  final resolved = normalizeAppLanguagePreference(
    preference == appLanguageSystem
        ? PlatformDispatcher.instance.locale.languageCode
        : preference,
  );
  return resolved == appLanguageSystem ? appLanguageEnglish : resolved;
});

final appThemePreferenceProvider =
    StateNotifierProvider<AppThemePreferenceNotifier, String>((ref) {
      return AppThemePreferenceNotifier(ref);
    });

String _normalizeApiBaseUrl(String? raw) {
  return AppConfig.normalizeHttpOrigin(raw, fallback: AppConfig.apiBaseUrl);
}

class ApiBaseUrlNotifier extends StateNotifier<String> {
  ApiBaseUrlNotifier(this.ref)
    : super(
        _normalizeApiBaseUrl(
          ref.read(sharedPrefsProvider).getString(_apiBaseUrlKey),
        ),
      );

  final Ref ref;

  Future<void> update(String url) async {
    final normalized = _normalizeApiBaseUrl(url);
    state = normalized;
    await ref.read(sharedPrefsProvider).setString(_apiBaseUrlKey, normalized);
  }
}

class AppLanguagePreferenceNotifier extends StateNotifier<String> {
  AppLanguagePreferenceNotifier(this.ref)
    : super(
        normalizeAppLanguagePreference(
          ref.read(sharedPrefsProvider).getString(_appLanguagePreferenceKey),
        ),
      );

  final Ref ref;

  Future<void> update(String language) async {
    final normalized = normalizeAppLanguagePreference(language);
    state = normalized;
    await ref
        .read(sharedPrefsProvider)
        .setString(_appLanguagePreferenceKey, normalized);
  }
}

class AppThemePreferenceNotifier extends StateNotifier<String> {
  AppThemePreferenceNotifier(this.ref)
    : super(
        normalizeAppThemePreference(
          ref.read(sharedPrefsProvider).getString(_appThemePreferenceKey),
        ),
      );

  final Ref ref;

  Future<void> update(String theme) async {
    final normalized = normalizeAppThemePreference(theme);
    state = normalized;
    await ref
        .read(sharedPrefsProvider)
        .setString(_appThemePreferenceKey, normalized);
  }
}

String _offlineStorageScope(AuthSession session) {
  if (session.isDemo) {
    return 'demo';
  }
  if (!session.isAuthenticated) {
    return 'signed_out';
  }

  final email = session.email?.trim().toLowerCase();
  if (email != null && email.isNotEmpty) {
    return 'user:$email';
  }
  final token = session.bearerToken;
  if (token != null && token.isNotEmpty) {
    return 'token:${token.hashCode}';
  }
  return 'authenticated';
}

final offlineStorageScopeProvider = Provider<String>((ref) {
  final session = ref.watch(authSessionProvider);
  return _offlineStorageScope(session);
});

class OfflineSyncStateNotifier extends StateNotifier<OfflineSyncState> {
  OfflineSyncStateNotifier({required String scope})
    : super(OfflineSyncState(scope: scope));

  void markFresh(String cacheKey) {
    final nextKeys = {...state.staleKeys}..remove(cacheKey);
    state = state.copyWith(staleKeys: nextKeys);
  }

  void markStale(String cacheKey) {
    final nextKeys = {...state.staleKeys, cacheKey};
    state = state.copyWith(staleKeys: nextKeys);
  }

  void rewriteIds(Map<String, String> idMappings) {
    if (idMappings.isEmpty || state.staleKeys.isEmpty) {
      return;
    }

    state = state.copyWith(
      staleKeys: state.staleKeys
          .map((entry) => rewriteOfflineIdsInString(entry, idMappings))
          .toSet(),
    );
  }

  void replaceQueue(List<QueuedOfflineAction> queue) {
    var pending = 0;
    var retrying = 0;
    var blockedDependency = 0;
    var pausedAuth = 0;
    var failed = 0;
    for (final action in queue) {
      switch (action.status) {
        case OfflineQueueStatus.pending:
          pending++;
          break;
        case OfflineQueueStatus.retrying:
          retrying++;
          break;
        case OfflineQueueStatus.blockedDependency:
          blockedDependency++;
          break;
        case OfflineQueueStatus.pausedAuth:
          pausedAuth++;
          break;
        case OfflineQueueStatus.failed:
          failed++;
          break;
        case OfflineQueueStatus.cancelled:
          break;
      }
    }

    state = state.copyWith(
      pendingCount: pending,
      retryingCount: retrying,
      blockedDependencyCount: blockedDependency,
      pausedAuthCount: pausedAuth,
      failedCount: failed,
    );
  }

  void setReplaying(bool value) {
    state = state.copyWith(
      isReplaying: value,
      lastReplayAt: value ? null : DateTime.now(),
      clearLastReplayAt: value,
    );
  }

  void setReplayError(String? value) {
    state = state.copyWith(
      lastReplayError: value,
      clearLastReplayError: value == null,
    );
  }
}

final offlineSyncStateProvider =
    StateNotifierProvider<OfflineSyncStateNotifier, OfflineSyncState>((ref) {
      final scope = ref.watch(offlineStorageScopeProvider);
      return OfflineSyncStateNotifier(scope: scope);
    });

final offlineCacheStoreProvider = Provider<OfflineCacheStore>((ref) {
  return OfflineCacheStore(ref.read(sharedPrefsProvider));
});

final offlineQueueStoreProvider = Provider<OfflineQueueStore>((ref) {
  return OfflineQueueStore(ref.read(sharedPrefsProvider));
});

final offlineIdMappingStoreProvider = Provider<OfflineIdMappingStore>((ref) {
  return OfflineIdMappingStore(ref.read(sharedPrefsProvider));
});

final offlineQueueRevisionProvider = StateProvider<int>((ref) => 0);

final offlineQueueEntriesProvider = FutureProvider<List<QueuedOfflineAction>>((
  ref,
) async {
  ref.watch(offlineQueueRevisionProvider);
  final scope = ref.watch(offlineStorageScopeProvider);
  final items = await ref.read(offlineQueueStoreProvider).load(scope);
  ref.read(offlineSyncStateProvider.notifier).replaceQueue(items);
  return items;
});

final offlineIdMappingsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  ref.watch(offlineQueueRevisionProvider);
  final scope = ref.watch(offlineStorageScopeProvider);
  return ref.read(offlineIdMappingStoreProvider).load(scope);
});

String offlineEntityKey(String entityType, String entityId) {
  return '$entityType:$entityId';
}

int _offlineEntitySyncRank(OfflineEntitySyncStatus status) {
  return switch (status) {
    OfflineEntitySyncStatus.failed => 5,
    OfflineEntitySyncStatus.pausedAuth => 4,
    OfflineEntitySyncStatus.retrying => 3,
    OfflineEntitySyncStatus.blockedDependency => 2,
    OfflineEntitySyncStatus.pending => 1,
  };
}

OfflineEntitySyncStatus _offlineEntityStatusFromQueueStatus(
  OfflineQueueStatus status,
) {
  return switch (status) {
    OfflineQueueStatus.failed => OfflineEntitySyncStatus.failed,
    OfflineQueueStatus.pausedAuth => OfflineEntitySyncStatus.pausedAuth,
    OfflineQueueStatus.retrying => OfflineEntitySyncStatus.retrying,
    OfflineQueueStatus.blockedDependency =>
      OfflineEntitySyncStatus.blockedDependency,
    _ => OfflineEntitySyncStatus.pending,
  };
}

final offlineEntitySyncMapProvider =
    Provider<Map<String, OfflineEntitySyncInfo>>((ref) {
      final queue = ref.watch(offlineQueueEntriesProvider).value ?? const [];
      final entries = <String, OfflineEntitySyncInfo>{};

      for (final action in queue) {
        final entityType = action.entityType;
        final entityId = action.entityId;
        if (entityType == null ||
            entityType.isEmpty ||
            entityId == null ||
            entityId.isEmpty) {
          continue;
        }

        final key = offlineEntityKey(entityType, entityId);
        final nextStatus = _offlineEntityStatusFromQueueStatus(action.status);
        final previous = entries[key];
        if (previous == null ||
            _offlineEntitySyncRank(nextStatus) >=
                _offlineEntitySyncRank(previous.status)) {
          entries[key] = OfflineEntitySyncInfo(
            entityType: entityType,
            entityId: entityId,
            status: nextStatus,
            actionCount: (previous?.actionCount ?? 0) + 1,
            lastError: action.lastError ?? previous?.lastError,
          );
        } else {
          entries[key] = OfflineEntitySyncInfo(
            entityType: previous.entityType,
            entityId: previous.entityId,
            status: previous.status,
            actionCount: previous.actionCount + 1,
            lastError: previous.lastError ?? action.lastError,
          );
        }
      }

      return entries;
    });

final offlineEntitySyncProvider =
    Provider.family<OfflineEntitySyncInfo?, String>((ref, entityKey) {
      return ref.watch(offlineEntitySyncMapProvider)[entityKey];
    });

final apiServiceProvider = Provider<ApiService>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final authSession = ref.watch(authSessionProvider);
  final clerkAuthService = ref.watch(clerkAuthServiceProvider);
  final syncState = ref.read(offlineSyncStateProvider.notifier);
  return ApiService(
    baseUrl: baseUrl,
    authToken: authSession.bearerToken,
    authTokenProvider: authSession.isAuthenticated
        ? () async => clerkAuthService?.getFreshToken()
        : null,
    allowDemoData: authSession.isDemo,
    diagnostics: ref.watch(appDiagnosticsProvider),
    onUnauthorized: () {
      ref.read(authSessionProvider.notifier).handleUnauthorized();
    },
    cacheStore: ref.read(offlineCacheStoreProvider),
    queueStore: ref.read(offlineQueueStoreProvider),
    idMappingStore: ref.read(offlineIdMappingStoreProvider),
    offlineScope: ref.watch(offlineStorageScopeProvider),
    onCacheKeyFresh: (cacheKey) async => syncState.markFresh(cacheKey),
    onCacheKeyStale: (cacheKey) async => syncState.markStale(cacheKey),
    onQueueUpdated: (queue) async {
      syncState.replaceQueue(queue);
      ref.read(offlineQueueRevisionProvider.notifier).state++;
    },
  );
});

final Provider<FeedbackLocalStore> feedbackLocalStoreProvider =
    Provider<FeedbackLocalStore>((ref) {
      return FeedbackLocalStore(ref.read(sharedPrefsProvider));
    });

final Provider<FeedbackService> feedbackServiceProvider =
    Provider<FeedbackService>((ref) {
      return FeedbackService(
        api: () => ref.read(apiServiceProvider),
        localStore: () => ref.read(feedbackLocalStoreProvider),
        authSession: () => ref.read(authSessionProvider),
        language: () => ref.read(currentUserSettingsProvider).value?.language,
        invalidateRecentSubmissions: () {
          ref.invalidate(feedbackRecentSubmissionsProvider);
        },
        invalidateDefaultAdminEntries: () {
          ref.invalidate(
            feedbackAdminEntriesProvider(const FeedbackAdminQuery()),
          );
        },
      );
    });

final isFeedbackAdminProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(authSessionProvider);
  final accessState = ref.watch(appAccessStateProvider).value;
  if (!session.isAuthenticated || session.isDemo) {
    return false;
  }
  if (accessState?.canUseWorkspaceData != true) {
    return false;
  }
  return ref.read(feedbackServiceProvider).fetchAdminCapability();
});

final Provider<String> feedbackDraftProvider = Provider<String>((ref) {
  return ref.read(feedbackServiceProvider).loadDraftMessage();
});

final FutureProvider<List<LocalFeedbackSubmission>>
feedbackRecentSubmissionsProvider =
    FutureProvider<List<LocalFeedbackSubmission>>((ref) async {
      return ref.read(feedbackServiceProvider).loadRecentSubmissions();
    });

final FutureProviderFamily<List<FeedbackEntry>, FeedbackAdminQuery>
feedbackAdminEntriesProvider =
    FutureProvider.family<List<FeedbackEntry>, FeedbackAdminQuery>((
      ref,
      query,
    ) async {
      return ref.read(feedbackServiceProvider).listAdmin(query: query);
    });

final clerkPublishableKeyProvider = Provider<String>(
  (ref) => AppConfig.clerkPublishableKey,
);

final clerkAuthServiceProvider = Provider<ClerkAuthService?>((ref) {
  final publishableKey = ref.watch(clerkPublishableKeyProvider);
  if (publishableKey.isEmpty) {
    return null;
  }

  final service = ClerkAuthService(
    publishableKey: publishableKey,
    sharedPreferences: ref.read(sharedPrefsProvider),
  );
  ref.onDispose(service.terminate);
  return service;
});

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession>(
      (ref) => AuthSessionNotifier(ref),
    );

final appAccessStateProvider =
    AsyncNotifierProvider<AppAccessNotifier, AppAccessState>(
      AppAccessNotifier.new,
    );

enum AppAccessRefreshMode { interactive, silentResume }

bool shouldEmitIntermediateAppAccessStages(AppAccessRefreshMode mode) {
  return mode == AppAccessRefreshMode.interactive;
}

typedef _AppAccessResolveKey = ({
  AuthStatus status,
  String? bearerToken,
  bool onboardingComplete,
  String apiBaseUrl,
});

class AuthSessionNotifier extends StateNotifier<AuthSession> {
  AuthSessionNotifier(this.ref)
    : super(const AuthSession(status: AuthStatus.loading)) {
    unawaited(_restoreSession());
  }

  final Ref ref;

  Future<void> _restoreSession() async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    diagnostics.info(
      scope: 'auth.restore',
      message: 'Restoring stored session.',
    );
    final prefs = ref.read(sharedPrefsProvider);
    if (AppConfig.devAuthBypass) {
      _clearLegacyAuthPrefs();
      state = const AuthSession(
        status: AuthStatus.authenticated,
        bearerToken: 'devserver-auth-bypass',
        email: 'devserver@contentglows.local',
      );
      diagnostics.info(
        scope: 'auth.restore',
        message: 'Started development auth-bypass session.',
      );
      _invalidateAuthenticatedState();
      return;
    }

    if (prefs.getBool(_demoModeKey) == true) {
      state = AuthSession(
        status: AuthStatus.demo,
        onboardingComplete: prefs.getBool(_demoOnboardingKey) ?? false,
      );
      diagnostics.info(
        scope: 'auth.restore',
        message: 'Restored demo session.',
        context: {'onboardingComplete': state.onboardingComplete},
      );
      ref.invalidate(appBootstrapProvider);
      return;
    }

    final service = ref.read(clerkAuthServiceProvider);
    if (service == null) {
      _clearLegacyAuthPrefs();
      state = const AuthSession(status: AuthStatus.signedOut);
      diagnostics.warning(
        scope: 'auth.restore',
        message: 'Clerk is not configured. Starting signed out.',
      );
      return;
    }

    try {
      final restored = await service.restoreSession();
      if (restored == null) {
        _clearLegacyAuthPrefs();
        state = const AuthSession(status: AuthStatus.signedOut);
        diagnostics.info(
          scope: 'auth.restore',
          message: 'No active Clerk session found.',
        );
        return;
      }

      _clearLegacyAuthPrefs();
      state = AuthSession(
        status: AuthStatus.authenticated,
        bearerToken: restored.bearerToken,
        email: restored.email,
      );
      diagnostics.info(
        scope: 'auth.restore',
        message: 'Restored authenticated Clerk session.',
      );
      _invalidateAuthenticatedState();
    } catch (error, stackTrace) {
      _clearLegacyAuthPrefs();
      state = const AuthSession(status: AuthStatus.signedOut);
      diagnostics.error(
        scope: 'auth.restore',
        message: 'Failed to restore Clerk session.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void signInDemo() {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setBool(_demoModeKey, true);
    prefs.setBool(_demoOnboardingKey, false);
    _clearLegacyAuthPrefs();
    state = const AuthSession(
      status: AuthStatus.demo,
      onboardingComplete: false,
    );
    ref
        .read(appDiagnosticsProvider)
        .info(scope: 'auth.session', message: 'Signed in to demo workspace.');
    _invalidateAuthenticatedState();
  }

  void setAuthenticatedSession(String token, {String? email}) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.remove(_demoModeKey);
    prefs.remove(_demoOnboardingKey);
    _clearLegacyAuthPrefs();

    state = AuthSession(
      status: AuthStatus.authenticated,
      bearerToken: token,
      email: email,
    );
    ref
        .read(appDiagnosticsProvider)
        .info(
          scope: 'auth.session',
          message: 'Authenticated session established.',
          context: {'email': email ?? 'none'},
        );
    _invalidateAuthenticatedState();
  }

  void markOnboardingComplete() {
    if (!state.isDemo) {
      return;
    }

    final prefs = ref.read(sharedPrefsProvider);
    prefs.setBool(_demoOnboardingKey, true);
    state = state.copyWith(onboardingComplete: true);
    ref.invalidate(appBootstrapProvider);
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final service = ref.read(clerkAuthServiceProvider);
    if (service == null) {
      diagnostics.warning(
        scope: 'auth.sign_in',
        message: 'Sign-in requested without Clerk configuration.',
        context: {'email': email},
      );
      throw StateError('Clerk is not configured. Set CLERK_PUBLISHABLE_KEY.');
    }

    diagnostics.info(
      scope: 'auth.sign_in',
      message: 'Attempting password sign-in.',
      context: {'email': email},
    );

    try {
      final result = await service.signInWithPassword(
        email: email,
        password: password,
      );
      setAuthenticatedSession(result.bearerToken, email: result.email ?? email);
    } catch (error, stackTrace) {
      diagnostics.error(
        scope: 'auth.sign_in',
        message: 'Password sign-in failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'email': email},
      );
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final service = ref.read(clerkAuthServiceProvider);
    if (service == null) {
      diagnostics.warning(
        scope: 'auth.google_sign_in',
        message: 'Google sign-in requested without Clerk configuration.',
      );
      throw StateError('Clerk is not configured. Set CLERK_PUBLISHABLE_KEY.');
    }

    diagnostics.info(
      scope: 'auth.google_sign_in',
      message: 'Starting native Google sign-in.',
    );
    try {
      final result = await service.signInWithGoogle();
      setAuthenticatedSession(result.bearerToken, email: result.email);
    } catch (error, stackTrace) {
      diagnostics.warning(
        scope: 'auth.google_sign_in',
        message: error is ClerkAuthException && error.isCancelled
            ? 'Native Google sign-in was cancelled.'
            : 'Native Google sign-in failed.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final service = ref.read(clerkAuthServiceProvider);
    if (service == null) {
      diagnostics.warning(
        scope: 'auth.sign_up',
        message: 'Sign-up requested without Clerk configuration.',
        context: {'email': email},
      );
      throw StateError('Clerk is not configured. Set CLERK_PUBLISHABLE_KEY.');
    }

    diagnostics.info(
      scope: 'auth.sign_up',
      message: 'Attempting password sign-up.',
      context: {'email': email, 'firstName': firstName, 'lastName': lastName},
    );

    try {
      final result = await service.signUpWithPassword(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      setAuthenticatedSession(result.bearerToken, email: result.email ?? email);
    } catch (error, stackTrace) {
      diagnostics.error(
        scope: 'auth.sign_up',
        message: 'Password sign-up failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'email': email, 'firstName': firstName, 'lastName': lastName},
      );
      rethrow;
    }
  }

  Future<void> syncFromClerkSession() async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final service = ref.read(clerkAuthServiceProvider);
    if (service == null) {
      diagnostics.warning(
        scope: 'auth.sync',
        message: 'Session sync requested without Clerk configuration.',
      );
      throw StateError('Clerk is not configured. Set CLERK_PUBLISHABLE_KEY.');
    }

    diagnostics.info(
      scope: 'auth.sync',
      message: 'Syncing from Clerk session.',
    );

    try {
      final restored = await service.restoreSession();
      if (restored == null) {
        throw StateError('Clerk did not return an active session.');
      }

      setAuthenticatedSession(restored.bearerToken, email: restored.email);
    } catch (error, stackTrace) {
      diagnostics.error(
        scope: 'auth.sync',
        message: 'Failed to sync from Clerk session.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> clearLocalSession() async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final service = ref.read(clerkAuthServiceProvider);
    try {
      await service?.signOut();
    } catch (error, stackTrace) {
      diagnostics.warning(
        scope: 'auth.clear_session',
        message: 'Remote sign-out failed while clearing local session.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_demoModeKey);
    await prefs.remove(_demoOnboardingKey);

    for (final key in prefs.getKeys()) {
      final normalized = key.toLowerCase();
      if (normalized.contains('clerk') ||
          normalized.contains('session') ||
          normalized.contains('jwt')) {
        await prefs.remove(key);
      }
    }

    _clearLegacyAuthPrefs();
    state = const AuthSession(status: AuthStatus.signedOut);
    diagnostics.info(
      scope: 'auth.clear_session',
      message: 'Local auth session cleared.',
    );
    _invalidateAuthenticatedState();
  }

  void signOut() {
    if (AppConfig.devAuthBypass) {
      ref
          .read(appDiagnosticsProvider)
          .info(
            scope: 'auth.sign_out',
            message: 'Ignored sign-out in development auth-bypass mode.',
          );
      return;
    }

    ref
        .read(appDiagnosticsProvider)
        .info(scope: 'auth.sign_out', message: 'Sign-out requested.');
    unawaited(_signOut(remote: true));
  }

  void handleUnauthorized() {
    if (!state.isAuthenticated) {
      return;
    }
    ref
        .read(appDiagnosticsProvider)
        .warning(
          scope: 'auth.unauthorized',
          message: 'Backend returned unauthorized for active session.',
        );
    unawaited(_signOut(remote: false));
  }

  Future<void> _signOut({required bool remote}) async {
    if (remote) {
      final service = ref.read(clerkAuthServiceProvider);
      try {
        await service?.signOut();
      } catch (error, stackTrace) {
        ref
            .read(appDiagnosticsProvider)
            .warning(
              scope: 'auth.sign_out',
              message: 'Remote sign-out failed. Clearing local session anyway.',
              error: error,
              stackTrace: stackTrace,
            );
      }
    }

    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_demoModeKey);
    await prefs.remove(_demoOnboardingKey);
    _clearLegacyAuthPrefs();

    state = const AuthSession(status: AuthStatus.signedOut);
    ref
        .read(appDiagnosticsProvider)
        .info(
          scope: 'auth.sign_out',
          message: 'Session signed out locally.',
          context: {'remote': remote},
        );
    _invalidateAuthenticatedState();
  }

  void _invalidateAuthenticatedState() {
    ref.invalidate(appBootstrapProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(currentUserSettingsProvider);
    ref.invalidate(creatorProfileProvider);
    ref.invalidate(publishAccountsProvider);
    ref.invalidate(pendingContentProvider);
    ref.invalidate(contentHistoryProvider);
    ref.invalidate(personasProvider);
    ref.invalidate(dripPlansProvider);
    ref.invalidate(isFeedbackAdminProvider);
    ref.invalidate(feedbackRecentSubmissionsProvider);
    ref.invalidate(feedbackAdminEntriesProvider(const FeedbackAdminQuery()));
    ref.invalidate(offlineQueueEntriesProvider);
    ref.invalidate(offlineIdMappingsProvider);
    ref.invalidate(offlineQueueControllerProvider);
  }

  void _clearLegacyAuthPrefs() {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.remove('auth_mode');
    prefs.remove('auth_bearer_token');
    prefs.remove('auth_email');
    prefs.remove('is_logged_in');
    prefs.remove('onboarding_complete');
  }
}

class AppAccessNotifier extends AsyncNotifier<AppAccessState> {
  Future<AppAccessState>? _inFlightResolve;
  _AppAccessResolveKey? _inFlightResolveKey;

  @override
  Future<AppAccessState> build() async {
    ref.watch(apiBaseUrlProvider);
    final authSession = ref.watch(authSessionProvider);
    return _resolveCoalesced(authSession);
  }

  Future<void> refresh({
    AppAccessRefreshMode mode = AppAccessRefreshMode.interactive,
  }) async {
    final authSession = ref.read(authSessionProvider);
    state = await AsyncValue.guard(
      () => _resolveCoalesced(authSession, mode: mode),
    );
  }

  Future<AppAccessState> _resolveCoalesced(
    AuthSession authSession, {
    AppAccessRefreshMode mode = AppAccessRefreshMode.interactive,
  }) {
    final key = _resolveKey(authSession);
    final inFlight = _inFlightResolve;
    if (inFlight != null && _inFlightResolveKey == key) {
      ref
          .read(appDiagnosticsProvider)
          .info(
            scope: 'app_access.resolve',
            message: 'Joining in-flight app access resolution.',
            context: {'mode': mode.name},
          );
      return inFlight;
    }

    final resolve = _resolve(authSession, mode: mode);
    _inFlightResolve = resolve;
    _inFlightResolveKey = key;
    return resolve.whenComplete(() {
      if (identical(_inFlightResolve, resolve)) {
        _inFlightResolve = null;
        _inFlightResolveKey = null;
      }
    });
  }

  _AppAccessResolveKey _resolveKey(AuthSession authSession) {
    return (
      status: authSession.status,
      bearerToken: authSession.bearerToken,
      onboardingComplete: authSession.onboardingComplete,
      apiBaseUrl: ref.read(apiBaseUrlProvider),
    );
  }

  Future<AppAccessState> _resolve(
    AuthSession authSession, {
    AppAccessRefreshMode mode = AppAccessRefreshMode.interactive,
  }) async {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final emitIntermediateStages = shouldEmitIntermediateAppAccessStages(mode);
    diagnostics.info(
      scope: 'app_access.resolve',
      message: 'Resolving app access.',
      context: {'mode': mode.name},
    );
    if (authSession.isLoading) {
      return const AppAccessState(stage: AppAccessStage.restoringSession);
    }

    if (authSession.status == AuthStatus.signedOut) {
      diagnostics.info(
        scope: 'app_access.resolve',
        message: 'Access resolution ended in signed-out state.',
      );
      return const AppAccessState(stage: AppAccessStage.signedOut);
    }

    if (authSession.isDemo || authSession.bearerToken == null) {
      diagnostics.info(
        scope: 'app_access.resolve',
        message: 'Access resolution entered demo mode.',
      );
      return AppAccessState(
        stage: AppAccessStage.demo,
        bootstrap: AppBootstrap.demo(
          onboardingComplete: authSession.onboardingComplete,
        ),
        checkedAt: DateTime.now(),
      );
    }

    final api = ref.read(apiServiceProvider);
    diagnostics.info(
      scope: 'app_access.resolve',
      message: 'Checking backend availability.',
    );
    if (emitIntermediateStages) {
      state = AsyncData(
        AppAccessState(
          stage: AppAccessStage.checkingBackend,
          checkedAt: DateTime.now(),
        ),
      );
    }

    final health = await api.healthCheck();
    final checkedAt = DateTime.now();
    final backendReachable =
        health['status'] == 'ok' || health['status'] == 'healthy';

    if (!backendReachable) {
      final cachedBootstrap = await api.loadCachedBootstrap();
      diagnostics.warning(
        scope: 'app_access.resolve',
        message: 'Backend health check reported unavailable status.',
        context: {
          'backendStatus': health['status'],
          'cachedBootstrap': cachedBootstrap != null,
        },
      );
      return AppAccessState(
        stage: AppAccessStage.apiUnavailable,
        backendHealth: health,
        bootstrap: cachedBootstrap,
        message: cachedBootstrap == null
            ? 'FastAPI health check did not return a healthy status.'
            : 'FastAPI is unavailable. Using the last cached workspace bootstrap.',
        checkedAt: checkedAt,
      );
    }

    if (emitIntermediateStages) {
      state = AsyncData(
        AppAccessState(
          stage: AppAccessStage.checkingWorkspace,
          backendHealth: health,
          checkedAt: checkedAt,
        ),
      );
    }

    try {
      diagnostics.info(
        scope: 'app_access.resolve',
        message: 'Loading workspace bootstrap.',
      );
      final bootstrap = await api.fetchBootstrap();
      diagnostics.info(
        scope: 'app_access.resolve',
        message: bootstrap.shouldOnboard
            ? 'Workspace requires onboarding.'
            : 'Workspace bootstrap completed.',
      );
      return AppAccessState(
        stage: bootstrap.shouldOnboard
            ? AppAccessStage.needsOnboarding
            : AppAccessStage.ready,
        backendHealth: health,
        bootstrap: bootstrap,
        checkedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      final cachedBootstrap = error.isUnauthorized
          ? null
          : await api.loadCachedBootstrap();
      diagnostics.warning(
        scope: 'app_access.resolve',
        message: error.isUnauthorized
            ? 'Workspace bootstrap was rejected by the backend.'
            : 'Workspace bootstrap failed.',
        error: error,
        context: {
          'statusCode': error.statusCode,
          'path': error.path,
          'method': error.method,
        },
      );
      return AppAccessState(
        stage: error.isUnauthorized
            ? AppAccessStage.bootstrapUnauthorized
            : AppAccessStage.bootstrapFailed,
        backendHealth: health,
        bootstrap: cachedBootstrap,
        statusCode: error.statusCode,
        message: error.message,
        checkedAt: DateTime.now(),
      );
    } catch (error, stackTrace) {
      diagnostics.error(
        scope: 'app_access.resolve',
        message: 'Workspace bootstrap failed unexpectedly.',
        error: error,
        stackTrace: stackTrace,
      );
      return AppAccessState(
        stage: AppAccessStage.bootstrapFailed,
        backendHealth: health,
        message: error.toString(),
        checkedAt: DateTime.now(),
      );
    }
  }
}

final appBootstrapProvider = Provider<AppBootstrap?>((ref) {
  return ref.watch(appAccessStateProvider).value?.bootstrap;
});

final offlineQueueControllerProvider =
    AsyncNotifierProvider<OfflineQueueController, void>(
      OfflineQueueController.new,
    );

class OfflineQueueController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final scope = ref.watch(offlineStorageScopeProvider);
    final queue = await ref.read(offlineQueueStoreProvider).load(scope);
    ref.read(offlineSyncStateProvider.notifier).replaceQueue(queue);
  }

  Future<void> refresh() async {
    final scope = ref.read(offlineStorageScopeProvider);
    final queue = await ref.read(offlineQueueStoreProvider).load(scope);
    ref.read(offlineSyncStateProvider.notifier).replaceQueue(queue);
    ref.read(offlineQueueRevisionProvider.notifier).state++;
  }

  Future<void> cancel(String id) async {
    final scope = ref.read(offlineStorageScopeProvider);
    final store = ref.read(offlineQueueStoreProvider);
    final queue = await store.load(scope);
    final next = queue.where((entry) => entry.id != id).toList();
    await store.save(scope, next);
    ref.read(offlineSyncStateProvider.notifier).replaceQueue(next);
    ref.read(offlineQueueRevisionProvider.notifier).state++;
  }

  Future<void> retryOne(String id) async {
    await _replay(onlyId: id);
  }

  Future<void> retryAll() async {
    await _replay();
  }

  String? _extractCreatedId(Object? data) {
    if (data is Map) {
      final id =
          data['id'] ??
          data['content_record_id'] ??
          data['plan_id'] ??
          data['record_id'];
      if (id != null) {
        return id.toString();
      }
    }
    return null;
  }

  List<String> _unresolvedDependencies(
    QueuedOfflineAction action,
    Map<String, String> idMappings,
  ) {
    return action.dependsOnTempIds
        .where((tempId) => !idMappings.containsKey(tempId))
        .toList();
  }

  Future<List<QueuedOfflineAction>> _reconcileTempId({
    required String scope,
    required List<QueuedOfflineAction> queue,
    required String tempId,
    required String realId,
  }) async {
    if (tempId == realId) {
      return queue;
    }

    final idMappings = {tempId: realId};
    await ref
        .read(offlineIdMappingStoreProvider)
        .register(scope, tempId, realId);
    await ref.read(offlineCacheStoreProvider).rewriteIds(scope, idMappings);
    ref.read(offlineSyncStateProvider.notifier).rewriteIds(idMappings);
    return queue.map((entry) => entry.rewriteIds(idMappings)).toList();
  }

  Future<void> _replay({String? onlyId}) async {
    final authSession = ref.read(authSessionProvider);
    if (authSession.isLoading) {
      return;
    }

    final scope = ref.read(offlineStorageScopeProvider);
    final store = ref.read(offlineQueueStoreProvider);
    final api = ref.read(apiServiceProvider);
    var queue = await store.load(scope);
    var idMappings = await ref.read(offlineIdMappingStoreProvider).load(scope);
    if (queue.isEmpty) {
      return;
    }

    final sync = ref.read(offlineSyncStateProvider.notifier);
    sync.setReplaying(true);
    sync.setReplayError(null);
    var shouldRefreshWorkspaceData = false;

    try {
      for (var index = 0; index < queue.length; index++) {
        final action = queue[index];
        if (onlyId != null && action.id != onlyId) {
          continue;
        }
        if (action.status == OfflineQueueStatus.cancelled) {
          continue;
        }

        final unresolvedDependencies = _unresolvedDependencies(
          action,
          idMappings,
        );
        if (unresolvedDependencies.isNotEmpty) {
          queue[index] = action.copyWith(
            status: OfflineQueueStatus.blockedDependency,
            lastError: 'Waiting for queued dependency sync.',
            updatedAt: DateTime.now(),
          );
          await store.save(scope, queue);
          sync.replaceQueue(queue);
          ref.read(offlineQueueRevisionProvider.notifier).state++;
          continue;
        }

        final retrying = action.copyWith(
          status: OfflineQueueStatus.retrying,
          attemptCount: action.attemptCount + 1,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
        queue[index] = retrying;
        await store.save(scope, queue);
        sync.replaceQueue(queue);
        ref.read(offlineQueueRevisionProvider.notifier).state++;

        try {
          final responseData = await api.replayQueuedAction(retrying);
          queue.removeAt(index);
          index--;
          final tempId = retrying.meta['tempId']?.toString();
          final realId = _extractCreatedId(responseData);
          if (tempId != null &&
              tempId.isNotEmpty &&
              realId != null &&
              realId.isNotEmpty &&
              tempId != realId) {
            idMappings = {...idMappings, tempId: realId};
            queue = await _reconcileTempId(
              scope: scope,
              queue: queue,
              tempId: tempId,
              realId: realId,
            );
          }
          await store.save(scope, queue);
          sync.replaceQueue(queue);
          shouldRefreshWorkspaceData = true;
          ref.read(offlineQueueRevisionProvider.notifier).state++;
        } on ApiException catch (error) {
          final nextStatus = switch (error.statusCode) {
            401 || 403 => OfflineQueueStatus.pausedAuth,
            final code when code != null && code >= 400 && code < 500 =>
              OfflineQueueStatus.failed,
            _ => OfflineQueueStatus.pending,
          };
          queue[index] = retrying.copyWith(
            status: nextStatus,
            lastError: error.message,
            updatedAt: DateTime.now(),
          );
          await store.save(scope, queue);
          sync.replaceQueue(queue);
          sync.setReplayError(error.message);
          ref.read(offlineQueueRevisionProvider.notifier).state++;

          if (nextStatus == OfflineQueueStatus.pausedAuth ||
              nextStatus == OfflineQueueStatus.pending) {
            break;
          }
        }
      }
    } finally {
      sync.setReplaying(false);
      ref.read(offlineQueueRevisionProvider.notifier).state++;
      if (shouldRefreshWorkspaceData) {
        ref.invalidate(appBootstrapProvider);
        ref.invalidate(projectsProvider);
        ref.invalidate(projectsStateProvider);
        ref.invalidate(currentUserSettingsProvider);
        ref.invalidate(personasProvider);
        ref.invalidate(affiliationsProvider);
        ref.invalidate(pendingContentProvider);
        ref.invalidate(dripPlansProvider);
        ref.invalidate(offlineIdMappingsProvider);
      }
      unawaited(ref.read(appAccessStateProvider.notifier).refresh());
    }
  }
}

class ProjectsState {
  const ProjectsState({
    this.items = const <Project>[],
    this.message,
    this.isDegraded = false,
  });

  final List<Project> items;
  final String? message;
  final bool isDegraded;
}

final projectsStateProvider = FutureProvider<ProjectsState>((ref) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const ProjectsState();
  }

  final api = ref.read(apiServiceProvider);
  try {
    final projects = await api.fetchProjects();
    return ProjectsState(items: projects);
  } catch (error, stackTrace) {
    if (!_isNonCriticalReadFailure(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'projects.read.degraded',
      message:
          'Projects fetch failed; project UI will stay available in degraded mode.',
      error: error,
      stackTrace: stackTrace,
    );
    return ProjectsState(message: error.toString(), isDegraded: true);
  }
});

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final state = await ref.watch(projectsStateProvider.future);
  return state.items;
});

final availableProjectsProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsProvider).value ?? const <Project>[];
  return projects.where((project) => !project.isDeleted).toList();
});

final activeProjectProvider = Provider<Project?>((ref) {
  final availableProjects = ref.watch(availableProjectsProvider);
  final selectableProjects = availableProjects
      .where((project) => !project.isArchived)
      .toList();
  if (selectableProjects.isEmpty) {
    return null;
  }

  final userSettings = ref.watch(currentUserSettingsProvider).value;
  final bootstrap = ref.watch(appBootstrapProvider);
  if (userSettings == null &&
      bootstrap != null &&
      bootstrap.user.workspaceExists &&
      (bootstrap.defaultProjectId == null ||
          bootstrap.defaultProjectId!.trim().isEmpty)) {
    return null;
  }
  final selectionMode = normalizeProjectSelectionMode(
    userSettings?.projectSelectionMode,
  );

  Project? byId(String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    for (final project in selectableProjects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  if (selectionMode == projectSelectionModeNone) {
    return null;
  }

  if (selectionMode == projectSelectionModeSelected) {
    return byId(userSettings?.defaultProjectId);
  }

  return byId(userSettings?.defaultProjectId) ??
      byId(bootstrap?.defaultProjectId) ??
      selectableProjects.cast<Project?>().firstWhere(
        (project) => project?.isDefault == true,
        orElse: () => selectableProjects.first,
      );
});

final activeProjectIdProvider = Provider<String?>((ref) {
  return ref.watch(activeProjectProvider.select((project) => project?.id));
});

class BrandProfilesState {
  const BrandProfilesState({
    this.items = const <BrandProfile>[],
    this.message,
    this.isDegraded = false,
  });

  final List<BrandProfile> items;
  final String? message;
  final bool isDegraded;
}

class BrandProfileBlueprintsState {
  const BrandProfileBlueprintsState({
    this.items = const <BrandVideoBlueprint>[],
    this.message,
    this.isDegraded = false,
  });

  final List<BrandVideoBlueprint> items;
  final String? message;
  final bool isDegraded;
}

final brandProfilesStateProvider = FutureProvider<BrandProfilesState>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const BrandProfilesState();
  }

  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const BrandProfilesState();
  }

  final api = ref.watch(apiServiceProvider);
  try {
    final profiles = await api.fetchBrandProfiles(projectId: activeProjectId);
    return BrandProfilesState(items: profiles);
  } catch (error, stackTrace) {
    if (!_isNonCriticalReadFailure(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'brand_profiles.read.degraded',
      message:
          'Brand profiles fetch failed; the branding settings view will stay available in degraded mode.',
      error: error,
      stackTrace: stackTrace,
    );
    return BrandProfilesState(message: error.toString(), isDegraded: true);
  }
});

final brandProfileBlueprintsStateProvider =
    FutureProvider<BrandProfileBlueprintsState>((ref) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const BrandProfileBlueprintsState();
  }

  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const BrandProfileBlueprintsState();
  }

  final api = ref.watch(apiServiceProvider);
  try {
    final blueprints = await api.fetchBrandProfilesBlueprintsForProject(
      projectId: activeProjectId,
    );
    return BrandProfileBlueprintsState(items: blueprints);
  } catch (error, stackTrace) {
    if (!_isNonCriticalReadFailure(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'brand_profile_blueprints.read.degraded',
      message:
          'Brand blueprint list fetch failed; profile screens keep a best-effort list.',
      error: error,
      stackTrace: stackTrace,
    );
    return BrandProfileBlueprintsState(
      message: error.toString(),
      isDegraded: true,
    );
  }
});

final brandProfilesProvider = FutureProvider<List<BrandProfile>>((ref) async {
  final state = await ref.watch(brandProfilesStateProvider.future);
  return state.items;
});

final brandProfileControllerProvider =
    AsyncNotifierProvider<BrandProfileController, void>(
      BrandProfileController.new,
    );

class BrandProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createBrandProfile({required BrandProfileDraft draft}) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null) {
      throw StateError('No active project selected.');
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.createBrandProfile(projectId: projectId, draft: draft);
      ref.invalidate(brandProfilesStateProvider);
      ref.invalidate(brandProfilesProvider);
      ref.invalidate(brandProfileBlueprintsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> updateBrandProfile({
    required String brandProfileId,
    required BrandProfileDraft draft,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.updateBrandProfile(
        brandProfileId: brandProfileId,
        draft: draft,
      );
      ref.invalidate(brandProfilesStateProvider);
      ref.invalidate(brandProfilesProvider);
      ref.invalidate(brandProfileBlueprintsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> setDefaultBrandProfile(String brandProfileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.setDefaultBrandProfile(brandProfileId: brandProfileId);
      ref.invalidate(brandProfilesStateProvider);
      ref.invalidate(brandProfilesProvider);
      ref.invalidate(brandProfileBlueprintsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> deleteBrandProfile(String brandProfileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.deleteBrandProfile(brandProfileId: brandProfileId);
      ref.invalidate(brandProfilesStateProvider);
      ref.invalidate(brandProfilesProvider);
      ref.invalidate(brandProfileBlueprintsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }
}

class ProjectAssetLibraryState {
  const ProjectAssetLibraryState({
    this.projectId,
    this.assets = const <ProjectAsset>[],
    this.total = 0,
    this.mediaKindFilter,
    this.sourceFilter,
    this.categoryFilter,
    this.subcategoryFilter,
    this.categoryCatalog,
    this.includeTombstoned = false,
    this.selectedAssetId,
    this.assetDetails = const <String, ProjectAsset>{},
    this.assetUsage = const <String, List<ProjectAssetUsage>>{},
    this.assetEvents = const <String, List<ProjectAssetEvent>>{},
    this.assetUnderstanding =
        const <String, AssetUnderstandingStatusResponse>{},
    this.assetRecommendations =
        const <String, List<ProjectAssetRecommendationItem>>{},
    this.lastError,
    this.isMutating = false,
  });

  final String? projectId;
  final List<ProjectAsset> assets;
  final int total;
  final String? mediaKindFilter;
  final String? sourceFilter;
  final String? categoryFilter;
  final String? subcategoryFilter;
  final ProjectAssetCategoryCatalog? categoryCatalog;
  final bool includeTombstoned;
  final String? selectedAssetId;
  final Map<String, ProjectAsset> assetDetails;
  final Map<String, List<ProjectAssetUsage>> assetUsage;
  final Map<String, List<ProjectAssetEvent>> assetEvents;
  final Map<String, AssetUnderstandingStatusResponse> assetUnderstanding;
  final Map<String, List<ProjectAssetRecommendationItem>> assetRecommendations;
  final Object? lastError;
  final bool isMutating;

  ProjectAsset? get selectedAsset {
    final id = selectedAssetId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return assetDetails[id] ??
        assets.cast<ProjectAsset?>().firstWhere(
          (entry) => entry?.id == id,
          orElse: () => null,
        );
  }

  ProjectAssetLibraryState copyWith({
    String? projectId,
    bool clearProjectId = false,
    List<ProjectAsset>? assets,
    int? total,
    String? mediaKindFilter,
    bool clearMediaKindFilter = false,
    String? sourceFilter,
    bool clearSourceFilter = false,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    String? subcategoryFilter,
    bool clearSubcategoryFilter = false,
    ProjectAssetCategoryCatalog? categoryCatalog,
    bool? includeTombstoned,
    String? selectedAssetId,
    bool clearSelectedAssetId = false,
    Map<String, ProjectAsset>? assetDetails,
    Map<String, List<ProjectAssetUsage>>? assetUsage,
    Map<String, List<ProjectAssetEvent>>? assetEvents,
    Map<String, AssetUnderstandingStatusResponse>? assetUnderstanding,
    Map<String, List<ProjectAssetRecommendationItem>>? assetRecommendations,
    Object? lastError,
    bool clearLastError = false,
    bool? isMutating,
  }) {
    return ProjectAssetLibraryState(
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      assets: assets ?? this.assets,
      total: total ?? this.total,
      mediaKindFilter: clearMediaKindFilter
          ? null
          : (mediaKindFilter ?? this.mediaKindFilter),
      sourceFilter: clearSourceFilter
          ? null
          : (sourceFilter ?? this.sourceFilter),
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      subcategoryFilter: clearSubcategoryFilter
          ? null
          : (subcategoryFilter ?? this.subcategoryFilter),
      categoryCatalog: categoryCatalog ?? this.categoryCatalog,
      includeTombstoned: includeTombstoned ?? this.includeTombstoned,
      selectedAssetId: clearSelectedAssetId
          ? null
          : (selectedAssetId ?? this.selectedAssetId),
      assetDetails: assetDetails ?? this.assetDetails,
      assetUsage: assetUsage ?? this.assetUsage,
      assetEvents: assetEvents ?? this.assetEvents,
      assetUnderstanding: assetUnderstanding ?? this.assetUnderstanding,
      assetRecommendations: assetRecommendations ?? this.assetRecommendations,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      isMutating: isMutating ?? this.isMutating,
    );
  }

  factory ProjectAssetLibraryState.empty([String? projectId]) {
    return ProjectAssetLibraryState(projectId: projectId);
  }
}

final projectAssetLibraryProvider =
    AsyncNotifierProvider<
      ProjectAssetLibraryNotifier,
      ProjectAssetLibraryState
    >(ProjectAssetLibraryNotifier.new);

class ProjectAssetLibraryNotifier
    extends AsyncNotifier<ProjectAssetLibraryState> {
  int _contextRevision = 0;

  bool _isFresh(String projectId, int revision) {
    return revision == _contextRevision &&
        ref.read(activeProjectIdProvider) == projectId;
  }

  bool _isActiveProjectState(String projectId) {
    return ref.read(activeProjectIdProvider) == projectId &&
        state.asData?.value.projectId == projectId;
  }

  @override
  Future<ProjectAssetLibraryState> build() async {
    final projectId = ref.watch(activeProjectIdProvider);
    final previous = state.asData?.value;
    _contextRevision++;
    final revision = _contextRevision;
    if (projectId == null || projectId.isEmpty) {
      return ProjectAssetLibraryState.empty();
    }

    final mediaKindFilter = previous?.projectId == projectId
        ? previous?.mediaKindFilter
        : null;
    final sourceFilter = previous?.projectId == projectId
        ? previous?.sourceFilter
        : null;
    final categoryFilter = previous?.projectId == projectId
        ? previous?.categoryFilter
        : null;
    final subcategoryFilter = previous?.projectId == projectId
        ? previous?.subcategoryFilter
        : null;
    final includeTombstoned = previous?.projectId == projectId
        ? previous?.includeTombstoned ?? false
        : false;
    try {
      final api = ref.read(apiServiceProvider);
      final locale = ref.watch(projectAssetCategoryLocaleProvider);
      ProjectAssetCategoryCatalog? categoryCatalog;
      try {
        categoryCatalog = await api.getProjectAssetCategoryCatalog(
          projectId: projectId,
          locale: locale,
        );
      } catch (_) {
        categoryCatalog = previous?.categoryCatalog;
      }
      final response = await api.listProjectAssets(
        projectId: projectId,
        mediaKind: mediaKindFilter,
        source: sourceFilter,
        categoryId: categoryFilter,
        subcategoryId: subcategoryFilter,
        includeTombstoned: includeTombstoned,
      );
      if (!_isFresh(projectId, revision)) {
        return previous ?? ProjectAssetLibraryState.empty(projectId);
      }
      return ProjectAssetLibraryState(
        projectId: projectId,
        assets: response.items,
        total: response.total,
        mediaKindFilter: mediaKindFilter,
        sourceFilter: sourceFilter,
        categoryFilter: categoryFilter,
        subcategoryFilter: subcategoryFilter,
        categoryCatalog: categoryCatalog,
        includeTombstoned: includeTombstoned,
      );
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        return previous ?? ProjectAssetLibraryState.empty(projectId);
      }
      return ProjectAssetLibraryState(
        projectId: projectId,
        mediaKindFilter: mediaKindFilter,
        sourceFilter: sourceFilter,
        categoryFilter: categoryFilter,
        subcategoryFilter: subcategoryFilter,
        categoryCatalog: previous?.categoryCatalog,
        includeTombstoned: includeTombstoned,
        lastError: error,
      );
    }
  }

  void setMediaKindFilter(String? value) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        mediaKindFilter: value,
        clearMediaKindFilter: value == null || value.trim().isEmpty,
        clearSelectedAssetId: true,
      ),
    );
    ref.invalidateSelf();
  }

  void setSourceFilter(String? value) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        sourceFilter: value,
        clearSourceFilter: value == null || value.trim().isEmpty,
        clearSelectedAssetId: true,
      ),
    );
    ref.invalidateSelf();
  }

  void setCategoryFilter(String? value) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        categoryFilter: value,
        clearCategoryFilter: value == null || value.trim().isEmpty,
        clearSubcategoryFilter: true,
        clearSelectedAssetId: true,
      ),
    );
    ref.invalidateSelf();
  }

  void setSubcategoryFilter(String? value) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        subcategoryFilter: value,
        clearSubcategoryFilter: value == null || value.trim().isEmpty,
        clearSelectedAssetId: true,
      ),
    );
    ref.invalidateSelf();
  }

  void setIncludeTombstoned(bool value) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(includeTombstoned: value, clearSelectedAssetId: true),
    );
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> selectAsset(String? assetId) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    if (assetId == null || assetId.isEmpty) {
      state = AsyncData(current.copyWith(clearSelectedAssetId: true));
      return;
    }
    state = AsyncData(
      current.copyWith(selectedAssetId: assetId, clearLastError: true),
    );
    await loadSelectedAssetDetail();
  }

  Future<void> loadSelectedAssetDetail() async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final projectId = current.projectId;
    final assetId = current.selectedAssetId;
    if (projectId == null || assetId == null) {
      return;
    }
    final revision = _contextRevision;
    try {
      final api = ref.read(apiServiceProvider);
      final detail = await api.getProjectAssetDetail(
        projectId: projectId,
        assetId: assetId,
      );
      final usage = await api.getProjectAssetUsage(
        projectId: projectId,
        assetId: assetId,
      );
      final events = await api.getProjectAssetEvents(
        projectId: projectId,
        assetId: assetId,
      );
      final understanding = await api.getProjectAssetUnderstandingStatus(
        projectId: projectId,
        assetId: assetId,
      );
      if (!_isFresh(projectId, revision)) {
        return;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(
        fresh.copyWith(
          assetDetails: {...fresh.assetDetails, assetId: detail},
          assetUsage: {...fresh.assetUsage, assetId: usage},
          assetEvents: {...fresh.assetEvents, assetId: events},
          assetUnderstanding: {
            ...fresh.assetUnderstanding,
            assetId: understanding,
          },
          clearLastError: true,
        ),
      );
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        return;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(lastError: error));
    }
  }

  Future<AssetUnderstandingJob?> queueUnderstanding({
    required String assetId,
    String provider = 'gemini_compatible',
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    final idempotencyKey =
        'app-$assetId-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final job = await ref
          .read(apiServiceProvider)
          .queueProjectAssetUnderstanding(
            projectId: projectId,
            assetId: assetId,
            idempotencyKey: idempotencyKey,
            provider: provider,
          );
      if (!_isFresh(projectId, revision)) {
        return job;
      }
      final status = await ref
          .read(apiServiceProvider)
          .getProjectAssetUnderstandingStatus(
            projectId: projectId,
            assetId: assetId,
          );
      if (!_isFresh(projectId, revision)) {
        return job;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(
        fresh.copyWith(
          isMutating: false,
          assetUnderstanding: {...fresh.assetUnderstanding, assetId: status},
        ),
      );
      return job;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<AssetUnderstandingStatusResponse?> refreshUnderstandingStatus({
    required String assetId,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    try {
      final status = await ref
          .read(apiServiceProvider)
          .getProjectAssetUnderstandingStatus(
            projectId: projectId,
            assetId: assetId,
          );
      if (!_isFresh(projectId, revision)) {
        return status;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(
        fresh.copyWith(
          assetUnderstanding: {...fresh.assetUnderstanding, assetId: status},
          clearLastError: true,
        ),
      );
      return status;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(lastError: error));
      rethrow;
    }
  }

  Future<AssetUnderstandingJob?> retryUnderstanding({
    required String assetId,
    required String jobId,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final job = await ref
          .read(apiServiceProvider)
          .retryProjectAssetUnderstanding(
            projectId: projectId,
            assetId: assetId,
            jobId: jobId,
          );
      if (!_isFresh(projectId, revision)) {
        return job;
      }
      await refreshUnderstandingStatus(assetId: assetId);
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      return job;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<AssetUnderstandingStatusResponse?> moderateTags({
    required String assetId,
    List<Map<String, dynamic>> decisions = const <Map<String, dynamic>>[],
    List<String> manualTags = const <String>[],
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final status = await ref
          .read(apiServiceProvider)
          .moderateProjectAssetTags(
            projectId: projectId,
            assetId: assetId,
            decisions: decisions,
            manualTags: manualTags,
          );
      if (!_isFresh(projectId, revision)) {
        return status;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(
        fresh.copyWith(
          isMutating: false,
          assetUnderstanding: {...fresh.assetUnderstanding, assetId: status},
        ),
      );
      return status;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<List<ProjectAssetRecommendationItem>> recommendAssets({
    List<String> desiredTags = const <String>[],
    int limit = 10,
    bool includeGlobalCandidates = true,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return const <ProjectAssetRecommendationItem>[];
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final response = await ref
          .read(apiServiceProvider)
          .recommendProjectAssets(
            projectId: projectId,
            desiredTags: desiredTags,
            limit: limit,
            includeGlobalCandidates: includeGlobalCandidates,
          );
      if (!_isFresh(projectId, revision)) {
        return response.items;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(
        fresh.copyWith(
          isMutating: false,
          assetRecommendations: {
            ...fresh.assetRecommendations,
            for (final item in response.items) item.assetId: [item],
          },
        ),
      );
      return response.items;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<ProjectAsset?> attachGlobalAsset({
    required String globalAssetId,
    String? selectForAssetIdAfterAttach,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final asset = await ref
          .read(apiServiceProvider)
          .attachGlobalProjectAsset(
            projectId: projectId,
            globalAssetId: globalAssetId,
          );
      if (!_isFresh(projectId, revision)) {
        return asset;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return asset;
      }
      await selectAsset(selectForAssetIdAfterAttach ?? asset.id);
      return asset;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<ProjectAsset?> assignCategory({
    required String assetId,
    String? categoryId,
    String? subcategoryId,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final asset = await ref
          .read(apiServiceProvider)
          .assignProjectAssetCategory(
            projectId: projectId,
            assetId: assetId,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
          );
      if (!_isFresh(projectId, revision)) {
        return asset;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return asset;
      }
      await selectAsset(assetId);
      return asset;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<ProjectAssetUsage?> selectForTarget({
    required String assetId,
    required String targetType,
    required String targetId,
    required String usageAction,
    String? placement,
    bool isPrimary = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final usage = await ref
          .read(apiServiceProvider)
          .selectProjectAsset(
            projectId: projectId,
            assetId: assetId,
            targetType: targetType,
            targetId: targetId,
            usageAction: usageAction,
            placement: placement,
            isPrimary: isPrimary,
            metadata: metadata,
          );
      if (!_isFresh(projectId, revision)) {
        return usage;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return usage;
      }
      await selectAsset(assetId);
      return usage;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<ProjectAssetUsage?> setPrimary({
    required String assetId,
    required String targetType,
    required String targetId,
    required String usageAction,
    String? placement,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return null;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final usage = await ref
          .read(apiServiceProvider)
          .setProjectAssetPrimary(
            projectId: projectId,
            assetId: assetId,
            targetType: targetType,
            targetId: targetId,
            usageAction: usageAction,
            placement: placement,
            metadata: metadata,
          );
      if (!_isFresh(projectId, revision)) {
        return usage;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return usage;
      }
      await selectAsset(assetId);
      return usage;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<int> clearPrimary({
    required String targetType,
    required String targetId,
    String? placement,
  }) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return 0;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      final cleared = await ref
          .read(apiServiceProvider)
          .clearProjectAssetPrimary(
            projectId: projectId,
            targetType: targetType,
            targetId: targetId,
            placement: placement,
          );
      if (!_isFresh(projectId, revision)) {
        return cleared;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      return cleared;
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<void> tombstoneAsset(String assetId) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      await ref
          .read(apiServiceProvider)
          .tombstoneProjectAsset(projectId: projectId, assetId: assetId);
      if (!_isFresh(projectId, revision)) {
        return;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return;
      }
      await selectAsset(assetId);
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }

  Future<void> restoreAsset(String assetId) async {
    final current = state.asData?.value;
    final projectId = current?.projectId;
    if (current == null || projectId == null) {
      return;
    }
    final revision = _contextRevision;
    state = AsyncData(current.copyWith(isMutating: true, clearLastError: true));
    try {
      await ref
          .read(apiServiceProvider)
          .restoreProjectAsset(projectId: projectId, assetId: assetId);
      if (!_isFresh(projectId, revision)) {
        return;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false));
      await refresh();
      if (!_isActiveProjectState(projectId)) {
        return;
      }
      await selectAsset(assetId);
    } catch (error) {
      if (!_isFresh(projectId, revision)) {
        rethrow;
      }
      final fresh = state.asData?.value ?? current;
      state = AsyncData(fresh.copyWith(isMutating: false, lastError: error));
      rethrow;
    }
  }
}

class SocialPlacementState {
  const SocialPlacementState({
    required this.contentId,
    this.projectId,
    this.plan,
    this.preflight,
    this.isLoadingPlan = false,
    this.isRunningPreflight = false,
    this.needsRegistryRefresh = false,
    this.lastError,
  });

  final String contentId;
  final String? projectId;
  final PlacementPlan? plan;
  final PublishPreflightResponse? preflight;
  final bool isLoadingPlan;
  final bool isRunningPreflight;
  final bool needsRegistryRefresh;
  final Object? lastError;

  String? get registryVersion =>
      preflight?.registryVersion ?? plan?.registryVersion;

  bool get isBusy => isLoadingPlan || isRunningPreflight;

  bool get hasBlockingIssues =>
      needsRegistryRefresh || preflight?.hasBlockingIssues == true;

  List<PlatformPlacementPlan> get displayPlatforms {
    final currentPlan = plan;
    final currentPreflight = preflight;
    if (currentPreflight == null) {
      return currentPlan?.platforms ?? const <PlatformPlacementPlan>[];
    }
    final planByPlatform = <String, PlatformPlacementPlan>{
      for (final platform
          in currentPlan?.platforms ?? const <PlatformPlacementPlan>[])
        platform.platformId: platform,
    };
    return currentPreflight.platforms.map((platform) {
      final planned = planByPlatform[platform.platformId];
      final labels = <String, String>{
        for (final slot in planned?.slots ?? const <PlacementSlot>[])
          slot.placementId: slot.label,
      };
      return PlatformPlacementPlan(
        platformId: platform.platformId,
        label: planned?.label ?? platform.platformId,
        canPublish: platform.canPublish,
        slots: platform.slots
            .map(
              (slot) =>
                  slot.copyWith(label: labels[slot.placementId] ?? slot.label),
            )
            .toList(),
        issues: platform.issues,
      );
    }).toList();
  }

  SocialPlacementState copyWith({
    String? projectId,
    PlacementPlan? plan,
    bool clearPlan = false,
    PublishPreflightResponse? preflight,
    bool clearPreflight = false,
    bool? isLoadingPlan,
    bool? isRunningPreflight,
    bool? needsRegistryRefresh,
    Object? lastError,
    bool clearLastError = false,
  }) {
    return SocialPlacementState(
      contentId: contentId,
      projectId: projectId ?? this.projectId,
      plan: clearPlan ? null : (plan ?? this.plan),
      preflight: clearPreflight ? null : (preflight ?? this.preflight),
      isLoadingPlan: isLoadingPlan ?? this.isLoadingPlan,
      isRunningPreflight: isRunningPreflight ?? this.isRunningPreflight,
      needsRegistryRefresh: needsRegistryRefresh ?? this.needsRegistryRefresh,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

final socialPlacementProvider = StateNotifierProvider.autoDispose
    .family<SocialPlacementNotifier, SocialPlacementState, String>((
      ref,
      contentId,
    ) {
      final projectId = ref.watch(activeProjectIdProvider);
      return SocialPlacementNotifier(
        ref: ref,
        contentId: contentId,
        projectId: projectId,
      );
    });

class SocialPlacementNotifier extends StateNotifier<SocialPlacementState> {
  SocialPlacementNotifier({
    required this.ref,
    required String contentId,
    required String? projectId,
  }) : super(SocialPlacementState(contentId: contentId, projectId: projectId));

  final Ref ref;
  int _revision = 0;
  bool _disposed = false;

  bool _isFresh(int revision) {
    return !_disposed &&
        revision == _revision &&
        ref.read(activeProjectIdProvider) == state.projectId;
  }

  Future<PlacementPlan?> loadPlan({
    required List<String> platforms,
    required String locale,
  }) async {
    final normalizedPlatforms = platforms
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedPlatforms.isEmpty) {
      state = state.copyWith(
        clearPlan: true,
        clearPreflight: true,
        needsRegistryRefresh: false,
        clearLastError: true,
      );
      return null;
    }
    final revision = ++_revision;
    state = state.copyWith(
      isLoadingPlan: true,
      clearPreflight: true,
      clearLastError: true,
    );
    try {
      final plan = await ref
          .read(apiServiceProvider)
          .fetchPlacementPlan(
            contentId: state.contentId,
            platforms: normalizedPlatforms,
            locale: locale,
          );
      if (!_isFresh(revision) || plan.contentId != state.contentId) {
        return null;
      }
      state = state.copyWith(
        plan: plan,
        isLoadingPlan: false,
        needsRegistryRefresh: false,
        clearLastError: true,
      );
      return plan;
    } catch (error) {
      if (_isFresh(revision)) {
        state = state.copyWith(isLoadingPlan: false, lastError: error);
      }
      return null;
    }
  }

  Future<PublishPreflightResponse?> runPreflight({
    required List<PublishPlatformTarget> platforms,
    bool refreshPlanOnStale = true,
    List<String> planPlatforms = const <String>[],
    String locale = 'en',
  }) async {
    if (platforms.isEmpty) return null;
    final revision = ++_revision;
    final requestedVersion = state.plan?.registryVersion;
    state = state.copyWith(isRunningPreflight: true, clearLastError: true);
    try {
      final preflight = await ref
          .read(apiServiceProvider)
          .preflightPublish(
            contentRecordId: state.contentId,
            platforms: platforms,
            registryVersion: requestedVersion,
          );
      if (!_isFresh(revision) || preflight.contentId != state.contentId) {
        return null;
      }
      final stale =
          requestedVersion != null &&
          requestedVersion != preflight.registryVersion;
      state = state.copyWith(
        preflight: preflight,
        isRunningPreflight: false,
        needsRegistryRefresh: stale,
        clearLastError: true,
      );
      if (stale && refreshPlanOnStale && planPlatforms.isNotEmpty) {
        await loadPlan(platforms: planPlatforms, locale: locale);
        return runPreflight(
          platforms: platforms,
          refreshPlanOnStale: false,
          planPlatforms: planPlatforms,
          locale: locale,
        );
      }
      return preflight;
    } catch (error) {
      if (_isFresh(revision)) {
        state = state.copyWith(isRunningPreflight: false, lastError: error);
      }
      return null;
    }
  }

  Future<void> refresh({
    required List<String> planPlatforms,
    required List<PublishPlatformTarget> publishTargets,
    required String locale,
  }) async {
    final plan = await loadPlan(platforms: planPlatforms, locale: locale);
    if (plan == null || publishTargets.isEmpty) return;
    await runPreflight(
      platforms: publishTargets,
      planPlatforms: planPlatforms,
      locale: locale,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}

class PublishAccountsState {
  const PublishAccountsState({
    this.accounts = const <PublishAccount>[],
    this.availability = PublishAccountsAvailability.available,
    this.message,
  });

  final List<PublishAccount> accounts;
  final PublishAccountsAvailability availability;
  final String? message;

  bool get isAvailable => availability == PublishAccountsAvailability.available;
  bool get isUnavailable =>
      availability == PublishAccountsAvailability.unavailable;
  bool get hasError => availability == PublishAccountsAvailability.error;
}

enum PublishAccountsAvailability { available, unavailable, error }

class GithubIntegrationState {
  const GithubIntegrationState({
    this.connected = false,
    this.username,
    this.scope,
    this.message,
  });

  final bool connected;
  final String? username;
  final String? scope;
  final String? message;
}

final githubIntegrationStatusProvider = FutureProvider<GithubIntegrationState>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const GithubIntegrationState();
  }

  try {
    final status = await ref
        .watch(apiServiceProvider)
        .fetchGithubIntegrationStatus();
    return GithubIntegrationState(
      connected: status['connected'] as bool? ?? false,
      username: status['github_username']?.toString(),
      scope: (status['scope'] is List)
          ? (status['scope'] as List).join(', ')
          : status['scope']?.toString(),
      message: status['message']?.toString(),
    );
  } on ApiException catch (error) {
    return GithubIntegrationState(message: error.message.trim());
  }
});

final searchConsolePeriodProvider = StateProvider<String>((ref) => '30d');

final searchConsoleConnectionStatusProvider =
    FutureProvider<SearchConsoleConnectionStatus>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null) {
        return SearchConsoleConnectionStatus.missing();
      }
      if (accessState?.canUseWorkspaceData != true) {
        return SearchConsoleConnectionStatus.missing(activeProjectId);
      }

      try {
        return await ref
            .watch(apiServiceProvider)
            .fetchSearchConsoleStatus(projectId: activeProjectId);
      } on ApiException catch (error) {
        return SearchConsoleConnectionStatus(
          projectId: activeProjectId,
          connected: false,
          status: 'degraded',
          validationStatus: 'error',
          lastSyncMessage: error.message.trim(),
        );
      }
    });

final searchConsolePropertiesProvider =
    FutureProvider<List<SearchConsoleProperty>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      final status = await ref.watch(
        searchConsoleConnectionStatusProvider.future,
      );
      if (activeProjectId == null ||
          accessState?.canUseWorkspaceData != true ||
          !status.connected) {
        return const <SearchConsoleProperty>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchSearchConsoleProperties(projectId: activeProjectId);
    });

final searchConsoleSummaryProvider = FutureProvider<SearchConsoleSummary?>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  final activeProjectId = ref.watch(activeProjectIdProvider);
  final period = ref.watch(searchConsolePeriodProvider);
  if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
    return null;
  }
  return ref
      .watch(apiServiceProvider)
      .fetchSearchConsoleSummary(projectId: activeProjectId, period: period);
});

final searchConsoleOpportunitiesProvider =
    FutureProvider<List<SearchConsoleOpportunity>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      final period = ref.watch(searchConsolePeriodProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <SearchConsoleOpportunity>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchSearchConsoleOpportunities(
            projectId: activeProjectId,
            period: period,
          );
    });

final projectIntelligenceStatusProvider =
    FutureProvider<ProjectIntelligenceStatus>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null) {
        return ProjectIntelligenceStatus.empty();
      }
      if (accessState?.canUseWorkspaceData != true) {
        return ProjectIntelligenceStatus.empty(activeProjectId);
      }
      try {
        return await ref
            .watch(apiServiceProvider)
            .fetchProjectIntelligenceStatus(projectId: activeProjectId);
      } on ApiException catch (error) {
        return ProjectIntelligenceStatus(
          projectId: activeProjectId,
          counts: const <String, int>{},
          degraded: true,
          degradedReason: error.message.trim(),
        );
      }
    });

final projectIntelligenceSourcesProvider =
    FutureProvider<List<ProjectIntelligenceSource>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <ProjectIntelligenceSource>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceSources(projectId: activeProjectId);
    });

final projectIntelligenceDocumentsProvider =
    FutureProvider<List<ProjectIntelligenceDocument>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <ProjectIntelligenceDocument>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceDocuments(projectId: activeProjectId);
    });

final projectIntelligenceFactsProvider =
    FutureProvider<List<ProjectIntelligenceFact>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <ProjectIntelligenceFact>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceFacts(projectId: activeProjectId);
    });

final projectIntelligenceRecommendationsProvider =
    FutureProvider<List<ProjectIntelligenceRecommendation>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <ProjectIntelligenceRecommendation>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceRecommendations(projectId: activeProjectId);
    });

final projectIntelligenceJobsProvider =
    FutureProvider<List<ProjectIntelligenceJob>>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return const <ProjectIntelligenceJob>[];
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceJobs(projectId: activeProjectId);
    });

final projectIntelligenceProviderReadinessProvider =
    FutureProvider<ProjectIntelligenceProviderReadiness?>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      if (activeProjectId == null || accessState?.canUseWorkspaceData != true) {
        return null;
      }
      return ref
          .watch(apiServiceProvider)
          .fetchProjectIntelligenceProviderReadiness(
            projectId: activeProjectId,
          );
    });

class ProjectIntelligenceControllerState {
  const ProjectIntelligenceControllerState({
    this.isUploading = false,
    this.isSyncing = false,
    this.isMutating = false,
    this.lastMessage,
    this.lastError,
  });

  final bool isUploading;
  final bool isSyncing;
  final bool isMutating;
  final String? lastMessage;
  final String? lastError;

  ProjectIntelligenceControllerState copyWith({
    bool? isUploading,
    bool? isSyncing,
    bool? isMutating,
    String? lastMessage,
    String? lastError,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return ProjectIntelligenceControllerState(
      isUploading: isUploading ?? this.isUploading,
      isSyncing: isSyncing ?? this.isSyncing,
      isMutating: isMutating ?? this.isMutating,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final projectIntelligenceControllerProvider =
    StateNotifierProvider<
      ProjectIntelligenceController,
      ProjectIntelligenceControllerState
    >((ref) {
      return ProjectIntelligenceController(ref);
    });

class ProjectIntelligenceController
    extends StateNotifier<ProjectIntelligenceControllerState> {
  ProjectIntelligenceController(this.ref)
    : super(const ProjectIntelligenceControllerState());

  final Ref ref;

  Future<void> uploadTextSource({
    required String fileName,
    required String text,
    String mimeType = 'text/markdown',
    bool includeAiSynthesis = false,
  }) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null || text.trim().isEmpty) {
      return;
    }
    state = state.copyWith(
      isUploading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      final result = await ref
          .read(apiServiceProvider)
          .uploadProjectIntelligenceFiles(
            projectId: projectId,
            includeAiSynthesis: includeAiSynthesis,
            files: <ProjectIntelligenceUploadFile>[
              ProjectIntelligenceUploadFile(
                fileName: fileName.trim().isEmpty
                    ? 'source.md'
                    : fileName.trim(),
                mimeType: mimeType,
                bytes: Uint8List.fromList(utf8.encode(text)),
              ),
            ],
          );
      _invalidateReads();
      state = state.copyWith(
        isUploading: false,
        lastMessage: 'accepted:${result.accepted}, failed:${result.failed}',
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isUploading: false,
        lastError: error.message.trim(),
      );
      rethrow;
    }
  }

  Future<void> syncConnectors({
    List<String> connectors = const <String>[],
    bool includeAiSynthesis = false,
  }) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null) {
      return;
    }
    state = state.copyWith(
      isSyncing: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      final result = await ref
          .read(apiServiceProvider)
          .syncProjectIntelligence(
            projectId: projectId,
            connectors: connectors,
            includeAiSynthesis: includeAiSynthesis,
          );
      _invalidateReads();
      state = state.copyWith(
        isSyncing: false,
        lastMessage: 'accepted:${result.accepted}, failed:${result.failed}',
      );
    } on ApiException catch (error) {
      state = state.copyWith(isSyncing: false, lastError: error.message.trim());
      rethrow;
    }
  }

  Future<void> removeSource(String sourceId) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null) {
      return;
    }
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await ref
          .read(apiServiceProvider)
          .removeProjectIntelligenceSource(
            projectId: projectId,
            sourceId: sourceId,
          );
      _invalidateReads();
      state = state.copyWith(isMutating: false, lastMessage: 'source_removed');
    } on ApiException catch (error) {
      state = state.copyWith(
        isMutating: false,
        lastError: error.message.trim(),
      );
      rethrow;
    }
  }

  Future<void> addRecommendationToIdeaPool(String recommendationId) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null) {
      return;
    }
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final result = await ref
          .read(apiServiceProvider)
          .addProjectIntelligenceRecommendationToIdeaPool(
            projectId: projectId,
            recommendationId: recommendationId,
          );
      _invalidateReads();
      ref.invalidate(ideasProvider);
      state = state.copyWith(isMutating: false, lastMessage: result.action);
    } on ApiException catch (error) {
      state = state.copyWith(
        isMutating: false,
        lastError: error.message.trim(),
      );
      rethrow;
    }
  }

  void _invalidateReads() {
    ref.invalidate(projectIntelligenceStatusProvider);
    ref.invalidate(projectIntelligenceSourcesProvider);
    ref.invalidate(projectIntelligenceDocumentsProvider);
    ref.invalidate(projectIntelligenceFactsProvider);
    ref.invalidate(projectIntelligenceRecommendationsProvider);
    ref.invalidate(projectIntelligenceJobsProvider);
    ref.invalidate(projectIntelligenceProviderReadinessProvider);
  }
}

final openRouterCredentialStatusProvider =
    FutureProvider<OpenRouterCredentialStatus>((ref) async {
      final accessState = ref.watch(appAccessStateProvider).value;
      if (accessState?.canUseWorkspaceData != true) {
        return const OpenRouterCredentialStatus(
          provider: 'openrouter',
          configured: false,
          validationStatus: 'unknown',
        );
      }

      try {
        return await ref
            .watch(apiServiceProvider)
            .fetchOpenRouterCredentialStatus();
      } on ApiException {
        return const OpenRouterCredentialStatus(
          provider: 'openrouter',
          configured: false,
          validationStatus: 'unknown',
        );
      }
    });

final emailSourceStatusProvider = FutureProvider<EmailSourceStatus>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const EmailSourceStatus(
      configured: false,
      validationStatus: 'missing',
    );
  }

  try {
    return await ref.watch(apiServiceProvider).fetchEmailSourceStatus();
  } on ApiException {
    return const EmailSourceStatus(
      configured: false,
      validationStatus: 'unknown',
    );
  }
});

final aiRuntimeSettingsProvider = FutureProvider<AIRuntimeSettings>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return AIRuntimeSettings.fallback();
  }

  try {
    return await ref.watch(apiServiceProvider).fetchAiRuntimeSettings();
  } on ApiException {
    return AIRuntimeSettings.fallback();
  }
});

final aiUsageClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final aiUsageStateProvider =
    AsyncNotifierProvider<AIUsageNotifier, AIUsageSnapshot?>(
      AIUsageNotifier.new,
    );

final aiUsagePreflightStateProvider =
    Provider.family<AIUsagePreflightResponse?, AIUsageAction>((ref, action) {
      final accessState = ref.watch(appAccessStateProvider).value;
      final activeProjectId = ref.watch(activeProjectIdProvider);
      final snapshot = ref.watch(aiUsageStateProvider).value;
      if (accessState?.canUseWorkspaceData != true ||
          snapshot?.projectId != activeProjectId) {
        return null;
      }
      return snapshot?.preflights[action];
    });

final aiUsageQuotaProvider = Provider.family<AIQuotaStatus?, AIUsageAction>((
  ref,
  action,
) {
  final accessState = ref.watch(appAccessStateProvider).value;
  final activeProjectId = ref.watch(activeProjectIdProvider);
  final snapshot = ref.watch(aiUsageStateProvider).value;
  if (accessState?.canUseWorkspaceData != true ||
      snapshot?.projectId != activeProjectId) {
    return null;
  }
  final preflight = snapshot?.preflights[action];
  if (preflight != null) {
    return preflight.quota;
  }
  for (final quota in snapshot?.summary.quotas ?? const <AIQuotaStatus>[]) {
    if (quota.action == action) {
      return quota;
    }
  }
  return null;
});

class AIUsageNotifier extends AsyncNotifier<AIUsageSnapshot?> {
  @override
  Future<AIUsageSnapshot?> build() async {
    final accessState = ref.watch(appAccessStateProvider).value;
    final projectId = ref.watch(activeProjectIdProvider);
    if (accessState?.canUseWorkspaceData != true || projectId == null) {
      return null;
    }
    return _load(projectId);
  }

  Future<void> refresh() async {
    final accessState = ref.read(appAccessStateProvider).value;
    final projectId = ref.read(activeProjectIdProvider);
    if (accessState?.canUseWorkspaceData != true || projectId == null) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(projectId));
  }

  Future<AIUsagePreflightResponse> preflight(AIUsageAction action) async {
    final accessState = ref.read(appAccessStateProvider).value;
    final projectId = ref.read(activeProjectIdProvider);
    if (accessState?.canUseWorkspaceData != true || projectId == null) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'An active project is required to check AI usage.',
        code: 'ai_usage_project_required',
        retryable: false,
      );
    }

    final previous = state.value;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(apiServiceProvider)
          .preflightAiUsage(projectId: projectId, action: action);
      final current = previous != null && previous.projectId == projectId
          ? previous
          : await _load(projectId);
      state = AsyncData(
        current.withPreflight(
          action,
          result,
          fetchedAt: ref.read(aiUsageClockProvider)(),
        ),
      );
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refreshAfterGeneration() => refresh();

  Future<AIUsageSnapshot> _load(String projectId) async {
    final summary = await ref
        .read(apiServiceProvider)
        .fetchAiUsageSummary(projectId: projectId);
    return AIUsageSnapshot(
      projectId: projectId,
      summary: summary,
      fetchedAt: ref.read(aiUsageClockProvider)(),
    );
  }
}

final publishAccountsStateProvider = FutureProvider<PublishAccountsState>((
  ref,
) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.canUseWorkspaceData != true) {
    return const PublishAccountsState();
  }
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const PublishAccountsState();
  }
  final api = ref.watch(apiServiceProvider);
  try {
    final accounts = await api.fetchPublishAccounts(projectId: activeProjectId);
    return PublishAccountsState(accounts: accounts);
  } on ApiException catch (error) {
    final message = error.message.trim();
    final normalizedMessage = message.toLowerCase();
    final isMissingPublishConfig =
        error.statusCode == 503 &&
        error.path == '/api/publish/accounts' &&
        (normalizedMessage.contains('not configured') ||
            normalizedMessage.contains('api key'));

    if (isMissingPublishConfig) {
      return PublishAccountsState(
        availability: PublishAccountsAvailability.unavailable,
        message: message.isEmpty
            ? 'Publish account connections are unavailable because the backend publish integration is not configured.'
            : message,
      );
    }

    return PublishAccountsState(
      availability: PublishAccountsAvailability.error,
      message: message.isEmpty
          ? 'Could not fetch connected accounts.'
          : message,
    );
  }
});

final publishAccountsProvider = FutureProvider<List<PublishAccount>>((
  ref,
) async {
  final state = await ref.watch(publishAccountsStateProvider.future);
  return state.accounts;
});

final contentDetailProvider = FutureProvider.family<ContentItem, String>((
  ref,
  contentId,
) async {
  final pendingItems =
      ref.read(pendingContentProvider).value ?? const <ContentItem>[];
  final fallback = pendingItems
      .where((item) => item.id == contentId)
      .firstOrNull;
  return ref
      .watch(apiServiceProvider)
      .fetchContentDetail(contentId, fallback: fallback);
});

final pendingContentProvider =
    AsyncNotifierProvider<PendingContentNotifier, List<ContentItem>>(
      PendingContentNotifier.new,
    );

class PendingContentNotifier extends AsyncNotifier<List<ContentItem>> {
  @override
  Future<List<ContentItem>> build() async {
    final api = ref.read(apiServiceProvider);
    final activeProjectId = ref.watch(activeProjectIdProvider);
    if (activeProjectId == null) {
      return const <ContentItem>[];
    }
    try {
      final items = await api.fetchPendingContent(projectId: activeProjectId);
      if (items.isEmpty && activeProjectId == DemoSeed.projectId) {
        return await api.seedTestContentBatch(projectId: activeProjectId);
      }
      return items;
    } catch (error, stackTrace) {
      if (!_isNonCriticalReadFailure(error)) {
        rethrow;
      }
      _logDegradedRead(
        ref,
        scope: 'content.pending.degraded',
        message:
            'Pending content fetch failed; showing an empty review queue until the backend recovers.',
        error: error,
        stackTrace: stackTrace,
      );
      return const <ContentItem>[];
    }
  }

  Future<void> refresh() async {
    final previous = state.value ?? const <ContentItem>[];
    state = const AsyncLoading();
    final activeProjectId = ref.watch(activeProjectIdProvider);
    if (activeProjectId == null) {
      state = const AsyncData(<ContentItem>[]);
      return;
    }
    try {
      final api = ref.read(apiServiceProvider);
      var items = await api.fetchPendingContent(projectId: activeProjectId);
      if (items.isEmpty && activeProjectId == DemoSeed.projectId) {
        items = await api.seedTestContentBatch(projectId: activeProjectId);
      }
      state = AsyncData(items);
    } catch (error, stackTrace) {
      if (!_isNonCriticalReadFailure(error)) {
        state = AsyncError(error, stackTrace);
        return;
      }
      _logDegradedRead(
        ref,
        scope: 'content.pending.degraded',
        message:
            'Pending content refresh failed; keeping the current review queue.',
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncData(previous);
    }
  }

  Future<int> seedTestContentBatch() async {
    final activeProjectId = ref.read(activeProjectIdProvider);
    if (activeProjectId == null || activeProjectId.trim().isEmpty) {
      return 0;
    }

    final api = ref.read(apiServiceProvider);
    final seeded = await api.seedTestContentBatch(projectId: activeProjectId);
    final current = state.value ?? const <ContentItem>[];
    final mergedById = <String, ContentItem>{
      for (final item in current) item.id: item,
      for (final item in seeded) item.id: item,
    };
    final merged = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(merged);
    return seeded.length;
  }

  Future<ApproveResult> approve(
    String id, {
    String? bodyOverride,
    String? titleOverride,
  }) async {
    final current = state.value ?? [];
    final item = current.where((c) => c.id == id).firstOrNull;
    state = AsyncData(current.where((c) => c.id != id).toList());
    try {
      final api = ref.read(apiServiceProvider);

      if (item == null) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return const ApproveResult(
          approved: true,
          published: false,
          message: 'Content approved.',
        );
      }

      if (item.channels.isEmpty) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}" with no publish channels configured.',
          severity: ApproveSeverity.info,
        );
      }

      final publishableChannels = <PublishingChannel>[];
      final unsupportedChannels = <String>[];
      for (final channel in item.channels) {
        if (channelToPlatform(channel) != null) {
          publishableChannels.add(channel);
        } else {
          unsupportedChannels.add(channel.name);
        }
      }

      if (publishableChannels.isEmpty) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but selected channels are not wired to LATE yet: ${unsupportedChannels.join(', ')}.',
          severity: ApproveSeverity.warning,
        );
      }

      final publishAccountsState = await ref.read(
        publishAccountsStateProvider.future,
      );
      final accounts = publishAccountsState.accounts;

      if (publishAccountsState.isUnavailable) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but publish accounts are unavailable: ${publishAccountsState.message ?? 'backend publish integration is not configured'}.',
          severity: ApproveSeverity.warning,
        );
      }

      if (publishAccountsState.hasError) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but connected accounts could not be checked: ${publishAccountsState.message ?? 'unknown error'}.',
          severity: ApproveSeverity.warning,
        );
      }

      final platforms = <Map<String, String>>[];
      final missingAccounts = <String>[];
      final ambiguousAccounts = <String>[];

      for (final channel in publishableChannels) {
        final platform = channelToPlatform(channel);
        if (platform == null) continue;
        final account = _resolvePublishAccount(accounts, platform);
        if (account == null) {
          if (_hasAmbiguousPublishAccount(accounts, platform)) {
            ambiguousAccounts.add(platform);
          } else {
            missingAccounts.add(platform);
          }
          continue;
        }
        platforms.add({'platform': platform, 'account_id': account.id});
      }

      if (ambiguousAccounts.isNotEmpty) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but multiple LATE accounts are available without a default for: ${ambiguousAccounts.join(', ')}. Choose a default account in Settings.',
          severity: ApproveSeverity.warning,
        );
      }

      if (platforms.isEmpty) {
        await api.approveContent(id);
        ref.invalidate(contentHistoryProvider);
        _invalidateContentDetail(id);
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but no connected LATE accounts matched: ${missingAccounts.join(', ')}.',
          severity: ApproveSeverity.warning,
        );
      }

      final publishBody = await _resolvePublishBody(
        api,
        item,
        bodyOverride: bodyOverride,
      );
      final publishTitle = titleOverride ?? item.title;

      if (_usesCanonicalVideoPublishFlow(item)) {
        final activeProjectId = ref.read(activeProjectIdProvider);
        var preparedItem = item;
        if (!preparedItem.isVideoReadyToPublish ||
            preparedItem.videoGenerationTimelineId == null ||
            preparedItem.videoGenerationVersionId == null) {
          final refreshedCandidates = activeProjectId == null
              ? const <Map<String, dynamic>>[]
              : await api.refreshPreparedVideoCandidates(
                  projectId: activeProjectId,
                  contentIds: [item.id],
                  triggerSource: 'feed_swipe_publish',
                );
          final refreshed = refreshedCandidates.firstOrNull;
          if (refreshed != null) {
            preparedItem = item.copyWith(
              metadata: {
                ...(item.metadata ?? const <String, dynamic>{}),
                'video_generation_state': refreshed['status'],
                'video_generation_readiness': refreshed['readiness'],
                'video_generation_blockers': refreshed['blockers'] is List
                    ? List<String>.from(refreshed['blockers'] as List)
                    : const <String>[],
                'video_generation_blocker_code':
                    refreshed['blocker_code'] ?? refreshed['blockerCode'],
                'video_generation_blocker_summary':
                    refreshed['blocker_summary'] ?? refreshed['blockerSummary'],
                'video_generation_timeline_id':
                    refreshed['timeline_id'] ?? refreshed['timelineId'],
                'video_generation_version_id':
                    refreshed['version_id'] ?? refreshed['versionId'],
                'video_generation_preview_job_id':
                    refreshed['preview_job_id'] ?? refreshed['previewJobId'],
                'video_generation_final_job_id':
                    refreshed['final_job_id'] ?? refreshed['finalJobId'],
                'video_generation_brand_profile_id':
                    refreshed['brand_profile_id'] ?? refreshed['brandProfileId'],
                'video_generation_brand_template_id':
                    refreshed['brand_template_id'] ?? refreshed['brandTemplateId'],
                'video_generation_brand_template_revision':
                    refreshed['brand_template_revision'] ??
                        refreshed['brandTemplateRevision'],
              },
            );
          }
        }
        if (!preparedItem.isVideoReadyToPublish ||
            preparedItem.videoGenerationTimelineId == null ||
            preparedItem.videoGenerationVersionId == null) {
          state = AsyncData(current);
          final readiness = preparedItem.videoGenerationReadiness;
          final blockerSummary = preparedItem.videoGenerationBlockerSummary;
          final blockers = preparedItem.videoGenerationBlockers;
          return ApproveResult(
            approved: false,
            published: false,
            message: switch (readiness) {
              'preparing' =>
                'Branded video is still preparing. Refresh the feed in a moment or open the video editor.',
              'blocked' || 'failed' =>
                blockerSummary?.trim().isNotEmpty == true
                    ? 'Branded video is not ready: $blockerSummary. Opening the video editor.'
                    : 'Branded video is not ready: ${blockers.join(', ')}. Opening the video editor.',
              _ =>
                'Branded video is not ready yet. Open the video editor to inspect or retry.',
            },
            severity: readiness == 'preparing'
                ? ApproveSeverity.info
                : ApproveSeverity.warning,
            openVideoEditor: true,
          );
        }
        final publishResponse = await api.swipePublishVideoTimeline(
          timelineId: preparedItem.videoGenerationTimelineId!,
          versionId: preparedItem.videoGenerationVersionId!,
          previewJobId: preparedItem.videoGenerationPreviewJobId,
          content: publishBody,
          platforms: platforms,
          title: publishTitle,
          tags: item.tags,
        );
        if (publishResponse.state == 'published' ||
            publishResponse.state == 'scheduled') {
          await api.approveContent(id);
          ref.invalidate(contentHistoryProvider);
          _invalidateContentDetail(id);
          return ApproveResult(
            approved: true,
            published: true,
            message:
                '${publishResponse.state == 'scheduled' ? 'Scheduled' : 'Published'} '
                '"${item.title}" via the branded video pipeline.',
            severity: ApproveSeverity.success,
          );
        }

        state = AsyncData(current);
        return ApproveResult(
          approved: false,
          published: false,
          message: publishResponse.state == 'final_pending'
              ? 'Branded video ready for review, but final render is still running. Opening the video editor.'
              : 'Branded video publish is blocked: ${publishResponse.blockers.join(', ')}. Opening the video editor.',
          severity: publishResponse.state == 'final_pending'
              ? ApproveSeverity.info
              : ApproveSeverity.warning,
          openVideoEditor: true,
        );
      }

      await api.approveContent(id);

      final response = await api.publishContent(
        content: publishBody,
        platforms: platforms,
        title: publishTitle,
        tags: item.tags,
        contentRecordId: item.id,
      );

      ref.invalidate(contentHistoryProvider);
      _invalidateContentDetail(id);

      final success = response['success'] == true;
      final publishedPlatforms = platforms
          .map((p) => p['platform'])
          .whereType<String>()
          .toList();
      final warnings = <String>[
        if (missingAccounts.isNotEmpty)
          'missing accounts: ${missingAccounts.join(', ')}',
        if (unsupportedChannels.isNotEmpty)
          'unsupported channels: ${unsupportedChannels.join(', ')}',
      ];

      if (!success) {
        final error = (response['error'] ?? 'Publishing failed').toString();
        final status = (response['status'] ?? '').toString();
        return ApproveResult(
          approved: true,
          published: false,
          message:
              'Approved "${item.title}", but publish ${status == 'partial' ? 'partially failed' : 'failed'}: $error${warnings.isNotEmpty ? ' (${warnings.join(' | ')})' : ''}.',
          severity: ApproveSeverity.warning,
        );
      }

      return ApproveResult(
        approved: true,
        published: true,
        message:
            'Published "${item.title}" to ${publishedPlatforms.join(', ')}${warnings.isNotEmpty ? ' (${warnings.join(' | ')})' : ''}.',
        severity: warnings.isEmpty
            ? ApproveSeverity.success
            : ApproveSeverity.warning,
      );
    } catch (error) {
      state = AsyncData(current);
      return ApproveResult(
        approved: false,
        published: false,
        message: 'Approval failed: $error',
        severity: ApproveSeverity.error,
      );
    }
  }

  Future<void> reject(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectContent(id);
      ref.invalidate(contentHistoryProvider);
      _invalidateContentDetail(id);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  void _invalidateContentDetail(String id) {
    ref.invalidate(contentDetailProvider(id));
  }

  void updateItem(ContentItem updated) {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((c) => c.id == updated.id ? updated : c).toList(),
    );
    _invalidateContentDetail(updated.id);
  }

  Future<String> _resolvePublishBody(
    ApiService api,
    ContentItem item, {
    String? bodyOverride,
  }) async {
    final override = bodyOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return bodyOverride!;
    }

    final body = await api.fetchContentBody(item.id, allowStaleCache: false);
    if (body == null || body.trim().isEmpty) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Full content body is unavailable. Open the editor and retry after sync before publishing.',
      );
    }
    return body;
  }

  bool _usesCanonicalVideoPublishFlow(ContentItem item) =>
      item.type == ContentType.videoScript ||
      item.type == ContentType.reel ||
      item.type == ContentType.short;
}

enum ApproveSeverity { success, info, warning, error }

class ApproveResult {
  final bool approved;
  final bool published;
  final String message;
  final ApproveSeverity severity;
  final bool openVideoEditor;

  const ApproveResult({
    required this.approved,
    required this.published,
    required this.message,
    this.severity = ApproveSeverity.success,
    this.openVideoEditor = false,
  });
}

String? channelToPlatform(PublishingChannel ch) => switch (ch) {
  PublishingChannel.twitter => 'twitter',
  PublishingChannel.linkedin => 'linkedin',
  PublishingChannel.instagram => 'instagram',
  PublishingChannel.tiktok => 'tiktok',
  PublishingChannel.youtube => 'youtube',
  _ => null,
};

PublishAccount? _resolvePublishAccount(
  List<PublishAccount> accounts,
  String platform,
) {
  final active = accounts
      .where((account) => account.platform == platform && account.isActive)
      .toList();
  if (active.isEmpty) return null;
  final defaults = active.where((account) => account.isDefault).toList();
  if (defaults.length == 1) return defaults.single;
  if (active.length == 1) return active.single;
  return null;
}

bool _hasAmbiguousPublishAccount(
  List<PublishAccount> accounts,
  String platform,
) {
  final active = accounts
      .where((account) => account.platform == platform && account.isActive)
      .toList();
  if (active.length < 2) return false;
  return active.where((account) => account.isDefault).length != 1;
}

bool _isNonCriticalReadFailure(Object error) {
  return switch (error) {
    ApiException(type: ApiErrorType.unauthorized) => false,
    ApiException _ => true,
    _ => true,
  };
}

bool _isDripReadFailureThatCanFallback(Object error) {
  return switch (error) {
    ApiException(type: ApiErrorType.offline) => true,
    _ => false,
  };
}

void _logDegradedRead(
  Ref ref, {
  required String scope,
  required String message,
  required Object error,
  StackTrace? stackTrace,
  Map<String, Object?> context = const <String, Object?>{},
}) {
  ref
      .read(appDiagnosticsProvider)
      .warning(
        scope: scope,
        message: message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
}

final contentHistoryProvider = FutureProvider<List<ContentItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const <ContentItem>[];
  }
  try {
    return await api.fetchContentHistory(projectId: activeProjectId);
  } catch (error, stackTrace) {
    if (!_isNonCriticalReadFailure(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'content.history.degraded',
      message:
          'Published content fetch failed; falling back to an empty history view.',
      error: error,
      stackTrace: stackTrace,
    );
    return const <ContentItem>[];
  }
});

final pendingCountProvider = Provider<int>((ref) {
  return ref.watch(pendingContentProvider).value?.length ?? 0;
});

final backendStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final accessState = ref.watch(appAccessStateProvider).value;
  if (accessState?.backendHealth != null) {
    return accessState!.backendHealth!;
  }
  final api = ref.read(apiServiceProvider);
  return api.healthCheck();
});

final currentUserSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, AppSettings?>(
      UserSettingsNotifier.new,
    );

class UserSettingsNotifier extends AsyncNotifier<AppSettings?> {
  @override
  Future<AppSettings?> build() async {
    final authSession = ref.watch(authSessionProvider);
    final accessState = ref.watch(appAccessStateProvider).value;
    if (authSession.isLoading || authSession.status == AuthStatus.signedOut) {
      return null;
    }

    if (authSession.isDemo) {
      return AppSettings(
        id: 'demo-settings',
        userId: 'demo-user',
        theme: 'system',
        language: ref.read(appLanguagePreferenceProvider),
        emailNotifications: true,
      );
    }

    if (accessState?.canUseWorkspaceData != true) {
      return null;
    }

    final api = ref.read(apiServiceProvider);
    AppSettings settings;
    try {
      settings = await api.fetchSettings();
    } catch (error, stackTrace) {
      if (!_isNonCriticalReadFailure(error)) {
        rethrow;
      }
      _logDegradedRead(
        ref,
        scope: 'settings.read.degraded',
        message:
            'Settings fetch failed; leaving settings controls in degraded mode.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    final normalizedLanguage = normalizeAppLanguagePreference(
      settings.language,
    );
    final normalizedTheme = normalizeAppThemePreference(settings.theme);
    await ref
        .read(appLanguagePreferenceProvider.notifier)
        .update(normalizedLanguage);
    await ref.read(appThemePreferenceProvider.notifier).update(normalizedTheme);
    return settings.copyWith(
      language: normalizedLanguage,
      theme: normalizedTheme,
    );
  }

  Future<void> toggleNotifications(bool enabled) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    if (ref.read(authSessionProvider).isDemo) {
      state = AsyncData(current.copyWith(emailNotifications: enabled));
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      return api.updateSettings({'emailNotifications': enabled});
    });
  }

  Future<void> toggleIdeaPool(bool enabled) async {
    final current = state.value;
    if (current == null) return;

    if (ref.read(authSessionProvider).isDemo) {
      final rs = Map<String, dynamic>.from(current.robotSettings ?? {});
      rs['ideaPoolEnabled'] = enabled;
      state = AsyncData(current.copyWith(robotSettings: rs));
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      return api.updateSettings({
        'robotSettings': {'ideaPoolEnabled': enabled},
      });
    });
  }

  Future<void> updateContentFrequency({
    required String key,
    required int value,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final currentRobotSettings = Map<String, dynamic>.from(
      current.robotSettings ?? <String, dynamic>{},
    );
    final currentFrequency = currentRobotSettings['contentFrequency'];
    final nextFrequency = currentFrequency is Map
        ? Map<String, dynamic>.from(currentFrequency)
        : <String, dynamic>{};
    nextFrequency[key] = value;
    final nextRobotSettings = <String, dynamic>{
      ...currentRobotSettings,
      'contentFrequency': nextFrequency,
    };

    if (ref.read(authSessionProvider).isDemo) {
      state = AsyncData(current.copyWith(robotSettings: nextRobotSettings));
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      return api.updateSettings({'robotSettings': nextRobotSettings});
    });
  }

  Future<void> updateLanguage(String language) async {
    final normalizedLanguage = normalizeAppLanguagePreference(language);
    await ref
        .read(appLanguagePreferenceProvider.notifier)
        .update(normalizedLanguage);

    final current = state.value;
    if (current == null) {
      return;
    }

    if (ref.read(authSessionProvider).isDemo) {
      state = AsyncData(current.copyWith(language: normalizedLanguage));
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final settings = await api.updateSettings({
        'language': normalizedLanguage,
      });
      return settings.copyWith(language: normalizedLanguage);
    });
  }

  Future<AppSettings?> setDefaultProjectId(String? projectId) async {
    final current = state.value;
    if (current == null) {
      return null;
    }
    final nextSelectionMode = projectId == null
        ? projectSelectionModeNone
        : projectSelectionModeSelected;

    if (ref.read(authSessionProvider).isDemo) {
      final updated = current.copyWith(
        defaultProjectId: projectId,
        projectSelectionMode: nextSelectionMode,
      );
      state = AsyncData(updated);
      return updated;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      return api.updateSettings({
        'defaultProjectId': projectId,
        'projectSelectionMode': nextSelectionMode,
      });
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  Future<AppSettings?> setNoProjectSelected() async {
    final current = state.value;
    if (current == null) {
      return null;
    }

    if (ref.read(authSessionProvider).isDemo) {
      final updated = current.copyWith(
        projectSelectionMode: projectSelectionModeNone,
      );
      state = AsyncData(updated);
      return updated;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      return api.updateSettings({
        'projectSelectionMode': projectSelectionModeNone,
      });
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  Future<void> updateTheme(String theme) async {
    final normalizedTheme = normalizeAppThemePreference(theme);
    await ref.read(appThemePreferenceProvider.notifier).update(normalizedTheme);

    final current = state.value;
    if (current == null) {
      return;
    }

    if (ref.read(authSessionProvider).isDemo) {
      state = AsyncData(current.copyWith(theme: normalizedTheme));
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final settings = await api.updateSettings({'theme': normalizedTheme});
      return settings.copyWith(theme: normalizedTheme);
    });
  }
}

final activeProjectControllerProvider =
    AsyncNotifierProvider<ActiveProjectController, void>(
      ActiveProjectController.new,
    );

class ActiveProjectController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setActiveProject(String? projectId) async {
    final previous = ref.read(currentUserSettingsProvider).value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (projectId == null) {
        await ref
            .read(currentUserSettingsProvider.notifier)
            .setNoProjectSelected();
      } else {
        await ref
            .read(currentUserSettingsProvider.notifier)
            .setDefaultProjectId(projectId);
      }
      ref.invalidate(appBootstrapProvider);
      ref.invalidate(projectsStateProvider);
      ref.invalidate(projectsProvider);
      ref.invalidate(pendingContentProvider);
      ref.invalidate(contentHistoryProvider);
      ref.invalidate(creatorProfileProvider);
      ref.invalidate(personasProvider);
      ref.invalidate(affiliationsProvider);
      ref.invalidate(ideasProvider);
      ref.invalidate(dripPlansProvider);
    });
    if (state.hasError) {
      if (previous != null) {
        ref.invalidate(currentUserSettingsProvider);
      }
      throw state.error!;
    }
  }
}

final projectMutationControllerProvider =
    AsyncNotifierProvider<ProjectMutationController, void>(
      ProjectMutationController.new,
    );

class ProjectMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createProject({
    required String name,
    String? sourceUrl,
    List<ContentTypeConfig> contentTypes = const <ContentTypeConfig>[],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final project = await api.createProject(
        name: name,
        sourceUrl: sourceUrl,
        contentTypes: contentTypes,
      );
      ref.invalidate(projectsStateProvider);
      await ref
          .read(currentUserSettingsProvider.notifier)
          .setDefaultProjectId(project.id);
      await ref.read(appAccessStateProvider.notifier).refresh();
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> updateProject({
    required String projectId,
    required String name,
    String? sourceUrl,
    List<ContentTypeConfig> contentTypes = const <ContentTypeConfig>[],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.updateProject(
        projectId: projectId,
        name: name,
        sourceUrl: sourceUrl,
        contentTypes: contentTypes,
      );
      ref.invalidate(projectsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> archiveProject(String projectId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.archiveProject(projectId);
      ref.invalidate(projectsStateProvider);
      final activeProject = ref.read(activeProjectProvider);
      if (activeProject?.id == projectId) {
        await ref
            .read(currentUserSettingsProvider.notifier)
            .setDefaultProjectId(null);
      }
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> unarchiveProject(String projectId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.unarchiveProject(projectId);
      ref.invalidate(projectsStateProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> deleteProject(String projectId) async {
    await archiveProject(projectId);
  }
}

final creatorProfileProvider = FutureProvider<CreatorProfile?>((ref) async {
  final authSession = ref.watch(authSessionProvider);
  if (!authSession.isAuthenticated) {
    return null;
  }

  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return null;
  }
  return api.fetchCreatorProfile(projectId: activeProjectId);
});

final personasProvider = FutureProvider<List<Persona>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const <Persona>[];
  }
  return api.fetchPersonas(projectId: activeProjectId);
});

final affiliationsProvider = FutureProvider<List<AffiliateLink>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const <AffiliateLink>[];
  }
  return api.fetchAffiliations(projectId: activeProjectId);
});

final linkWebhooksProvider = FutureProvider<List<LinkWebhook>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const <LinkWebhook>[];
  }
  return api.fetchLinkWebhooks(projectId: activeProjectId);
});

final linkWebhookDeliveriesProvider =
    FutureProvider.family<List<LinkWebhookDelivery>, String>((ref, webhookId) async {
  final api = ref.read(apiServiceProvider);
  return api.fetchLinkWebhookDeliveries(webhookId);
});

final utmTemplatesProvider = FutureProvider<List<UtmTemplate>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  if (activeProjectId == null) {
    return const <UtmTemplate>[];
  }
  return api.fetchUtmTemplates(projectId: activeProjectId);
});

final linkConversionsProvider =
    FutureProvider.family<List<LinkConversion>, String>((ref, linkId) async {
  final api = ref.read(apiServiceProvider);
  return api.fetchLinkConversions(linkId);
});

final lastNarrativeProvider = StateProvider<NarrativeSynthesisResult?>(
  (ref) => null,
);

// ─── Idea Pool ──────────────────────────────────────────

final ideasProvider = AsyncNotifierProvider<IdeasNotifier, List<Idea>>(
  IdeasNotifier.new,
);

class IdeasNotifier extends AsyncNotifier<List<Idea>> {
  String _statusFilter = 'all';
  String _sourceFilter = 'all';

  String get statusFilter => _statusFilter;
  String get sourceFilter => _sourceFilter;

  @override
  Future<List<Idea>> build() async {
    final api = ref.read(apiServiceProvider);
    final activeProjectId = ref.watch(activeProjectIdProvider);
    if (activeProjectId == null) {
      return const <Idea>[];
    }
    return api.fetchIdeas(
      status: _statusFilter == 'all' ? null : _statusFilter,
      source: _sourceFilter == 'all' ? null : _sourceFilter,
      projectId: activeProjectId,
    );
  }

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    ref.invalidateSelf();
  }

  void setSourceFilter(String filter) {
    _sourceFilter = filter;
    ref.invalidateSelf();
  }

  Future<void> dismissIdea(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.updateIdea(id, {'status': 'dismissed'});
    ref.invalidateSelf();
  }

  Future<void> prioritizeIdea(String id, double score) async {
    final api = ref.read(apiServiceProvider);
    await api.updateIdea(id, {'priority_score': score});
    ref.invalidateSelf();
  }

  Future<void> deleteIdea(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.deleteIdea(id);
    ref.invalidateSelf();
  }
}

// ─── Content Drip ──────────────────────────────────────────

final dripPlansProvider = FutureProvider<List<DripPlan>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final raw = await api.fetchDripPlans();
    return raw.map((j) => DripPlan.fromJson(j)).toList();
  } catch (error, stackTrace) {
    if (!_isDripReadFailureThatCanFallback(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'drip.plans.degraded',
      message:
          'Drip plans fetch failed; keeping the offline drip list available.',
      error: error,
      stackTrace: stackTrace,
    );
    return const <DripPlan>[];
  }
});

final dripStatsProvider = FutureProvider.family<DripStats, String>((
  ref,
  planId,
) async {
  final api = ref.read(apiServiceProvider);
  try {
    final raw = await api.getDripStats(planId);
    return DripStats.fromJson(raw);
  } catch (error, stackTrace) {
    if (!_isDripReadFailureThatCanFallback(error)) {
      rethrow;
    }
    _logDegradedRead(
      ref,
      scope: 'drip.stats.degraded',
      message:
          'Drip stats fetch failed; showing the plan without live progression details.',
      error: error,
      stackTrace: stackTrace,
      context: {'planId': planId},
    );
    return const DripStats();
  }
});
