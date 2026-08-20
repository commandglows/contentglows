import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_error_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

final _runsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.fetchRuns(limit: 50);
});

class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(_runsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Robot Runs')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_runsProvider),
          ),
        ],
      ),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'runs.load',
            title: context.tr('Failed to load runs'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(_runsProvider),
          ),
        ),
        data: (runs) {
          if (runs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: AppSpacing.wide * 2,
                      color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.tr('No robot runs yet'),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_runsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: runs.length,
              itemBuilder: (context, index) => _RunCard(run: runs[index]),
            ),
          );
        },
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});
  final Map<String, dynamic> run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final robotName = run['robot_name'] as String? ?? 'Unknown';
    final workflow = run['workflow_type'] as String? ?? '';
    final status = run['status'] as String? ?? 'unknown';
    final startedAt = run['started_at'] as String? ?? '';
    final duration = run['duration_seconds'] as num?;

    final statusColor = switch (status) {
      'success' => AppTheme.approveColor,
      'running' => AppTheme.infoColor,
      'error' => AppTheme.rejectColor,
      _ => theme.colorScheme.outline,
    };

    final statusIcon = switch (status) {
      'success' => Icons.check_circle,
      'running' => Icons.sync,
      'error' => Icons.error,
      _ => Icons.help_outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(robotName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (workflow.isNotEmpty) workflow,
            if (startedAt.isNotEmpty) startedAt.split('T').first,
            if (duration != null) '${duration.toInt()}s',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(status,
              style: TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: statusColor,
              )),
        ),
      ),
    );
  }
}
