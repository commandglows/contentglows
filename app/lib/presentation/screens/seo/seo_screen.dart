import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/api_service.dart';
import '../../../providers/providers.dart';
import '../../widgets/app_error_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

class SeoScreen extends ConsumerStatefulWidget {
  const SeoScreen({super.key});

  @override
  ConsumerState<SeoScreen> createState() => _SeoScreenState();
}

class _SeoScreenState extends ConsumerState<SeoScreen> {
  final _repoUrlCtrl = TextEditingController();
  bool _analyzing = false;
  Map<String, dynamic>? _result;
  bool _isRepoPickerLoading = false;

  @override
  void dispose() {
    _repoUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final githubStatus = ref.watch(githubIntegrationStatusProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('SEO Mesh')),
        actions: const [ProjectPickerAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            context.tr('Topical Mesh Analysis'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Analyze your site structure and topical coverage'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _repoUrlCtrl,
            decoration: InputDecoration(
              labelText: context.tr('Repository URL'),
              hintText: context.tr('https://github.com/user/site'),
              helperText: githubStatus?.connected == true
                  ? null
                  : context.tr(
                      'Connect your GitHub account to pick a repository.',
                    ),
              suffixIcon: IconButton(
                icon: _isRepoPickerLoading
                    ? const SizedBox(
                        width: AppSizes.icon,
                        height: AppSizes.icon,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.medium,
                        ),
                      )
                    : const Icon(Icons.travel_explore_rounded),
                tooltip: context.tr('Choose from connected GitHub repos'),
                onPressed: _isRepoPickerLoading
                    ? null
                    : githubStatus?.connected == true
                    ? _openGithubRepoPicker
                    : _connectGithubFromSeo,
              ),
            ),
            keyboardType: TextInputType.url,
          ),
          if (githubStatus?.connected != true) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: Text(context.tr('Connect GitHub')),
              onPressed: _connectGithubFromSeo,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            onPressed: _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    height: AppSizes.iconLarge,
                    width: AppSizes.iconLarge,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                    ),
                  )
                : const Icon(Icons.hub),
            label: Text(
              _analyzing
                  ? context.tr('Analyzing...')
                  : context.tr('Analyze Mesh'),
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _MeshResults(result: _result!),
          ],
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    if (_repoUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Repository URL is required'))),
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _result = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.analyzeMesh(repoUrl: _repoUrlCtrl.text.trim());
      setState(() => _result = result);
    } catch (error, stackTrace) {
      if (mounted) {
        showDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Analysis failed: {error}', {'error': '$error'}),
          scope: 'seo.analyze_mesh',
          error: error,
          stackTrace: stackTrace,
          contextData: {'repoUrl': _repoUrlCtrl.text.trim()},
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _openGithubRepoPicker() async {
    final api = ref.read(apiServiceProvider);
    final githubStatus = ref.read(githubIntegrationStatusProvider).value;
    if (githubStatus?.connected != true) {
      await _connectGithubFromSeo();
      return;
    }

    setState(() => _isRepoPickerLoading = true);
    try {
      final repos = await api.fetchGithubRepos();
      if (!mounted) {
        return;
      }

      final selected = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) {
          final sorted = [...repos]
            ..sort((a, b) {
              final updatedA = a['updated_at']?.toString() ?? '';
              final updatedB = b['updated_at']?.toString() ?? '';
              return updatedB.compareTo(updatedA);
            });

          return AlertDialog(
            title: Text(context.tr('Choose GitHub repository')),
            content: SizedBox(
              width: 520,
              height: 420,
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('No repository found for this account.'),
                      ),
                    )
                  : ListView(
                      children: sorted.map((repo) {
                        final fullName = repo['full_name']?.toString() ?? '';
                        final description =
                            repo['description']?.toString() ?? '';
                        return ListTile(
                          leading: const Icon(Icons.folder_copy_rounded),
                          title: Text(fullName),
                          subtitle: Text(
                            description.isEmpty
                                ? context.tr('No description')
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
                child: Text(context.tr('Cancel')),
              ),
            ],
          );
        },
      );

      if (selected == null || !mounted) {
        return;
      }

      final htmlUrl = selected['html_url']?.toString() ?? '';
      final fullName = selected['full_name']?.toString() ?? '';
      final next = (htmlUrl.isNotEmpty)
          ? htmlUrl
          : 'https://github.com/$fullName';
      if (next.isNotEmpty) {
        setState(() => _repoUrlCtrl.text = next);
      }
    } finally {
      if (mounted) setState(() => _isRepoPickerLoading = false);
    }
  }

  Future<void> _connectGithubFromSeo() async {
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
        scope: 'seo.github.connect',
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
              'GitHub OAuth is unavailable. Check backend configuration.',
            ),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.error.withValues(alpha: AppOpacity.prominent),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Could not open browser for GitHub authorization'),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.error.withValues(alpha: AppOpacity.prominent),
        ),
      );
    }
  }
}

class _MeshResults extends StatelessWidget {
  const _MeshResults({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = result['total_pages'] as num? ?? 0;
    final issues = (result['issues'] as List?)?.length ?? 0;
    final recommendations = (result['recommendations'] as List?)?.length ?? 0;
    final score = result['overall_score'] as num?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        Row(
          children: [
            _StatCard(
              label: context.tr('Pages'),
              value: '$pages',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            _StatCard(
              label: context.tr('Issues'),
              value: '$issues',
              color: AppTheme.warningColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            _StatCard(
              label: context.tr('Tips'),
              value: '$recommendations',
              color: AppTheme.approveColor,
            ),
            if (score != null) ...[
              const SizedBox(width: AppSpacing.xs),
              _StatCard(
                label: context.tr('Score'),
                value: '${score.toInt()}%',
                color: AppTheme.infoColor,
              ),
            ],
          ],
        ),

        // Issues
        if (result['issues'] case final List issueList
            when issueList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('Issues'), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          ...issueList
              .take(10)
              .map(
                (issue) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xxs2),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.warning_amber,
                      color: AppTheme.warningColor,
                      size: AppSizes.iconXl,
                    ),
                    title: Text(
                      (issue as Map)['description']?.toString() ??
                          context.tr('Issue'),
                      style: TextStyle(fontSize: AppText.compact),
                    ),
                  ),
                ),
              ),
        ],

        // Recommendations
        if (result['recommendations'] case final List recs
            when recs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('Recommendations'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...recs
              .take(10)
              .map(
                (rec) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xxs2),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.approveColor,
                      size: AppSizes.iconXl,
                    ),
                    title: Text(
                      (rec as Map)['description']?.toString() ??
                          context.tr('Recommendation'),
                      style: TextStyle(fontSize: AppText.compact),
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.subtle),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppText.title,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxsHalf),
            Text(
              label,
              style: TextStyle(fontSize: AppText.xs11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
