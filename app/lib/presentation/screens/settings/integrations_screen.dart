import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/ai_runtime.dart';
import '../../../data/models/ai_usage.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/content_item.dart';
import '../../../data/models/email_source.dart';
import '../../../data/models/openrouter_credential.dart';
import '../../../data/models/search_console.dart';
import '../../../data/services/api_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';
import 'settings_widgets.dart';

/// Sub-page nested under /settings, hosting every connection to external
/// services (backend, AI runtime, OpenRouter key, GitHub, publishing channels).
/// Keeps the main Settings page lean by lifting noisy, infrequent connection
/// flows into a dedicated screen.
class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  static const double _kHeroPadding = 18.0;
  static const double _kHeroIconSize = 44.0;
  static const double _kHeroGlyphSize = 24.0;
  static const double _kHeroTitleGap = 14.0;
  static const double _kHeroMiniGap = 2.0;
  static const double _kInlineSpacing6 = 6.0;
  static const double _kInlineSpacing8 = 8.0;
  static const double _kInlineSpacing10 = 10.0;
  static const double _kInlineSpacing14 = 14.0;
  static const double _kLineHeight = 1.4;
  static const double _kCompactLineHeight = 1.35;
  static const double _kPanelIconSize = 16.0;
  static const double _kActionIconSize = 18.0;
  static const double _kActionButtonHeight = 44.0;
  static const double _kActionButtonCompactHeight = 36.0;
  static const double _kLoaderHeight = 2.0;
  static const double _kLoaderSmall = 16.0;
  static const double _kLoaderRegular = 18.0;
  static const double _kInfoTextSize = 13.0;

  late TextEditingController _apiUrlController;
  late TextEditingController _openRouterApiKeyController;
  late TextEditingController _emailSourceEmailController;
  late TextEditingController _emailSourcePasswordController;
  late TextEditingController _emailSourceHostController;
  late TextEditingController _emailSourceFolderController;
  late TextEditingController _emailSourceArchiveController;
  bool _showOpenRouterKey = false;
  bool _showEmailSourcePassword = false;
  bool _isSavingRuntimeMode = false;
  bool _isSavingOpenRouterKey = false;
  bool _isValidatingOpenRouterKey = false;
  bool _isDeletingOpenRouterKey = false;
  bool _isSavingEmailSource = false;
  bool _isValidatingEmailSource = false;
  bool _isDeletingEmailSource = false;
  bool _isConnectingSearchConsole = false;
  bool _isSavingSearchConsoleProperty = false;
  bool _isValidatingSearchConsole = false;
  bool _isDisconnectingSearchConsole = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _openRouterApiKeyController = TextEditingController();
    _emailSourceEmailController = TextEditingController();
    _emailSourcePasswordController = TextEditingController();
    _emailSourceHostController = TextEditingController(text: 'imap.gmail.com');
    _emailSourceFolderController = TextEditingController(text: 'Newsletters');
    _emailSourceArchiveController = TextEditingController(
      text: 'CONTENTGLOWS_DONE',
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _openRouterApiKeyController.dispose();
    _emailSourceEmailController.dispose();
    _emailSourcePasswordController.dispose();
    _emailSourceHostController.dispose();
    _emailSourceFolderController.dispose();
    _emailSourceArchiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final appAccess = ref.watch(appAccessStateProvider).value;
    final authSession = ref.watch(authSessionProvider);
    final backendStatus = ref.watch(backendStatusProvider);
    final githubIntegration = ref.watch(githubIntegrationStatusProvider);
    final searchConsoleStatus = ref.watch(
      searchConsoleConnectionStatusProvider,
    );
    final searchConsoleProperties = ref.watch(searchConsolePropertiesProvider);
    final emailSourceStatus = ref.watch(emailSourceStatusProvider);
    final aiRuntimeSettings = ref.watch(aiRuntimeSettingsProvider);
    final aiUsageState = ref.watch(aiUsageStateProvider);
    final openRouterCredential = ref.watch(openRouterCredentialStatusProvider);
    final publishAccountsState = ref.watch(publishAccountsStateProvider);
    final publishAccounts = ref.watch(publishAccountsProvider);
    final activeProjectId = ref.watch(activeProjectIdProvider);

    if (_apiUrlController.text.isEmpty) {
      _apiUrlController.text = apiBaseUrl;
    }

    final groupGap = settingsGroupGap(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Integrations')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.tr('Back'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [ProjectPickerAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: settingsPagePadding(context),
          children: [
            _buildIntegrationsHero(),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'AI runtime',
              caption:
                  'How AI features are funded. BYOK uses your OpenRouter key. Platform uses ContentGlows-managed credits.',
              gap: 0,
              children: [
                SettingsBlock(
                  child: _buildAiRuntimeBody(
                    aiRuntimeSettings,
                    aiUsageState: aiUsageState,
                    authSession: authSession,
                  ),
                ),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'OpenRouter API key',
              caption:
                  'Stored encrypted server-side. Used for persona prefill, ritual, angles, newsletter and research.',
              gap: 0,
              children: [
                SettingsBlock(
                  child: _buildOpenRouterBody(
                    openRouterCredential,
                    authSession: authSession,
                  ),
                ),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'GitHub',
              gap: 0,
              children: [
                SettingsBlock(child: _buildGithubBody(githubIntegration)),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'Google Search Console',
              caption:
                  'Connect a project property with Google OAuth. Search data is shown separately from private site traffic.',
              gap: 0,
              children: [
                SettingsBlock(
                  child: _buildSearchConsoleBody(
                    searchConsoleStatus,
                    propertiesState: searchConsoleProperties,
                    authSession: authSession,
                    activeProjectId: activeProjectId,
                  ),
                ),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'Email source',
              caption:
                  'Use an IMAP folder as a private idea source. Gmail requires an app password.',
              gap: 0,
              children: [
                SettingsBlock(
                  child: _buildEmailSourceBody(
                    emailSourceStatus,
                    authSession: authSession,
                    activeProjectId: activeProjectId,
                  ),
                ),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'Backend connection',
              caption:
                  'FastAPI endpoint used for workspace, content and project data.',
              gap: 0,
              children: [
                SettingsBlock(
                  child: _buildBackendBody(backendStatus, appAccess: appAccess),
                ),
              ],
            ),
            SizedBox(height: groupGap),

            SettingsGroup(
              title: 'Publishing channels',
              caption:
                  'Connect once, publish from the editor. OAuth opens in your browser.',
              gap: 0,
              children: _buildChannelRows(
                accountsAsync: publishAccounts,
                publishAccountsState: publishAccountsState,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationsHero() {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(_kHeroPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: _kHeroIconSize,
            height: _kHeroIconSize,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(AppAlpha.tint),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.hub_outlined,
              color: theme.colorScheme.primary,
              size: _kHeroGlyphSize,
            ),
          ),
          const SizedBox(width: _kHeroTitleGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Connect your stack'),
                  style: TextStyle(
                    fontSize: AppText.base,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: _kHeroMiniGap),
                Text(
                  context.tr(
                    'AI runtime, API keys, GitHub and publishing destinations live here.',
                  ),
                  style: TextStyle(
                    fontSize: AppText.xs,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: _kLineHeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----- Backend ---------------------------------------------------------

  Widget _buildBackendBody(
    AsyncValue<Map<String, dynamic>> backendStatus, {
    required dynamic appAccess,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        backendStatus.when(
          data: (data) {
            final isOnline =
                data['status'] == 'ok' || data['status'] == 'healthy';
            return SettingsStatusPill(
              label: isOnline
                  ? context.tr('Connected')
                  : context.tr('Offline (using mock data)'),
              color: isOnline ? AppTheme.approveColor : AppTheme.rejectColor,
              icon: isOnline ? Icons.circle : Icons.warning_amber_rounded,
            );
          },
          loading: () => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: _kHeroTitleGap,
                height: _kHeroTitleGap,
                child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
              ),
              const SizedBox(width: _IntegrationsScreenState._kInlineSpacing8),
              Text(context.tr('Checking...')),
            ],
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsStatusPill(
                label: context.tr('Error checking status'),
                color: AppTheme.warningColor,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing10),
              SettingsErrorDiagnostic(
                details: 'Backend error: ${(error.toString()).trim()}',
                linkUrl: '${ref.read(apiBaseUrlProvider)}/health',
                linkLabel: context.tr('Open {screen}', {'screen': 'Health'}),
              ),
            ],
          ),
        ),
        if (appAccess?.isDegraded == true) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              'Degraded mode is active. The app stays available, cached data may be stale, and queued actions will replay when FastAPI recovers.',
            ),
            style: TextStyle(
              color: AppTheme.warningColor.withAlpha(AppAlpha.high220),
              fontSize: AppText.xs,
              height: _kLineHeight,
            ),
          ),
        ],
        const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
        TextField(
          controller: _apiUrlController,
          decoration: InputDecoration(
            labelText: context.tr('API URL'),
            hintText: 'http://localhost:8000',
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: context.tr('Apply'),
              onPressed: () {
                ref
                    .read(apiBaseUrlProvider.notifier)
                    .update(_apiUrlController.text);
                ref.invalidate(backendStatusProvider);
                ref.invalidate(appAccessStateProvider);
                ref.invalidate(pendingContentProvider);
                ref.invalidate(publishAccountsProvider);
              },
            ),
          ),
        ),
        if (theme.brightness == Brightness.light) const SizedBox.shrink(),
      ],
    );
  }

  // ----- AI runtime ------------------------------------------------------

  Widget _buildAiRuntimeBody(
    AsyncValue<AIRuntimeSettings> state, {
    required AsyncValue<AIUsageSnapshot?> aiUsageState,
    required AuthSession authSession,
  }) {
    final theme = Theme.of(context);
    final canManage = authSession.isAuthenticated && !authSession.isDemo;

    return state.when(
      data: (settings) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiRuntimeSettingsCard(
            settings: settings,
            canManage: canManage,
            isUpdating: _isSavingRuntimeMode,
            onModeSelected: canManage ? _setAiRuntimeMode : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          AIUsageQuotaCard(
            state: aiUsageState,
            selectedMode: settings.mode,
            onRefresh: () => ref.read(aiUsageStateProvider.notifier).refresh(),
            onContactSupport: () => context.push('/feedback'),
          ),
        ],
      ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Loading AI runtime settings...'),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: _kLineHeight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            width: _kLoaderRegular,
            height: _kLoaderRegular,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Unable to load AI runtime settings.'),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: _kLineHeight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SettingsErrorDiagnostic(
            details: 'AI runtime error: ${(error.toString()).trim()}',
            linkUrl: '${ref.read(apiBaseUrlProvider)}/api/settings/ai-runtime',
            linkLabel: context.tr('Open AI runtime endpoint'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAiRuntimeMode(String mode) async {
    if (_isSavingRuntimeMode) return;
    setState(() => _isSavingRuntimeMode = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateAiRuntimeMode(mode);
      if (!mounted) return;
      ref.invalidate(aiRuntimeSettingsProvider);
      ref.invalidate(openRouterCredentialStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('AI runtime mode updated to {mode}.', {'mode': mode}),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Failed to update AI runtime mode.')
            : error.message.trim(),
        scope: 'settings.ai_runtime.update',
        contextData: {'mode': mode, 'responseBody': error.responseBody},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isSavingRuntimeMode = false);
    }
  }

  // ----- OpenRouter ------------------------------------------------------

  Widget _buildOpenRouterBody(
    AsyncValue<OpenRouterCredentialStatus> state, {
    required AuthSession authSession,
  }) {
    final theme = Theme.of(context);
    final canManage = authSession.isAuthenticated && !authSession.isDemo;
    final busy =
        _isSavingOpenRouterKey ||
        _isValidatingOpenRouterKey ||
        _isDeletingOpenRouterKey;

    return state.when(
      data: (status) {
        final statusColor = _openRouterStatusColor(status);
        final statusLabel = _openRouterStatusLabel(status);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsStatusPill(
              label: statusLabel,
              color: statusColor,
              icon: status.configured
                  ? Icons.key_rounded
                  : Icons.add_circle_outline,
            ),
            if (status.maskedSecret != null &&
                status.maskedSecret!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withAlpha(AppAlpha.low12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppTheme.infoColor.withAlpha(AppAlpha.tint),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: _IntegrationsScreenState._kPanelIconSize,
                      color: AppTheme.infoColor,
                    ),
                    const SizedBox(width: _IntegrationsScreenState._kInlineSpacing8),
                    Expanded(
                      child: Text(
                        context.tr('Stored key: {key}', {
                          'key': status.maskedSecret!,
                        }),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: _IntegrationsScreenState._kInfoTextSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status.updatedAt != null || status.lastValidatedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _openRouterMetaText(status),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _openRouterApiKeyController,
              obscureText: !_showOpenRouterKey,
              enabled: canManage && !busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.tr('OpenRouter API key'),
                hintText: 'sk-or-v1-...',
                helperText: canManage
                    ? context.tr('Paste a new key to replace the current one.')
                    : context.tr('Sign in to manage your OpenRouter key'),
                helperMaxLines: 2,
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showOpenRouterKey = !_showOpenRouterKey),
                  tooltip: _showOpenRouterKey
                      ? context.tr('Hide key')
                      : context.tr('Show key'),
                  icon: Icon(
                    _showOpenRouterKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
            Wrap(
              spacing: AppSpacing.compact,
              runSpacing: AppSpacing.compact,
              children: [
                FilledButton.icon(
                  onPressed: canManage && !busy
                      ? _saveOpenRouterCredential
                      : null,
                  icon: _isSavingOpenRouterKey
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.save_rounded, size: _kActionIconSize),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.approveColor,
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Save key')),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && status.configured && !busy
                      ? _validateOpenRouterCredential
                      : null,
                  icon: _isValidatingOpenRouterKey
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.verified_outlined, size: _kActionIconSize),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Validate')),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && status.configured && !busy
                      ? _deleteOpenRouterCredential
                      : null,
                  icon: _isDeletingOpenRouterKey
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.delete_outline, size: _kActionIconSize),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rejectColor,
                    side: BorderSide(
                      color: AppTheme.rejectColor.withAlpha(AppAlpha.border),
                    ),
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Delete')),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => openSettingsUrl(
                          context,
                          ref,
                          'https://openrouter.ai/keys',
                        ),
                  icon: const Icon(Icons.open_in_new, size: _kActionIconSize),
                  label: Text(context.tr('Get a key')),
                  style: TextButton.styleFrom(minimumSize: const Size(0, _kActionButtonHeight)),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          const SizedBox(
            width: _kLoaderRegular,
            height: _kLoaderRegular,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('Loading OpenRouter credential status...'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Unable to load OpenRouter credential state.'),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: _kLineHeight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SettingsErrorDiagnostic(
            details: 'OpenRouter error: ${(error.toString()).trim()}',
            linkUrl:
                '${ref.read(apiBaseUrlProvider)}/api/settings/integrations/openrouter',
            linkLabel: context.tr('Open OpenRouter endpoint'),
          ),
        ],
      ),
    );
  }

  Color _openRouterStatusColor(OpenRouterCredentialStatus status) {
    if (!status.configured) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    if (status.isValid) return AppTheme.approveColor;
    if (status.isInvalid) return AppTheme.rejectColor;
    return AppTheme.warningColor;
  }

  String _openRouterStatusLabel(OpenRouterCredentialStatus status) {
    if (!status.configured) {
      return context.tr('No OpenRouter key configured');
    }
    switch (status.validationStatus) {
      case 'valid':
        return context.tr('OpenRouter key is valid');
      case 'invalid':
        return context.tr('OpenRouter key is invalid');
      case 'missing':
        return context.tr('OpenRouter key is missing');
      default:
        return context.tr('OpenRouter key saved, not validated yet');
    }
  }

  String _openRouterMetaText(OpenRouterCredentialStatus status) {
    final parts = <String>[];
    if (status.updatedAt != null) {
      parts.add(
        context.tr('Updated: {date}', {
          'date': _formatDateTime(status.updatedAt!),
        }),
      );
    }
    if (status.lastValidatedAt != null) {
      parts.add(
        context.tr('Validated: {date}', {
          'date': _formatDateTime(status.lastValidatedAt!),
        }),
      );
    }
    return parts.join(' • ');
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _saveOpenRouterCredential() async {
    final apiKey = _openRouterApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Enter an OpenRouter API key first.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingOpenRouterKey = true);
    try {
      final api = ref.read(apiServiceProvider);
      final status = await api.saveOpenRouterCredential(apiKey);
      _openRouterApiKeyController.clear();
      ref.invalidate(openRouterCredentialStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('OpenRouter key saved: {key}', {
              'key': status.maskedSecret ?? 'masked',
            }),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to save OpenRouter key: {error}', {
          'error': error.message,
        }),
        scope: 'settings.openrouter.save',
        error: error,
        contextData: {'statusCode': error.statusCode, 'path': error.path},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to save OpenRouter key: {error}', {
          'error': '$error',
        }),
        scope: 'settings.openrouter.save.unexpected',
        error: error,
        stackTrace: stackTrace,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isSavingOpenRouterKey = false);
    }
  }

  Future<void> _validateOpenRouterCredential() async {
    setState(() => _isValidatingOpenRouterKey = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.validateOpenRouterCredential();
      ref.invalidate(openRouterCredentialStatusProvider);
      if (!mounted) return;
      final validationMessage =
          result.message ?? context.tr('Validation completed.');
      if (result.valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationMessage),
            backgroundColor: AppTheme.approveColor.withAlpha(
              AppAlpha.high210,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        showCopyableDiagnosticSnackBar(
          context,
          ref,
          message: validationMessage,
          scope: 'settings.openrouter.validation_warning',
          backgroundColor: AppTheme.warningColor.withAlpha(AppAlpha.high220),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to validate OpenRouter key: {error}', {
          'error': error.message,
        }),
        scope: 'settings.openrouter.validate',
        error: error,
        contextData: {'statusCode': error.statusCode, 'path': error.path},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to validate OpenRouter key: {error}', {
          'error': '$error',
        }),
        scope: 'settings.openrouter.validate.unexpected',
        error: error,
        stackTrace: stackTrace,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isValidatingOpenRouterKey = false);
    }
  }

  Future<void> _deleteOpenRouterCredential() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete OpenRouter key?')),
        content: Text(
          context.tr(
            'This removes your stored OpenRouter credential and disables AI features across the app until you add a new one.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rejectColor,
            ),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingOpenRouterKey = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteOpenRouterCredential();
      _openRouterApiKeyController.clear();
      ref.invalidate(openRouterCredentialStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('OpenRouter key deleted.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to delete OpenRouter key: {error}', {
          'error': error.message,
        }),
        scope: 'settings.openrouter.delete',
        error: error,
        contextData: {'statusCode': error.statusCode, 'path': error.path},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to delete OpenRouter key: {error}', {
          'error': '$error',
        }),
        scope: 'settings.openrouter.delete.unexpected',
        error: error,
        stackTrace: stackTrace,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isDeletingOpenRouterKey = false);
    }
  }

  // ----- Email source ----------------------------------------------------

  Widget _buildEmailSourceBody(
    AsyncValue<EmailSourceStatus> state, {
    required AuthSession authSession,
    required String? activeProjectId,
  }) {
    final theme = Theme.of(context);
    final canManage = authSession.isAuthenticated && !authSession.isDemo;
    final busy =
        _isSavingEmailSource ||
        _isValidatingEmailSource ||
        _isDeletingEmailSource;

    return state.when(
      data: (status) {
        _primeEmailSourceControllers(status);
        final statusColor = _emailSourceStatusColor(status);
        final statusLabel = _emailSourceStatusLabel(status);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsStatusPill(
              label: statusLabel,
              color: statusColor,
              icon: status.configured
                  ? Icons.mark_email_read_outlined
                  : Icons.alternate_email,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(
                'Connect a mailbox folder once. ContentGlows checks it every 6 hours, turns useful emails into ideas, then moves processed emails to the archive folder.',
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppText.xs,
                height: _kLineHeight,
              ),
            ),
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
            TextField(
              controller: _emailSourceEmailController,
              enabled: canManage && !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.tr('Email address'),
                hintText: 'you@gmail.com',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailSourcePasswordController,
              enabled: canManage && !busy,
              obscureText: !_showEmailSourcePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.tr('App password'),
                hintText: status.configured
                    ? context.tr('Leave blank to keep current password')
                    : 'xxxx xxxx xxxx xxxx',
                helperText: context.tr(
                  'For Gmail: Google Account > Security > App passwords.',
                ),
                helperMaxLines: 2,
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _showEmailSourcePassword = !_showEmailSourcePassword,
                  ),
                  tooltip: _showEmailSourcePassword
                      ? context.tr('Hide password')
                      : context.tr('Show password'),
                  icon: Icon(
                    _showEmailSourcePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailSourceHostController,
              enabled: canManage && !busy,
              decoration: InputDecoration(
                labelText: context.tr('IMAP host'),
                hintText: 'imap.gmail.com',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailSourceFolderController,
                    enabled: canManage && !busy,
                    decoration: InputDecoration(
                      labelText: context.tr('Folder to scan'),
                      hintText: 'Newsletters',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: _IntegrationsScreenState._kInlineSpacing10),
                Expanded(
                  child: TextField(
                    controller: _emailSourceArchiveController,
                    enabled: canManage && !busy,
                    decoration: InputDecoration(
                      labelText: context.tr('Processed folder'),
                      hintText: 'CONTENTGLOWS_DONE',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (status.updatedAt != null || status.lastValidatedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _emailSourceMetaText(status),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                ),
              ),
            ],
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
            Wrap(
              spacing: AppSpacing.compact,
              runSpacing: AppSpacing.compact,
              children: [
                FilledButton.icon(
                  onPressed: canManage && activeProjectId != null && !busy
                      ? _saveEmailSourceIntegration
                      : null,
                  icon: _isSavingEmailSource
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.save_rounded, size: _kActionIconSize),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.approveColor,
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Save')),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && status.configured && !busy
                      ? _validateEmailSourceIntegration
                      : null,
                  icon: _isValidatingEmailSource
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.verified_outlined, size: _kActionIconSize),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Validate')),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && status.configured && !busy
                      ? _deleteEmailSourceIntegration
                      : null,
                  icon: _isDeletingEmailSource
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.delete_outline, size: _kActionIconSize),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rejectColor,
                    side: BorderSide(
                      color: AppTheme.rejectColor.withAlpha(AppAlpha.border),
                    ),
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Delete')),
                ),
              ],
            ),
            if (activeProjectId == null) ...[
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing10),
              Text(
                context.tr(
                  'Select a project before enabling automatic email ingestion.',
                ),
                style: TextStyle(
                  color: AppTheme.warningColor.withAlpha(AppAlpha.high220),
                  fontSize: AppText.xs,
                ),
              ),
            ],
          ],
        );
      },
      loading: () => Row(
        children: [
          const SizedBox(
            width: _kLoaderRegular,
            height: _kLoaderRegular,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('Loading email source...'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Unable to load email source state.'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          SettingsErrorDiagnostic(
            details: 'Email source error: ${(error.toString()).trim()}',
            linkUrl:
                '${ref.read(apiBaseUrlProvider)}/api/settings/integrations/email-source',
            linkLabel: context.tr('Open email source endpoint'),
          ),
        ],
      ),
    );
  }

  void _primeEmailSourceControllers(EmailSourceStatus status) {
    if (_emailSourceEmailController.text.isEmpty && status.email != null) {
      _emailSourceEmailController.text = status.email!;
    }
    if (_emailSourceHostController.text.isEmpty) {
      _emailSourceHostController.text = status.host;
    }
    if (_emailSourceFolderController.text.isEmpty) {
      _emailSourceFolderController.text = status.sourceFolder;
    }
    if (_emailSourceArchiveController.text.isEmpty) {
      _emailSourceArchiveController.text = status.archiveFolder;
    }
  }

  Color _emailSourceStatusColor(EmailSourceStatus status) {
    if (!status.configured) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    if (status.isValid) return AppTheme.approveColor;
    if (status.isInvalid) return AppTheme.rejectColor;
    return AppTheme.warningColor;
  }

  String _emailSourceStatusLabel(EmailSourceStatus status) {
    if (!status.configured) {
      return context.tr('No email source connected');
    }
    switch (status.validationStatus) {
      case 'valid':
        return context.tr('Email source is valid');
      case 'invalid':
        return context.tr('Email source needs attention');
      default:
        return context.tr('Email source saved, not validated yet');
    }
  }

  String _emailSourceMetaText(EmailSourceStatus status) {
    final parts = <String>[];
    if (status.updatedAt != null) {
      parts.add(
        context.tr('Updated: {date}', {
          'date': _formatDateTime(status.updatedAt!),
        }),
      );
    }
    if (status.lastValidatedAt != null) {
      parts.add(
        context.tr('Validated: {date}', {
          'date': _formatDateTime(status.lastValidatedAt!),
        }),
      );
    }
    return parts.join(' • ');
  }

  Future<void> _saveEmailSourceIntegration() async {
    final activeProjectId = ref.read(activeProjectIdProvider);
    if (activeProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Select a project before enabling email ingestion.'),
          ),
        ),
      );
      return;
    }
    final email = _emailSourceEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter an email address first.'))),
      );
      return;
    }

    setState(() => _isSavingEmailSource = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.saveEmailSource(
        email: email,
        appPassword: _emailSourcePasswordController.text,
        host: _emailSourceHostController.text.trim().isEmpty
            ? 'imap.gmail.com'
            : _emailSourceHostController.text.trim(),
        sourceFolder: _emailSourceFolderController.text.trim().isEmpty
            ? 'Newsletters'
            : _emailSourceFolderController.text.trim(),
        archiveFolder: _emailSourceArchiveController.text.trim().isEmpty
            ? 'CONTENTGLOWS_DONE'
            : _emailSourceArchiveController.text.trim(),
        projectId: activeProjectId,
      );
      _emailSourcePasswordController.clear();
      ref.invalidate(emailSourceStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Email source saved. Automatic checks run every 6 hours.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to save email source: {error}', {
          'error': error.message,
        }),
        scope: 'settings.email_source.save',
        error: error,
        contextData: {'statusCode': error.statusCode, 'path': error.path},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isSavingEmailSource = false);
    }
  }

  Future<void> _validateEmailSourceIntegration() async {
    setState(() => _isValidatingEmailSource = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.validateEmailSource();
      ref.invalidate(emailSourceStatusProvider);
      if (!mounted) return;
      final color = result.valid
          ? AppTheme.approveColor.withAlpha(AppAlpha.high210)
          : AppTheme.warningColor.withAlpha(AppAlpha.high220);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to validate email source: {error}', {
          'error': error.message,
        }),
        scope: 'settings.email_source.validate',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isValidatingEmailSource = false);
    }
  }

  Future<void> _deleteEmailSourceIntegration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete email source?')),
        content: Text(
          context.tr(
            'This removes the stored IMAP app password and stops email-based idea ingestion.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rejectColor,
            ),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingEmailSource = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteEmailSource();
      _emailSourcePasswordController.clear();
      ref.invalidate(emailSourceStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Email source deleted.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to delete email source: {error}', {
          'error': error.message,
        }),
        scope: 'settings.email_source.delete',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isDeletingEmailSource = false);
    }
  }

  // ----- GitHub ----------------------------------------------------------

  Widget _buildGithubBody(AsyncValue<GithubIntegrationState> state) {
    final theme = Theme.of(context);

    return state.when(
      data: (value) {
        final connected = value.connected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsStatusPill(
              label: connected
                  ? context.tr('Connected as {username}', {
                      'username': value.username ?? context.tr('unknown'),
                    })
                  : context.tr('Not connected'),
              color: connected
                  ? AppTheme.approveColor
                  : theme.colorScheme.onSurfaceVariant,
              icon: connected ? Icons.check_circle_outline : Icons.link_off,
            ),
            if (value.scope != null && value.scope!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr('Granted scopes: {scope}', {'scope': value.scope!}),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                ),
              ),
            ],
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
            connected
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.link_off, size: _kActionIconSize),
                    label: Text(context.tr('Disconnect GitHub')),
                    onPressed: _disconnectGithub,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, _kActionButtonHeight),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _connectGithub,
                    icon: const Icon(Icons.link, size: _kActionIconSize),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.approveColor,
                      minimumSize: const Size(0, _kActionButtonHeight),
                    ),
                    label: Text(context.tr('Connect GitHub')),
                  ),
          ],
        );
      },
      loading: () => Row(
        children: [
          const SizedBox(
            width: _kLoaderRegular,
            height: _kLoaderRegular,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('Checking GitHub integration...'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Unable to load GitHub integration state.'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          SettingsErrorDiagnostic(
            details: 'GitHub error: ${(error.toString()).trim()}',
            linkUrl:
                '${ref.read(apiBaseUrlProvider)}/api/integrations/github/status',
            linkLabel: context.tr('Open GitHub status endpoint'),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton(
            onPressed: _connectGithub,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.approveColor,
              minimumSize: const Size(0, _kActionButtonHeight),
            ),
            child: Text(context.tr('Try reconnecting')),
          ),
        ],
      ),
    );
  }

  Future<void> _connectGithub() async {
    final api = ref.read(apiServiceProvider);
    String? connectUrl;
    try {
      connectUrl = await api.getGithubConnectUrl();
    } on ApiException catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('GitHub OAuth is unavailable: {error}', {
          'error': error.message,
        }),
        scope: 'settings.github.connect',
        error: error,
        stackTrace: stackTrace,
        contextData: {'path': error.path, 'statusCode': error.statusCode},
      );
      return;
    }

    if (connectUrl == null || connectUrl.isEmpty) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr(
          'GitHub OAuth is unavailable. Check backend configuration.',
        ),
        scope: 'settings.github.connect_url_missing',
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
      return;
    }

    final uri = Uri.parse(connectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('GitHub connection')),
          content: Text(
            context.tr(
              'A browser opened for authorization. Once you finish, return here and tap Refresh.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Close')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.invalidate(githubIntegrationStatusProvider);
              },
              child: Text(context.tr('Refresh')),
            ),
          ],
        ),
      );
    } else if (mounted) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Could not open browser for GitHub authorization'),
        scope: 'settings.github.browser_unavailable',
        contextData: {'connectUrl': connectUrl},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    }
  }

  Future<void> _disconnectGithub() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Disconnect GitHub?')),
        content: Text(
          context.tr(
            'This removes your GitHub connection and hides private repository data from the picker.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rejectColor,
            ),
            child: Text(context.tr('Disconnect')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final api = ref.read(apiServiceProvider);
    final success = await api.disconnectGithubIntegration();
    if (!mounted) return;

    if (success) {
      ref.invalidate(githubIntegrationStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('GitHub disconnected.'))),
      );
    } else {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Failed to disconnect GitHub.'),
        scope: 'settings.github.disconnect',
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    }
  }

  // ----- Google Search Console ------------------------------------------

  Widget _buildSearchConsoleBody(
    AsyncValue<SearchConsoleConnectionStatus> state, {
    required AsyncValue<List<SearchConsoleProperty>> propertiesState,
    required AuthSession authSession,
    required String? activeProjectId,
  }) {
    final theme = Theme.of(context);
    final canManage =
        authSession.isAuthenticated &&
        !authSession.isDemo &&
        activeProjectId != null;
    final busy =
        _isConnectingSearchConsole ||
        _isSavingSearchConsoleProperty ||
        _isValidatingSearchConsole ||
        _isDisconnectingSearchConsole;

    return state.when(
      data: (status) {
        final needsPropertyFallback =
            status.connected &&
            ((status.propertyUrl == null || status.propertyUrl!.isEmpty) ||
                status.isDegraded ||
                status.isInvalid);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsStatusPill(
              label: _searchConsoleStatusLabel(status),
              color: _searchConsoleStatusColor(status, theme.colorScheme),
              icon: _searchConsoleStatusIcon(status),
            ),
            if (status.accountEmail != null ||
                status.propertyLabel != null ||
                status.lastSyncMessage != null) ...[
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing10),
              _SearchConsoleMetaLine(
                icon: Icons.account_circle_outlined,
                text:
                    status.accountEmail ?? context.tr('No Google account yet'),
              ),
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing6),
              _SearchConsoleMetaLine(
                icon: Icons.travel_explore_outlined,
                text:
                    status.propertyLabel ??
                    context.tr(
                      'Property is matched automatically from the selected project domain',
                    ),
              ),
              if (status.lastSyncMessage != null &&
                  status.lastSyncMessage!.isNotEmpty) ...[
                const SizedBox(height: _IntegrationsScreenState._kInlineSpacing6),
                _SearchConsoleMetaLine(
                  icon: Icons.info_outline,
                  text: status.lastSyncMessage!,
                ),
              ],
            ],
            if (needsPropertyFallback && activeProjectId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSearchConsolePropertySuggestions(
                propertiesState,
                projectId: activeProjectId,
                selectedPropertyUrl: status.propertyUrl,
                canManage: canManage && !busy,
              ),
            ],
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
            Wrap(
              spacing: AppSpacing.compact,
              runSpacing: AppSpacing.compact,
              children: [
                FilledButton.icon(
                  onPressed: canManage && !busy
                      ? () => _connectSearchConsole(activeProjectId)
                      : null,
                  icon: _isConnectingSearchConsole
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.open_in_browser_rounded, size: _kActionIconSize),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.infoColor,
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Connect Google')),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && status.connected && !busy
                      ? () => _validateSearchConsole(activeProjectId)
                      : null,
                  icon: _isValidatingSearchConsole
                      ? const SizedBox(
                          width: _kLoaderSmall,
                          height: _kLoaderSmall,
                          child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                        )
                      : const Icon(Icons.verified_outlined, size: _kActionIconSize),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _kActionButtonHeight),
                  ),
                  label: Text(context.tr('Validate')),
                ),
                if (status.connected)
                  OutlinedButton.icon(
                    onPressed: canManage && !busy
                        ? () => _disconnectSearchConsole(activeProjectId)
                        : null,
                    icon: _isDisconnectingSearchConsole
                        ? const SizedBox(
                            width: _kLoaderSmall,
                            height: _kLoaderSmall,
                            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
                          )
                        : const Icon(Icons.link_off_rounded, size: _kActionIconSize),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.rejectColor,
                      minimumSize: const Size(0, _kActionButtonHeight),
                    ),
                    label: Text(context.tr('Disconnect')),
                  ),
              ],
            ),
            if (!canManage) ...[
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing10),
              Text(
                activeProjectId == null
                    ? context.tr(
                        'Select a project before connecting Search Console.',
                      )
                    : context.tr('Sign in to manage Search Console.'),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                  height: _kLineHeight,
                ),
              ),
            ],
          ],
        );
      },
      loading: () => Row(
        children: [
          const SizedBox(
            width: _kLoaderRegular,
            height: _kLoaderRegular,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('Checking Search Console integration...'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Unable to load Search Console integration state.'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          SettingsErrorDiagnostic(
            details: 'Search Console error: ${(error.toString()).trim()}',
            linkUrl:
                '${ref.read(apiBaseUrlProvider)}/api/search-console/status',
            linkLabel: context.tr('Open Search Console status endpoint'),
          ),
        ],
      ),
    );
  }

  String _searchConsoleStatusLabel(SearchConsoleConnectionStatus status) {
    if (status.isValid) {
      return context.tr('Connected and valid');
    }
    if (status.isDegraded) {
      return context.tr('Connected, degraded');
    }
    if (status.isInvalid) {
      return context.tr('Reconnect required');
    }
    if (status.connected) {
      return context.tr('Connected, validation pending');
    }
    return context.tr('Not connected');
  }

  Widget _buildSearchConsolePropertySuggestions(
    AsyncValue<List<SearchConsoleProperty>> state, {
    required String projectId,
    required String? selectedPropertyUrl,
    required bool canManage,
  }) {
    final theme = Theme.of(context);
    return state.when(
      data: (properties) {
        final compatible = properties
            .where((property) => property.matchesProjectDomain)
            .toList(growable: false);
        if (compatible.isEmpty) {
          return Text(
            context.tr(
              'No compatible Search Console property found for this project domain.',
            ),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
              height: _IntegrationsScreenState._kCompactLineHeight,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Compatible properties'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: AppText.xs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canManage
                      ? () => ref.invalidate(searchConsolePropertiesProvider)
                      : null,
                  tooltip: context.tr('Refresh properties'),
                  icon: const Icon(Icons.refresh_rounded, size: _kActionIconSize),
                ),
              ],
            ),
            const SizedBox(height: _IntegrationsScreenState._kInlineSpacing6),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: compatible.take(8).map((property) {
                final selected = selectedPropertyUrl == property.siteUrl;
                return ChoiceChip(
                  label: Text(property.siteUrl),
                  selected: selected,
                  avatar: property.matchesProjectDomain
                      ? Icon(
                          Icons.check_circle_outline,
                          size: _IntegrationsScreenState._kPanelIconSize,
                          color: AppTheme.approveColor,
                        )
                      : null,
                  onSelected: canManage && !selected
                      ? (_) => _saveSearchConsoleProperty(
                          projectId,
                          property.siteUrl,
                        )
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: _kHeroTitleGap,
            height: _kHeroTitleGap,
            child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
          ),
          const SizedBox(width: _IntegrationsScreenState._kInlineSpacing8),
          Text(
            context.tr('Loading accessible properties...'),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
            ),
          ),
        ],
      ),
      error: (error, _) => Text(
        context.tr('Unable to load accessible properties: {error}', {
          'error': error.toString(),
        }),
        style: TextStyle(
          color: AppTheme.warningColor,
          fontSize: AppText.xs,
          height: _IntegrationsScreenState._kCompactLineHeight,
        ),
      ),
    );
  }

  Color _searchConsoleStatusColor(
    SearchConsoleConnectionStatus status,
    ColorScheme colorScheme,
  ) {
    if (status.isValid) return AppTheme.approveColor;
    if (status.isDegraded) return AppTheme.warningColor;
    if (status.isInvalid) return AppTheme.rejectColor;
    if (status.connected) return AppTheme.infoColor;
    return colorScheme.onSurfaceVariant;
  }

  IconData _searchConsoleStatusIcon(SearchConsoleConnectionStatus status) {
    if (status.isValid) return Icons.check_circle_outline;
    if (status.isDegraded) return Icons.warning_amber_rounded;
    if (status.isInvalid) return Icons.error_outline;
    if (status.connected) return Icons.link_rounded;
    return Icons.link_off_rounded;
  }

  Future<void> _connectSearchConsole(String projectId) async {
    if (_isConnectingSearchConsole) return;
    setState(() => _isConnectingSearchConsole = true);
    try {
      final api = ref.read(apiServiceProvider);
      final start = await api.startSearchConsoleOAuth(projectId: projectId);
      final uri = Uri.tryParse(start.authorizeUrl);
      if (uri == null) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid Google OAuth URL returned by FastAPI.',
        );
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('Google Search Console')),
            content: Text(
              context.tr(
                'A browser opened for authorization. Once Google returns, come back here and refresh the status.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('Close')),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.invalidate(searchConsoleConnectionStatusProvider);
                  ref.invalidate(searchConsolePropertiesProvider);
                },
                child: Text(context.tr('Refresh')),
              ),
            ],
          ),
        );
      } else if (mounted) {
        showCopyableDiagnosticSnackBar(
          context,
          ref,
          message: context.tr(
            'Could not open browser for Google Search Console authorization',
          ),
          scope: 'settings.search_console.browser_unavailable',
          contextData: {'authorizeUrl': start.authorizeUrl},
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        );
      }
    } on ApiException catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Google Search Console OAuth is unavailable.')
            : error.message.trim(),
        scope: 'settings.search_console.connect',
        error: error,
        stackTrace: stackTrace,
        contextData: {'path': error.path, 'statusCode': error.statusCode},
      );
    } finally {
      if (mounted) setState(() => _isConnectingSearchConsole = false);
    }
  }

  Future<void> _saveSearchConsoleProperty(
    String projectId,
    String propertyUrl,
  ) async {
    if (_isSavingSearchConsoleProperty) return;
    setState(() => _isSavingSearchConsoleProperty = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.setSearchConsoleProperty(
        projectId: projectId,
        propertyUrl: propertyUrl,
      );
      ref.invalidate(searchConsoleConnectionStatusProvider);
      ref.invalidate(searchConsolePropertiesProvider);
      ref.invalidate(searchConsoleSummaryProvider);
      ref.invalidate(searchConsoleOpportunitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Search Console property matched.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Failed to save Search Console property.')
            : error.message.trim(),
        scope: 'settings.search_console.property',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isSavingSearchConsoleProperty = false);
    }
  }

  Future<void> _validateSearchConsole(String projectId) async {
    if (_isValidatingSearchConsole) return;
    setState(() => _isValidatingSearchConsole = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.validateSearchConsole(projectId: projectId);
      ref.invalidate(searchConsoleConnectionStatusProvider);
      ref.invalidate(searchConsolePropertiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Search Console validated.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ref.invalidate(searchConsoleConnectionStatusProvider);
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Failed to validate Search Console.')
            : error.message.trim(),
        scope: 'settings.search_console.validate',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isValidatingSearchConsole = false);
    }
  }

  Future<void> _disconnectSearchConsole(String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Disconnect Search Console?')),
        content: Text(
          context.tr(
            'This removes the project OAuth connection. Cached SEO snapshots can still be shown as stale until replaced.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rejectColor,
            ),
            child: Text(context.tr('Disconnect')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDisconnectingSearchConsole = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.disconnectSearchConsole(projectId: projectId);
      ref.invalidate(searchConsoleConnectionStatusProvider);
      ref.invalidate(searchConsolePropertiesProvider);
      ref.invalidate(searchConsoleSummaryProvider);
      ref.invalidate(searchConsoleOpportunitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Search Console disconnected.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Failed to disconnect Search Console.')
            : error.message.trim(),
        scope: 'settings.search_console.disconnect',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isDisconnectingSearchConsole = false);
    }
  }

  // ----- Publishing channels --------------------------------------------

  List<Widget> _buildChannelRows({
    required AsyncValue<List<PublishAccount>> accountsAsync,
    required AsyncValue<PublishAccountsState> publishAccountsState,
  }) {
    final notices = <Widget>[];
    final unavailable = publishAccountsState.value?.isUnavailable == true;
    final hasError = publishAccountsState.value?.hasError == true;

    if (unavailable) {
      notices.add(
        SettingsBlock(
          child: _buildPublishAccountsNotice(
            context.tr(
              'Publish account connections are unavailable until the backend publish integration is configured.',
            ),
            detail: publishAccountsState.value?.message,
          ),
        ),
      );
    } else if (hasError) {
      notices.add(
        SettingsBlock(
          child: _buildPublishAccountsNotice(
            context.tr(
              'Connected accounts could not be loaded right now. Publishing stays available only for already-resolved flows.',
            ),
            detail: publishAccountsState.value?.message,
            tone: AppTheme.warningColor,
          ),
        ),
      );
    }

    final channels = [
      ('WordPress', PublishingChannel.wordpress, Icons.language),
      ('Twitter / X', PublishingChannel.twitter, Icons.alternate_email),
      ('LinkedIn', PublishingChannel.linkedin, Icons.work_outline),
      ('Instagram', PublishingChannel.instagram, Icons.camera_alt_outlined),
      ('Ghost', PublishingChannel.ghost, Icons.edit_note),
      ('YouTube', PublishingChannel.youtube, Icons.play_circle_outline),
      ('TikTok', PublishingChannel.tiktok, Icons.music_note),
    ];

    final rows = channels.map((ch) {
      final (name, channel, icon) = ch;
      final platform = channelToPlatform(channel);
      final account = accountsAsync.value == null || platform == null
          ? null
          : _accountForPlatform(accountsAsync.value!, platform);
      final connected = account != null;

      return SettingsRow(
        icon: icon,
        title: name,
        subtitle: _channelSubtitle(
          accountsAsync: accountsAsync,
          publishAccountsState: publishAccountsState,
          platform: platform,
          connected: connected,
          account: account,
        ),
        iconColor: connected ? AppTheme.approveColor : null,
        trailing: _buildChannelTrailing(
          name: name,
          platform: platform,
          connected: connected,
          isLoading: accountsAsync.isLoading,
          publishAccountsState: publishAccountsState,
        ),
      );
    }).toList();

    return [...notices, ...rows];
  }

  Widget _buildPublishAccountsNotice(
    String message, {
    String? detail,
    Color? tone,
  }) {
    final theme = Theme.of(context);
    final resolvedTone = tone ?? AppTheme.rejectColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: resolvedTone, fontSize: _IntegrationsScreenState._kInfoTextSize, height: _kLineHeight),
        ),
        if (detail != null && detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
            ),
          ),
        ],
      ],
    );
  }

  String _channelSubtitle({
    required AsyncValue<List<PublishAccount>> accountsAsync,
    required AsyncValue<PublishAccountsState> publishAccountsState,
    required String? platform,
    required bool connected,
    required PublishAccount? account,
  }) {
    if (accountsAsync.isLoading) {
      return context.tr('Loading connected accounts...');
    }
    if (publishAccountsState.value?.isUnavailable == true) {
      return context.tr('Publish connections unavailable');
    }
    if (publishAccountsState.value?.hasError == true ||
        accountsAsync.hasError) {
      return context.tr('Could not fetch connected accounts');
    }
    if (platform == null) {
      return context.tr('Not wired to LATE publish flow yet');
    }
    if (connected && account != null) {
      return '${account.displayName} @${account.username}';
    }
    return context.tr('Tap Connect to authorize');
  }

  Widget? _buildChannelTrailing({
    required String name,
    required String? platform,
    required bool connected,
    required bool isLoading,
    required AsyncValue<PublishAccountsState> publishAccountsState,
  }) {
    if (isLoading) {
      return const SizedBox(
        width: _kLoaderRegular,
        height: _kLoaderRegular,
        child: CircularProgressIndicator(strokeWidth: _IntegrationsScreenState._kLoaderHeight),
      );
    }

    if (platform == null) {
      return Text(
        context.tr('Not wired'),
        style: TextStyle(
          color: AppTheme.warningColor.withAlpha(AppAlpha.icon),
          fontSize: AppText.xs,
        ),
      );
    }

    if (publishAccountsState.value?.isUnavailable == true ||
        publishAccountsState.value?.hasError == true) {
      return Text(
        context.tr('Unavailable'),
        style: TextStyle(
          color: AppTheme.warningColor.withAlpha(AppAlpha.icon),
          fontSize: AppText.xs,
        ),
      );
    }

    if (connected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsStatusPill(
            label: context.tr('Connected'),
            color: AppTheme.approveColor,
          ),
          const SizedBox(width: AppSpacing.xxs),
          IconButton(
            icon: Icon(
              Icons.link_off,
              size: AppSpacing.lg,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: context.tr('Disconnect'),
            onPressed: () => _disconnectChannel(name, platform),
            constraints: const BoxConstraints(
              minWidth: _kActionButtonHeight,
              minHeight: _kActionButtonHeight,
            ),
          ),
        ],
      );
    }

    return FilledButton.tonal(
      onPressed: () => _connectChannel(name, platform),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minimumSize: const Size(0, _kActionButtonCompactHeight),
      ),
      child: Text(context.tr('Connect')),
    );
  }

  Future<void> _connectChannel(String channelName, String? platform) async {
    if (platform == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '{channelName} is not supported for direct connection yet',
              {'channelName': channelName},
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      );
      return;
    }

    final activeProjectId = ref.read(activeProjectIdProvider);
    if (activeProjectId == null) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr(
          'Select a project before connecting a publish account.',
        ),
        scope: 'settings.channel.no_project',
        contextData: {'channel': channelName, 'platform': platform},
        backgroundColor: AppTheme.warningColor.withAlpha(AppAlpha.text),
      );
      return;
    }

    final api = ref.read(apiServiceProvider);
    final connectUrl = await api.getConnectUrl(
      platform,
      projectId: activeProjectId,
    );

    if (!mounted) return;

    if (connectUrl == null || connectUrl.isEmpty) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr('Could not get connect URL for {channelName}', {
          'channelName': channelName,
        }),
        scope: 'settings.channel.connect_url_missing',
        contextData: {'channel': channelName, 'platform': platform},
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
      return;
    }

    final uri = Uri.parse(connectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            context.tr('Connecting {channelName}', {
              'channelName': channelName,
            }),
          ),
          content: Text(
            context.tr(
              'A browser window has opened for you to authorize {channelName}.\n\nOnce done, tap "Refresh" to see your connected account.',
              {'channelName': channelName},
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.invalidate(publishAccountsStateProvider);
                ref.invalidate(publishAccountsProvider);
              },
              child: Text(context.tr('Refresh')),
            ),
          ],
        ),
      );
    } else if (mounted) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: context.tr(
          'Could not open browser for {channelName} authorization',
          {'channelName': channelName},
        ),
        scope: 'settings.channel.browser_unavailable',
        contextData: {
          'channel': channelName,
          'platform': platform,
          'connectUrl': connectUrl,
        },
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    }
  }

  Future<void> _disconnectChannel(String channelName, String platform) async {
    final accounts = ref.read(publishAccountsProvider).value ?? [];
    final account = _accountForPlatform(accounts, platform);
    if (account == null) return;
    final activeProjectId = ref.read(activeProjectIdProvider);
    if (activeProjectId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('Disconnect {channelName}?', {'channelName': channelName}),
        ),
        content: Text(
          context.tr('This will remove the connection to {displayName}.', {
            'displayName': account.displayName,
          }),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rejectColor,
            ),
            child: Text(context.tr('Disconnect')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final api = ref.read(apiServiceProvider);
    final success = await api.disconnectAccount(
      account.id,
      projectId: activeProjectId,
    );

    if (mounted) {
      if (success) {
        ref.invalidate(publishAccountsStateProvider);
        ref.invalidate(publishAccountsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Disconnected {channelName}', {
                'channelName': channelName,
              }),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        );
      } else {
        showCopyableDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Failed to disconnect {channelName}', {
            'channelName': channelName,
          }),
          scope: 'settings.channel.disconnect',
          contextData: {'channel': channelName, 'platform': platform},
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        );
      }
    }
  }

  PublishAccount? _accountForPlatform(
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
}

