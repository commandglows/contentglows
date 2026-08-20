import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project_asset.dart';
import '../../../data/models/video_timeline.dart';
import '../../../providers/video_timeline_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_asset_picker.dart';

class VideoTimelineScreen extends ConsumerWidget {
  const VideoTimelineScreen({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoTimelineProvider(contentId));
    final notifier = ref.read(videoTimelineProvider(contentId).notifier);
    final timeline = state.timeline;
    final document = timeline?.draft;
    final canUndo = notifier.canUndo;
    final canRedo = notifier.canRedo;

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline video')),
      body: state.isLoading && timeline == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: notifier.loadFromContentId,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _TimelineSummary(
                    state: state,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onSaveVersion: () => notifier.saveVersion(),
                    onUndo: notifier.undoDraft,
                    onRedo: notifier.redoDraft,
                    onRequestPreview: () => notifier.requestPreview(),
                    onApprovePreview: () => notifier.approvePreview(),
                    onRequestFinal: () => notifier.requestFinalRender(),
                    onRefreshPreview: () =>
                        notifier.refreshJob(finalRender: false),
                    onRefreshFinal: () =>
                        notifier.refreshJob(finalRender: true),
                  ),
                  if (state.lastError != null &&
                      state.lastError!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _InlineError(message: state.lastError!),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _EditToolbar(
                    state: state,
                    onAddText: notifier.addTextClip,
                    onAddAsset: () => _showAssetPicker(
                      context: context,
                      state: state,
                      notifier: notifier,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (document == null)
                    const _EmptyTimeline()
                  else
                    _TimelineEditor(
                      document: document,
                      state: state,
                      onSelectClip: notifier.selectClip,
                      onMoveClip: notifier.moveClipFrames,
                      onResizeClip: notifier.resizeClipFrames,
                      onDeleteClip: notifier.deleteClip,
                      onToggleTrackMute: notifier.toggleTrackMute,
                      onToggleTrackLock: notifier.toggleTrackLock,
                      onEditText: (clip) =>
                          _showTextEditor(context, clip, notifier),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _showTextEditor(
    BuildContext context,
    VideoTimelineClip clip,
    VideoTimelineController notifier,
  ) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _TextClipEditorDialog(initialText: clip.text ?? ''),
    );
    if (text != null) {
      notifier.updateClipText(clip.id, text);
    }
  }

  Future<void> _showAssetPicker({
    required BuildContext context,
    required VideoTimelineState state,
    required VideoTimelineController notifier,
  }) async {
    final version = state.activeVersion;
    if (version == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save a version before selecting assets.'),
        ),
      );
      return;
    }

    var clipType = 'image';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Add asset clip',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'image',
                            icon: Icon(Icons.image_outlined),
                            label: Text('Image'),
                          ),
                          ButtonSegment(
                            value: 'video',
                            icon: Icon(Icons.videocam_outlined),
                            label: Text('Video'),
                          ),
                          ButtonSegment(
                            value: 'audio',
                            icon: Icon(Icons.graphic_eq_rounded),
                            label: Text('Audio'),
                          ),
                          ButtonSegment(
                            value: 'music',
                            icon: Icon(Icons.music_note_rounded),
                            label: Text('Music'),
                          ),
                        ],
                        selected: {clipType},
                        onSelectionChanged: (selection) {
                          setModalState(() => clipType = selection.first);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: ProjectAssetPicker(
                          targetType: 'video_version',
                          targetId: version.versionId,
                          usageAction: 'select_for_video_version',
                          placement: 'timeline_$clipType',
                          allowedMediaKinds: _allowedMediaKinds(clipType),
                          onSelected: (ProjectAssetUsage usage) {
                            notifier.addAssetClip(
                              assetId: usage.assetId,
                              clipType: clipType,
                            );
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TextClipEditorDialog extends StatefulWidget {
  const _TextClipEditorDialog({required this.initialText});

  final String initialText;

  @override
  State<_TextClipEditorDialog> createState() => _TextClipEditorDialogState();
}

class _TextClipEditorDialogState extends State<_TextClipEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit text clip'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 2000,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Text'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _TimelineSummary extends StatelessWidget {
  const _TimelineSummary({
    required this.state,
    required this.canUndo,
    required this.canRedo,
    required this.onSaveVersion,
    required this.onUndo,
    required this.onRedo,
    required this.onRequestPreview,
    required this.onApprovePreview,
    required this.onRequestFinal,
    required this.onRefreshPreview,
    required this.onRefreshFinal,
  });

  final VideoTimelineState state;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onSaveVersion;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onRequestPreview;
  final VoidCallback onApprovePreview;
  final VoidCallback onRequestFinal;
  final VoidCallback onRefreshPreview;
  final VoidCallback onRefreshFinal;

  @override
  Widget build(BuildContext context) {
    final timeline = state.timeline;
    final version = state.activeVersion;
    final canSave = timeline != null && !state.isBusy;
    final canPreview =
        version != null && !state.hasUnsavedChanges && !state.isBusy;
    final canApprove =
        state.previewJob != null &&
        state.previewJob!.isCompleted &&
        !state.previewJob!.stale &&
        !state.isBusy;
    final canFinal =
        version?.approvedPreviewJobId != null &&
        !state.hasUnsavedChanges &&
        !state.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _StatusChip(
              label: state.hasUnsavedChanges ? 'Draft changed' : 'Saved draft',
              icon: state.hasUnsavedChanges
                  ? Icons.edit_note_rounded
                  : Icons.check_rounded,
              tone: state.hasUnsavedChanges
                  ? _StatusTone.warning
                  : _StatusTone.good,
            ),
            _StatusChip(
              label: 'Preview ${timeline?.previewStatus ?? 'missing'}',
              icon: Icons.play_circle_outline_rounded,
              tone: _toneForStatus(timeline?.previewStatus),
            ),
            _StatusChip(
              label: 'Final ${timeline?.finalStatus ?? 'missing'}',
              icon: Icons.movie_creation_outlined,
              tone: _toneForStatus(timeline?.finalStatus),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.compact),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              onPressed: canUndo ? onUndo : null,
              tooltip: 'Undo draft change',
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              onPressed: canRedo ? onRedo : null,
              tooltip: 'Redo draft change',
              icon: const Icon(Icons.redo_rounded),
            ),
            const SizedBox(width: AppSpacing.xxs),
            FilledButton.icon(
              onPressed: canSave ? onSaveVersion : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save version'),
            ),
            OutlinedButton.icon(
              onPressed: canPreview ? onRequestPreview : null,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Request preview'),
            ),
            OutlinedButton.icon(
              onPressed: canApprove ? onApprovePreview : null,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Approve preview'),
            ),
            FilledButton.icon(
              onPressed: canFinal ? onRequestFinal : null,
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('Request final'),
            ),
            IconButton(
              onPressed: state.previewJob != null ? onRefreshPreview : null,
              tooltip: 'Refresh preview job',
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: state.finalJob != null ? onRefreshFinal : null,
              tooltip: 'Refresh final job',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.compact),
        _TimelineFacts(state: state),
      ],
    );
  }
}

class _TimelineFacts extends StatelessWidget {
  const _TimelineFacts({required this.state});

