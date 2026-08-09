enum VideoTimelineFormatPreset { vertical9x16, landscape16x9, unknown }

extension VideoTimelineFormatPresetX on VideoTimelineFormatPreset {
  String get id {
    return switch (this) {
      VideoTimelineFormatPreset.vertical9x16 => 'vertical_9_16',
      VideoTimelineFormatPreset.landscape16x9 => 'landscape_16_9',
      VideoTimelineFormatPreset.unknown => 'unknown',
    };
  }
}

VideoTimelineFormatPreset parseVideoTimelineFormatPreset(String? value) {
  return switch (value?.trim()) {
    'vertical_9_16' => VideoTimelineFormatPreset.vertical9x16,
    'landscape_16_9' => VideoTimelineFormatPreset.landscape16x9,
    _ => VideoTimelineFormatPreset.unknown,
  };
}

class VideoTimelinePreset {
  const VideoTimelinePreset({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.fps,
  });

  final String id;
  final String label;
  final int width;
  final int height;
  final int fps;
}

const List<VideoTimelinePreset> kVideoTimelinePresets = <VideoTimelinePreset>[
  VideoTimelinePreset(
    id: 'vertical_9_16',
    label: 'Vertical 9:16',
    width: 1080,
    height: 1920,
    fps: 30,
  ),
  VideoTimelinePreset(
    id: 'landscape_16_9',
    label: 'Landscape 16:9',
    width: 1920,
    height: 1080,
    fps: 30,
  ),
];

enum VideoTimelineStatus {
  missing,
  queued,
  inProgress,
  completed,
  failed,
  cancelled,
  stale,
  unknown,
}

extension VideoTimelineStatusX on VideoTimelineStatus {
  String get id {
    return switch (this) {
      VideoTimelineStatus.missing => 'missing',
      VideoTimelineStatus.queued => 'queued',
      VideoTimelineStatus.inProgress => 'in_progress',
      VideoTimelineStatus.completed => 'completed',
      VideoTimelineStatus.failed => 'failed',
      VideoTimelineStatus.cancelled => 'cancelled',
      VideoTimelineStatus.stale => 'stale',
      VideoTimelineStatus.unknown => 'unknown',
    };
  }
}

VideoTimelineStatus parseVideoTimelineStatus(String? value) {
  return switch (value?.trim()) {
    'missing' => VideoTimelineStatus.missing,
    'queued' => VideoTimelineStatus.queued,
    'in_progress' => VideoTimelineStatus.inProgress,
    'completed' => VideoTimelineStatus.completed,
    'failed' => VideoTimelineStatus.failed,
    'cancelled' => VideoTimelineStatus.cancelled,
    'stale' => VideoTimelineStatus.stale,
    _ => VideoTimelineStatus.unknown,
  };
}

class TimelineErrorDetail {
  const TimelineErrorDetail({
    required this.code,
    required this.message,
    this.field,
    this.retryAfterSeconds,
  });

  final String code;
  final String message;
  final String? field;
  final int? retryAfterSeconds;

