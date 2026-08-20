import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../widgets/app_error_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

final _activityProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider);
  return api.fetchActivity(
    limit: 50,
    projectId: activeProjectId,
  );
});

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(_activityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Activity')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_activityProvider),
          ),
        ],
      ),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'activity.load',
            title: context.tr('Failed to load activity'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(_activityProvider),
          ),
        ),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: AppSizes.heroIcon,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('No activity yet'),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.tr(
                      'Actions from robots and your work will appear here',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_activityProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: activities.length,
              itemBuilder: (context, index) =>
                  _ActivityItem(activity: activities[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});
  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = activity['action'] as String? ?? 'unknown';
    final robotId = activity['robotId'] as String?;
    final status = activity['status'] as String? ?? 'started';
    final createdAt = activity['createdAt'] as String? ?? '';

    final statusColor = switch (status) {
      'completed' => AppTheme.approveColor,
      'running' => AppTheme.infoColor,
      'failed' => AppTheme.rejectColor,
      _ => theme.colorScheme.outline,
    };

    final actionIcon = switch (action) {
      String a when a.contains('mesh') => Icons.hub,
      String a when a.contains('seo') => Icons.search,
      String a when a.contains('newsletter') => Icons.email,
      String a when a.contains('robot') || a.contains('run') => Icons.smart_toy,
      String a when a.contains('publish') => Icons.publish,
      _ => Icons.bolt,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs2),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: statusColor.withValues(alpha: AppOpacity.medium),
          child: Icon(
            actionIcon,
            color: statusColor,
            size: AppSizes.iconLarge,
          ),
        ),
        title: Text(
          action.replaceAll('_', ' '),
          style: TextStyle(
            fontSize: AppText.compact,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            robotId,
            context.tr(status),
            createdAt.isNotEmpty ? createdAt.split('T').first : null,
          ].whereType<String>().join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
