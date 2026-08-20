import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_error_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

final _workDomainsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  return api.fetchWorkDomains(projectId: activeProjectId);
});

class WorkDomainsScreen extends ConsumerWidget {
  const WorkDomainsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domainsAsync = ref.watch(_workDomainsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Work Domains')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_workDomainsProvider),
          ),
        ],
      ),
      body: domainsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'work_domains.load',
            title: context.tr('Failed to load work domains'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(_workDomainsProvider),
          ),
        ),
        data: (domains) {
          if (domains.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspaces_outlined, size: AppSizes.heroIcon,
                      color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.tr('No work domains configured'),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(context.tr('Domains are created when robots run on a project'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outlineVariant)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_workDomainsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: domains.length,
              itemBuilder: (context, index) =>
                  _DomainCard(domain: domains[index]),
            ),
          );
        },
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});
  final Map<String, dynamic> domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = domain['domain'] as String? ?? 'unknown';
    final status = domain['status'] as String? ?? 'idle';
    final pending = domain['itemsPending'] as int? ?? 0;
    final completed = domain['itemsCompleted'] as int? ?? 0;
    final lastRunStatus = domain['lastRunStatus'] as String?;

    final statusColor = switch (status) {
      'running' => AppTheme.infoColor,
      'error' => AppTheme.rejectColor,
      'paused' => AppTheme.warningColor,
      _ => AppTheme.approveColor,
    };

    final domainIcon = switch (name) {
      'seo' => Icons.search,
      'newsletter' => Icons.email,
      'images' => Icons.image,
      'scheduler' => Icons.schedule,
      'articles' => Icons.article,
      _ => Icons.workspaces,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.compact),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.contentInset),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: statusColor.withValues(
                alpha: AppOpacity.medium,
              ),
              child: Icon(
                domainIcon,
                color: statusColor,
                size: AppSizes.iconHeading,
              ),
            ),
            const SizedBox(width: AppSpacing.contentInset),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name.toUpperCase(),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxs2,
                          vertical: AppSpacing.xxsHalf,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: AppOpacity.medium,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppRadii.compactControl,
                          ),
                        ),
                        child: Text(context.tr(status),
                            style: TextStyle(fontSize: AppText.xxs, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs2),
                  Row(
                    children: [
                      _Stat(
                        label: context.tr('Pending'),
                        value: '$pending',
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _Stat(
                        label: context.tr('Done'),
                        value: '$completed',
                        color: AppTheme.approveColor,
                      ),
                      if (lastRunStatus != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        _Stat(
                          label: context.tr('Last'),
                          value: context.tr(lastRunStatus),
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: AppText.sm, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: TextStyle(fontSize: AppText.xxs, color: color.withValues(alpha: AppOpacity.strong))),
      ],
    );
  }
}
