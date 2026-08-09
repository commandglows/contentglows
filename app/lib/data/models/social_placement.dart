class SocialPlacementRegistryEntry {
  const SocialPlacementRegistryEntry({
    required this.id,
    required this.label,
    this.labels = const <String, String>{},
    this.aliases = const <String>[],
  });

  final String id;
  final String label;
  final Map<String, String> labels;
  final List<String> aliases;

  factory SocialPlacementRegistryEntry.fromJson(Map<String, dynamic> json) {
    return SocialPlacementRegistryEntry(
      id: _string(json['id']),
      label: _string(json['label']),
      labels: _stringMap(json['labels']),
      aliases: _stringList(json['aliases']),
    );
  }
}

class SocialPlacementRule {
  const SocialPlacementRule({
    required this.placementId,
    required this.platformId,
    this.formatIds = const <String>[],
    this.required = false,
    this.recommended = false,
    this.mediaKinds = const <String>[],
    this.providerMediaIntent = '',
    this.ruleStrictness = 'advisory',
  });

  final String placementId;
  final String platformId;
  final List<String> formatIds;
  final bool required;
  final bool recommended;
  final List<String> mediaKinds;
  final String providerMediaIntent;
  final String ruleStrictness;

  factory SocialPlacementRule.fromJson(Map<String, dynamic> json) {
    return SocialPlacementRule(
      placementId: _string(json['placement_id'] ?? json['placementId']),
      platformId: _string(json['platform_id'] ?? json['platformId']),
      formatIds: _stringList(json['format_ids'] ?? json['formatIds']),
      required: _bool(json['required']),
      recommended: _bool(json['recommended']),
      mediaKinds: _stringList(json['media_kinds'] ?? json['mediaKinds']),
      providerMediaIntent: _string(
        json['provider_media_intent'] ?? json['providerMediaIntent'],
      ),
      ruleStrictness: _string(
        json['rule_strictness'] ?? json['ruleStrictness'],
        fallback: 'advisory',
      ),
    );
  }
}

class SocialPlacementRegistry {
  const SocialPlacementRegistry({
    required this.registryVersion,
    required this.locale,
    this.supportedLocales = const <String>[],
    this.formats = const <SocialPlacementRegistryEntry>[],
    this.platforms = const <SocialPlacementRegistryEntry>[],
    this.placements = const <SocialPlacementRegistryEntry>[],
    this.placementRules = const <SocialPlacementRule>[],
  });

  final String registryVersion;
  final String locale;
  final List<String> supportedLocales;
  final List<SocialPlacementRegistryEntry> formats;
  final List<SocialPlacementRegistryEntry> platforms;
  final List<SocialPlacementRegistryEntry> placements;
  final List<SocialPlacementRule> placementRules;

  factory SocialPlacementRegistry.fromJson(Map<String, dynamic> json) {
    return SocialPlacementRegistry(
      registryVersion: _string(
        json['registry_version'] ?? json['registryVersion'],
      ),
      locale: _string(json['locale'], fallback: 'en'),
      supportedLocales: _stringList(
        json['supported_locales'] ?? json['supportedLocales'],
      ),
      formats: _mapList(
        json['formats'],
      ).map(SocialPlacementRegistryEntry.fromJson).toList(),
      platforms: _mapList(
        json['platforms'],
      ).map(SocialPlacementRegistryEntry.fromJson).toList(),
      placements: _mapList(
        json['placements'],
      ).map(SocialPlacementRegistryEntry.fromJson).toList(),
      placementRules: _mapList(
        json['placement_rules'] ?? json['placementRules'],
      ).map(SocialPlacementRule.fromJson).toList(),
    );
  }
}

enum PlacementIssueSeverity { warning, blocking }

class PlacementIssue {
  const PlacementIssue({
    required this.code,
    required this.severity,
    required this.platformId,
    required this.message,
    this.placementId,
    this.assetId,
  });

