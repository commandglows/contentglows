import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_config.dart';
import '../../../data/models/app_access_state.dart';
import '../../../data/models/auth_session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

const double _entryOverlayIconTextLetterSpacing = 1.4;
const double _entryActionIconSize = 18.0;
const double _entryStateButtonHeightCompact = 44.0;
const double _entryStateButtonHeightExpanded = 56.0;
const double _entryIconSizeCompact = 24.0;
const double _entryIconSizeExpanded = 28.0;

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  bool _isGoogleSignInInProgress = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _signInWithGoogle() async {
    if (_isGoogleSignInInProgress) return;
    setState(() => _isGoogleSignInInProgress = true);
    try {
      await ref.read(authSessionProvider.notifier).signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in did not complete. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleSignInInProgress = false);
      }
    }
  }

  Future<void> _openWebsiteSignIn() async {
    final url = kIsWeb
        ? Uri.parse('${Uri.base.origin}/sign-in')
        : Uri.parse('${AppConfig.appWebUrl}/sign-in');
    await launchUrl(url);
  }

  Future<void> _openWebsiteSignUp() async {
    final url = kIsWeb
        ? Uri.parse('${Uri.base.origin}/sign-up')
        : Uri.parse('${AppConfig.appWebUrl}/sign-up');
    await launchUrl(url);
  }

  Widget? _buildEntryErrorDiagnostics(
    AuthSession authSession,
    AppAccessState? accessState,
  ) {
    final message = accessState?.message;
    if (message == null || message.trim().isEmpty) {
      return null;
    }

    return AppErrorView(
      scope: 'entry.${accessState?.diagnosticsLabel ?? 'unknown'}',
      title: 'Copy this error',
      message: message,
      compact: true,
      showIcon: false,
      copyLabel: 'Copy diagnostics',
      helperText:
          'Copy this report and send it back so the failing auth/bootstrap state can be inspected.',
      contextData: {
        'accessStage': accessState?.diagnosticsLabel ?? 'unknown',
        'statusCode': accessState?.statusCode?.toString() ?? 'none',
        'backendStatus': accessState?.backendStatusLabel ?? 'unknown',
        'sessionState': authSession.status.name,
        'sessionEmail': authSession.email ?? 'none',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    final appAccessAsync = ref.watch(appAccessStateProvider);
    final palette = AppTheme.paletteOf(context);
    final stateCard = _buildStateCard(
      context,
      ref,
      authSession,
      appAccessAsync,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.heroGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTheme.entryScreenMaxWidth,
                ),
                child: stateCard,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(
    BuildContext context,
    WidgetRef ref,
    AuthSession authSession,
    AsyncValue<AppAccessState> appAccessAsync,
  ) {
    final accessState = appAccessAsync.value;
    final stage = accessState?.stage;

    if (appAccessAsync.isLoading || stage == AppAccessStage.restoringSession) {
      return _card(
        eyebrow: 'Restoring session',
        title: 'Checking Clerk session',
        description:
            'The app is restoring your Clerk session and deciding whether to open auth, onboarding, or your workspace.',
        icon: Icons.sync_rounded,
        accent: AppTheme.editColor,
        showProgress: true,
        primaryLabel: 'Please wait',
        onPrimary: null,
      );
    }

    if (stage == AppAccessStage.checkingBackend ||
        stage == AppAccessStage.checkingWorkspace) {
      return _card(
        eyebrow: 'Checking session',
        title: stage == AppAccessStage.checkingBackend
            ? 'Checking backend availability'
            : 'Loading your workspace',
        description: stage == AppAccessStage.checkingBackend
            ? 'Your Clerk session is active. The app is confirming that FastAPI is reachable before asking for workspace state.'
            : 'The app is validating your session and loading your workspace from FastAPI.',
        icon: Icons.sync_rounded,
        accent: AppTheme.editColor,
        showProgress: true,
        primaryLabel: 'Please wait',
        onPrimary: null,
        secondaryLabel: 'Sign out',
        onSecondary: () => ref.read(authSessionProvider.notifier).signOut(),
      );
    }

    if (stage == AppAccessStage.apiUnavailable ||
        stage == AppAccessStage.bootstrapFailed ||
        stage == AppAccessStage.bootstrapUnauthorized) {
      final isUnauthorized = stage == AppAccessStage.bootstrapUnauthorized;
      final title = isUnauthorized
          ? 'Reconnect your account'
          : 'FastAPI is unavailable';
      final description = isUnauthorized
          ? 'Your Clerk session reached the app, but FastAPI rejected the bootstrap request. Sign in again to refresh the bearer token.'
          : 'Your Clerk session is active, but ContentGlows cannot load product state from FastAPI right now. Use the degraded mode tools to inspect backend status, retry, or wait for the API to recover.';

      return _card(
        eyebrow: stage == AppAccessStage.apiUnavailable
            ? 'API down'
            : 'Session error',
        title: title,
        description: description,
        icon: Icons.warning_amber_rounded,
        accent: AppTheme.warningColor,
        primaryLabel: isUnauthorized
            ? (kIsWeb ? 'Continue with Google' : 'Sign In Again')
            : 'Open System Status',
        onPrimary: () {
          if (isUnauthorized) {
            ref.read(authSessionProvider.notifier).signOut();
            if (kIsWeb) {
              _openWebsiteSignIn();
            } else {
              context.go('/auth');
            }
            return;
          }
          context.go('/uptime');
        },
        secondaryLabel: isUnauthorized ? 'Sign out' : 'Retry API',
        onSecondary: () {
          if (isUnauthorized) {
            ref.read(authSessionProvider.notifier).signOut();
            return;
          }
          ref.read(appAccessStateProvider.notifier).refresh();
        },
        caption: 'Backend detail: ${accessState?.message ?? 'unknown'}',
        extra: _buildEntryErrorDiagnostics(authSession, accessState),
      );
    }

    if (stage == AppAccessStage.ready) {
      return _card(
        eyebrow: 'Session active',
        title: 'Welcome back to ContentGlows',
        description:
            'Your account is already recognized. Jump back into the content pipeline instead of going through onboarding again.',
        icon: Icons.verified_user_rounded,
        accent: AppTheme.approveColor,
        primaryLabel: 'Open Dashboard',
        onPrimary: () => context.go('/feed'),
        secondaryLabel: 'Sign out',
        onSecondary: () => ref.read(authSessionProvider.notifier).signOut(),
        extra: _buildCopyFlowDiagnostics(
          context,
          ref,
          authSession,
          accessState,
        ),
      );
    }

    if (stage == AppAccessStage.needsOnboarding ||
        stage == AppAccessStage.demo) {
      return _card(
        eyebrow: 'Setup required',
        title: 'Finish onboarding before entering the app',
        description:
            'Your session exists, but the workspace setup is still incomplete. Continue onboarding to configure project, content types, and publishing flow.',
        icon: Icons.rocket_launch_rounded,
        accent: AppTheme.editColor,
        primaryLabel: 'Continue Onboarding',
        onPrimary: () => context.go('/onboarding?intent=entry'),
        secondaryLabel: 'Sign out',
        onSecondary: () => ref.read(authSessionProvider.notifier).signOut(),
        extra: _buildCopyFlowDiagnostics(
          context,
          ref,
          authSession,
          accessState,
        ),
      );
    }

    return _card(
      eyebrow: 'Logged out',
      title: 'Sign in to access your workspace',
      description: kIsWeb
          ? 'You are not signed in yet. Continue with Google on the dedicated app-domain Clerk page. Workspace creation and onboarding are only available after authentication.'
          : _isAndroid
          ? 'You are not signed in yet. Continue with Google to sign in securely with the native Android flow.'
          : 'You are not signed in yet. Sign-in is currently available on the web app.',
      icon: Icons.lock_outline_rounded,
      accent: AppTheme.warningColor,
      showProgress: _isGoogleSignInInProgress,
      primaryLabel: _isGoogleSignInInProgress
          ? 'Opening Google…'
          : kIsWeb || _isAndroid
          ? 'Continue with Google'
          : 'Sign In',
      onPrimary: _isGoogleSignInInProgress
          ? null
          : kIsWeb
          ? _openWebsiteSignIn
          : _isAndroid
          ? _signInWithGoogle
          : () => context.go('/auth'),
      secondaryLabel: 'Open Interactive Demo',
      onSecondary: () {
        ref.read(authSessionProvider.notifier).signInDemo();
        context.go('/onboarding?intent=entry');
      },
      tertiaryLabel: 'Create Account',
      onTertiary: kIsWeb ? _openWebsiteSignUp : () => context.go('/auth'),
      caption: 'Sign-in and account creation are handled by Clerk.',
      extra: _buildCopyFlowDiagnostics(context, ref, authSession, accessState),
    );
  }

  Widget _buildCopyFlowDiagnostics(
    BuildContext context,
    WidgetRef ref,
    AuthSession authSession,
    AppAccessState? accessState,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () {
            copyDiagnosticsToClipboard(
              context,
              ref,
              title: 'ContentGlows entry diagnostics',
              scope: 'entry.copy_flow_diagnostics',
              currentError: accessState?.message,
              contextData: {
                'sessionState': authSession.status.name,
                'sessionEmail': authSession.email ?? 'none',
                'accessStage': accessState?.diagnosticsLabel ?? 'loading',
                'backendStatus': accessState?.backendStatusLabel ?? 'unknown',
                'backendGitSha':
                    accessState?.backendHealth?['git_sha']?.toString() ??
                    'unknown',
                'bootstrapStatus':
                    accessState?.bootstrapStatusLabel ?? 'not_started',
                'workspaceStatus':
                    accessState?.bootstrap?.workspaceStatus ?? 'none',
                'workspaceExists':
                    accessState?.bootstrap?.user.workspaceExists ?? false,
                'projectsCount':
                    accessState?.bootstrap?.projectsCount ?? 'none',
                'defaultProjectId':
                    accessState?.bootstrap?.defaultProjectId ?? 'none',
              },
              successMessage: 'Entry diagnostics copied to clipboard.',
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: AppOpacity.nearOpaque,
              ),
            ),
          ),
          icon: const Icon(Icons.copy_all_rounded, size: _entryActionIconSize),
          label: Text(context.tr('Copy access diagnostics')),
        ),
      ),
    );
  }

  Widget _card({
    required String eyebrow,
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
    bool showProgress = false,
    required String primaryLabel,
    required VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? tertiaryLabel,
    VoidCallback? onTertiary,
    String? caption,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(
          compact ? AppRadii.xl : AppRadii.card,
        ),
        border: Border.all(color: palette.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(AppAlpha.low22),
            blurRadius: AppSpacing.xl + AppSpacing.sm,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.tr(eyebrow).toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: AppText.sm,
                    fontWeight: FontWeight.w700,
                    letterSpacing: _entryOverlayIconTextLetterSpacing,
                  ),
                ),
              ),
              Container(
                width: compact
                    ? _entryStateButtonHeightCompact
                    : _entryStateButtonHeightExpanded,
                height: compact
                    ? _entryStateButtonHeightCompact
                    : _entryStateButtonHeightExpanded,
                decoration: BoxDecoration(
                  color: accent.withAlpha(AppAlpha.glow),
                  borderRadius: BorderRadius.circular(
                    compact ? AppRadii.lg : AppRadii.xl,
                  ),
                ),
                child: showProgress
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: AppStroke.accent,
                        ),
                      )
                    : Icon(
                        icon,
                        color: accent,
                        size: compact
                            ? _entryIconSizeCompact
                            : _entryIconSizeExpanded,
                      ),
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            context.tr(title),
            style:
                (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      height: AppLineHeight.dense,
                    ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          Text(
            context.tr(description),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: AppLineHeight.relaxed,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
              child: Text(context.tr(primaryLabel)),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.9,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                ),
                child: Text(context.tr(secondaryLabel)),
              ),
            ),
          ],
          if (tertiaryLabel != null && onTertiary != null) ...[
            SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onTertiary,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                ),
                child: Text(context.tr(tertiaryLabel)),
              ),
            ),
          ],
          if (caption != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(caption),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
                height: AppLineHeight.relaxed,
              ),
            ),
          ],
          if (extra case final extraWidget?) ...[extraWidget],
        ],
      ),
    );
  }
}
