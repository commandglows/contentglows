class ProjectAsset {
  const ProjectAsset({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.mediaKind,
    required this.source,
    required this.status,
    required this.metadata,
    required this.storageDescriptor,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAssetId,
    this.contentAssetId,
    this.mimeType,
    this.fileName,
    this.originalFileName,
    this.categoryId,
    this.subcategoryId,
    this.suggestedExportFileName,
    this.storageUri,
    this.tombstonedAt,
    this.cleanupEligibleAt,
  });

  final String id;
  final String projectId;
  final String userId;
  final String? sourceAssetId;
  final String? contentAssetId;
  final String mediaKind;
  final String source;
  final String? mimeType;
  final String? fileName;
  final String? originalFileName;
  final String? categoryId;
  final String? subcategoryId;
  final String? suggestedExportFileName;
  final String? storageUri;
  final Map<String, dynamic> storageDescriptor;
  final String status;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? tombstonedAt;
  final DateTime? cleanupEligibleAt;

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    return ProjectAsset(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      sourceAssetId: _asStringOrNull(
        json['sourceAssetId'] ?? json['source_asset_id'],
      ),
      contentAssetId: _asStringOrNull(
        json['contentAssetId'] ?? json['content_asset_id'],
      ),
      mediaKind: (json['mediaKind'] ?? json['media_kind'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      mimeType: _asStringOrNull(json['mimeType'] ?? json['mime_type']),
      fileName: _asStringOrNull(json['fileName'] ?? json['file_name']),
      originalFileName: _asStringOrNull(
        json['originalFileName'] ?? json['original_file_name'],
      ),
      categoryId: _asStringOrNull(json['categoryId'] ?? json['category_id']),
      subcategoryId: _asStringOrNull(
        json['subcategoryId'] ?? json['subcategory_id'],
      ),
      suggestedExportFileName: _asStringOrNull(
        json['suggestedExportFileName'] ?? json['suggested_export_file_name'],
      ),
      storageUri: _asStringOrNull(json['storageUri'] ?? json['storage_uri']),
      storageDescriptor: _asMap(
        json['storageDescriptor'] ?? json['storage_descriptor'],
      ),
      status: (json['status'] ?? '').toString(),
      metadata: _asMap(json['metadata']),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
      tombstonedAt: _asDateTimeOrNull(
        json['tombstonedAt'] ?? json['tombstoned_at'],
      ),
      cleanupEligibleAt: _asDateTimeOrNull(
        json['cleanupEligibleAt'] ?? json['cleanup_eligible_at'],
      ),
    );
  }
}

class ProjectAssetUsage {
  const ProjectAssetUsage({
    required this.id,
    required this.assetId,
    required this.projectId,
    required this.userId,
    required this.targetType,
    required this.targetId,
    required this.usageAction,
    required this.isPrimary,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.placement,
    this.deletedAt,
  });

  final String id;
  final String assetId;
  final String projectId;
  final String userId;
  final String targetType;
  final String targetId;
  final String? placement;
  final String usageAction;
  final bool isPrimary;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  factory ProjectAssetUsage.fromJson(Map<String, dynamic> json) {
    return ProjectAssetUsage(
      id: (json['id'] ?? '').toString(),
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      targetType: (json['targetType'] ?? json['target_type'] ?? '').toString(),
      targetId: (json['targetId'] ?? json['target_id'] ?? '').toString(),
      placement: _asStringOrNull(json['placement']),
      usageAction: (json['usageAction'] ?? json['usage_action'] ?? '')
          .toString(),
      isPrimary: _asBool(json['isPrimary'] ?? json['is_primary']) ?? false,
      metadata: _asMap(json['metadata']),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
      deletedAt: _asDateTimeOrNull(json['deletedAt'] ?? json['deleted_at']),
    );
  }
}

class ProjectAssetEvent {
  const ProjectAssetEvent({
    required this.id,
    required this.assetId,
    required this.projectId,
    required this.userId,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
    this.targetType,
    this.targetId,
    this.placement,
  });

  final String id;
  final String assetId;
  final String projectId;
  final String userId;
  final String eventType;
  final String? targetType;
  final String? targetId;
  final String? placement;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory ProjectAssetEvent.fromJson(Map<String, dynamic> json) {
    return ProjectAssetEvent(
      id: (json['id'] ?? '').toString(),
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['event_type'] ?? '').toString(),
      targetType: _asStringOrNull(json['targetType'] ?? json['target_type']),
      targetId: _asStringOrNull(json['targetId'] ?? json['target_id']),
      placement: _asStringOrNull(json['placement']),
      metadata: _asMap(json['metadata']),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}

class ProjectAssetEligibility {
  const ProjectAssetEligibility({
    required this.assetId,
    required this.usageAction,
    required this.eligible,
    this.targetType,
    this.targetId,
    this.reason,
  });

  final String assetId;
  final String usageAction;
  final String? targetType;
  final String? targetId;
  final bool eligible;
  final String? reason;

  factory ProjectAssetEligibility.fromJson(Map<String, dynamic> json) {
    return ProjectAssetEligibility(
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      usageAction: (json['usageAction'] ?? json['usage_action'] ?? '')
          .toString(),
      targetType: _asStringOrNull(json['targetType'] ?? json['target_type']),
      targetId: _asStringOrNull(json['targetId'] ?? json['target_id']),
      eligible: _asBool(json['eligible']) ?? false,
      reason: _asStringOrNull(json['reason']),
    );
  }
}

class ProjectAssetCleanupItem {
  const ProjectAssetCleanupItem({
    required this.assetId,
    required this.mediaKind,
    required this.status,
    this.cleanupEligibleAt,
    this.reason,
  });

  final String assetId;
  final String mediaKind;
  final String status;
  final DateTime? cleanupEligibleAt;
  final String? reason;

  factory ProjectAssetCleanupItem.fromJson(Map<String, dynamic> json) {
    return ProjectAssetCleanupItem(
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      mediaKind: (json['mediaKind'] ?? json['media_kind'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      cleanupEligibleAt: _asDateTimeOrNull(
        json['cleanupEligibleAt'] ?? json['cleanup_eligible_at'],
      ),
      reason: _asStringOrNull(json['reason']),
    );
  }
}

class ProjectAssetCleanupReport {
  const ProjectAssetCleanupReport({
    required this.cleanupEligible,
    required this.degraded,
    required this.missingStorage,
    required this.physicalDeleteAllowed,
  });

  final List<ProjectAssetCleanupItem> cleanupEligible;
  final List<ProjectAssetCleanupItem> degraded;
  final List<ProjectAssetCleanupItem> missingStorage;
  final bool physicalDeleteAllowed;

  factory ProjectAssetCleanupReport.fromJson(Map<String, dynamic> json) {
    return ProjectAssetCleanupReport(
      cleanupEligible: _asList(
        json['cleanupEligible'] ?? json['cleanup_eligible'],
      ).map(ProjectAssetCleanupItem.fromJson).toList(),
      degraded: _asList(
        json['degraded'],
      ).map(ProjectAssetCleanupItem.fromJson).toList(),
      missingStorage: _asList(
        json['missingStorage'] ?? json['missing_storage'],
      ).map(ProjectAssetCleanupItem.fromJson).toList(),
      physicalDeleteAllowed:
          _asBool(
            json['physicalDeleteAllowed'] ?? json['physical_delete_allowed'],
          ) ??
          false,
    );
  }
}

class ProjectAssetListResponse {
  const ProjectAssetListResponse({required this.items, required this.total});

  final List<ProjectAsset> items;
  final int total;

  factory ProjectAssetListResponse.fromJson(Map<String, dynamic> json) {
    return ProjectAssetListResponse(
      items: _asList(json['items']).map(ProjectAsset.fromJson).toList(),
      total: _asInt(json['total']) ?? 0,
    );
  }
}

class ProjectAssetSubcategory {
  const ProjectAssetSubcategory({
    required this.subcategoryId,
    required this.label,
  });

  final String subcategoryId;
  final String label;

  factory ProjectAssetSubcategory.fromJson(Map<String, dynamic> json) {
    return ProjectAssetSubcategory(
      subcategoryId: (json['subcategoryId'] ?? json['subcategory_id'] ?? '')
          .toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class ProjectAssetCategory {
  const ProjectAssetCategory({
    required this.categoryId,
    required this.label,
    this.subcategories = const <ProjectAssetSubcategory>[],
  });

  final String categoryId;
  final String label;
  final List<ProjectAssetSubcategory> subcategories;

  factory ProjectAssetCategory.fromJson(Map<String, dynamic> json) {
    return ProjectAssetCategory(
      categoryId: (json['categoryId'] ?? json['category_id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      subcategories: _asList(
        json['subcategories'],
      ).map(ProjectAssetSubcategory.fromJson).toList(),
    );
  }

  ProjectAssetSubcategory? subcategoryById(String? subcategoryId) {
    if (subcategoryId == null) {
      return null;
    }
    for (final subcategory in subcategories) {
      if (subcategory.subcategoryId == subcategoryId) {
        return subcategory;
      }
    }
    return null;
  }
}

class ProjectAssetCategoryCatalog {
  const ProjectAssetCategoryCatalog({
    required this.version,
    required this.locale,
    required this.supportedLocales,
    required this.categories,
  });

  final String version;
  final String locale;
  final List<String> supportedLocales;
  final List<ProjectAssetCategory> categories;

  factory ProjectAssetCategoryCatalog.fromJson(Map<String, dynamic> json) {
    return ProjectAssetCategoryCatalog(
      version: (json['version'] ?? '').toString(),
      locale: (json['locale'] ?? '').toString(),
      supportedLocales: _asList(
        json['supportedLocales'] ?? json['supported_locales'],
      ).map((item) => item.toString()).toList(),
      categories: _asList(
        json['categories'],
      ).map(ProjectAssetCategory.fromJson).toList(),
    );
  }

  ProjectAssetCategory? categoryById(String? categoryId) {
    if (categoryId == null) {
      return null;
    }
    for (final category in categories) {
      if (category.categoryId == categoryId) {
        return category;
      }
    }
    return null;
  }
}

class AssetSemanticTag {
  const AssetSemanticTag({
    required this.key,
    required this.label,
    required this.confidence,
    required this.source,
    required this.acceptedByUser,
    required this.rejectedByUser,
  });

  final String key;
  final String label;
  final double confidence;
  final String source;
  final bool acceptedByUser;
  final bool rejectedByUser;

  factory AssetSemanticTag.fromJson(Map<String, dynamic> json) {
    return AssetSemanticTag(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      confidence: _asDouble(json['confidence']) ?? 0,
      source: (json['source'] ?? 'ai_suggestion').toString(),
      acceptedByUser:
          _asBool(json['acceptedByUser'] ?? json['accepted_by_user']) ?? false,
      rejectedByUser:
          _asBool(json['rejectedByUser'] ?? json['rejected_by_user']) ?? false,
    );
  }
}

class AssetSceneSegment {
  const AssetSceneSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.label,
    required this.confidence,
    this.suggestedPlacement,
  });

  final double startSeconds;
  final double endSeconds;
  final String label;
  final double confidence;
  final String? suggestedPlacement;

  factory AssetSceneSegment.fromJson(Map<String, dynamic> json) {
    return AssetSceneSegment(
      startSeconds:
          _asDouble(json['startSeconds'] ?? json['start_seconds']) ?? 0,
      endSeconds: _asDouble(json['endSeconds'] ?? json['end_seconds']) ?? 0,
      label: (json['label'] ?? '').toString(),
      confidence: _asDouble(json['confidence']) ?? 0,
      suggestedPlacement: _asStringOrNull(
        json['suggestedPlacement'] ?? json['suggested_placement'],
      ),
    );
  }
}

class AssetSourceAttribution {
  const AssetSourceAttribution({
    this.sourcePlatform,
    this.sourceUrl,
    this.creatorHandle,
    this.creatorName,
    this.creditText,
    required this.rightsStatus,
    required this.creditRequired,
  });

  final String? sourcePlatform;
  final String? sourceUrl;
  final String? creatorHandle;
  final String? creatorName;
  final String? creditText;
  final String rightsStatus;
  final bool creditRequired;

  factory AssetSourceAttribution.fromJson(Map<String, dynamic> json) {
    return AssetSourceAttribution(
      sourcePlatform: _asStringOrNull(
        json['sourcePlatform'] ?? json['source_platform'],
      ),
      sourceUrl: _asStringOrNull(json['sourceUrl'] ?? json['source_url']),
      creatorHandle: _asStringOrNull(
        json['creatorHandle'] ?? json['creator_handle'],
      ),
      creatorName: _asStringOrNull(json['creatorName'] ?? json['creator_name']),
      creditText: _asStringOrNull(json['creditText'] ?? json['credit_text']),
      rightsStatus: (json['rightsStatus'] ?? json['rights_status'] ?? 'unknown')
          .toString(),
      creditRequired:
          _asBool(json['creditRequired'] ?? json['credit_required']) ?? false,
    );
  }
}

class AssetUnderstandingResult {
  const AssetUnderstandingResult({
    required this.assetId,
    required this.projectId,
    required this.status,
    required this.tags,
    required this.segments,
    this.summary,
    this.sourceAttribution,
    this.credentialSource,
    this.provider,
    this.errorCode,
  });

  final String assetId;
  final String projectId;
  final String status;
  final String? summary;
  final List<AssetSemanticTag> tags;
  final List<AssetSceneSegment> segments;
  final AssetSourceAttribution? sourceAttribution;
  final String? credentialSource;
  final String? provider;
  final String? errorCode;

  factory AssetUnderstandingResult.fromJson(Map<String, dynamic> json) {
    return AssetUnderstandingResult(
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      summary: _asStringOrNull(json['summary']),
      tags: _asList(json['tags']).map(AssetSemanticTag.fromJson).toList(),
      segments: _asList(
        json['segments'],
      ).map(AssetSceneSegment.fromJson).toList(),
      sourceAttribution:
          _asMapOrNull(
                json['sourceAttribution'] ?? json['source_attribution'],
              ) ==
              null
          ? null
          : AssetSourceAttribution.fromJson(
              _asMap(json['sourceAttribution'] ?? json['source_attribution']),
            ),
      credentialSource: _asStringOrNull(
        json['credentialSource'] ?? json['credential_source'],
      ),
      provider: _asStringOrNull(json['provider']),
      errorCode: _asStringOrNull(json['errorCode'] ?? json['error_code']),
    );
  }
}

class AssetUnderstandingJob {
  const AssetUnderstandingJob({
    required this.id,
    required this.assetId,
    required this.projectId,
    required this.userId,
    required this.mediaType,
    required this.provider,
    required this.status,
    required this.idempotencyKey,
    required this.attempts,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.credentialSource,
    this.retryOfJobId,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String assetId;
  final String projectId;
  final String userId;
  final String mediaType;
  final String provider;
  final String? credentialSource;
  final String status;
  final String idempotencyKey;
  final String? retryOfJobId;
  final String? errorCode;
  final String? errorMessage;
  final int attempts;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AssetUnderstandingJob.fromJson(Map<String, dynamic> json) {
    return AssetUnderstandingJob(
      id: (json['id'] ?? '').toString(),
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? json['media_type'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      credentialSource: _asStringOrNull(
        json['credentialSource'] ?? json['credential_source'],
      ),
      status: (json['status'] ?? '').toString(),
      idempotencyKey: (json['idempotencyKey'] ?? json['idempotency_key'] ?? '')
          .toString(),
      retryOfJobId: _asStringOrNull(
        json['retryOfJobId'] ?? json['retry_of_job_id'],
      ),
      errorCode: _asStringOrNull(json['errorCode'] ?? json['error_code']),
      errorMessage: _asStringOrNull(
        json['errorMessage'] ?? json['error_message'],
      ),
      attempts: _asInt(json['attempts']) ?? 0,
      metadata: _asMap(json['metadata']),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class AssetUnderstandingStatusResponse {
  const AssetUnderstandingStatusResponse({this.job, this.result});

  final AssetUnderstandingJob? job;
  final AssetUnderstandingResult? result;

  factory AssetUnderstandingStatusResponse.fromJson(Map<String, dynamic> json) {
    return AssetUnderstandingStatusResponse(
      job: _asMapOrNull(json['job']) == null
          ? null
          : AssetUnderstandingJob.fromJson(_asMap(json['job'])),
      result: _asMapOrNull(json['result']) == null
          ? null
          : AssetUnderstandingResult.fromJson(_asMap(json['result'])),
    );
  }
}

class ProjectAssetRecommendationItem {
  const ProjectAssetRecommendationItem({
    required this.assetId,
    required this.score,
    required this.candidateType,
    required this.requiresProjectAttachment,
    required this.fitReasons,
    required this.suggestedPlacements,
    required this.warnings,
    this.sourceProjectId,
    this.sourceAttribution,
  });

  final String assetId;
  final double score;
  final String candidateType;
  final String? sourceProjectId;
  final bool requiresProjectAttachment;
  final List<Map<String, dynamic>> fitReasons;
  final List<String> suggestedPlacements;
  final AssetSourceAttribution? sourceAttribution;
  final List<String> warnings;

  bool get candidateGlobalAsset => candidateType == 'candidate_global_asset';

  factory ProjectAssetRecommendationItem.fromJson(Map<String, dynamic> json) {
    final fitReasons = _asList(json['fitReasons'] ?? json['fit_reasons']);
    final placementsRaw =
        json['suggestedPlacements'] ?? json['suggested_placements'];
    final warningsRaw = json['warnings'];
    return ProjectAssetRecommendationItem(
      assetId: (json['assetId'] ?? json['asset_id'] ?? '').toString(),
      score: _asDouble(json['score']) ?? 0,
      candidateType:
          (json['candidateType'] ??
                  json['candidate_type'] ??
                  'attached_project_asset')
              .toString(),
      sourceProjectId: _asStringOrNull(
        json['sourceProjectId'] ?? json['source_project_id'],
      ),
      requiresProjectAttachment:
          _asBool(
            json['requiresProjectAttachment'] ??
                json['requires_project_attachment'],
          ) ??
          false,
      fitReasons: fitReasons,
      suggestedPlacements: _asStringList(placementsRaw),
      sourceAttribution:
          _asMapOrNull(
                json['sourceAttribution'] ?? json['source_attribution'],
              ) ==
              null
          ? null
          : AssetSourceAttribution.fromJson(
              _asMap(json['sourceAttribution'] ?? json['source_attribution']),
            ),
      warnings: _asStringList(warningsRaw),
    );
  }
}

class ProjectAssetRecommendationResponse {
  const ProjectAssetRecommendationResponse({required this.items});

  final List<ProjectAssetRecommendationItem> items;

  factory ProjectAssetRecommendationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectAssetRecommendationResponse(
      items: _asList(
        json['items'],
      ).map(ProjectAssetRecommendationItem.fromJson).toList(),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? _asMapOrNull(Object? value) {
  final map = _asMap(value);
  if (map.isEmpty) {
    return null;
  }
  return map;
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.whereType<Object?>().map(_asMap).toList(growable: false);
}

DateTime _asDateTime(Object? value) {
  final parsed = _asDateTimeOrNull(value);
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asDateTimeOrNull(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
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

double? _asDouble(Object? value) {
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

bool? _asBool(Object? value) {
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
  return null;
}

String? _asStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => _asStringOrNull(entry))
      .whereType<String>()
      .toList(growable: false);
}