  final String code;
  final PlacementIssueSeverity severity;
  final String platformId;
  final String? placementId;
  final String? assetId;
  final String message;

  bool get isBlocking => severity == PlacementIssueSeverity.blocking;

  factory PlacementIssue.fromJson(Map<String, dynamic> json) {
    return PlacementIssue(
      code: _string(json['code']),
      severity: _string(json['severity']) == 'blocking'
          ? PlacementIssueSeverity.blocking
          : PlacementIssueSeverity.warning,
      platformId: _string(json['platform_id'] ?? json['platformId']),
      placementId: _nullableString(json['placement_id'] ?? json['placementId']),
      assetId: _nullableString(json['asset_id'] ?? json['assetId']),
      message: _string(json['message']),
    );
  }
}

class PlacementSlot {
  const PlacementSlot({
    required this.placementId,
    required this.label,
    this.required = false,
    this.recommended = false,
    this.mediaKinds = const <String>[],
    this.providerMediaIntent = '',
    this.ruleStrictness = 'advisory',
    this.selectedAssetId,
    this.state = 'missing',
    this.issues = const <PlacementIssue>[],
  });

  final String placementId;
  final String label;
  final bool required;
  final bool recommended;
  final List<String> mediaKinds;
  final String providerMediaIntent;
  final String ruleStrictness;
  final String? selectedAssetId;
  final String state;
  final List<PlacementIssue> issues;

  bool get isAttached => state == 'attached' && selectedAssetId != null;
  bool get hasBlockingIssue => issues.any((issue) => issue.isBlocking);

  PlacementSlot copyWith({String? label}) {
    return PlacementSlot(
      placementId: placementId,
      label: label ?? this.label,
      required: required,
      recommended: recommended,
      mediaKinds: mediaKinds,
      providerMediaIntent: providerMediaIntent,
      ruleStrictness: ruleStrictness,
      selectedAssetId: selectedAssetId,
      state: state,
      issues: issues,
    );
  }

  factory PlacementSlot.fromJson(Map<String, dynamic> json) {
    return PlacementSlot(
      placementId: _string(json['placement_id'] ?? json['placementId']),
      label: _string(json['label']),
      required: _bool(json['required']),
      recommended: _bool(json['recommended']),
      mediaKinds: _stringList(json['media_kinds'] ?? json['mediaKinds']),
      providerMediaIntent: _string(
        json['provider_media_intent'] ?? json['providerMediaIntent'],
      ),
      ruleStrictness: _string(
        json['rule_strictness'] ?? json['ruleStrictness'],
        fallback: 'advisory',
      ),
      selectedAssetId: _nullableString(
        json['selected_asset_id'] ?? json['selectedAssetId'],
      ),
      state: _string(json['state'], fallback: 'missing'),
      issues: _mapList(json['issues']).map(PlacementIssue.fromJson).toList(),
    );
  }
}

class PlatformPlacementPlan {
  const PlatformPlacementPlan({
    required this.platformId,
    required this.label,
    this.canPublish = true,
    this.slots = const <PlacementSlot>[],
    this.issues = const <PlacementIssue>[],
  });

  final String platformId;
  final String label;
  final bool canPublish;
  final List<PlacementSlot> slots;
  final List<PlacementIssue> issues;

  factory PlatformPlacementPlan.fromJson(Map<String, dynamic> json) {
    return PlatformPlacementPlan(
      platformId: _string(json['platform_id'] ?? json['platformId']),
      label: _string(json['label']),
      canPublish: _bool(
        json['can_publish'] ?? json['canPublish'],
        fallback: true,
      ),
      slots: _mapList(json['slots']).map(PlacementSlot.fromJson).toList(),
      issues: _mapList(json['issues']).map(PlacementIssue.fromJson).toList(),
    );
  }
}

class PlacementPlan {
  const PlacementPlan({
    required this.registryVersion,
    required this.contentId,
    required this.formatId,
    required this.locale,
    this.platforms = const <PlatformPlacementPlan>[],
  });

