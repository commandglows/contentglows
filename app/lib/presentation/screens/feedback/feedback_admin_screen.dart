import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/feedback_entry.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class FeedbackAdminScreen extends ConsumerStatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  ConsumerState<FeedbackAdminScreen> createState() =>
      _FeedbackAdminScreenState();
}

class _FeedbackAdminScreenState extends ConsumerState<FeedbackAdminScreen> {
  final AudioPlayer _player = AudioPlayer();
  FeedbackAdminStatusFilter _statusFilter = FeedbackAdminStatusFilter.all;
  FeedbackAdminTypeFilter _typeFilter = FeedbackAdminTypeFilter.all;
  String? _playingEntryId;

  FeedbackAdminQuery get _query =>
      FeedbackAdminQuery(status: _statusFilter, type: _typeFilter);

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingEntryId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    if (authSession.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('Feedback Admin'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final capabilityAsync = ref.watch(isFeedbackAdminProvider);
    return capabilityAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.tr('Feedback Admin'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text(context.tr('Checking access...')),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Feedback Admin'))),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: AppErrorView(
              scope: 'feedback_admin.capability',
              title: 'Could not verify access',
              error: error,
              stackTrace: stackTrace,
              onRetry: () => ref.invalidate(isFeedbackAdminProvider),
            ),
          ),
        ),
      ),
      data: (canAccess) {
        if (!canAccess) {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('Feedback Admin'))),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  context.tr(
                    'Access denied. This view is visible only to allowlisted accounts.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final entriesAsync = ref.watch(feedbackAdminEntriesProvider(_query));
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Feedback Admin')),
            actions: [
              IconButton(
                onPressed: () {
                  ref.invalidate(isFeedbackAdminProvider);
                  ref.invalidate(feedbackAdminEntriesProvider(_query));
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                context.tr(
                  'User feedback received by the backend. Real access control still lives server-side.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                  height: AppLineHeight.relaxed,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final filter in FeedbackAdminStatusFilter.values)
                    ChoiceChip(
                      label: Text(context.tr(_statusLabel(filter))),
                      selected: _statusFilter == filter,
                      onSelected: (_) => setState(() => _statusFilter = filter),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final filter in FeedbackAdminTypeFilter.values)
                    ChoiceChip(
                      label: Text(context.tr(_typeLabel(filter))),
                      selected: _typeFilter == filter,
                      onSelected: (_) => setState(() => _typeFilter = filter),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              entriesAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return Text(context.tr('No feedback for this filter.'));
                  }
                  return Column(
                    children: [
                      for (final entry in entries)
                        _FeedbackEntryCard(
                          entry: entry,
                          isPlaying: _playingEntryId == entry.id,
                          onTogglePlayback: entry.audioUrl == null
                              ? null
                              : () => _togglePlayback(entry),
                          onMarkReviewed:
                              entry.status == FeedbackEntryStatus.reviewed
                              ? null
                              : () => _markReviewed(entry.id),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.wide),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppErrorView(
                    scope: 'feedback_admin.load',
                    title: context.tr('Could not load feedback'),
                    error: error,
                    stackTrace: stackTrace,
                    compact: true,
                    showIcon: false,
                    onRetry: () =>
                        ref.invalidate(feedbackAdminEntriesProvider(_query)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _togglePlayback(FeedbackEntry entry) async {
    final audioUrl = entry.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _showSnack(context.tr('No audio URL provided by backend.'));
      return;
    }

    if (_playingEntryId == entry.id) {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingEntryId = null);
      return;
    }

    await _player.stop();
    await _player.play(UrlSource(audioUrl));
    if (!mounted) return;
    setState(() => _playingEntryId = entry.id);
  }

  Future<void> _markReviewed(String feedbackId) async {
    final l10n = context.l10n;
    try {
      await ref.read(feedbackServiceProvider).markReviewed(feedbackId);
      if (!mounted) return;
      ref.invalidate(feedbackAdminEntriesProvider(_query));
      ref.invalidate(feedbackAdminEntriesProvider(const FeedbackAdminQuery()));
      _showSnack(l10n.tr('Feedback marked as read.'));
    } catch (error, stackTrace) {
      if (!mounted) return;
      _showSnack(
        l10n.tr('Failed to update: {error}', params: {'error': error}),
        error: error,
        stackTrace: stackTrace,
        scope: 'feedback_admin.mark_reviewed',
      );
    }
  }

  void _showSnack(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String scope = 'feedback_admin.message',
  }) {
    if (!mounted) return;
    if (error != null) {
      showDiagnosticSnackBar(
        context,
        ref,
        message: message,
        scope: scope,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({
    required this.entry,
    required this.isPlaying,
    this.onTogglePlayback,
    this.onMarkReviewed,
  });

  final FeedbackEntry entry;
  final bool isPlaying;
  final VoidCallback? onTogglePlayback;
  final VoidCallback? onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(context.tr(entry.isAudio ? 'Audio' : 'Text')),
                  avatar: Icon(
                    entry.isAudio ? Icons.mic_rounded : Icons.notes_rounded,
                    size: AppSpacing.dense,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Chip(
                  backgroundColor: entry.status == FeedbackEntryStatus.reviewed
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primaryContainer,
                  label: Text(
                    context.tr(
                      entry.status == FeedbackEntryStatus.reviewed
                          ? 'Read'
                          : 'New',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.message?.trim().isNotEmpty == true
                  ? entry.message!
                  : context.tr('Audio feedback'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _MetaChip(
                  label: DateFormat.yMMMd(
                    context.localeTag,
                  ).add_Hm().format(entry.createdAt.toLocal()),
                ),
                _MetaChip(label: entry.platform),
                _MetaChip(label: entry.locale),
                _MetaChip(
                  label: entry.userEmail?.isNotEmpty == true
                      ? entry.userEmail!
                      : context.tr('anonymous'),
                ),
                if (entry.durationMs != null)
                  _MetaChip(label: _formatDuration(entry.durationMs!)),
              ],
            ),
            if (entry.isAudio) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onTogglePlayback,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(context.tr(isPlaying ? 'Pause' : 'Play')),
                  ),
                  if (entry.audioUrl == null || entry.audioUrl!.isEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      context.tr('Audio unavailable'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onMarkReviewed,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(context.tr('Mark as read')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.compactStack,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _statusLabel(FeedbackAdminStatusFilter filter) => switch (filter) {
  FeedbackAdminStatusFilter.all => 'All',
  FeedbackAdminStatusFilter.unread => 'Unread',
  FeedbackAdminStatusFilter.reviewed => 'Read',
};

String _typeLabel(FeedbackAdminTypeFilter filter) => switch (filter) {
  FeedbackAdminTypeFilter.all => 'All types',
  FeedbackAdminTypeFilter.text => 'Text',
  FeedbackAdminTypeFilter.audio => 'Audio',
};

String _formatDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
