import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/project_onboarding_validation.dart';
import '../../../data/demo/demo_seed.dart';
import '../../../data/models/project.dart';
import '../../../data/services/api_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_exit_confirmation.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;
  bool _didLoadProject = false;
  bool _isRepoPickerLoading = false;
  String? _lastAutoProjectName;

  // Page 1: Project source
  final _repoUrlController = TextEditingController();
  final _projectNameController = TextEditingController();

  // Page 2: Content types
  late List<ContentTypeConfig> _contentTypes;
  late final bool _isDemoMode;
  String get _mode =>
      GoRouterState.of(context).uri.queryParameters['mode'] ?? 'workspace';
  String? get _projectId =>
      GoRouterState.of(context).uri.queryParameters['projectId'];
  bool get _isProjectCreateMode => _mode == 'create';
  bool get _isProjectEditMode => _mode == 'edit';
  bool get _isWorkspaceSetupMode =>
      !_isProjectCreateMode && !_isProjectEditMode;

  @override
  void initState() {
    super.initState();
    _isDemoMode = ref.read(authSessionProvider).isDemo;
    if (_isDemoMode) {
      _projectNameController.text = DemoSeed.projectName;
      _repoUrlController.text = DemoSeed.repoUrl;
      _contentTypes = DemoSeed.contentTypes();
    } else {
      _contentTypes = ContentTypeConfig.defaults();
    }
    _projectNameController.addListener(_onProjectChanged);
    _repoUrlController.addListener(_onProjectChanged);
  }

  @override
  void dispose() {
    _projectNameController.removeListener(_onProjectChanged);
    _repoUrlController.removeListener(_onProjectChanged);
    _pageController.dispose();
    _repoUrlController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadProject || !_isProjectEditMode || _projectId == null) {
      return;
    }

    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final project = projects
        .where((candidate) => candidate.id == _projectId)
        .cast<Project?>()
        .firstWhere((_) => true, orElse: () => null);
    if (project == null) {
      return;
    }
    _didLoadProject = true;
    _projectNameController.text = project.name;
    _repoUrlController.text = project.url;
    _contentTypes = project.settings?.contentTypes.isNotEmpty == true
        ? project.settings!.contentTypes
        : ContentTypeConfig.defaults();
  }

  void _onProjectChanged() {
    _maybeAutofillProjectNameFromRepo();
    if (mounted) {
      setState(() {});
    }
  }

  void _maybeAutofillProjectNameFromRepo() {
    if (_isDemoMode || _isProjectEditMode) {
      return;
    }

    final repoName = extractGithubRepositoryName(_repoUrlController.text);
    if (repoName == null) {
      return;
    }

    final currentProjectName = _projectNameController.text.trim();
    if (currentProjectName.isNotEmpty &&
        currentProjectName != _lastAutoProjectName) {
      return;
    }

    _lastAutoProjectName = repoName;
    if (_projectNameController.text != repoName) {
      _projectNameController.text = repoName;
    }
  }

  String get _projectName => _projectNameController.text.trim();

  String get _repoUrl => _repoUrlController.text.trim();

  bool get _hasValidProjectStep =>
      _projectName.isNotEmpty &&
      (_isDemoMode || _repoUrl.isEmpty || isValidProjectSourceUrl(_repoUrl));

  String? get _repoUrlErrorText {
    if (_isDemoMode || _repoUrl.isEmpty || isValidProjectSourceUrl(_repoUrl)) {
      return null;
    }
    return context.tr('Enter a valid HTTP(S) source URL.');
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final projectToEdit = _isProjectEditMode
        ? projectsAsync.value
              ?.where((project) => project.id == _projectId)
              .cast<Project?>()
              .firstWhere((_) => true, orElse: () => null)
        : null;
    if (!_didLoadProject && projectToEdit != null) {
      _didLoadProject = true;
      _projectNameController.text = projectToEdit.name;
      _repoUrlController.text = projectToEdit.url;
      _contentTypes = projectToEdit.settings?.contentTypes.isNotEmpty == true
          ? projectToEdit.settings!.contentTypes
          : ContentTypeConfig.defaults();
    }

    final routeIsFirst = ModalRoute.of(context)?.isFirst ?? true;

    return PopScope<void>(
      canPop: _currentPage == 0 && !routeIsFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr(_isProjectEditMode ? 'Project settings' : 'Setup'),
          ),
          leading: _currentPage > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousPage,
                )
              : null,
          actions: [
            IconButton(
              tooltip: context.tr('Copy diagnostics'),
              onPressed: _copyOnboardingDiagnostics,
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Progress indicator
              _buildProgressBar(),
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildProjectPage(),
                    _buildContentTypesPage(),
                    _buildSummaryPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSystemBack() {
    if (_currentPage > 0) {
      _previousPage();
      return;
    }

    unawaited(confirmAndExitApp(context));
  }

  Widget _buildProgressBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i <= _currentPage;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.approveColor
                    : colorScheme.outlineVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page 1: Project ──

  Widget _buildProjectPage() {
    final theme = Theme.of(context);
    final githubStatus = ref.watch(githubIntegrationStatusProvider).value;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_isDemoMode) ...[_buildDemoBanner(), const SizedBox(height: 24)],
        Text(
          context.tr(
            _isProjectEditMode
                ? 'Project settings'
                : 'Connect your project source',
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Add an optional source URL (GitHub or public website). You can continue with just a project name.',
          ),
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _projectNameController,
          readOnly: _isDemoMode,
          decoration: InputDecoration(
            labelText: context.tr('Project name'),
            hintText: context.tr('My Tech Blog'),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _repoUrlController,
          readOnly: _isDemoMode,
          decoration: InputDecoration(
            labelText: context.tr('Source URL (optional)'),
            hintText: context.tr(
              'https://example.com or https://github.com/user/repo',
            ),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: _isDemoMode
                ? null
                : IconButton(
                    tooltip: context.tr(
                      'Choose from connected GitHub repos (optional)',
                    ),
                    icon: _isRepoPickerLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    onPressed:
                        (githubStatus?.connected == true &&
                            !_isRepoPickerLoading)
                        ? () => _openGithubRepoPicker()
                        : () => _connectGithubFromOnboarding(),
                  ),
            errorText: _repoUrlErrorText,
          ),
          keyboardType: TextInputType.url,
        ),
        if (githubStatus?.connected != true && !_isDemoMode) ...[
          const SizedBox(height: 10),
          Text(
            context.tr(
              'GitHub connection is optional. Connect it only if you want to pick a repository automatically.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.link),
            onPressed: _connectGithubFromOnboarding,
            label: Text(context.tr('Connecter GitHub')),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _hasValidProjectStep ? _nextPage : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.approveColor,
          ),
          child: Text(
            context.tr(_isDemoMode ? 'Review Demo Setup' : 'Continue'),
          ),
        ),
      ],
    );
  }

  Future<void> _connectGithubFromOnboarding() async {
    if (_isDemoMode) return;
    final api = ref.read(apiServiceProvider);
    String? connectUrl;
    try {
      connectUrl = await api.getGithubConnectUrl();
    } on ApiException catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: context.tr(
          'L’authentification GitHub est indisponible : {error}',
          {'error': error.message},
        ),
        scope: 'onboarding.github.connect',
        error: error,
        stackTrace: stackTrace,
        contextData: {'path': error.path, 'statusCode': error.statusCode},
      );
      return;
    }

    if (connectUrl == null || connectUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'L’authentification GitHub n’est pas disponible. Vérifiez la configuration backend.',
            ),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
        ),
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
          title: Text(context.tr('Connexion GitHub')),
          content: Text(
            context.tr(
              'Une fenêtre navigateur s’est ouverte pour autoriser ContentGlows.'
              ' Revenez ici puis appuyez sur Actualiser pour mettre à jour l’état.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Fermer')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.invalidate(githubIntegrationStatusProvider);
              },
              child: Text(context.tr('Actualiser')),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Impossible d’ouvrir le navigateur pour l’autorisation GitHub.',
            ),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
        ),
      );
    }
  }

  Future<void> _openGithubRepoPicker() async {
    if (_isRepoPickerLoading) return;
    final api = ref.read(apiServiceProvider);

    setState(() => _isRepoPickerLoading = true);
    try {
      final repos = await api.fetchGithubRepos();
      if (!mounted) return;

      final selected = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) {
          final sorted = [...repos]
            ..sort((a, b) {
              final aUpdated = a['updated_at']?.toString() ?? '';
              final bUpdated = b['updated_at']?.toString() ?? '';
              return bUpdated.compareTo(aUpdated);
            });
          return AlertDialog(
            title: Text(context.tr('Choisissez un dépôt GitHub')),
            content: SizedBox(
              width: 520,
              height: 420,
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('Aucun dépôt trouvé pour ce compte.'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      children: sorted.map((repo) {
                        final fullName = repo['full_name']?.toString() ?? '';
                        final description =
                            repo['description']?.toString() ?? '';
                        return ListTile(
                          leading: Icon(
                            Icons.folder_copy_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(fullName),
                          subtitle: Text(
                            description.isEmpty
                                ? context.tr('Aucune description')
                                : description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, {
                            'html_url': repo['html_url'],
                            'full_name': fullName,
                          }),
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Annuler')),
              ),
            ],
          );
        },
      );

      if (selected != null && mounted) {
        final htmlUrl = selected['html_url']?.toString();
        final fullName = selected['full_name']?.toString();
        final next = (htmlUrl?.isNotEmpty == true)
            ? htmlUrl
            : 'https://github.com/${fullName ?? ''}';
        setState(() => _repoUrlController.text = next ?? '');
      }
    } finally {
      if (mounted) setState(() => _isRepoPickerLoading = false);
    }
  }

  Widget _buildDemoBanner() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.approveColor.withAlpha(24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.approveColor.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Demo workspace locked'),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'This onboarding uses a fixed public repo and pre-generated content. Users can explore the flow, but the demo data is intentionally read-only.',
            ),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2: Content Types ──

  Widget _buildContentTypesPage() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.tr('What content do you want?'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Choose the types of content the AI should generate for you, and how often.',
          ),
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_contentTypes.length, (i) {
          final ct = _contentTypes[i];
          return _buildContentTypeCard(ct, i);
        }),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _contentTypes.any((c) => c.enabled) ? _nextPage : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.approveColor,
          ),
          child: Text(context.tr('Continue')),
        ),
      ],
    );
  }

  Widget _buildContentTypeCard(ContentTypeConfig ct, int index) {
    final iconData = _iconForType(ct.icon);
    final color = AppTheme.colorForContentType(ct.label.split(' ').first);
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ct.enabled ? color.withAlpha(15) : palette.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ct.enabled
              ? color.withAlpha(80)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        children: [
          // Toggle row
          ListTile(
            leading: Icon(
              iconData,
              color: ct.enabled ? color : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              context.tr(ct.label),
              style: TextStyle(
                color: ct.enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Switch(
              value: ct.enabled,
              activeTrackColor: color,
              onChanged: _isDemoMode
                  ? null
                  : (val) {
                      setState(() {
                        _contentTypes[index] = ct.copyWith(enabled: val);
                      });
                    },
            ),
          ),
          // Frequency slider (if enabled)
          if (ct.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Text(
                    '${ct.frequencyPerWeek}${context.tr('/week')}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: ct.frequencyPerWeek.toDouble(),
                      min: 1,
                      max: ct.type == 'social_post' ? 14 : 7,
                      divisions: (ct.type == 'social_post' ? 13 : 6),
                      activeColor: color,
                      onChanged: _isDemoMode
                          ? null
                          : (val) {
                              setState(() {
                                _contentTypes[index] = ct.copyWith(
                                  frequencyPerWeek: val.round(),
                                );
                              });
                            },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Page 3: Summary ──

  Widget _buildSummaryPage() {
    final enabled = _contentTypes.where((c) => c.enabled).toList();
    final totalPerWeek = enabled.fold<int>(
      0,
      (sum, c) => sum + c.frequencyPerWeek,
    );
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.tr('Ready to go!'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isDemoMode
              ? context.tr(
                  'Here is the fixed demo workspace that will be served to every demo user.',
                )
              : context.tr(
                  'Here\'s your content plan. You can change it anytime in Settings.',
                ),
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        // Project card
        _summaryCard(
          icon: Icons.folder_outlined,
          title: _projectNameController.text.isEmpty
              ? context.tr('Project')
              : _projectNameController.text,
          subtitle: _repoUrlController.text.isEmpty
              ? context.tr('No source linked')
              : _isDemoMode
              ? '${_repoUrlController.text}\nLive demo: ${DemoSeed.siteUrl}'
              : _repoUrlController.text,
        ),
        const SizedBox(height: 12),
        // Content summary
        _summaryCard(
          icon: Icons.auto_awesome,
          title: context.tr('{count} contents/week', {'count': totalPerWeek}),
          subtitle: enabled.map((c) => context.tr(c.label)).join(', '),
        ),
        const SizedBox(height: 12),
        // Next steps
        _summaryCard(
          icon: Icons.checklist,
          title: context.tr('Next steps'),
          subtitle: context.tr(
            '1. Set up your brand voice (weekly ritual)\n2. Create a customer persona\n3. Content starts flowing!',
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _isFinishing ? null : _finish,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.approveColor,
          ),
          child: _isFinishing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(context.tr(_isDemoMode ? 'Open Demo Workspace' : 'Start')),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.approveColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String icon) => switch (icon) {
    'article' => Icons.article_outlined,
    'email' => Icons.email_outlined,
    'chat' => Icons.chat_bubble_outline,
    'videocam' => Icons.videocam_outlined,
    'slow_motion_video' => Icons.slow_motion_video,
    _ => Icons.auto_awesome,
  };

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _copyOnboardingDiagnostics() {
    final authSession = ref.read(authSessionProvider);
    final accessState = ref.read(appAccessStateProvider).value;
    copyDiagnosticsToClipboard(
      context,
      ref,
      title: 'ContentGlows onboarding diagnostics',
      scope: 'onboarding.copy_diagnostics',
      currentError: accessState?.message,
      contextData: {
        'sessionState': authSession.status.name,
        'sessionEmail': authSession.email ?? 'none',
        'isDemoMode': _isDemoMode,
        'onboardingPage': _currentPage + 1,
        'projectName': _projectName.isEmpty ? 'blank' : _projectName,
        'repoUrl': _repoUrl.isEmpty ? 'blank' : _repoUrl,
        'hasValidProjectStep': _hasValidProjectStep,
        'accessStage': accessState?.diagnosticsLabel ?? 'loading',
        'workspaceStatus': accessState?.bootstrap?.workspaceStatus ?? 'none',
        'workspaceExists':
            accessState?.bootstrap?.user.workspaceExists ?? false,
        'projectsCount': accessState?.bootstrap?.projectsCount ?? 'none',
        'defaultProjectId': accessState?.bootstrap?.defaultProjectId ?? 'none',
      },
      successMessage: 'Onboarding diagnostics copied to clipboard.',
    );
  }

  Future<void> _finish() async {
    if (_isDemoMode) {
      ref.read(authSessionProvider.notifier).markOnboardingComplete();
      context.go('/feed');
      return;
    }

    if (!_hasValidProjectStep) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Enter a valid HTTP(S) source URL, or leave it empty to continue.',
            ),
          ),
        ),
      );
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final authSession = ref.read(authSessionProvider);
    if (!authSession.isAuthenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              _isProjectEditMode
                  ? 'Sign in with Google before editing a project.'
                  : 'Sign in with Google before creating a workspace.',
            ),
          ),
        ),
      );
      context.go('/entry');
      return;
    }

    setState(() => _isFinishing = true);
    try {
      final mutationController = ref.read(
        projectMutationControllerProvider.notifier,
      );
      if (_isProjectEditMode && _projectId != null) {
        await mutationController.updateProject(
          projectId: _projectId!,
          name: _projectName,
          sourceUrl: _repoUrl,
          contentTypes: _contentTypes,
        );
      } else if (_isProjectCreateMode || _isWorkspaceSetupMode) {
        await mutationController.createProject(
          name: _projectName,
          sourceUrl: _repoUrl,
          contentTypes: _contentTypes,
        );
      }
      ref.invalidate(projectsProvider);
      ref.invalidate(appBootstrapProvider);
      ref.invalidate(projectsStateProvider);
      await ref.read(appAccessStateProvider.notifier).refresh();
      if (!mounted) return;
      context.go(_isWorkspaceSetupMode ? '/feed' : '/projects');
    } catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: _isProjectEditMode
            ? 'Project update failed: $error'
            : 'Workspace creation failed: $error',
        scope: _isProjectEditMode
            ? 'onboarding.update_project'
            : 'onboarding.create_workspace',
        error: error,
        stackTrace: stackTrace,
        contextData: {'projectName': _projectName, 'repoUrl': _repoUrl},
      );
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }
}
