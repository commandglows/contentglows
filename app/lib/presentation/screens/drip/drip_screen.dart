import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/drip_plan.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/offline_sync_status_chip.dart';
import '../../widgets/project_picker_action.dart';
import 'drip_plan_detail_screen.dart';
import 'drip_wizard_sheet.dart';

class DripScreen extends ConsumerWidget {
  const DripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(dripPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Content Drip')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openWizard(context, ref),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'drip.plans.load',
            title: context.tr('Failed to load drip plans'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(dripPlansProvider),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return _EmptyState(onCreatePressed: () => _openWizard(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dripPlansProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: plans.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _PlanCard(
                plan: plans[index],
                onTap: () => _openDetail(context, plans[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openWizard(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DripWizardSheet(
        onCreated: () => ref.invalidate(dripPlansProvider),
      ),
    );
  }

  void _openDetail(BuildContext context, DripPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DripPlanDetailScreen(planId: plan.id)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePressed});
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.wide),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: AppSizes.heroIcon, color: colorScheme.primary.withValues(alpha: AppOpacity.half)),
            const SizedBox(height: AppSpacing.md),
            Text(context.tr('No drip plans yet'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                  'Create a plan to progressively publish your content.\nGoogle will see a natural publishing rhythm.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: AppOpacity.muted)),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Create drip plan')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.onTap});
  final DripPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statsAsync = ref.watch(dripStatsProvider(plan.id));
    final syncInfo = ref.watch(
      offlineEntitySyncProvider(offlineEntityKey('drip_plan', plan.id)),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (syncInfo != null) ...[
                    OfflineSyncStatusChip(info: syncInfo, compact: true),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  _StatusChip(status: plan.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Config summary
              Text(
                '${plan.totalItems} ${context.tr('articles')}  ·  ${plan.itemsPerDay}/${context.tr('day')}  ·  ${context.tr(plan.clusterMode)}  ·  ${context.tr(plan.ssgFramework)}',
                style: TextStyle(fontSize: AppText.compact, color: colorScheme.onSurface.withValues(alpha: AppOpacity.muted)),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Progress bar
              statsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.progress),
                      child: LinearProgressIndicator(
                        value: stats.progressPercent,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs2),
                    Text(
                      '${stats.published}/${stats.totalItems} published',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Next drip
              if (plan.nextDripAt != null && plan.isActive) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.schedule, size: AppSizes.iconSm, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      context.tr('Next drip: {date}', {
                        'date': _formatIso(plan.nextDripAt!, context),
                      }),
                      style: TextStyle(fontSize: AppText.xs, color: colorScheme.primary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatIso(String raw, BuildContext context) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('MMM d, HH:mm', context.localeTag).format(parsed.toLocal());
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      'active' => (AppTheme.approveColor, Icons.play_circle_filled),
      'paused' => (AppTheme.warningColor, Icons.pause_circle_filled),
      'completed' => (AppTheme.infoColor, Icons.check_circle),
      'cancelled' => (colorScheme.onSurfaceVariant, Icons.cancel),
      _ => (colorScheme.onSurfaceVariant, Icons.circle_outlined),
    };

    return Chip(
      avatar: Icon(icon, size: AppSizes.icon, color: color),
      label: Text(context.tr(status), style: TextStyle(fontSize: AppText.xs, color: color)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
