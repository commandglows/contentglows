import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/drip_plan.dart';
import '../../../data/services/api_service.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class DripPlanDetailScreen extends ConsumerStatefulWidget {
  const DripPlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  ConsumerState<DripPlanDetailScreen> createState() =>
      _DripPlanDetailScreenState();
}

class _DripPlanDetailScreenState extends ConsumerState<DripPlanDetailScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final idMappings =
        ref.watch(offlineIdMappingsProvider).value ?? const <String, String>{};
    final resolvedPlanId = idMappings[widget.planId] ?? widget.planId;
    final plansAsync = ref.watch(dripPlansProvider);
    final statsAsync = ref.watch(dripStatsProvider(resolvedPlanId));

    final plan = plansAsync.whenData((plans) {
      for (final entry in plans) {
        if (entry.id == widget.planId || entry.id == resolvedPlanId) {
          return entry;
        }
      }
      throw Exception('Plan not found');
    });

    return Scaffold(
      appBar: AppBar(
        title: plan.when(
          data: (p) => Text(p.name),
          loading: () => Text(context.tr('Loading...')),
          error: (error, stackTrace) => Text(context.tr('Error')),
        ),
        actions: [
          plan.when(
            data: (p) =>
                _ActionMenu(plan: p, onAction: (a) => _handleAction(a, p)),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'drip.plan_detail.load',
            title: context.tr('Failed to load drip plan'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () {
              ref.invalidate(dripPlansProvider);
              ref.invalidate(dripStatsProvider(resolvedPlanId));
            },
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dripPlansProvider);
            ref.invalidate(dripStatsProvider(resolvedPlanId));
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Status + config summary
              _StatusHeader(plan: p),
              const SizedBox(height: AppSpacing.md),

              // Progress
              statsAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => _ProgressCard(
                  stats: stats,
                  colorScheme: Theme.of(context).colorScheme,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Clusters
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => _ClustersCard(
                  stats: stats,
                  colorScheme: Theme.of(context).colorScheme,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Config details
              _ConfigCard(plan: p),
              const SizedBox(height: AppSpacing.md),

              // Action buttons
              if (!p.isTerminal)
                _ActionButtons(
                  plan: p,
                  loading: _loading,
                  onAction: (a) => _handleAction(a, p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, DripPlan plan) async {
    setState(() => _loading = true);
    final api = ref.read(apiServiceProvider);
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String message;
      switch (action) {
        case 'preflight':
          final result = await api.preflightDripPlan(plan.id);
          final count = (result['issue_count'] as num?)?.toInt() ?? 0;
          final severity = result['severity']?.toString() ?? 'info';
          if (mounted && count > 0) {
            await _showPreflightDialog(context, result);
          }
          message = l10n.tr(
            'Preflight: {severity} ({count} issues)',
            params: {'severity': severity, 'count': '$count'},
          );
        case 'import':
          final dir =
              plan.ssgConfig['content_directory'] as String? ?? 'src/data';
          final result = await api.importDripContent(plan.id, dir);
          message = l10n.tr(
            'Imported {count} articles',
            params: {'count': '${result['items_imported']}'},
          );
        case 'cluster':
          final result = await api.clusterDripPlan(
            plan.id,
            mode: plan.clusterMode,
          );
          message = l10n.tr(
            'Clustered into {count} groups',
            params: {'count': '${result['total_clusters']}'},
          );
        case 'schedule':
          final result = await api.scheduleDripPlan(plan.id);
          message = l10n.tr(
            'Scheduled {count} items',
            params: {'count': '${result['total_items']}'},
          );
        case 'activate':
          await api.activateDripPlan(plan.id);
          message = l10n.tr('Plan activated — dripping starts!');
        case 'pause':
          await api.pauseDripPlan(plan.id);
          message = l10n.tr('Plan paused');
        case 'resume':
          await api.resumeDripPlan(plan.id);
          message = l10n.tr('Plan resumed');
        case 'cancel':
          await api.cancelDripPlan(plan.id);
          message = l10n.tr('Plan cancelled');
        case 'execute':
          final result = await api.executeDripTick(plan.id);
          message = l10n.tr(
            'Published {count} articles',
            params: {'count': '${result['published']}'},
          );
        case 'delete':
          await api.deleteDripPlan(plan.id);
          if (mounted) {
            navigator.pop();
          }
          message = l10n.tr('Plan deleted');
        default:
          message = l10n.tr('Unknown action');
      }

      if (!mounted) return;
      ref.invalidate(dripPlansProvider);
      ref.invalidate(dripStatsProvider(plan.id));
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: l10n.tr('Action failed: {error}', params: {'error': '$error'}),
        scope: 'drip.plan_detail.action',
        error: error,
        stackTrace: stackTrace,
        contextData: {'planId': widget.planId},
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPreflightDialog(
    BuildContext context,
    Map<String, dynamic> result,
  ) async {
    final issues = result['issues'];
    final issueList = issues is List ? issues : const [];
    if (issueList.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Preflight issues')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: issueList.length,
            separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final raw = issueList[i];
              final entry = raw is Map ? raw : const {};
              final sev = entry['severity']?.toString() ?? 'info';
              final msg = entry['message']?.toString() ?? '';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (sev) {
                      'error' => Icons.error,
                      'warning' => Icons.warning,
                      _ => Icons.info,
                    },
                    size: AppSizes.iconLarge,
                    color: switch (sev) {
                      'error' => Theme.of(context).colorScheme.error,
                      'warning' => AppTheme.warningColor,
                      _ => Theme.of(context).colorScheme.primary,
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text('[$sev] $msg')),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Close')),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.plan});
  final DripPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon(plan.status),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  context.tr(plan.status),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _statusColor(plan.status, colorScheme),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(context.tr('Articles'), '${plan.totalItems}'),
            _infoRow(
              context.tr('Cadence'),
              '${plan.itemsPerDay}/${context.tr('day')} (${context.tr(plan.cadenceMode)})',
            ),
            _infoRow(context.tr('Start'), plan.startDate),
            if (plan.nextDripAt != null)
              _infoRow(
                context.tr('Next drip'),
                _formatIso(plan.nextDripAt!, context),
              ),
            if (plan.lastDripAt != null)
              _infoRow(
                context.tr('Last drip'),
                _formatIso(plan.lastDripAt!, context),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatIso(String raw, BuildContext context) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat(
      'MMM d, HH:mm',
      context.localeTag,
    ).format(parsed.toLocal());
  }

  Widget _infoRow(String label, String value) => Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxsHalf),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
          ],
        ),
      );
    },
  );

  Widget _statusIcon(String status) => Builder(
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Icon(
        switch (status) {
          'active' => Icons.play_circle_filled,
          'paused' => Icons.pause_circle_filled,
          'completed' => Icons.check_circle,
          'cancelled' => Icons.cancel,
          _ => Icons.circle_outlined,
        },
        color: _statusColor(status, colorScheme),
        size: AppSizes.iconXl,
      );
    },
  );

  Color _statusColor(String status, ColorScheme colorScheme) =>
      switch (status) {
        'active' => AppTheme.approveColor,
        'paused' => AppTheme.warningColor,
        'completed' => AppTheme.infoColor,
        'cancelled' => colorScheme.onSurfaceVariant,
        _ => colorScheme.onSurfaceVariant,
      };
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stats, required this.colorScheme});
  final DripStats stats;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Progress'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.compactControl),
              child: LinearProgressIndicator(
                value: stats.progressPercent,
                minHeight: 16,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('Published {published}/{total} ({percent}%)', {
                'published': '${stats.published}',
                'total': '${stats.totalItems}',
                'percent': (stats.progressPercent * 100).toStringAsFixed(0),
              }),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              children: stats.byStatus.entries
                  .map(
                    (e) => Chip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: _statusDotColor(
                          e.key,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                      label: Text(
                        context.tr('{status}: {count}', {
                          'status': context.tr(e.key),
                          'count': '${e.value}',
                        }),
                        style: const TextStyle(fontSize: AppText.xs),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClustersCard extends StatelessWidget {
  const _ClustersCard({required this.stats, required this.colorScheme});
  final DripStats stats;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (stats.clusters.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Clusters'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...stats.clusters.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Icon(
                      c.isComplete ? Icons.check_circle : Icons.circle_outlined,
                      size: AppSizes.iconLarge,
                      color: c.isComplete
                          ? AppTheme.approveColor
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(c.name, style: const TextStyle(fontSize: AppText.compact)),
                    ),
                    Text(
                      '${c.published}/${c.total}',
                      style: TextStyle(
                        fontSize: AppText.compact,
                        color: colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.plan});
  final DripPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Configuration'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _row(context.tr('Framework'), plan.ssgFramework),
            _row(
              context.tr('Gating'),
              plan.ssgConfig['gating_method'] as String? ?? '?',
            ),
            _row(context.tr('Rebuild'), plan.rebuildMethod),
            _row(context.tr('Clustering'), context.tr(plan.clusterMode)),
            _row(
              context.tr('Timezone'),
              plan.cadenceConfig['timezone'] as String? ?? 'UTC',
            ),
            _row(
              context.tr('Publish time'),
              plan.cadenceConfig['publish_time'] as String? ?? '06:00',
            ),
            if (plan.ssgConfig['enforce_robots_noindex_until_publish'] == true)
              _row(context.tr('Index-proof'), context.tr('Enabled')),
            if (plan.ssgConfig['require_opt_in'] == true)
              _row(context.tr('Safe mode'), context.tr('Enabled')),
            if (plan.gscConfig != null && plan.gscConfig!['enabled'] == true)
              _row(context.tr('GSC'), context.tr('Enabled')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxsHalf),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
          ],
        ),
      );
    },
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.plan,
    required this.loading,
    required this.onAction,
  });
  final DripPlan plan;
  final bool loading;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.isDraft) ...[
          FilledButton.tonalIcon(
            onPressed: () => onAction('preflight'),
            icon: const Icon(Icons.fact_check),
            label: Text(context.tr('Run preflight')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => onAction('import'),
            icon: const Icon(Icons.download),
            label: Text(context.tr('Import Content')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            onPressed: () => onAction('cluster'),
            icon: const Icon(Icons.hub),
            label: Text(context.tr('Cluster Items')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            onPressed: () => onAction('schedule'),
            icon: const Icon(Icons.calendar_month),
            label: Text(context.tr('Generate Schedule')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => onAction('activate'),
            icon: const Icon(Icons.play_arrow),
            label: Text(context.tr('Activate Plan')),
          ),
        ],
        if (plan.isActive) ...[
          FilledButton.tonalIcon(
            onPressed: () => onAction('preflight'),
            icon: const Icon(Icons.fact_check),
            label: Text(context.tr('Run preflight')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => onAction('execute'),
            icon: const Icon(Icons.water_drop),
            label: Text(context.tr('Execute Drip Now')),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => onAction('pause'),
            icon: const Icon(Icons.pause),
            label: Text(context.tr('Pause')),
          ),
        ],
        if (plan.isPaused) ...[
          FilledButton.tonalIcon(
            onPressed: () => onAction('preflight'),
            icon: const Icon(Icons.fact_check),
            label: Text(context.tr('Run preflight')),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => onAction('resume'),
            icon: const Icon(Icons.play_arrow),
            label: Text(context.tr('Resume')),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => onAction('cancel'),
            icon: const Icon(Icons.cancel),
            label: Text(context.tr('Cancel Plan')),
          ),
        ],
      ],
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.plan, required this.onAction});
  final DripPlan plan;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onAction,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'preflight',
          child: Text(context.tr('Run preflight')),
        ),
        if (plan.isDraft)
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('Delete plan')),
          ),
        if (plan.isActive)
          PopupMenuItem(
            value: 'cancel',
            child: Text(context.tr('Cancel plan')),
          ),
        if (plan.isPaused) ...[
          PopupMenuItem(value: 'resume', child: Text(context.tr('Resume'))),
          PopupMenuItem(value: 'cancel', child: Text(context.tr('Cancel'))),
        ],
      ],
    );
  }
}

Color _statusDotColor(String status, ColorScheme colorScheme) {
  return switch (status) {
    'published' => AppTheme.approveColor,
    'scheduled' => AppTheme.infoColor,
    'approved' => AppTheme.warningColor,
    _ => colorScheme.onSurfaceVariant,
  };
}