  factory TimelineErrorDetail.fromJson(Map<String, dynamic> json) {
    return TimelineErrorDetail(
      code: _asString(json['code']),
      message: _asString(json['message']),
      field: _asStringOrNull(json['field']),
      retryAfterSeconds: _asIntOrNull(
        json['retry_after_seconds'] ?? json['retryAfterSeconds'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'field': field,
      'retry_after_seconds': retryAfterSeconds,
    };
  }
}

class VideoTimelineTrack {
  const VideoTimelineTrack({
    required this.id,
    required this.type,
    required this.order,
    this.exclusive = true,
    this.muted = false,
    this.locked = false,
  });

  final String id;
  final String type;
  final int order;
  final bool exclusive;
  final bool muted;
  final bool locked;

  factory VideoTimelineTrack.fromJson(Map<String, dynamic> json) {
    return VideoTimelineTrack(
      id: _asString(json['id']),
      type: _asString(json['type']),
      order: _asInt(json['order']),
      exclusive: _asBool(json['exclusive'], fallback: true),
      muted: _asBool(json['muted'], fallback: false),
      locked: _asBool(json['locked'], fallback: false),
    );
  }

  VideoTimelineTrack copyWith({
    String? id,
    String? type,
    int? order,
    bool? exclusive,
    bool? muted,
    bool? locked,
  }) {
    return VideoTimelineTrack(
      id: id ?? this.id,
      type: type ?? this.type,
      order: order ?? this.order,
      exclusive: exclusive ?? this.exclusive,
      muted: muted ?? this.muted,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'order': order,
      'exclusive': exclusive,
      'muted': muted,
      'locked': locked,
    };
  }
}

class VideoTimelineClip {
  const VideoTimelineClip({
    required this.id,
    required this.trackId,
    required this.clipType,
    required this.startFrame,
    required this.durationFrames,
    this.assetId,
    this.trimStartFrame = 0,
    this.role,
    this.text,
    this.volume,
    this.style = const <String, dynamic>{},
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String trackId;
  final String clipType;
  final int startFrame;
  final int durationFrames;
  final String? assetId;
  final int trimStartFrame;
  final String? role;
  final String? text;
  final double? volume;
  final Map<String, dynamic> style;
  final Map<String, dynamic> metadata;

  factory VideoTimelineClip.fromJson(Map<String, dynamic> json) {
    return VideoTimelineClip(
      id: _asString(json['id']),
      trackId: _asString(json['track_id'] ?? json['trackId']),
      clipType: _asString(json['clip_type'] ?? json['clipType']),
      startFrame: _asInt(json['start_frame'] ?? json['startFrame']),
      durationFrames: _asInt(json['duration_frames'] ?? json['durationFrames']),
      assetId: _asStringOrNull(json['asset_id'] ?? json['assetId']),
      trimStartFrame:
          _asIntOrNull(json['trim_start_frame'] ?? json['trimStartFrame']) ?? 0,
      role: _asStringOrNull(json['role']),
      text: _asStringOrNull(json['text']),
      volume: _asDoubleOrNull(json['volume']),
      style: _asMap(json['style']),
      metadata: _asMap(json['metadata']),
    );
  }

  VideoTimelineClip copyWith({
    String? id,
    String? trackId,
    String? clipType,
    int? startFrame,
    int? durationFrames,
    String? assetId,
    bool clearAssetId = false,
    int? trimStartFrame,
    String? role,
    String? text,
    bool clearText = false,
    double? volume,
    bool clearVolume = false,
    Map<String, dynamic>? style,
    Map<String, dynamic>? metadata,
  }) {
    return VideoTimelineClip(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      clipType: clipType ?? this.clipType,
      startFrame: startFrame ?? this.startFrame,
      durationFrames: durationFrames ?? this.durationFrames,
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
      trimStartFrame: trimStartFrame ?? this.trimStartFrame,
      role: role ?? this.role,
      text: clearText ? null : (text ?? this.text),
      volume: clearVolume ? null : (volume ?? this.volume),
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'track_id': trackId,
      'clip_type': clipType,
      'start_frame': startFrame,
      'duration_frames': durationFrames,
      'asset_id': assetId,
      'trim_start_frame': trimStartFrame,
      'role': role,
      'text': text,
      'volume': volume,
      'style': style,
      'metadata': metadata,
    };
  }
}

class VideoTimelineDocument {
  const VideoTimelineDocument({
    this.schemaVersion = '1.0',
    this.formatPreset = 'vertical_9_16',
    this.fps = 30,
    this.durationFrames,
    this.tracks = const <VideoTimelineTrack>[],
    this.clips = const <VideoTimelineClip>[],
  });

  final String schemaVersion;
  final String formatPreset;
  final int fps;
  final int? durationFrames;
  final List<VideoTimelineTrack> tracks;
  final List<VideoTimelineClip> clips;

  VideoTimelineFormatPreset get resolvedFormatPreset =>
      parseVideoTimelineFormatPreset(formatPreset);

  factory VideoTimelineDocument.fromJson(Map<String, dynamic> json) {
    return VideoTimelineDocument(
      schemaVersion:
          _asStringOrNull(json['schema_version'] ?? json['schemaVersion']) ??
          '1.0',
      formatPreset:
          _asStringOrNull(json['format_preset'] ?? json['formatPreset']) ??
          'vertical_9_16',
      fps: _asIntOrNull(json['fps']) ?? 30,
      durationFrames: _asIntOrNull(
        json['duration_frames'] ?? json['durationFrames'],
      ),
      tracks: _asList(json['tracks']).map(VideoTimelineTrack.fromJson).toList(),
      clips: _asList(json['clips']).map(VideoTimelineClip.fromJson).toList(),
    );
  }

  VideoTimelineDocument copyWith({
    String? schemaVersion,
    String? formatPreset,
    int? fps,
    int? durationFrames,
    bool clearDurationFrames = false,
    List<VideoTimelineTrack>? tracks,
    List<VideoTimelineClip>? clips,
  }) {
    return VideoTimelineDocument(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      formatPreset: formatPreset ?? this.formatPreset,
      fps: fps ?? this.fps,
      durationFrames: clearDurationFrames
          ? null
          : (durationFrames ?? this.durationFrames),
      tracks: tracks ?? this.tracks,
      clips: clips ?? this.clips,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'format_preset': formatPreset,
      'fps': fps,
      'duration_frames': durationFrames,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'clips': clips.map((clip) => clip.toJson()).toList(),
    };
  }
}

class VideoTimelineValidationResult {
  const VideoTimelineValidationResult({
    required this.valid,
    this.errors = const <TimelineErrorDetail>[],
  });

  final bool valid;
  final List<TimelineErrorDetail> errors;

  factory VideoTimelineValidationResult.fromJson(Map<String, dynamic> json) {
    return VideoTimelineValidationResult(
      valid: _asBool(json['valid'], fallback: false),
      errors: _asList(
        json['errors'],
      ).map(TimelineErrorDetail.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'valid': valid,
      'errors': errors.map((error) => error.toJson()).toList(),
    };
  }
}

class VideoTimelineArtifact {
  const VideoTimelineArtifact({
    required this.playbackUrl,
    required this.artifactExpiresAt,
    required this.retentionExpiresAt,
    required this.deletionWarningAt,
    required this.byteSize,
    required this.mimeType,
    required this.fileName,
    required this.renderMode,
  });

  final String playbackUrl;
  final DateTime artifactExpiresAt;
  final DateTime retentionExpiresAt;
  final DateTime deletionWarningAt;
  final int byteSize;
  final String mimeType;
  final String fileName;
  final String renderMode;

  factory VideoTimelineArtifact.fromJson(Map<String, dynamic> json) {
    return VideoTimelineArtifact(
      playbackUrl: _asString(json['playback_url'] ?? json['playbackUrl']),
      artifactExpiresAt: _asDateTime(
        json['artifact_expires_at'] ?? json['artifactExpiresAt'],
      ),
      retentionExpiresAt: _asDateTime(
        json['retention_expires_at'] ?? json['retentionExpiresAt'],
      ),
      deletionWarningAt: _asDateTime(
        json['deletion_warning_at'] ?? json['deletionWarningAt'],
      ),
      byteSize: _asInt(json['byte_size'] ?? json['byteSize']),
      mimeType: _asString(json['mime_type'] ?? json['mimeType']),
      fileName: _asString(json['file_name'] ?? json['fileName']),
      renderMode: _asString(json['render_mode'] ?? json['renderMode']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playback_url': playbackUrl,
      'artifact_expires_at': artifactExpiresAt.toUtc().toIso8601String(),
      'retention_expires_at': retentionExpiresAt.toUtc().toIso8601String(),
      'deletion_warning_at': deletionWarningAt.toUtc().toIso8601String(),
      'byte_size': byteSize,
      'mime_type': mimeType,
      'file_name': fileName,
      'render_mode': renderMode,
    };
  }
}

class VideoTimelineRenderJob {
  const VideoTimelineRenderJob({
    required this.jobId,
    required this.timelineId,
    required this.versionId,
    required this.renderMode,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.message,
    this.artifact,
    this.stale = false,
  });

  final String jobId;
  final String timelineId;
  final String versionId;
  final String renderMode;
  final String status;
  final int progress;
  final String? message;
  final VideoTimelineArtifact? artifact;
  final bool stale;
  final DateTime createdAt;
  final DateTime updatedAt;

  VideoTimelineStatus get resolvedStatus => parseVideoTimelineStatus(status);
  bool get isActive => status == 'queued' || status == 'in_progress';
  bool get isCompleted => status == 'completed';

  factory VideoTimelineRenderJob.fromJson(Map<String, dynamic> json) {
    return VideoTimelineRenderJob(
      jobId: _asString(json['job_id'] ?? json['jobId']),
      timelineId: _asString(json['timeline_id'] ?? json['timelineId']),
      versionId: _asString(json['version_id'] ?? json['versionId']),
      renderMode: _asString(json['render_mode'] ?? json['renderMode']),
      status: _asString(json['status']),
      progress: _asIntOrNull(json['progress']) ?? 0,
      message: _asStringOrNull(json['message']),
      artifact: _asMapOrNull(json['artifact']) == null
          ? null
          : VideoTimelineArtifact.fromJson(_asMap(json['artifact'])),
      stale: _asBool(json['stale'], fallback: false),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  VideoTimelineRenderJob copyWith({
    String? jobId,
    String? timelineId,
    String? versionId,
    String? renderMode,
    String? status,
    int? progress,
    String? message,
    bool clearMessage = false,
    VideoTimelineArtifact? artifact,
    bool clearArtifact = false,
    bool? stale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoTimelineRenderJob(
      jobId: jobId ?? this.jobId,
      timelineId: timelineId ?? this.timelineId,
      versionId: versionId ?? this.versionId,
      renderMode: renderMode ?? this.renderMode,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: clearMessage ? null : (message ?? this.message),
      artifact: clearArtifact ? null : (artifact ?? this.artifact),
      stale: stale ?? this.stale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'timeline_id': timelineId,
      'version_id': versionId,
      'render_mode': renderMode,
      'status': status,
      'progress': progress,
      'message': message,
      'artifact': artifact?.toJson(),
      'stale': stale,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class VideoTimelineVersion {
  const VideoTimelineVersion({
    required this.versionId,
    required this.timelineId,
    required this.versionNumber,
    required this.timeline,
    required this.rendererProps,
    required this.createdAt,
    this.approvedPreviewJobId,
    this.previewApprovedAt,
  });

  final String versionId;
  final String timelineId;
  final int versionNumber;
  final VideoTimelineDocument timeline;
  final Map<String, dynamic> rendererProps;
  final String? approvedPreviewJobId;
  final DateTime? previewApprovedAt;
  final DateTime createdAt;

  factory VideoTimelineVersion.fromJson(Map<String, dynamic> json) {
    return VideoTimelineVersion(
      versionId: _asString(json['version_id'] ?? json['versionId']),
      timelineId: _asString(json['timeline_id'] ?? json['timelineId']),
      versionNumber: _asInt(json['version_number'] ?? json['versionNumber']),
      timeline: VideoTimelineDocument.fromJson(_asMap(json['timeline'])),
      rendererProps: _asMap(json['renderer_props'] ?? json['rendererProps']),
      approvedPreviewJobId: _asStringOrNull(
        json['approved_preview_job_id'] ?? json['approvedPreviewJobId'],
      ),
      previewApprovedAt: _asDateTimeOrNull(
        json['preview_approved_at'] ?? json['previewApprovedAt'],
      ),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  VideoTimelineVersion copyWith({
    String? versionId,
    String? timelineId,
    int? versionNumber,
    VideoTimelineDocument? timeline,
    Map<String, dynamic>? rendererProps,
    String? approvedPreviewJobId,
    bool clearApprovedPreviewJobId = false,
    DateTime? previewApprovedAt,
    bool clearPreviewApprovedAt = false,
    DateTime? createdAt,
  }) {
    return VideoTimelineVersion(
      versionId: versionId ?? this.versionId,
      timelineId: timelineId ?? this.timelineId,
      versionNumber: versionNumber ?? this.versionNumber,
      timeline: timeline ?? this.timeline,
      rendererProps: rendererProps ?? this.rendererProps,
      approvedPreviewJobId: clearApprovedPreviewJobId
          ? null
          : (approvedPreviewJobId ?? this.approvedPreviewJobId),
      previewApprovedAt: clearPreviewApprovedAt
          ? null
          : (previewApprovedAt ?? this.previewApprovedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_id': versionId,
      'timeline_id': timelineId,
      'version_number': versionNumber,
      'timeline': timeline.toJson(),
      'renderer_props': rendererProps,
      'approved_preview_job_id': approvedPreviewJobId,
      'preview_approved_at': previewApprovedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class VideoTimelineDraftResponse {
  const VideoTimelineDraftResponse({
    required this.timelineId,
    required this.draftRevision,
    required this.timeline,
    required this.validation,
    required this.previewStatus,
    this.latestVersionId,
  });

  final String timelineId;
  final int draftRevision;
  final String? latestVersionId;
  final VideoTimelineDocument timeline;
  final VideoTimelineValidationResult validation;
  final String previewStatus;

  VideoTimelineStatus get resolvedPreviewStatus =>
      parseVideoTimelineStatus(previewStatus);

  factory VideoTimelineDraftResponse.fromJson(Map<String, dynamic> json) {
    return VideoTimelineDraftResponse(
      timelineId: _asString(json['timeline_id'] ?? json['timelineId']),
      draftRevision: _asInt(json['draft_revision'] ?? json['draftRevision']),
      latestVersionId: _asStringOrNull(
        json['latest_version_id'] ?? json['latestVersionId'],
      ),
      timeline: VideoTimelineDocument.fromJson(_asMap(json['timeline'])),
      validation: VideoTimelineValidationResult.fromJson(
        _asMap(json['validation']),
      ),
      previewStatus: _asString(json['preview_status'] ?? json['previewStatus']),
    );
  }
}

class VideoTimelineResponse {
  const VideoTimelineResponse({
    required this.timelineId,
    required this.contentId,
    required this.projectId,
    required this.userId,
    required this.formatPreset,
    required this.draftRevision,
    required this.draft,
    required this.previewStatus,
    required this.finalStatus,
    required this.createdAt,
    required this.updatedAt,
    this.currentVersionId,
    this.latestVersion,
  });

  final String timelineId;
  final String contentId;
  final String projectId;
  final String userId;
  final String formatPreset;
  final String? currentVersionId;
  final int draftRevision;
  final VideoTimelineDocument draft;
  final VideoTimelineVersion? latestVersion;
  final String previewStatus;
  final String finalStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  VideoTimelineStatus get resolvedPreviewStatus =>
      parseVideoTimelineStatus(previewStatus);
  VideoTimelineStatus get resolvedFinalStatus =>
      parseVideoTimelineStatus(finalStatus);

  factory VideoTimelineResponse.fromJson(Map<String, dynamic> json) {
    return VideoTimelineResponse(
      timelineId: _asString(json['timeline_id'] ?? json['timelineId']),
      contentId: _asString(json['content_id'] ?? json['contentId']),
      projectId: _asString(json['project_id'] ?? json['projectId']),
      userId: _asString(json['user_id'] ?? json['userId']),
      formatPreset:
          _asStringOrNull(json['format_preset'] ?? json['formatPreset']) ??
          'vertical_9_16',
      currentVersionId: _asStringOrNull(
        json['current_version_id'] ?? json['currentVersionId'],
      ),
      draftRevision: _asInt(json['draft_revision'] ?? json['draftRevision']),
      draft: VideoTimelineDocument.fromJson(_asMap(json['draft'])),
      latestVersion:
          _asMapOrNull(json['latest_version'] ?? json['latestVersion']) == null
          ? null
          : VideoTimelineVersion.fromJson(
              _asMap(json['latest_version'] ?? json['latestVersion']),
            ),
      previewStatus:
          _asStringOrNull(json['preview_status'] ?? json['previewStatus']) ??
          'missing',
      finalStatus:
          _asStringOrNull(json['final_status'] ?? json['finalStatus']) ??
          'missing',
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  VideoTimelineResponse copyWith({
    String? timelineId,
    String? contentId,
    String? projectId,
    String? userId,
    String? formatPreset,
    String? currentVersionId,
    bool clearCurrentVersionId = false,
    int? draftRevision,
    VideoTimelineDocument? draft,
    VideoTimelineVersion? latestVersion,
    bool clearLatestVersion = false,
    String? previewStatus,
    String? finalStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoTimelineResponse(
      timelineId: timelineId ?? this.timelineId,
      contentId: contentId ?? this.contentId,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      formatPreset: formatPreset ?? this.formatPreset,
      currentVersionId: clearCurrentVersionId
          ? null
          : (currentVersionId ?? this.currentVersionId),
      draftRevision: draftRevision ?? this.draftRevision,
      draft: draft ?? this.draft,
      latestVersion: clearLatestVersion
          ? null
          : (latestVersion ?? this.latestVersion),
      previewStatus: previewStatus ?? this.previewStatus,
      finalStatus: finalStatus ?? this.finalStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BrandedVideoGenerationResponse {
  const BrandedVideoGenerationResponse({
    this.brandProfileId,
    this.brandTemplateId,
    this.brandTemplateRevision,
    required this.timeline,
    required this.version,
    required this.previewJob,
    required this.readiness,
    required this.blockers,
  });

  final String? brandProfileId;
  final String? brandTemplateId;
  final int? brandTemplateRevision;
  final VideoTimelineResponse timeline;
  final VideoTimelineVersion version;
  final VideoTimelineRenderJob previewJob;
  final String readiness;
  final List<String> blockers;

  factory BrandedVideoGenerationResponse.fromJson(Map<String, dynamic> json) {
    return BrandedVideoGenerationResponse(
      brandProfileId: _asStringOrNull(
        json['brand_profile_id'] ?? json['brandProfileId'],
      ),
      brandTemplateId: _asStringOrNull(
        json['brand_template_id'] ?? json['brandTemplateId'],
      ),
      brandTemplateRevision: _asIntOrNull(
        json['brand_template_revision'] ?? json['brandTemplateRevision'],
      ),
      timeline: VideoTimelineResponse.fromJson(_asMap(json['timeline'])),
      version: VideoTimelineVersion.fromJson(_asMap(json['version'])),
      previewJob: VideoTimelineRenderJob.fromJson(
        _asMap(json['preview_job'] ?? json['previewJob']),
      ),
      readiness: _asString(json['readiness']),
      blockers: _asStringList(json['blockers']),
    );
  }
}

class VideoTimelineSwipePublishResponse {
  const VideoTimelineSwipePublishResponse({
    required this.state,
    required this.version,
    required this.finalJob,
    required this.publishResult,
    required this.blockers,
  });

  final String state;
  final VideoTimelineVersion version;
  final VideoTimelineRenderJob? finalJob;
  final Map<String, dynamic>? publishResult;
  final List<String> blockers;

  factory VideoTimelineSwipePublishResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return VideoTimelineSwipePublishResponse(
      state: _asString(json['state']),
      version: VideoTimelineVersion.fromJson(_asMap(json['version'])),
      finalJob: _asMapOrNull(json['final_job'] ?? json['finalJob']) == null
          ? null
          : VideoTimelineRenderJob.fromJson(
              _asMap(json['final_job'] ?? json['finalJob']),
            ),
      publishResult: _asMapOrNull(
        json['publish_result'] ?? json['publishResult'],
      ),
      blockers: _asStringList(json['blockers']),
    );
  }
}

String _asString(Object? value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

String? _asStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _asIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _asDoubleOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry('$key', item));
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? _asMapOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final map = _asMap(value);
  return map.isEmpty ? null : map;
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.map(_asMap).toList();
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

DateTime _asDateTime(Object? value) {
  final parsed = _asDateTimeOrNull(value);
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _asDateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