class _SearchConsoleMetaLine extends StatelessWidget {
  const _SearchConsoleMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: _IntegrationsScreenState._kPanelIconSize, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: _IntegrationsScreenState._kInlineSpacing8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
              height: _IntegrationsScreenState._kCompactLineHeight,
            ),
          ),
        ),
      ],
    );
  }
}

class AIUsageQuotaCard extends StatelessWidget {
  const AIUsageQuotaCard({
    super.key,
    required this.state,
    required this.selectedMode,
    required this.onRefresh,
    this.onContactSupport,
  });

  final AsyncValue<AIUsageSnapshot?> state;
  final String selectedMode;
  final VoidCallback onRefresh;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: context.tr('AI usage and limits'),
      child: Column(
        key: const Key('ai-usage-quota-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Usage and limits'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: AppText.base,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('ai-usage-refresh'),
                onPressed: state.isLoading ? null : onRefresh,
                tooltip: context.tr('Refresh AI usage'),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            selectedMode == 'platform'
                ? context.tr(
                    'Managed AI uses ContentGlows usage units. Generation is blocked before provider costs when units are unavailable.',
                  )
                : context.tr(
                    'BYOK uses your provider credentials. Managed usage units are not consumed.',
                  ),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
              height: AppLineHeight.comfortable,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          state.when(
            loading: () => const _AIUsageLoadingState(),
            error: (error, _) => _AIUsageErrorState(
              error: error,
              onRefresh: onRefresh,
              onContactSupport: onContactSupport,
            ),
            data: (snapshot) => _AIUsageDataState(
              snapshot: snapshot,
              selectedMode: selectedMode,
              onContactSupport: onContactSupport,
            ),
          ),
        ],
      ),
    );
  }
}