  final VideoTimelineState state;

  @override
  Widget build(BuildContext context) {
    final timeline = state.timeline;
    final version = state.activeVersion;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      children: [
        Text('Preset ${timeline?.formatPreset ?? '-'}'),
        Text('Revision ${timeline?.draftRevision ?? 0}'),
        Text('Version ${version?.versionNumber ?? '-'}'),
        if (state.previewJob != null)
          Text(
            'Preview job ${state.previewJob!.status} '
            '${state.previewJob!.progress}%',
          ),
        if (state.finalJob != null)
          Text(
            'Final job ${state.finalJob!.status} ${state.finalJob!.progress}%',
          ),
        if (state.finalJob?.artifact != null)
          const Text('Final artifact ready'),
      ],
    );
  }
}

class _EditToolbar extends StatelessWidget {
  const _EditToolbar({
    required this.state,
    required this.onAddText,
    required this.onAddAsset,
  });

  final VideoTimelineState state;
  final VoidCallback onAddText;
  final VoidCallback onAddAsset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        FilledButton.tonalIcon(
          onPressed: state.timeline == null ? null : onAddText,
          icon: const Icon(Icons.title_rounded),
          label: const Text('Add text clip'),
        ),
        OutlinedButton.icon(
          onPressed: state.timeline == null ? null : onAddAsset,
          icon: const Icon(Icons.perm_media_outlined),
          label: const Text('Add asset clip'),
        ),
      ],
    );
  }
}

