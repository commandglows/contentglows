import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/content_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';

final _validationsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  return api.fetchPendingValidations(daysAhead: 14, projectId: activeProjectId);
});

class ContentToolsScreen extends ConsumerWidget {
  const ContentToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Content Tools')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('Validations')),
              Tab(text: context.tr('Funnel')),
              Tab(text: context.tr('Audit')),
            ],
          ),
          actions: const [ProjectPickerAction()],
        ),
        body: TabBarView(
          children: [_ValidationsTab(), _FunnelTab(), _AuditTab()],
        ),
      ),
    );
  }
}

class _ValidationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validationsAsync = ref.watch(_validationsProvider);
    final theme = Theme.of(context);

    return validationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          scope: 'content_tools.load',
          title: context.tr('Failed to load content tools'),
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(_validationsProvider),
        ),
      ),
      data: (data) {
        final articles = (data['articles'] as List?) ?? [];
        final total = data['total'] as int? ?? 0;

        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppSizes.heroIcon,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('No pending validations'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_validationsProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  context.tr('{count} articles awaiting validation', {
                    'count': total,
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...articles.map((a) {
                final article = a as Map<String, dynamic>;
                final articleId = article['id']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      article['title']?.toString() ?? context.tr('Untitled'),
                      style: const TextStyle(
                        fontSize: AppText.compact,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        article['cluster']?.toString() ?? '',
                        article['scheduled_pub_date']?.toString() ??
                            context.tr('no date'),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: TextButton(
                      onPressed: articleId.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(apiServiceProvider)
                                  .completeContent(articleId);
                              ref.invalidate(_validationsProvider);
                              ref.invalidate(contentHistoryProvider);
                            },
                      child: Text(context.tr('Complete')),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FunnelTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(contentHistoryProvider);
    final pendingAsync = ref.watch(pendingContentProvider);
    final theme = Theme.of(context);

    final allContent = [
      ...pendingAsync.value ?? [],
      ...historyAsync.value ?? [],
    ];

    if (allContent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: AppSizes.heroIcon,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('No content data for funnel analysis'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Group by cluster from metadata
    final clusters = <String, List<ContentItem>>{};
    for (final item in allContent) {
      final cluster = item.metadata?['cluster'] as String? ?? 'uncategorized';
      clusters.putIfAbsent(cluster, () => []).add(item);
    }

    final sorted = clusters.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingContentProvider);
        ref.invalidate(contentHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            context.tr('Content Clusters'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Articles grouped by topic cluster'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...sorted.map((entry) {
            final published = entry.value
                .where((c) => c.status == ContentStatus.published)
                .length;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: AppText.sm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  context.tr('{total} total · {published} published', {
                    'total': entry.value.length,
                    'published': published,
                  }),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: _clusterGrade(entry.value.length, theme),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _clusterGrade(int count, ThemeData theme) {
    final grade = count >= 30
        ? 'A'
        : count >= 20
        ? 'B+'
        : count >= 12
        ? 'B'
        : count >= 6
        ? 'C'
        : count >= 3
        ? 'D'
        : 'F';
    final color = switch (grade) {
      'A' => AppTheme.approveColor,
      'B+' || 'B' => AppTheme.infoColor,
      'C' => AppTheme.warningColor,
      _ => theme.colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: AppText.sm,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AuditTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(contentHistoryProvider);
    final pendingAsync = ref.watch(pendingContentProvider);
    final theme = Theme.of(context);

    final allContent = [
      ...pendingAsync.value ?? [],
      ...historyAsync.value ?? [],
    ];

    if (allContent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: AppSizes.heroIcon,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('No content to audit'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Simple audit: check for missing fields
    final issues = <_AuditIssue>[];
    for (final item in allContent) {
      if (item.title.isEmpty) {
        issues.add(_AuditIssue(item.id, item.title, 'Missing title'));
      }
      if (item.channels.isEmpty) {
        issues.add(_AuditIssue(item.id, item.title, 'No publishing channels'));
      }
      if (item.body.isEmpty) {
        issues.add(_AuditIssue(item.id, item.title, 'Empty body'));
      }
      if (item.tags.isEmpty) {
        issues.add(_AuditIssue(item.id, item.title, 'No tags'));
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingContentProvider);
        ref.invalidate(contentHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Summary
          Row(
            children: [
              _AuditStat(
                label: 'Total',
                value: '${allContent.length}',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              _AuditStat(
                label: 'Issues',
                value: '${issues.length}',
                color: issues.isEmpty
                    ? AppTheme.approveColor
                    : AppTheme.warningColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              _AuditStat(
                label: 'Reviewed',
                value:
                    '${allContent.where((item) => item.reviewActorDisplay != null).length}',
                color: AppTheme.infoColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            context.tr('Recent review actors'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...allContent
              .where((item) => item.reviewActorDisplay != null)
              .take(6)
              .map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xxs2),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.verified_user_outlined, size: AppSizes.iconXl),
                    title: Text(
                      item.title.isEmpty
                          ? context.tr('(no title)')
                          : item.title,
                      style: const TextStyle(fontSize: AppText.compact),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.reviewActorDisplay}${item.reviewActorType == null ? '' : ' • ${item.reviewActorType}'}',
                      style: TextStyle(
                        fontSize: AppText.xs,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.xs),

          if (issues.isEmpty)
            Card(
              color: AppTheme.approveColor.withValues(alpha: AppOpacity.subtle),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.approveColor),
                    const SizedBox(width: AppSpacing.xs),
                    Text(context.tr('All content passes basic audit checks')),
                  ],
                ),
              ),
            )
          else ...[
            Text(context.tr('Issues Found'), style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ...issues.map(
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
                    issue.title.isEmpty
                        ? context.tr('(no title)')
                        : issue.title,
                    style: const TextStyle(fontSize: AppText.compact),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    context.tr(issue.issue),
                    style: TextStyle(
                      fontSize: AppText.xs,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditIssue {
  final String contentId;
  final String title;
  final String issue;
  const _AuditIssue(this.contentId, this.title, this.issue);
}

class _AuditStat extends StatelessWidget {
  const _AuditStat({
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.contentInset),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.subtle),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppText.heading,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxsHalf),
            Text(
              context.tr(label),
              style: TextStyle(fontSize: AppText.xs11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