class _AIUsageLoadingState extends StatelessWidget {
  const _AIUsageLoadingState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: AppSizes.iconHeading,
          height: AppSizes.iconHeading,
          child: CircularProgressIndicator(strokeWidth: AppStroke.loading),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(context.tr('Checking current AI usage...'))),
      ],
    );
  }
}

class _AIUsageDataState extends StatelessWidget {
  const _AIUsageDataState({
    required this.snapshot,
    required this.selectedMode,
    this.onContactSupport,
  });

  final AIUsageSnapshot? snapshot;
  final String selectedMode;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (snapshot == null) {
      return Text(
        context.tr('Sign in and select a project to check AI usage.'),
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final billingMode = selectedMode == 'platform' ? 'managed' : 'byok';
    final quotas = snapshot!.summary.quotas
        .where((quota) => quota.billingMode == billingMode)
        .toList(growable: false);
    if (quotas.isEmpty) {
      return SettingsStatusPill(
        label: selectedMode == 'platform'
            ? context.tr('Managed AI is not available for this project')
            : context.tr('BYOK does not consume managed usage units'),
        color: selectedMode == 'platform'
            ? AppTheme.warningColor
            : AppTheme.infoColor,
        icon: selectedMode == 'platform'
            ? Icons.info_outline_rounded
            : Icons.key_rounded,
      );
    }

    return Column(
      children: [
        for (final quota in quotas) ...[
          _AIUsageQuotaRow(
            quota: quota,
            onContactSupport: onContactSupport,
          ),
          if (quota != quotas.last) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _AIUsageQuotaRow extends StatelessWidget {
  const _AIUsageQuotaRow({required this.quota, this.onContactSupport});

  final AIQuotaStatus quota;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = quota.allowed ? AppTheme.approveColor : AppTheme.warningColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.low12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withAlpha(AppAlpha.tint)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _actionLabel(context, quota.action),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SettingsStatusPill(
                label: quota.allowed
                    ? context.tr('Available')
                    : context.tr('Blocked'),
                color: color,
                icon: quota.allowed
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
              ),
            ],
          ),
          if (quota.billingMode == 'managed') ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('{remaining} of {limit} units remaining', {
                'remaining': _displayUnits(quota.unitRemaining),
                'limit': _displayUnits(quota.unitLimit),
              }),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppText.xs,
              ),
            ),
          ],
          if (!quota.allowed && onContactSupport != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: Key('ai-usage-contact-support-${quota.action.apiValue}'),
              onPressed: onContactSupport,
              icon: const Icon(Icons.forum_outlined),
              label: Text(context.tr('Contact support')),
            ),
          ],
        ],
      ),
    );
  }
}