class _TimelineEditor extends StatelessWidget {
  const _TimelineEditor({
    required this.document,
    required this.state,
    required this.onSelectClip,
    required this.onMoveClip,
    required this.onResizeClip,
    required this.onDeleteClip,
    required this.onEditText,
    required this.onToggleTrackMute,
    required this.onToggleTrackLock,
  });

  final VideoTimelineDocument document;
  final VideoTimelineState state;
  final void Function(String clipId) onSelectClip;
  final void Function(String clipId, int deltaFrames) onMoveClip;
  final void Function(String clipId, int deltaFrames) onResizeClip;
  final void Function(String clipId) onDeleteClip;
  final void Function(VideoTimelineClip clip) onEditText;
  final void Function(String trackId) onToggleTrackMute;
  final void Function(String trackId) onToggleTrackLock;

  @override
  Widget build(BuildContext context) {
    final tracks = [...document.tracks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final totalFrames = _timelineFrames(document);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${_secondsLabel(totalFrames, document.fps)} total • '
          '${document.fps} fps • ${document.clips.length} clip(s)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.compact),
        for (final track in tracks)
          _TrackLane(
            track: track,
            document: document,
            selectedClipId: state.selectedClipId,
            totalFrames: totalFrames,
            onSelectClip: onSelectClip,
            onMoveClip: onMoveClip,
            onResizeClip: onResizeClip,
            onDeleteClip: onDeleteClip,
            onEditText: onEditText,
            onToggleTrackMute: onToggleTrackMute,
            onToggleTrackLock: onToggleTrackLock,
          ),
        if (tracks.isEmpty) const _EmptyTimeline(),
      ],
    );
  }
}

class _TrackLane extends StatelessWidget {
  const _TrackLane({
    required this.track,
    required this.document,
    required this.selectedClipId,
    required this.totalFrames,
    required this.onSelectClip,
    required this.onMoveClip,
    required this.onResizeClip,
    required this.onDeleteClip,
    required this.onEditText,
    required this.onToggleTrackMute,
    required this.onToggleTrackLock,
  });

  final VideoTimelineTrack track;
  final VideoTimelineDocument document;
  final String? selectedClipId;
  final int totalFrames;
  final void Function(String clipId) onSelectClip;
  final void Function(String clipId, int deltaFrames) onMoveClip;
  final void Function(String clipId, int deltaFrames) onResizeClip;
  final void Function(String clipId) onDeleteClip;
  final void Function(VideoTimelineClip clip) onEditText;
  final void Function(String trackId) onToggleTrackMute;
  final void Function(String trackId) onToggleTrackLock;

  @override
  Widget build(BuildContext context) {
    final clips =
        document.clips.where((clip) => clip.trackId == track.id).toList()
          ..sort((a, b) => a.startFrame.compareTo(b.startFrame));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_trackIcon(track.type), size: AppSizes.iconLarge),
              const SizedBox(width: AppSpacing.xxs2),
              Text(
                track.type,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('${clips.length} clip(s)'),
              const Spacer(),
              Icon(
                track.muted ? Icons.volume_off : Icons.volume_up,
                size: AppSizes.icon,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                track.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: AppSizes.icon,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _TrackStrip(
            clips: clips,
            isMuted: track.muted,
            isLocked: track.locked,
            selectedClipId: selectedClipId,
            totalFrames: totalFrames,
            onSelectClip: onSelectClip,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              IconButton(
                tooltip: track.muted
                    ? 'Unmute ${track.type} track'
                    : 'Mute ${track.type} track',
                onPressed: () => onToggleTrackMute(track.id),
                icon: Icon(track.muted ? Icons.volume_off : Icons.volume_up),
              ),
              IconButton(
                tooltip: track.locked
                    ? 'Unlock ${track.type} track'
                    : 'Lock ${track.type} track',
                onPressed: () => onToggleTrackLock(track.id),
                icon: Icon(track.locked ? Icons.lock : Icons.lock_open_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (clips.isEmpty)
            const Text('No clips on this track.')
          else
            for (final clip in clips)
              _ClipControls(
                key: ValueKey('clip-controls-${clip.id}'),
                clip: clip,
                fps: document.fps,
                selected: clip.id == selectedClipId,
                canDelete: document.clips.length > 1,
                isTrackLocked: track.locked,
                isTrackMuted: track.muted,
                onSelect: () => onSelectClip(clip.id),
                onMove: track.locked
                    ? null
                    : (frames) => onMoveClip(clip.id, frames),
                onResize: track.locked
                    ? null
                    : (frames) => onResizeClip(clip.id, frames),
                onDelete: (document.clips.length > 1 && !track.locked)
                    ? () => onDeleteClip(clip.id)
                    : null,
                onEditText: clip.clipType == 'text'
                    ? (track.locked ? null : () => onEditText(clip))
                    : null,
              ),
        ],
      ),
    );
  }
}

class _TrackStrip extends StatelessWidget {
  const _TrackStrip({
    required this.clips,
    required this.isMuted,
    required this.isLocked,
    required this.selectedClipId,
    required this.totalFrames,
    required this.onSelectClip,
  });

