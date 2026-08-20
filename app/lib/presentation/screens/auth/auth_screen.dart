import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_config.dart';
import '../../../data/models/auth_session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  String? _error;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasClerkKey = AppConfig.clerkPublishableKey.isNotEmpty;
    final authSession = ref.watch(authSessionProvider);
    final palette = AppTheme.paletteOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Authentication'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTheme.authScreenMaxWidth,
          ),
          child: SingleChildScrollView(
            padding: AppSpacing.card(context),
            child: Container(
              padding: AppSpacing.card(context),
              decoration: BoxDecoration(
                color: palette.elevatedSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: palette.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningColor.withAlpha(AppAlpha.low18),
                    blurRadius: AppEffects.blurCard,
                    offset: const Offset(0, AppSpacing.xs),
                  ),
                ],
              ),
              child: hasClerkKey
                  ? _buildForm(authSession)
                  : _buildConfigMissing(authSession),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigMissing(AuthSession authSession) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('Clerk is not configured'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr(
            'Set `CLERK_PUBLISHABLE_KEY` with `--dart-define` to enable the production ClerkJS sign-in flow on the app domain.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: AppLineHeight.relaxed,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildRuntimeDiagnostics(
          hasClerkKey: false,
          authSession: authSession,
          error: _error ?? 'Clerk is missing from runtime config.',
        ),
      ],
    );
  }

  Widget _buildForm(AuthSession authSession) {
    if (kIsWeb) {
      return _buildWebRedirectState(authSession);
    }

    return _buildNativeCustomState(authSession);
  }

  Widget _buildNativeCustomState(AuthSession authSession) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(
            _isAndroid ? 'Sign in with Google' : 'Native sign-in unavailable',
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr(
            _isAndroid
                ? 'Continue with Google in your secure system browser. After approval, you return automatically to the Android app.'
                : 'Native Clerk authentication is currently available only on Android. Use the web app on this platform.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: AppLineHeight.relaxed,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null && _error!.isNotEmpty) ...[
          _buildRuntimeDiagnostics(
            hasClerkKey: true,
            authSession: authSession,
            error: _error,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting || !_isAndroid ? null : _signInWithGoogle,
            child: _isSubmitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: AppSpacing.md,
                        height: AppSpacing.md,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.medium,
                          color: AppTheme.onMediaColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Opening Google…'),
                    ],
                  )
                : Text(context.tr('Continue with Google')),
          ),
        ),
        Text(
          context.tr(
            _isAndroid
                ? 'Google opens in the secure system browser and returns automatically to this app. If it cannot finish, the diagnostic below identifies the native configuration issue.'
                : 'Open the web app to use the ClerkJS sign-in flow.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: AppLineHeight.body,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isSubmitting ? null : _clearLocalSession,
            child: Text(context.tr('Clear Local Clerk Session')),
          ),
        ),
      ],
    );
  }

  Widget _buildWebRedirectState(AuthSession authSession) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('Sign in with Google'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr(
            'ContentGlows web authentication now uses the official Clerk JavaScript SDK directly on the app domain. The old site handoff and the Flutter beta SDK are no longer the primary path.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: AppLineHeight.relaxed,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _openAppWebSignIn,
            child: Text(context.tr('Continue with Google')),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _openAppWebEntry,
            child: Text(context.tr('Already signed in? Open App')),
          ),
        ),
      ],
    );
  }

  Widget _buildRuntimeDiagnostics({
    required bool hasClerkKey,
    required AuthSession authSession,
    required String? error,
  }) {
    return AppErrorView(
      scope: hasClerkKey ? 'auth.runtime' : 'auth.config_missing',
      title: hasClerkKey ? 'Authentication error' : 'Clerk is not configured',
      message: error,
      compact: true,
      showIcon: !hasClerkKey || (error != null && error.isNotEmpty),
      copyLabel: 'Copy diagnostics',
      helperText: hasClerkKey
          ? 'Copy this report and send it back with the error message above.'
          : 'Rebuild the app with a valid CLERK_PUBLISHABLE_KEY to enable the Clerk web flow.',
      contextData: {
        'hasClerkKey': hasClerkKey,
        'sessionState': authSession.status.name,
        'sessionEmail': authSession.email ?? 'none',
        'appWebUrl': AppConfig.appWebUrl,
        'siteUrl': AppConfig.siteUrl,
        'apiBaseUrl': AppConfig.apiBaseUrl,
        'currentPath': kIsWeb ? Uri.base.path : 'not-web',
      },
    );
  }

  Future<void> _clearLocalSession() async {
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      await ref.read(authSessionProvider.notifier).clearLocalSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Local Clerk session cleared. Try signing in again.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      await ref.read(authSessionProvider.notifier).signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openAppWebSignIn() async {
    final url = kIsWeb
        ? Uri.parse('${Uri.base.origin}/sign-in')
        : Uri.parse('${AppConfig.appWebUrl}/sign-in');
    await launchUrl(url, mode: LaunchMode.platformDefault);
  }

  Future<void> _openAppWebEntry() async {
    final url = kIsWeb
        ? Uri.parse('${Uri.base.origin}/#/entry')
        : Uri.parse('${AppConfig.appWebUrl}/#/entry');
    await launchUrl(url, mode: LaunchMode.platformDefault);
  }
}