class _AIUsageErrorState extends StatelessWidget {
  const _AIUsageErrorState({
    required this.error,
    required this.onRefresh,
    this.onContactSupport,
  });

  final Object error;
  final VoidCallback onRefresh;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final apiError = error is ApiException ? error as ApiException : null;
    final canContactSupport =
        apiError?.code == 'ai_quota_exhausted' ||
        apiError?.code == 'ai_entitlement_missing';
    final message = switch (apiError?.code) {
      'ai_quota_exhausted' => context.tr(
        'Managed AI usage is exhausted. Generation remains blocked before provider costs. Contact support to add PAYG usage.',
      ),
      'ai_entitlement_missing' => context.tr(
        'Managed AI is not enabled for this project. Contact support before trying again.',
      ),
      'ai_runtime_user_credential_missing' => context.tr(
        'Your provider key is missing. Add and validate it in the OpenRouter section below.',
      ),
      'ai_generation_rate_limited' => context.tr(
        'AI generation is temporarily rate limited. Wait, then refresh before retrying.',
      ),
      _ => context.tr(
        'Current AI usage is unavailable. No cached quota is shown for paid actions.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsStatusPill(
          label: context.tr('Usage unavailable'),
          color: AppTheme.warningColor,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.compact,
          runSpacing: AppSpacing.compact,
          children: [
            OutlinedButton.icon(
              key: const Key('ai-usage-error-refresh'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('Check again')),
            ),
            if (canContactSupport && onContactSupport != null)
              FilledButton.icon(
                key: const Key('ai-usage-contact-support'),
                onPressed: onContactSupport,
                icon: const Icon(Icons.forum_outlined),
                label: Text(context.tr('Contact support')),
              ),
          ],
        ),
      ],
    );
  }
}