  final List<VideoTimelineClip> clips;
  final bool isMuted;
  final bool isLocked;
  final String? selectedClipId;
  final int totalFrames;
  final void Function(String clipId) onSelectClip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Stack(
            children: [
              for (final clip in clips)
                Positioned(
                  left: _frameToX(clip.startFrame, totalFrames, width),
                  width: _clipWidth(clip.durationFrames, totalFrames, width),
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: _ClipBlock(
                    isMuted: isMuted,
                    isTrackLocked: isLocked,
                    clip: clip,
                    selected: clip.id == selectedClipId,
                    onTap: () => onSelectClip(clip.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ClipBlock extends StatelessWidget {
  const _ClipBlock({
    required this.clip,
    required this.selected,
    required this.isMuted,
    required this.isTrackLocked,
    required this.onTap,
  });

  final VideoTimelineClip clip;
  final bool selected;
  final bool isMuted;
  final bool isTrackLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opacity = isTrackLocked || isMuted ? AppOpacity.divider : 1.0;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: selected ? scheme.primary : _clipColor(context, clip.clipType),
        borderRadius: BorderRadius.circular(AppRadii.compactControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.compactControl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.fine,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _clipLabel(clip),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isTrackLocked)
                  const Icon(
                    Icons.lock_rounded,
                    size: AppSizes.iconTiny,
                  ),
                if (isMuted) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(Icons.volume_off, size: AppSizes.iconTiny),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipControls extends StatelessWidget {
  const _ClipControls({
    super.key,
    required this.clip,
    required this.fps,
    required this.selected,
    required this.canDelete,
    required this.isTrackLocked,
    required this.isTrackMuted,
    required this.onSelect,
    this.onMove,
    this.onResize,
    this.onDelete,
    required this.onEditText,
  });

  final VideoTimelineClip clip;
  final int fps;
  final bool selected;
  final bool canDelete;
  final bool isTrackLocked;
  final bool isTrackMuted;
  final VoidCallback onSelect;
  final void Function(int frames)? onMove;
  final void Function(int frames)? onResize;
  final VoidCallback? onDelete;
  final VoidCallback? onEditText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.compact),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surface,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onSelect,
            child: Row(
              children: [
                Icon(_trackIcon(clip.clipType), size: AppSizes.iconLarge),
                const SizedBox(width: AppSpacing.xxs2),
                Expanded(
                  child: Text(
                    _clipLabel(clip),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_secondsLabel(clip.startFrame, fps)} → '
                  '${_secondsLabel(clip.startFrame + clip.durationFrames, fps)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Start ${clip.startFrame}f • Duration '
            '${clip.durationFrames}f (${_secondsLabel(clip.durationFrames, fps)})',
          ),
          if (clip.assetId != null && clip.assetId!.isNotEmpty)
            Text('Asset ${clip.assetId}'),
          if (clip.text != null && clip.text!.isNotEmpty)
            Text('Text ${clip.text}'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Move back 1 second',
                onPressed: onMove == null ? null : () => onMove!(-fps),
                icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
              ),
              IconButton(
                tooltip: 'Move back 1 frame',
                onPressed: onMove == null ? null : () => onMove!(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Move forward 1 frame',
                onPressed: onMove == null ? null : () => onMove!(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Move forward 1 second',
                onPressed: onMove == null ? null : () => onMove!(fps),
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
              ),
              IconButton(
                tooltip: 'Shorten by 1 second',
                onPressed: onResize == null ? null : () => onResize!(-fps),
                icon: const Icon(Icons.compress_rounded),
              ),
              IconButton(
                tooltip: 'Lengthen by 1 second',
                onPressed: onResize == null ? null : () => onResize!(fps),
                icon: const Icon(Icons.expand_rounded),
              ),
              if (onEditText != null)
                IconButton.filledTonal(
                  tooltip: 'Edit text',
                  onPressed: onEditText,
                  icon: const Icon(Icons.edit_rounded),
                ),
              IconButton(
                tooltip: 'Delete clip',
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              if (isTrackLocked)
                Icon(
                  Icons.lock_rounded,
                  size: AppSizes.icon,
                  color: AppTheme.attentionStrongColor,
                ),
              if (isTrackMuted)
                Icon(
                  Icons.volume_off,
                  size: AppSizes.icon,
                  color: AppTheme.attentionStrongColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      _StatusTone.good => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _StatusTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _StatusTone.bad => (scheme.errorContainer, scheme.onErrorContainer),
      _StatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: AppSizes.iconLarge, color: colors.$2),
      label: Text(label),
      backgroundColor: colors.$1,
      labelStyle: TextStyle(color: colors.$2, fontWeight: FontWeight.w700),
      side: BorderSide.none,
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.contentInset),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        'No timeline data available for this content item yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

enum _StatusTone { good, warning, bad, neutral }

_StatusTone _toneForStatus(String? status) {
  return switch (status) {
    'completed' => _StatusTone.good,
    'failed' || 'cancelled' => _StatusTone.bad,
    'stale' || 'queued' || 'in_progress' => _StatusTone.warning,
    _ => _StatusTone.neutral,
  };
}

Set<String> _allowedMediaKinds(String clipType) {
  return switch (clipType) {
    'video' => const {'video', 'video_cover'},
    'audio' => const {'audio'},
    'music' => const {'music', 'audio'},
    _ => const {'image', 'thumbnail', 'capture', 'video_cover'},
  };
}

IconData _trackIcon(String type) {
  return switch (type) {
    'text' => Icons.title_rounded,
    'overlay' => Icons.title_rounded,
    'video' => Icons.videocam_outlined,
    'audio' => Icons.graphic_eq_rounded,
    'music' => Icons.music_note_rounded,
    'background' => Icons.wallpaper_outlined,
    _ => Icons.image_outlined,
  };
}

String _clipLabel(VideoTimelineClip clip) {
  final text = clip.text?.trim();
  if (clip.clipType == 'text' && text != null && text.isNotEmpty) {
    return text;
  }
  return '${clip.clipType} • ${clip.id}';
}

Color _clipColor(BuildContext context, String type) {
  final scheme = Theme.of(context).colorScheme;
  return switch (type) {
    'text' => scheme.secondaryContainer,
    'video' => scheme.tertiaryContainer,
    'audio' || 'music' => scheme.primaryContainer,
    _ => scheme.surfaceContainerHigh,
  };
}

int _timelineFrames(VideoTimelineDocument document) {
  final explicit = document.durationFrames ?? 0;
  final clipsEnd = document.clips.fold<int>(0, (max, clip) {
    final end = clip.startFrame + clip.durationFrames;
    return end > max ? end : max;
  });
  return [explicit, clipsEnd, document.fps * 5].reduce((a, b) => a > b ? a : b);
}

double _frameToX(int frame, int totalFrames, double width) {
  if (totalFrames <= 0 || width <= 0) {
    return 0;
  }
  return (frame / totalFrames * width).clamp(0, width).toDouble();
}

double _clipWidth(int durationFrames, int totalFrames, double width) {
  if (totalFrames <= 0 || width <= 0) {
    return 32;
  }
  return (durationFrames / totalFrames * width).clamp(32, width).toDouble();
}

String _secondsLabel(int frames, int fps) {
  final safeFps = fps <= 0 ? 30 : fps;
  final seconds = frames / safeFps;
  return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)}s';
}