  final String registryVersion;
  final String contentId;
  final String formatId;
  final String locale;
  final List<PlatformPlacementPlan> platforms;

  factory PlacementPlan.fromJson(Map<String, dynamic> json) {
    return PlacementPlan(
      registryVersion: _string(
        json['registry_version'] ?? json['registryVersion'],
      ),
      contentId: _string(json['content_id'] ?? json['contentId']),
      formatId: _string(json['format_id'] ?? json['formatId']),
      locale: _string(json['locale'], fallback: 'en'),
      platforms: _mapList(
        json['platforms'],
      ).map(PlatformPlacementPlan.fromJson).toList(),
    );
  }
}

class PublishPlatformTarget {
  const PublishPlatformTarget({
    required this.platform,
    required this.accountId,
  });

  final String platform;
  final String accountId;

  Map<String, String> toJson() => {
    'platform': platform,
    'account_id': accountId,
  };
}

class ProviderMediaItemSummary {
  const ProviderMediaItemSummary({
    required this.type,
    required this.placementId,
    required this.assetId,
  });

  final String type;
  final String placementId;
  final String assetId;

  factory ProviderMediaItemSummary.fromJson(Map<String, dynamic> json) {
    return ProviderMediaItemSummary(
      type: _string(json['type']),
      placementId: _string(json['placement_id'] ?? json['placementId']),
      assetId: _string(json['asset_id'] ?? json['assetId']),
    );
  }
}

class PublishPlatformPreflight {
  const PublishPlatformPreflight({
    required this.platformId,
    required this.canPublish,
    this.slots = const <PlacementSlot>[],
    this.issues = const <PlacementIssue>[],
    this.mediaItems = const <ProviderMediaItemSummary>[],
  });

  final String platformId;
  final bool canPublish;
  final List<PlacementSlot> slots;
  final List<PlacementIssue> issues;
  final List<ProviderMediaItemSummary> mediaItems;

  factory PublishPlatformPreflight.fromJson(Map<String, dynamic> json) {
    return PublishPlatformPreflight(
      platformId: _string(json['platform_id'] ?? json['platformId']),
      canPublish: _bool(json['can_publish'] ?? json['canPublish']),
      slots: _mapList(json['slots']).map(PlacementSlot.fromJson).toList(),
      issues: _mapList(json['issues']).map(PlacementIssue.fromJson).toList(),
      mediaItems: _mapList(
        json['media_items'] ?? json['mediaItems'],
      ).map(ProviderMediaItemSummary.fromJson).toList(),
    );
  }
}

class PublishPreflightResponse {
  const PublishPreflightResponse({
    required this.canPublish,
    required this.registryVersion,
    required this.contentId,
    required this.formatId,
    this.platforms = const <PublishPlatformPreflight>[],
    this.issues = const <PlacementIssue>[],
  });

  final bool canPublish;
  final String registryVersion;
  final String contentId;
  final String formatId;
  final List<PublishPlatformPreflight> platforms;
  final List<PlacementIssue> issues;

  bool get hasBlockingIssues =>
      !canPublish || issues.any((issue) => issue.isBlocking);

  factory PublishPreflightResponse.fromJson(Map<String, dynamic> json) {
    return PublishPreflightResponse(
      canPublish: _bool(json['can_publish'] ?? json['canPublish']),
      registryVersion: _string(
        json['registry_version'] ?? json['registryVersion'],
      ),
      contentId: _string(json['content_id'] ?? json['contentId']),
      formatId: _string(json['format_id'] ?? json['formatId']),
      platforms: _mapList(
        json['platforms'],
      ).map(PublishPlatformPreflight.fromJson).toList(),
      issues: _mapList(json['issues']).map(PlacementIssue.fromJson).toList(),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((entry) => entry.toString()).toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  return value.map((key, entry) => MapEntry(key.toString(), entry.toString()));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}