String _actionLabel(BuildContext context, AIUsageAction action) {
  return switch (action) {
    AIUsageAction.fluxImageGeneration => context.tr('AI image generation'),
    AIUsageAction.bunnyUpload => context.tr('Media delivery'),
    AIUsageAction.remotionRender => context.tr('Video rendering'),
    AIUsageAction.byokMetadata => context.tr('BYOK AI metadata'),
  };
}

String _displayUnits(String value) {
  if (!value.contains('.')) return value;
  final compact = value.replaceFirst(RegExp(r'0+$'), '');
  return compact.endsWith('.') ? compact.substring(0, compact.length - 1) : compact;
}

/// AI runtime mode selector. Lifted from the legacy settings screen unchanged
/// in behavior so existing tests continue to target `Key('ai-runtime-mode-...')`.
class AiRuntimeSettingsCard extends StatelessWidget {
  const AiRuntimeSettingsCard({
    super.key,
    required this.settings,
    required this.canManage,
    required this.isUpdating,
    this.onModeSelected,
  });

  final AIRuntimeSettings settings;
  final bool canManage;
  final bool isUpdating;
  final Future<void> Function(String mode)? onModeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedMode = settings.mode == 'platform' ? 'platform' : 'byok';
    final byok = settings.modeAvailability('byok');
    final platform = settings.modeAvailability('platform');

