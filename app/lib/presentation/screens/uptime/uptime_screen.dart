import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/offline_sync.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_error_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

class UptimeScreen extends ConsumerStatefulWidget {
  const UptimeScreen({super.key});

  @override
  ConsumerState<UptimeScreen> createState() => _UptimeScreenState();
}

class _UptimeScreenState extends ConsumerState<UptimeScreen> {
  final List<_PingResult> _history = [];
  bool _checking = false;
  bool _refreshingStaleData = false;

  @override
  void initState() {
    super.initState();
    _checkOnce();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authSession = ref.watch(authSessionProvider);
    final appAccess = ref.watch(appAccessStateProvider);
    final statusAsync = ref.watch(backendStatusProvider);
    final offlineSync = ref.watch(offlineSyncStateProvider);
    final queueAsync = ref.watch(offlineQueueEntriesProvider);
    final accessState = appAccess.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Uptime')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: _checking
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _checking ? null : _checkAgain,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Access State'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Stage: {stage}', {
                      'stage':
                          accessState?.diagnosticsLabel ??
                          context.tr('loading'),
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Session: {state}', {
                      'state': authSession.status.name,
                    }),
                  ),
                  if (authSession.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Email: {email}', {
                        'email': '${authSession.email}',
                      }),
                    ),
                  ],
                  if (accessState?.message case final message?) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Last backend message: {message}', {
                        'message': message,
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Offline Sync'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Pending: {count}', {
                      'count': '${offlineSync.pendingCount}',
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Waiting for dependencies: {count}', {
                      'count': '${offlineSync.blockedDependencyCount}',
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Paused for auth: {count}', {
                      'count': '${offlineSync.pausedAuthCount}',
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Failed: {count}', {
                      'count': '${offlineSync.failedCount}',
                    }),
                  ),
                  if (offlineSync.hasStaleData) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Cached data is currently being used.'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Affected views: {views}', {
                        'views': _describeStaleKeys(offlineSync.staleKeys),
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: offlineSync.hasQueuedActions
                            ? () => ref
                                  .read(offlineQueueControllerProvider.notifier)
                                  .retryAll()
                            : null,
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(context.tr('Retry queued actions')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(offlineQueueControllerProvider.notifier)
                            .refresh(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('Refresh queue')),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            offlineSync.hasStaleData && !_refreshingStaleData
                            ? _refreshStaleData
                            : null,
                        icon: _refreshingStaleData
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_rounded),
                        label: Text(context.tr('Refresh stale data')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Current status
          statusAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Column(
              children: [
                _StatusBanner(online: false, theme: theme),
                const SizedBox(height: 12),
                AppErrorView(
                  scope: 'uptime.status_check',
                  title: context.tr('Backend status check failed'),
                  error: error,
                  stackTrace: stackTrace,
                  compact: true,
                  showIcon: false,
                  copyLabel: context.tr('Copy diagnostics'),
                  onRetry: () => _checkAgain(),
                ),
              ],
            ),
            data: (data) {
              final online =
                  data['status'] == 'ok' || data['status'] == 'healthy';
              return _StatusBanner(online: online, theme: theme);
            },
          ),
          const SizedBox(height: 20),

          // API details
          statusAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (data) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('API Details'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...data.entries
                          .where((e) => e.key != 'status')
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '${e.key}: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e.value}',
                                      style: const TextStyle(fontSize: 12),
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
            },
          ),
          const SizedBox(height: 20),
          queueAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => AppErrorView(
              scope: 'uptime.queue',
              title: context.tr('Queue status unavailable'),
              error: error,
              stackTrace: stackTrace,
              compact: true,
              showIcon: false,
              onRetry: () => ref.invalidate(offlineQueueEntriesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Queued Actions'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      for (final action in items)
                        _QueuedActionTile(
                          action: action,
                          onRetry: () => ref
                              .read(offlineQueueControllerProvider.notifier)
                              .retryOne(action.id),
                          onCancel: () => ref
                              .read(offlineQueueControllerProvider.notifier)
                              .cancel(action.id),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _checking ? null : _checkAgain,
                icon: const Icon(Icons.sync_rounded),
                label: Text(context.tr('Retry backend')),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  copyDiagnosticsToClipboard(
                    context,
                    ref,
                    title: context.tr('ContentGlows system status diagnostics'),
                    scope: 'uptime.copy_diagnostics',
                    currentError: accessState?.message,
                    contextData: {
                      'sessionState': authSession.status.name,
                      'sessionEmail': authSession.email ?? 'none',
                      'accessStage': accessState?.diagnosticsLabel ?? 'loading',
                    },
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(context.tr('Copy diagnostics')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authSessionProvider.notifier).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.tr('Sign out')),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Ping history
          if (_history.isNotEmpty) ...[
            Text(
              context.tr('Ping History'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._history.reversed.map(
              (ping) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    ping.online ? Icons.check_circle : Icons.error,
                    color: ping.online
                        ? AppTheme.approveColor
                        : AppTheme.rejectColor,
                    size: 20,
                  ),
                  title: Text(
                    ping.online ? context.tr('Online') : context.tr('Offline'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${ping.latencyMs}ms · ${ping.timestamp.hour}:${ping.timestamp.minute.toString().padLeft(2, '0')}:${ping.timestamp.second.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _checking ? null : _checkOnce,
            icon: const Icon(Icons.speed),
            label: Text(context.tr('Ping again')),
          ),
        ],
      ),
    );
  }

  Future<void> _checkOnce() async {
    setState(() => _checking = true);
    final api = ref.read(apiServiceProvider);
    final sw = Stopwatch()..start();
    try {
      final data = await api.healthCheck();
      sw.stop();
      final online = data['status'] == 'ok' || data['status'] == 'healthy';
      setState(() {
        _history.add(
          _PingResult(
            online: online,
            latencyMs: sw.elapsedMilliseconds,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      sw.stop();
      setState(() {
        _history.add(
          _PingResult(
            online: false,
            latencyMs: sw.elapsedMilliseconds,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
    ref.invalidate(backendStatusProvider);
    setState(() => _checking = false);
  }

  Future<void> _checkAgain() async {
    await _checkOnce();
    ref.invalidate(backendStatusProvider);
  }

  Future<void> _refreshStaleData() async {
    final staleKeys = ref.read(offlineSyncStateProvider).staleKeys;
    if (staleKeys.isEmpty) {
      return;
    }

    setState(() => _refreshingStaleData = true);
    try {
      final refreshes = <Future<void>>[];

      if (staleKeys.any((key) => key.startsWith('content.pending_review'))) {
        refreshes.add(
          ref.refresh(pendingContentProvider.future).then((_) => null),
        );
      }
      if (staleKeys.any((key) => key.startsWith('content.history'))) {
        refreshes.add(
          ref.refresh(contentHistoryProvider.future).then((_) => null),
        );
      }
      if (staleKeys.any((key) => key.startsWith('drip.plans'))) {
        refreshes.add(ref.refresh(dripPlansProvider.future).then((_) => null));
      }
      if (staleKeys.any((key) => key.startsWith('projects'))) {
        refreshes.add(
          ref.refresh(projectsStateProvider.future).then((_) => null),
        );
      }
      if (staleKeys.any((key) => key.startsWith('settings'))) {
        refreshes.add(
          ref.refresh(currentUserSettingsProvider.future).then((_) => null),
        );
      }

      if (refreshes.isNotEmpty) {
        await Future.wait(refreshes);
      }

      ref.invalidate(backendStatusProvider);
    } finally {
      if (mounted) {
        setState(() => _refreshingStaleData = false);
      }
    }
  }

  String _describeStaleKeys(Set<String> staleKeys) {
    final labels = <String>{};
    for (final key in staleKeys) {
      if (key.startsWith('content.pending_review')) {
        labels.add('review queue');
      } else if (key.startsWith('content.history')) {
        labels.add('history');
      } else if (key.startsWith('drip.plans')) {
        labels.add('drip plans');
      } else if (key.startsWith('projects')) {
        labels.add('projects');
      } else if (key.startsWith('settings')) {
        labels.add('settings');
      } else {
        labels.add(key);
      }
    }

    final sorted = labels.toList()..sort();
    return sorted.join(', ');
  }
}

class _QueuedActionTile extends StatelessWidget {
  const _QueuedActionTile({
    required this.action,
    required this.onRetry,
    required this.onCancel,
  });

  final QueuedOfflineAction action;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = switch (action.status) {
      OfflineQueueStatus.pending => context.tr('pending'),
      OfflineQueueStatus.retrying => context.tr('retrying'),
      OfflineQueueStatus.blockedDependency => context.tr('waiting_dependency'),
      OfflineQueueStatus.pausedAuth => context.tr('paused_auth'),
      OfflineQueueStatus.failed => context.tr('failed'),
      OfflineQueueStatus.cancelled => context.tr('cancelled'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${action.method} ${action.path}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Status: {status}', {'status': statusLabel}),
              style: theme.textTheme.bodySmall,
            ),
            if (action.lastError?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                action.lastError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(context.tr('Retry now')),
                ),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(context.tr('Cancel')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PingResult {
  final bool online;
  final int latencyMs;
  final DateTime timestamp;

  const _PingResult({
    required this.online,
    required this.latencyMs,
    required this.timestamp,
  });
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.online, required this.theme});
  final bool online;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final statusColor = online ? AppTheme.approveColor : AppTheme.rejectColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            online ? Icons.cloud_done : Icons.cloud_off,
            color: statusColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            online ? context.tr('API Online') : context.tr('API Offline'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
