import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../data/models/video_timeline.dart';
import '../data/services/api_service.dart';
import 'providers.dart';

class VideoTimelineState {
  const VideoTimelineState({
    this.timeline,
    this.latestVersion,
    this.previewJob,
    this.finalJob,
    this.isLoading = false,
    this.isSavingVersion = false,
    this.isRequestingPreview = false,
    this.isApprovingPreview = false,
    this.isRequestingFinal = false,
    this.hasUnsavedChanges = false,
    this.selectedClipId,
    this.lastError,
  });

  final VideoTimelineResponse? timeline;
  final VideoTimelineVersion? latestVersion;
  final VideoTimelineRenderJob? previewJob;
  final VideoTimelineRenderJob? finalJob;
  final bool isLoading;
  final bool isSavingVersion;
  final bool isRequestingPreview;
  final bool isApprovingPreview;
  final bool isRequestingFinal;
  final bool hasUnsavedChanges;
  final String? selectedClipId;
  final String? lastError;

  bool get hasTimeline => timeline != null;
  bool get isBusy =>
      isLoading ||
      isSavingVersion ||
      isRequestingPreview ||
      isApprovingPreview ||
      isRequestingFinal;
  VideoTimelineVersion? get activeVersion =>
      latestVersion ?? timeline?.latestVersion;
  VideoTimelineDocument? get activeDocument => timeline?.draft;
  VideoTimelineClip? get selectedClip {
    final id = selectedClipId;
    final document = activeDocument;
    if (id == null || document == null) {
      return null;
    }
    for (final clip in document.clips) {
      if (clip.id == id) {
        return clip;
      }
    }
    return null;
  }