    Widget modeChip({
      required String mode,
      required String label,
      required AIRuntimeModeAvailability? availability,
    }) {
      final enabled = availability?.enabled ?? (mode == 'byok');
      final selected = selectedMode == mode;
      final isDisabled = !enabled || !canManage || isUpdating;
      final subtitle = enabled
          ? null
          : availability?.message ?? 'Not available for this account';
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChoiceChip(
              key: Key('ai-runtime-mode-$mode'),
              label: Text(label),
              selected: selected,
              onSelected: isDisabled
                  ? null
                  : (_) {
                      final callback = onModeSelected;
                      if (callback != null) callback(mode);
                    },
            ),
            if (subtitle != null) ...[
              const SizedBox(height: _IntegrationsScreenState._kInlineSpacing6),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            modeChip(
              mode: 'byok',
              label: context.tr('BYOK'),
              availability: byok,
            ),
            const SizedBox(width: AppSpacing.sm),
            modeChip(
              mode: 'platform',
              label: context.tr('Platform'),
              availability: platform,
            ),
          ],
        ),
        const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
        if (!canManage)
          Text(
            context.tr(
              'Sign in to manage AI runtime mode and provider states.',
            ),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
            ),
          ),
        if (isUpdating) ...[
          const SizedBox(height: _IntegrationsScreenState._kInlineSpacing10),
          const LinearProgressIndicator(minHeight: _IntegrationsScreenState._kLoaderHeight),
        ],
        const SizedBox(height: _IntegrationsScreenState._kInlineSpacing14),
        ...settings.providers.map((provider) {
          final providerLabel = switch (provider.provider) {
            'openrouter' => 'OpenRouter',
            'exa' => 'Exa',
            'firecrawl' => 'Firecrawl',
            _ => provider.provider,
          };
          final byokLabel = provider.byok.configured
              ? context.tr('BYOK configured')
              : context.tr('BYOK missing');
          final platformLabel = provider.platform.available
              ? context.tr('Platform ready')
              : provider.platform.configured
              ? context.tr('Platform configured (locked)')
              : context.tr('Platform missing');
          return Container(
            key: Key('ai-runtime-provider-${provider.provider}'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: _IntegrationsScreenState._kInlineSpacing10,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                AppAlpha.border,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(
                  AppAlpha.strong120,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    providerLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: _IntegrationsScreenState._kInfoTextSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$byokLabel · $platformLabel',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppText.xs,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
