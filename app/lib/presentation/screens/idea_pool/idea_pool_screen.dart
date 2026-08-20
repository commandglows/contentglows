import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/idea.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';

const _statusFilters = ['all', 'raw', 'enriched', 'used', 'dismissed'];
const _sourceFilters = [
  'all',
  'newsletter_inbox',
  'seo_keywords',
  'search_console_feedback',
  'competitor_watch',
  'social_listening',
  'manual',
];

class IdeaPoolScreen extends ConsumerWidget {
  const IdeaPoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideasAsync = ref.watch(ideasProvider);
    final notifier = ref.read(ideasProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Idea Pool')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ideasProvider),
          ),
        ],
      ),
      body: ideasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'idea_pool.load',
            title: context.tr('Failed to load ideas'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(ideasProvider),
          ),
        ),
        data: (ideas) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ideasProvider),
            child: CustomScrollView(
              slivers: [
                // Stats
                SliverToBoxAdapter(child: _StatsRow(ideas: ideas)),
                // Status filter
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusFilters.map((filter) {
                          final selected = notifier.statusFilter == filter;
                          final label = filter == 'all'
                              ? 'All'
                              : filter[0].toUpperCase() + filter.substring(1);
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: FilterChip(
                              label: Text(context.tr(label)),
                              selected: selected,
                              onSelected: (_) =>
                                  notifier.setStatusFilter(filter),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                // Source filter
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xxs,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sourceFilters.map((filter) {
                          final selected = notifier.sourceFilter == filter;
                          final label = filter == 'all'
                              ? context.tr('All sources')
                              : Idea(
                                  id: '',
                                  source: filter,
                                  title: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ).sourceLabel;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: FilterChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) =>
                                  notifier.setSourceFilter(filter),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                // Ideas list
                if (ideas.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _IdeaCard(
                        idea: ideas[index],
                        onDismiss: () => notifier.dismissIdea(ideas[index].id),
                        onDelete: () =>
                            _confirmDelete(context, ref, ideas[index]),
                        onPrioritize: (score) =>
                            notifier.prioritizeIdea(ideas[index].id, score),
                      ),
                      childCount: ideas.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Idea idea,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete idea?')),
        content: Text(
          context.tr('Remove "{title}"? This cannot be undone.', {
            'title': idea.title,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(ideasProvider.notifier).deleteIdea(idea.id);
    }
  }
}

// ─── Stats Row ──────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.ideas});
  final List<Idea> ideas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = ideas.where((i) => i.status == 'raw').length;
    final enriched = ideas.where((i) => i.status == 'enriched').length;
    final used = ideas.where((i) => i.status == 'used').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: '${ideas.length}',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(label: 'Raw', value: '$raw', color: AppTheme.warningColor),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'Enriched',
            value: '$enriched',
            color: AppTheme.approveColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'Used',
            value: '$used',
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withAlpha(AppAlpha.low25),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppText.xxl,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxsHalf),
            Text(
              context.tr(label),
              style: TextStyle(fontSize: AppText.xs11, color: color.withAlpha(AppAlpha.icon)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Idea Card ──────────────────────────────────────────

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.idea,
    required this.onDismiss,
    required this.onDelete,
    required this.onPrioritize,
  });

  final Idea idea;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;
  final ValueChanged<double> onPrioritize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, y', context.localeTag);

    final statusColor = _statusColor(idea.status, colorScheme);
    final sourceColor = _sourceColor(idea.source, colorScheme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.contentInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    idea.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.micro,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(AppAlpha.glow),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    idea.statusLabel,
                    style: TextStyle(
                      fontSize: AppText.xs11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Metadata chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs2,
              children: [
                _MetaChip(
                  icon: Icons.source_outlined,
                  text: idea.sourceLabel,
                  color: sourceColor,
                ),
                if (idea.source == 'search_console_feedback')
                  _MetaChip(
                    icon: Icons.travel_explore_outlined,
                    text: context.tr('Google evidence'),
                    color: AppTheme.infoColor,
                  ),
                if (idea.priorityScore != null)
                  _MetaChip(
                    icon: Icons.trending_up,
                    text: context.tr('Score {score}', {
                      'score': idea.priorityScore!.toStringAsFixed(0),
                    }),
                    color: AppTheme.approveColor,
                  ),
                if (idea.searchVolume != null)
                  _MetaChip(
                    icon: Icons.search,
                    text: context.tr('{volume} vol', {
                      'volume': idea.searchVolume,
                    }),
                    color: AppTheme.infoColor,
                  ),
                if (idea.keywordDifficulty != null)
                  _MetaChip(
                    icon: Icons.speed,
                    text: context.tr('KD {score}', {
                      'score': idea.keywordDifficulty!.toStringAsFixed(0),
                    }),
                    color: AppTheme.rejectColor,
                  ),
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  text: dateFormat.format(idea.createdAt),
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            // Tags
            if (idea.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                children: idea.tags.take(5).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxsHalf,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(AppAlpha.subtle),
                      borderRadius: BorderRadius.circular(AppRadii.compactControl),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: AppText.xs11,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (idea.source == 'search_console_feedback') ...[
              const SizedBox(height: AppSpacing.xs),
              _SearchConsoleEvidence(idea: idea),
            ],
            // Actions
            if (idea.status == 'raw' || idea.status == 'enriched') ...[
              const SizedBox(height: AppSpacing.compact),
              Row(
                children: [
                  if (idea.status == 'enriched')
                    _ActionButton(
                      icon: Icons.arrow_upward,
                      label: 'Boost',
                      color: AppTheme.approveColor,
                      onTap: () =>
                          onPrioritize((idea.priorityScore ?? 50) + 10),
                    ),
                  if (idea.status == 'enriched') const SizedBox(width: AppSpacing.xs),
                  if (idea.status == 'enriched')
                    _ActionButton(
                      icon: Icons.arrow_downward,
                      label: 'Lower',
                      color: AppTheme.warningColor,
                      onTap: () => onPrioritize(
                        ((idea.priorityScore ?? 50) - 10).clamp(0, 100),
                      ),
                    ),
                  const Spacer(),
                  _ActionButton(
                    icon: Icons.close,
                    label: 'Dismiss',
                    color: colorScheme.onSurfaceVariant,
                    onTap: onDismiss,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    color: colorScheme.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    return switch (status) {
      'raw' => AppTheme.warningColor,
      'enriched' => AppTheme.approveColor,
      'used' => colorScheme.primary,
      'dismissed' => colorScheme.onSurfaceVariant,
      _ => colorScheme.outline,
    };
  }

  Color _sourceColor(String source, ColorScheme colorScheme) {
    return switch (source) {
      'newsletter_inbox' => AppTheme.warningColor,
      'seo_keywords' => AppTheme.infoColor,
      'search_console_feedback' => AppTheme.infoColor,
      'competitor_watch' => AppTheme.rejectColor,
      'social_listening' => AppTheme.editColor,
      'manual' => colorScheme.primary,
      _ => colorScheme.outline,
    };
  }
}

class _SearchConsoleEvidence extends StatelessWidget {
  const _SearchConsoleEvidence({required this.idea});

  final Idea idea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = idea.rawData;
    final targetUrl = raw['target_url']?.toString();
    final targetQuery = raw['target_query']?.toString();
    final reason = raw['reason']?.toString();
    final chips = <Widget>[];
    if (targetQuery != null && targetQuery.isNotEmpty) {
      chips.add(
        _MetaChip(
          icon: Icons.search_rounded,
          text: targetQuery,
          color: AppTheme.infoColor,
        ),
      );
    }
    if (targetUrl != null && targetUrl.isNotEmpty) {
      chips.add(
        _MetaChip(
          icon: Icons.link_rounded,
          text: targetUrl,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (reason != null && reason.isNotEmpty) {
      chips.add(
        _MetaChip(
          icon: Icons.flag_outlined,
          text: reason.replaceAll('_', ' '),
          color: AppTheme.warningColor,
        ),
      );
    }
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xxs2, children: chips.take(3).toList());
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconCompact, color: color),
        const SizedBox(width: AppStroke.strong),
        Text(text, style: TextStyle(fontSize: AppText.xs, color: color)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.narrow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.compact),
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        decoration: BoxDecoration(
          color: color.withAlpha(AppAlpha.subtle),
          borderRadius: BorderRadius.circular(AppRadii.narrow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.icon, color: color),
            const SizedBox(width: AppSpacing.xxs2),
            Text(
              context.tr(label),
              style: TextStyle(
                fontSize: AppText.compact,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: AppSizes.heroIcon,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('No ideas yet'),
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: AppText.base),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr(
              'Ideas from newsletters, SEO, Search Console,\ncompetitors and social listening will appear here.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: AppText.compact),
          ),
        ],
      ),
    );
  }
}