  VideoTimelineState copyWith({
    VideoTimelineResponse? timeline,
    bool clearTimeline = false,
    VideoTimelineVersion? latestVersion,
    bool clearLatestVersion = false,
    VideoTimelineRenderJob? previewJob,
    bool clearPreviewJob = false,
    VideoTimelineRenderJob? finalJob,
    bool clearFinalJob = false,
    bool? isLoading,
    bool? isSavingVersion,
    bool? isRequestingPreview,
    bool? isApprovingPreview,
    bool? isRequestingFinal,
    bool? hasUnsavedChanges,
    String? selectedClipId,
    bool clearSelectedClipId = false,
    String? lastError,
    bool clearLastError = false,
  }) {
    return VideoTimelineState(
      timeline: clearTimeline ? null : (timeline ?? this.timeline),
      latestVersion: clearLatestVersion
          ? null
          : (latestVersion ?? this.latestVersion),
      previewJob: clearPreviewJob ? null : (previewJob ?? this.previewJob),
      finalJob: clearFinalJob ? null : (finalJob ?? this.finalJob),
      isLoading: isLoading ?? this.isLoading,
      isSavingVersion: isSavingVersion ?? this.isSavingVersion,
      isRequestingPreview: isRequestingPreview ?? this.isRequestingPreview,
      isApprovingPreview: isApprovingPreview ?? this.isApprovingPreview,
      isRequestingFinal: isRequestingFinal ?? this.isRequestingFinal,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      selectedClipId: clearSelectedClipId
          ? null
          : (selectedClipId ?? this.selectedClipId),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class VideoTimelineController extends StateNotifier<VideoTimelineState> {
  VideoTimelineController({
    required ApiService apiService,
    required this.contentId,
  }) : _apiService = apiService,
       super(const VideoTimelineState(isLoading: true)) {
    unawaited(loadFromContentId());
  }

  final ApiService _apiService;
  final String contentId;
  static const int _maxDurationSeconds = 180;
  static const int _maxUndoSteps = 30;
  final List<_TimelineDraftSnapshot> _undoStack = [];
  final List<_TimelineDraftSnapshot> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> loadFromContentId() async {
    state = state.copyWith(isLoading: true, clearLastError: true);
    try {
      final generation = await _apiService.generateBrandedVideoFromContent(
        contentId: contentId,
        triggerSource: 'manual_create',
      );
      state = state.copyWith(
        timeline: generation.timeline,
        latestVersion: generation.version,
        previewJob: generation.previewJob,
        selectedClipId: _firstClipId(generation.timeline.draft),
        hasUnsavedChanges: false,
        clearFinalJob: true,
        isLoading: false,
      );
      _clearHistory();
    } catch (error) {
      state = state.copyWith(isLoading: false, lastError: _formatError(error));
    }
  }

  Future<VideoTimelineVersion?> saveVersion() async {
    final timeline = state.timeline;
    if (timeline == null) {
      return null;
    }
    state = state.copyWith(isSavingVersion: true, clearLastError: true);
    try {
      final version = await _apiService.createVideoTimelineVersion(
        timelineId: timeline.timelineId,
        draftRevision: timeline.draftRevision,
        timeline: timeline.draft,
        baseVersionId: timeline.currentVersionId,
      );
      final refreshed = await _apiService.getVideoTimeline(timeline.timelineId);
      state = state.copyWith(
        timeline: refreshed,
        latestVersion: refreshed.latestVersion ?? version,
        selectedClipId: _preserveSelectedClip(refreshed.draft),
        hasUnsavedChanges: false,
        clearPreviewJob: true,
        clearFinalJob: true,
        isSavingVersion: false,
      );
      _clearHistory();
      return version;
    } catch (error) {
      state = state.copyWith(
        isSavingVersion: false,
        lastError: _formatError(error),
      );
      return null;
    }
  }

  Future<VideoTimelineRenderJob?> requestPreview() async {
    final timeline = state.timeline;
    final version = state.activeVersion;
    if (timeline == null || version == null || state.hasUnsavedChanges) {
      state = state.copyWith(
        lastError: 'Save a clean version before requesting preview.',
      );
      return null;
    }
    state = state.copyWith(isRequestingPreview: true, clearLastError: true);
    try {
      final job = await _apiService.requestVideoTimelinePreview(
        timelineId: timeline.timelineId,
        versionId: version.versionId,
      );
      state = state.copyWith(
        previewJob: job,
        timeline: timeline.copyWith(
          previewStatus: job.status,
          updatedAt: DateTime.now().toUtc(),
        ),
        isRequestingPreview: false,
      );
      return job;
    } catch (error) {
      state = state.copyWith(
        isRequestingPreview: false,
        lastError: _formatError(error),
      );
      return null;
    }
  }

  Future<VideoTimelineVersion?> approvePreview({String? previewJobId}) async {
    final timeline = state.timeline;
    final version = state.activeVersion;
    final jobId = previewJobId ?? state.previewJob?.jobId;
    if (timeline == null || version == null || jobId == null || jobId.isEmpty) {
      state = state.copyWith(lastError: 'No preview job available to approve.');
      return null;
    }
    state = state.copyWith(isApprovingPreview: true, clearLastError: true);
    try {
      final approved = await _apiService.approveVideoTimelinePreview(
        timelineId: timeline.timelineId,
        versionId: version.versionId,
        previewJobId: jobId,
      );
      state = state.copyWith(
        latestVersion: approved,
        timeline: timeline.copyWith(
          currentVersionId: approved.versionId,
          latestVersion: approved,
          previewStatus: VideoTimelineStatus.completed.id,
          updatedAt: DateTime.now().toUtc(),
        ),
        isApprovingPreview: false,
      );
      return approved;
    } catch (error) {
      state = state.copyWith(
        isApprovingPreview: false,
        lastError: _formatError(error),
      );
      return null;
    }
  }

  Future<VideoTimelineRenderJob?> requestFinalRender({
    String? previewJobId,
  }) async {
    final timeline = state.timeline;
    final version = state.activeVersion;
    final jobId =
        previewJobId ??
        version?.approvedPreviewJobId ??
        state.previewJob?.jobId;
    if (state.hasUnsavedChanges) {
      state = state.copyWith(
        lastError: 'Save a clean version before requesting final render.',
      );
      return null;
    }
    if (timeline == null || version == null || jobId == null || jobId.isEmpty) {
      state = state.copyWith(
        lastError: 'Approve a preview before requesting final render.',
      );
      return null;
    }
    state = state.copyWith(isRequestingFinal: true, clearLastError: true);
    try {
      final job = await _apiService.requestVideoTimelineFinalRender(
        timelineId: timeline.timelineId,
        versionId: version.versionId,
        previewJobId: jobId,
      );
      state = state.copyWith(
        finalJob: job,
        timeline: timeline.copyWith(
          finalStatus: job.status,
          updatedAt: DateTime.now().toUtc(),
        ),
        isRequestingFinal: false,
      );
      return job;
    } catch (error) {
      state = state.copyWith(
        isRequestingFinal: false,
        lastError: _formatError(error),
      );
      return null;
    }
  }

  void undoDraft() {
    final timeline = state.timeline;
    final document = timeline?.draft;
    if (timeline == null || document == null || !canUndo) {
      return;
    }
    final current = _createSnapshot(document);
    _redoStack.add(current);
    if (_redoStack.length > _maxUndoSteps) {
      _redoStack.removeAt(0);
    }

    final snapshot = _undoStack.removeLast();
    _restoreSnapshot(snapshot, timeline.timelineId);
  }

  void redoDraft() {
    final timeline = state.timeline;
    final document = timeline?.draft;
    if (timeline == null || document == null || !canRedo) {
      return;
    }
    final current = _createSnapshot(document);
    _undoStack.add(current);
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }

    final snapshot = _redoStack.removeLast();
    _restoreSnapshot(snapshot, timeline.timelineId);
  }

  void toggleTrackMute(String trackId) {
    final document = state.activeDocument;
    if (document == null) {
      return;
    }
    _replaceTrack(
      document,
      trackId,
      (track) => track.copyWith(muted: !track.muted),
    );
  }

  void toggleTrackLock(String trackId) {
    final document = state.activeDocument;
    if (document == null) {
      return;
    }
    _replaceTrack(
      document,
      trackId,
      (track) => track.copyWith(locked: !track.locked),
    );
  }

  void selectClip(String clipId) {
    state = state.copyWith(selectedClipId: clipId, clearLastError: true);
  }

  void addTextClip() {
    final timeline = state.timeline;
    if (timeline == null) {
      return;
    }
    final document = _ensureTrack(timeline.draft, 'text');
    final track = _preferredTrack(document, 'text');
    if (track.locked) {
      state = state.copyWith(
        lastError: 'Unlock the text track before adding clips.',
      );
      return;
    }
    final fps = _fps(document);
    final duration = fps * 3;
    final startFrame = _nextStartFrame(document, duration);
    final clipId = _uniqueClipId(document, 'text');
    final clip = VideoTimelineClip(
      id: clipId,
      trackId: track.id,
      clipType: 'text',
      startFrame: startFrame,
      durationFrames: duration,
      role: 'caption',
      text: 'Nouveau texte',
      style: const {'font_size': 72, 'color': '#FFFFFF', 'align': 'center'},
      metadata: const {'created_in': 'flutter_timeline_v1'},
    );
    _replaceDraft(
      document.copyWith(clips: [...document.clips, clip]),
      selectedClipId: clipId,
    );
  }

  void addAssetClip({required String assetId, String clipType = 'image'}) {
    if (assetId.trim().isEmpty) {
      return;
    }
    final timeline = state.timeline;
    if (timeline == null) {
      return;
    }
    final normalizedType = switch (clipType) {
      'video' || 'audio' || 'music' || 'background' => clipType,
      _ => 'image',
    };
    final document = _ensureTrack(timeline.draft, normalizedType);
    final track = _preferredTrack(document, normalizedType);
    if (track.locked) {
      state = state.copyWith(
        lastError: 'Unlock the ${track.type} track before adding clips.',
      );
      return;
    }
    final fps = _fps(document);
    final duration = normalizedType == 'audio' || normalizedType == 'music'
        ? fps * 10
        : fps * 3;
    final clipId = _uniqueClipId(document, normalizedType);
    final clip = VideoTimelineClip(
      id: clipId,
      trackId: track.id,
      clipType: normalizedType,
      startFrame: _nextStartFrame(document, duration),
      durationFrames: duration,
      assetId: assetId,
      role: normalizedType,
      metadata: const {'created_in': 'flutter_timeline_v1'},
    );
    _replaceDraft(
      document.copyWith(clips: [...document.clips, clip]),
      selectedClipId: clipId,
    );
  }

  void updateSelectedClipText(String text) {
    final clip = state.selectedClip;
    if (clip == null) {
      return;
    }
    updateClipText(clip.id, text);
  }

  void updateClipText(String clipId, String text) {
    final document = state.activeDocument;
    if (document == null) {
      return;
    }
    if (_isTrackLocked(document, clipId)) {
      state = state.copyWith(lastError: 'Unlock the track to edit this clip.');
      return;
    }
    final clipped = text.trim().length > 2000
        ? text.trim().substring(0, 2000)
        : text.trim();
    _replaceClip(
      document,
      clipId,
      (clip) => clip.copyWith(text: clipped),
      selectedClipId: clipId,
    );
  }

  void moveClipFrames(String clipId, int deltaFrames) {
    final document = state.activeDocument;
    if (document == null) {
      return;
    }
    if (_isTrackLocked(document, clipId)) {
      state = state.copyWith(lastError: 'Unlock the track to move this clip.');
      return;
    }
    _replaceClip(document, clipId, (clip) {
      final maxStart = (_maxFrames(document) - clip.durationFrames).clamp(
        0,
        _maxFrames(document),
      );
      final nextStart = (clip.startFrame + deltaFrames).clamp(0, maxStart);
      return clip.copyWith(startFrame: nextStart);
    }, selectedClipId: clipId);
  }

  void resizeClipFrames(String clipId, int deltaFrames) {
    final document = state.activeDocument;
    if (document == null) {
      return;
    }
    if (_isTrackLocked(document, clipId)) {
      state = state.copyWith(
        lastError: 'Unlock the track to resize this clip.',
      );
      return;
    }
    _replaceClip(document, clipId, (clip) {
      final minDuration = (_fps(document) / 2).round().clamp(1, _fps(document));
      final maxDuration = (_maxFrames(document) - clip.startFrame).clamp(
        minDuration,
        _maxFrames(document),
      );
      final nextDuration = (clip.durationFrames + deltaFrames).clamp(
        minDuration,
        maxDuration,
      );
      return clip.copyWith(durationFrames: nextDuration);
    }, selectedClipId: clipId);
  }

  void deleteClip(String clipId) {
    final document = state.activeDocument;
    if (document == null || document.clips.length <= 1) {
      state = state.copyWith(
        lastError: 'Keep at least one clip in the timeline.',
      );
      return;
    }
    if (_isTrackLocked(document, clipId)) {
      state = state.copyWith(
        lastError: 'Unlock the track to delete this clip.',
      );
      return;
    }
    final clips = document.clips.where((clip) => clip.id != clipId).toList();
    if (clips.length == document.clips.length) {
      return;
    }
    _replaceDraft(
      document.copyWith(clips: clips),
      selectedClipId: clips.isEmpty ? null : clips.first.id,
    );
  }

  Future<void> refreshJob({required bool finalRender}) async {
    final timeline = state.timeline;
    final jobId = finalRender ? state.finalJob?.jobId : state.previewJob?.jobId;
    if (timeline == null || jobId == null || jobId.isEmpty) {
      return;
    }
    try {
      final job = await _apiService.getVideoTimelineJob(
        timelineId: timeline.timelineId,
        jobId: jobId,
      );
      state = finalRender
          ? state.copyWith(finalJob: job)
          : state.copyWith(previewJob: job);
      if (!finalRender && job.isCompleted) {
        state = state.copyWith(
          timeline: state.timeline?.copyWith(
            previewStatus: VideoTimelineStatus.completed.id,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
      if (finalRender && job.isCompleted) {
        state = state.copyWith(
          timeline: state.timeline?.copyWith(
            finalStatus: VideoTimelineStatus.completed.id,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
    } catch (_) {
      // Silent refresh failure.
    }
  }

  String _formatError(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return error.toString();
  }

  void _replaceClip(
    VideoTimelineDocument document,
    String clipId,
    VideoTimelineClip Function(VideoTimelineClip clip) update, {
    String? selectedClipId,
  }) {
    var changed = false;
    final clips = [
      for (final clip in document.clips)
        if (clip.id == clipId) ...[update(clip)] else clip,
    ];
    changed =
        clips.length == document.clips.length &&
        clips.any((clip) {
          final index = clips.indexOf(clip);
          return clip != document.clips[index];
        });
    if (!changed) {
      return;
    }
    _replaceDraft(
      document.copyWith(clips: clips),
      selectedClipId: selectedClipId,
    );
  }

  void _replaceDraft(VideoTimelineDocument document, {String? selectedClipId}) {
    final timeline = state.timeline;
    if (timeline == null) {
      return;
    }
    if (document == timeline.draft && selectedClipId == state.selectedClipId) {
      return;
    }
    _pushUndo(document: timeline.draft, selectedClipId: state.selectedClipId);
    _redoStack.clear();
    final normalizedDocument = _withDerivedVisibleDuration(document);
    state = state.copyWith(
      timeline: timeline.copyWith(
        draft: normalizedDocument,
        previewStatus: _staleStatus(timeline.previewStatus),
        finalStatus: _staleStatus(timeline.finalStatus),
        updatedAt: DateTime.now().toUtc(),
      ),
      selectedClipId: selectedClipId,
      hasUnsavedChanges: true,
      clearPreviewJob: true,
      clearFinalJob: true,
      clearLastError: true,
    );
  }

  void _replaceTrack(
    VideoTimelineDocument document,
    String trackId,
    VideoTimelineTrack Function(VideoTimelineTrack track) update,
  ) {
    var trackFound = false;
    final updatedTracks = document.tracks.map((track) {
      if (track.id == trackId) {
        trackFound = true;
        return update(track);
      }
      return track;
    }).toList();
    if (!trackFound) {
      return;
    }
    _replaceDraft(
      document.copyWith(tracks: updatedTracks),
      selectedClipId: state.selectedClipId,
    );
  }

  void _restoreSnapshot(_TimelineDraftSnapshot snapshot, String timelineId) {
    final timeline = state.timeline;
    if (timeline == null || snapshot.timelineId != timelineId) {
      return;
    }
    final normalized = _withDerivedVisibleDuration(snapshot.document);
    state = state.copyWith(
      timeline: timeline.copyWith(
        draft: normalized,
        previewStatus: _staleStatus(timeline.previewStatus),
        finalStatus: _staleStatus(timeline.finalStatus),
        updatedAt: DateTime.now().toUtc(),
      ),
      selectedClipId: snapshot.selectedClipId,
      hasUnsavedChanges: true,
      clearPreviewJob: true,
      clearFinalJob: true,
      clearLastError: true,
    );
  }

  void _pushUndo({
    required VideoTimelineDocument document,
    String? selectedClipId,
  }) {
    _undoStack.add(
      _TimelineDraftSnapshot(
        timelineId: state.timeline?.timelineId,
        document: _cloneDocument(document),
        selectedClipId: selectedClipId,
      ),
    );
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  _TimelineDraftSnapshot _createSnapshot(VideoTimelineDocument document) {
    return _TimelineDraftSnapshot(
      timelineId: state.timeline?.timelineId,
      document: _cloneDocument(document),
      selectedClipId: state.selectedClipId,
    );
  }

  VideoTimelineDocument _cloneDocument(VideoTimelineDocument document) {
    return document.copyWith(
      tracks: [
        for (final track in document.tracks)
          track.copyWith(
            exclusive: track.exclusive,
            muted: track.muted,
            locked: track.locked,
          ),
      ],
      clips: [
        for (final clip in document.clips)
          clip.copyWith(
            style: Map<String, dynamic>.from(clip.style),
            metadata: Map<String, dynamic>.from(clip.metadata),
          ),
      ],
    );
  }

  VideoTimelineDocument _ensureTrack(
    VideoTimelineDocument document,
    String clipType,
  ) {
    final trackType = _trackTypeForClipType(clipType);
    if (document.tracks.any((track) => track.type == trackType)) {
      return document;
    }
    final nextOrder = document.tracks.isEmpty
        ? 0
        : document.tracks
                  .map((track) => track.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    return document.copyWith(
      tracks: [
        ...document.tracks,
        VideoTimelineTrack(
          id: _uniqueTrackId(document, trackType),
          type: trackType,
          order: nextOrder,
          exclusive: trackType == 'visual',
        ),
      ],
    );
  }

  VideoTimelineTrack _preferredTrack(
    VideoTimelineDocument document,
    String clipType,
  ) {
    final trackType = _trackTypeForClipType(clipType);
    return document.tracks.firstWhere(
      (track) => track.type == trackType,
      orElse: () => document.tracks.isEmpty
          ? VideoTimelineTrack(
              id: 'track-$trackType-1',
              type: trackType,
              order: 0,
            )
          : document.tracks.first,
    );
  }

  int _nextStartFrame(VideoTimelineDocument document, int duration) {
    final endFrame = document.clips.fold<int>(0, (max, clip) {
      final end = clip.startFrame + clip.durationFrames;
      return end > max ? end : max;
    });
    final maxStart = (_maxFrames(document) - duration).clamp(
      0,
      _maxFrames(document),
    );
    return endFrame.clamp(0, maxStart);
  }

  String _uniqueClipId(VideoTimelineDocument document, String type) {
    final existing = document.clips.map((clip) => clip.id).toSet();
    var index = existing.length + 1;
    var id = 'clip-$type-$index';
    while (existing.contains(id)) {
      index += 1;
      id = 'clip-$type-$index';
    }
    return id;
  }

  String _uniqueTrackId(VideoTimelineDocument document, String type) {
    final existing = document.tracks.map((track) => track.id).toSet();
    var index = 1;
    var id = 'track-$type-$index';
    while (existing.contains(id)) {
      index += 1;
      id = 'track-$type-$index';
    }
    return id;
  }

  String? _firstClipId(VideoTimelineDocument document) {
    return document.clips.isEmpty ? null : document.clips.first.id;
  }

  String? _preserveSelectedClip(VideoTimelineDocument document) {
    final selected = state.selectedClipId;
    if (selected != null && document.clips.any((clip) => clip.id == selected)) {
      return selected;
    }
    return _firstClipId(document);
  }

  int _fps(VideoTimelineDocument document) {
    return document.fps <= 0 ? 30 : document.fps;
  }

  int _maxFrames(VideoTimelineDocument document) {
    return _fps(document) * _maxDurationSeconds;
  }

  VideoTimelineDocument _withDerivedVisibleDuration(
    VideoTimelineDocument document,
  ) {
    var visibleEndFrame = 0;
    for (final clip in document.clips) {
      if (!_isVisibleClipType(clip.clipType)) {
        continue;
      }
      final endFrame = clip.startFrame + clip.durationFrames;
      if (endFrame > visibleEndFrame) {
        visibleEndFrame = endFrame;
      }
    }
    if (visibleEndFrame <= 0) {
      return document;
    }
    return document.copyWith(
      durationFrames: visibleEndFrame.clamp(1, _maxFrames(document)).toInt(),
    );
  }

  String _staleStatus(String current) {
    return current == VideoTimelineStatus.missing.id
        ? VideoTimelineStatus.missing.id
        : VideoTimelineStatus.stale.id;
  }

  String _trackTypeForClipType(String clipType) {
    return switch (clipType) {
      'audio' || 'music' => 'audio',
      'text' => 'overlay',
      _ => 'visual',
    };
  }

  bool _isVisibleClipType(String clipType) {
    return switch (clipType) {
      'text' || 'image' || 'video' || 'background' => true,
      _ => false,
    };
  }

  VideoTimelineTrack? _trackForClip(
    VideoTimelineDocument document,
    String clipId,
  ) {
    final clip = document.clips.firstWhere(
      (candidate) => candidate.id == clipId,
      orElse: () => const VideoTimelineClip(
        id: '',
        trackId: '',
        clipType: '',
        startFrame: 0,
        durationFrames: 1,
      ),
    );
    if (clip.id.isEmpty) {
      return null;
    }
    return document.tracks.firstWhere(
      (track) => track.id == clip.trackId,
      orElse: () => const VideoTimelineTrack(id: '', type: '', order: 0),
    );
  }

  bool _isTrackLocked(VideoTimelineDocument document, String clipId) {
    final track = _trackForClip(document, clipId);
    return track != null && track.id.isNotEmpty && track.locked;
  }
}

class _TimelineDraftSnapshot {
  const _TimelineDraftSnapshot({
    this.timelineId,
    required this.document,
    this.selectedClipId,
  });

  final String? timelineId;
  final VideoTimelineDocument document;
  final String? selectedClipId;
}

final videoTimelineProvider = StateNotifierProvider.autoDispose
    .family<VideoTimelineController, VideoTimelineState, String>((
      ref,
      contentId,
    ) {
      return VideoTimelineController(
        apiService: ref.read(apiServiceProvider),
        contentId: contentId,
      );
    });
