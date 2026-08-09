class BrandProfile {
  const BrandProfile({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.name,
    this.logoAssetId,
    this.primaryColors = const <String>[],
    this.secondaryColors = const <String>[],
    this.fontHeading,
    this.fontBody,
    this.toneKeywords = const <String>[],
    this.ctaDefaults,
    this.captionStyleDefaults,
    this.motionIntensity = 'medium',
    this.transitionFamily,
    this.introModuleEnabled = true,
    this.outroModuleEnabled = true,
    this.isDefault = false,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String projectId;
  final String name;
  final String? logoAssetId;
  final List<String> primaryColors;
  final List<String> secondaryColors;
  final String? fontHeading;
  final String? fontBody;
  final List<String> toneKeywords;
  final Map<String, dynamic>? ctaDefaults;
  final Map<String, dynamic>? captionStyleDefaults;
  final String motionIntensity;
  final String? transitionFamily;
  final bool introModuleEnabled;
  final bool outroModuleEnabled;
  final bool isDefault;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BrandProfile.fromJson(Map<String, dynamic> json) {
    return BrandProfile(
      id: _asString(json['id']),
      userId: _asString(json['userId'] ?? json['user_id']),
      projectId: _asString(json['projectId'] ?? json['project_id']),
      name: _asString(json['name']),
      logoAssetId: _asStringOrNull(
        json['logoAssetId'] ?? json['logo_asset_id'],
      ),
      primaryColors: _asStringList(
        json['primaryColors'] ?? json['primary_colors'],
      ),
      secondaryColors: _asStringList(
        json['secondaryColors'] ?? json['secondary_colors'],
      ),
      fontHeading: _asStringOrNull(json['fontHeading'] ?? json['font_heading']),
      fontBody: _asStringOrNull(json['fontBody'] ?? json['font_body']),
      toneKeywords: _asStringList(
        json['toneKeywords'] ?? json['tone_keywords'],
      ),
      ctaDefaults: _asMapOrNull(json['ctaDefaults'] ?? json['cta_defaults']),
      captionStyleDefaults: _asMapOrNull(
        json['captionStyleDefaults'] ?? json['caption_style_defaults'],
      ),
      motionIntensity: _asString(
        json['motionIntensity'] ?? json['motion_intensity'] ?? 'medium',
      ),
      transitionFamily: _asStringOrNull(
        json['transitionFamily'] ?? json['transition_family'],
      ),
      introModuleEnabled: _asBool(
        json['introModuleEnabled'] ?? json['intro_module_enabled'],
        fallback: true,
      ),
      outroModuleEnabled: _asBool(
        json['outroModuleEnabled'] ?? json['outro_module_enabled'],
        fallback: true,
      ),
      isDefault: _asBool(
        json['isDefault'] ?? json['is_default'],
        fallback: false,
      ),
      revision: _asInt(json['revision'], fallback: 1),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  BrandProfileDraft toDraft() {
    return BrandProfileDraft(
      name: name,
      logoAssetId: logoAssetId,
      primaryColors: primaryColors,
      secondaryColors: secondaryColors,
      fontHeading: fontHeading,
      fontBody: fontBody,
      toneKeywords: toneKeywords,
      ctaDefaults: ctaDefaults,
      captionStyleDefaults: captionStyleDefaults,
      motionIntensity: motionIntensity,
      transitionFamily: transitionFamily,
      introModuleEnabled: introModuleEnabled,
      outroModuleEnabled: outroModuleEnabled,
      isDefault: isDefault,
    );
  }

  BrandProfile copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? name,
    String? logoAssetId,
    bool clearLogoAssetId = false,
    List<String>? primaryColors,
    List<String>? secondaryColors,
    String? fontHeading,
    bool clearFontHeading = false,
    String? fontBody,
    bool clearFontBody = false,
    List<String>? toneKeywords,
    Map<String, dynamic>? ctaDefaults,
    bool clearCtaDefaults = false,
    Map<String, dynamic>? captionStyleDefaults,
    bool clearCaptionStyleDefaults = false,
    String? motionIntensity,
    String? transitionFamily,
    bool clearTransitionFamily = false,
    bool? introModuleEnabled,
    bool? outroModuleEnabled,
    bool? isDefault,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BrandProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      logoAssetId: clearLogoAssetId ? null : (logoAssetId ?? this.logoAssetId),
      primaryColors: primaryColors ?? this.primaryColors,
      secondaryColors: secondaryColors ?? this.secondaryColors,
      fontHeading: clearFontHeading ? null : (fontHeading ?? this.fontHeading),
      fontBody: clearFontBody ? null : (fontBody ?? this.fontBody),
      toneKeywords: toneKeywords ?? this.toneKeywords,
      ctaDefaults: clearCtaDefaults ? null : (ctaDefaults ?? this.ctaDefaults),
      captionStyleDefaults: clearCaptionStyleDefaults
          ? null
          : (captionStyleDefaults ?? this.captionStyleDefaults),
      motionIntensity: motionIntensity ?? this.motionIntensity,
      transitionFamily: clearTransitionFamily
          ? null
          : (transitionFamily ?? this.transitionFamily),
      introModuleEnabled: introModuleEnabled ?? this.introModuleEnabled,
      outroModuleEnabled: outroModuleEnabled ?? this.outroModuleEnabled,
      isDefault: isDefault ?? this.isDefault,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'project_id': projectId,
      'name': name,
      'logo_asset_id': logoAssetId,
      'primary_colors': primaryColors,
      'secondary_colors': secondaryColors,
      'font_heading': fontHeading,
      'font_body': fontBody,
      'tone_keywords': toneKeywords,
      'cta_defaults': ctaDefaults,
      'caption_style_defaults': captionStyleDefaults,
      'motion_intensity': motionIntensity,
      'transition_family': transitionFamily,
      'intro_module_enabled': introModuleEnabled,
      'outro_module_enabled': outroModuleEnabled,
      'is_default': isDefault,
      'revision': revision,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BrandProfileDraft {
  const BrandProfileDraft({
    required this.name,
    this.logoAssetId,
    this.primaryColors = const <String>[],
    this.secondaryColors = const <String>[],
    this.fontHeading,
    this.fontBody,
    this.toneKeywords = const <String>[],
    this.ctaDefaults,
    this.captionStyleDefaults,
    this.motionIntensity = 'medium',
    this.transitionFamily,
    this.introModuleEnabled = true,
    this.outroModuleEnabled = true,
    this.isDefault = false,
  });

  final String name;
  final String? logoAssetId;
  final List<String> primaryColors;
  final List<String> secondaryColors;
  final String? fontHeading;
  final String? fontBody;
  final List<String> toneKeywords;
  final Map<String, dynamic>? ctaDefaults;
  final Map<String, dynamic>? captionStyleDefaults;
  final String motionIntensity;
  final String? transitionFamily;
  final bool introModuleEnabled;
  final bool outroModuleEnabled;
  final bool isDefault;

  factory BrandProfileDraft.fromProfile(BrandProfile profile) {
    return BrandProfileDraft(
      name: profile.name,
      logoAssetId: profile.logoAssetId,
      primaryColors: profile.primaryColors,
      secondaryColors: profile.secondaryColors,
      fontHeading: profile.fontHeading,
      fontBody: profile.fontBody,
      toneKeywords: profile.toneKeywords,
      ctaDefaults: profile.ctaDefaults,
      captionStyleDefaults: profile.captionStyleDefaults,
      motionIntensity: profile.motionIntensity,
      transitionFamily: profile.transitionFamily,
      introModuleEnabled: profile.introModuleEnabled,
      outroModuleEnabled: profile.outroModuleEnabled,
      isDefault: profile.isDefault,
    );
  }

  BrandProfileDraft copyWith({
    String? name,
    String? logoAssetId,
    bool clearLogoAssetId = false,
    List<String>? primaryColors,
    List<String>? secondaryColors,
    String? fontHeading,
    bool clearFontHeading = false,
    String? fontBody,
    bool clearFontBody = false,
    List<String>? toneKeywords,
    Map<String, dynamic>? ctaDefaults,
    bool clearCtaDefaults = false,
    Map<String, dynamic>? captionStyleDefaults,
    bool clearCaptionStyleDefaults = false,
    String? motionIntensity,
    String? transitionFamily,
    bool clearTransitionFamily = false,
    bool? introModuleEnabled,
    bool? outroModuleEnabled,
    bool? isDefault,
  }) {
    return BrandProfileDraft(
      name: name ?? this.name,
      logoAssetId: clearLogoAssetId ? null : (logoAssetId ?? this.logoAssetId),
      primaryColors: primaryColors ?? this.primaryColors,
      secondaryColors: secondaryColors ?? this.secondaryColors,
      fontHeading: clearFontHeading ? null : (fontHeading ?? this.fontHeading),
      fontBody: clearFontBody ? null : (fontBody ?? this.fontBody),
      toneKeywords: toneKeywords ?? this.toneKeywords,
      ctaDefaults: clearCtaDefaults ? null : (ctaDefaults ?? this.ctaDefaults),
      captionStyleDefaults: clearCaptionStyleDefaults
          ? null
          : (captionStyleDefaults ?? this.captionStyleDefaults),
      motionIntensity: motionIntensity ?? this.motionIntensity,
      transitionFamily: clearTransitionFamily
          ? null
          : (transitionFamily ?? this.transitionFamily),
      introModuleEnabled: introModuleEnabled ?? this.introModuleEnabled,
      outroModuleEnabled: outroModuleEnabled ?? this.outroModuleEnabled,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'logo_asset_id': logoAssetId,
      'primary_colors': primaryColors,
      'secondary_colors': secondaryColors,
      'font_heading': fontHeading,
      'font_body': fontBody,
      'tone_keywords': toneKeywords,
      'cta_defaults': ctaDefaults,
      'caption_style_defaults': captionStyleDefaults,
      'motion_intensity': motionIntensity,
      'transition_family': transitionFamily,
      'intro_module_enabled': introModuleEnabled,
      'outro_module_enabled': outroModuleEnabled,
      'is_default': isDefault,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'logo_asset_id': logoAssetId,
      'primary_colors': primaryColors,
      'secondary_colors': secondaryColors,
      'font_heading': fontHeading,
      'font_body': fontBody,
      'tone_keywords': toneKeywords,
      'cta_defaults': ctaDefaults,
      'caption_style_defaults': captionStyleDefaults,
      'motion_intensity': motionIntensity,
      'transition_family': transitionFamily,
      'intro_module_enabled': introModuleEnabled,
      'outro_module_enabled': outroModuleEnabled,
      'is_default': isDefault,
    };
  }
}

enum BrandVideoTemplateFormat {
  reels,
  shorts,
  linkedin,
  youtube,
}

extension BrandVideoTemplateFormatX on BrandVideoTemplateFormat {
  String get label {
    return switch (this) {
      BrandVideoTemplateFormat.reels => 'Reels',
      BrandVideoTemplateFormat.shorts => 'Shorts',
      BrandVideoTemplateFormat.linkedin => 'LinkedIn',
      BrandVideoTemplateFormat.youtube => 'YouTube',
    };
  }

  String get preset {
    return switch (this) {
      BrandVideoTemplateFormat.reels => 'vertical_9_16',
      BrandVideoTemplateFormat.shorts => 'vertical_9_16',
      BrandVideoTemplateFormat.linkedin => 'landscape_16_9',
      BrandVideoTemplateFormat.youtube => 'landscape_16_9',
    };
  }

  double get motionMultiplier {
    return switch (this) {
      BrandVideoTemplateFormat.reels => 1.05,
      BrandVideoTemplateFormat.shorts => 0.95,
      BrandVideoTemplateFormat.linkedin => 1.15,
      BrandVideoTemplateFormat.youtube => 1.20,
    };
  }
}

class BrandVideoBlueprint {
  const BrandVideoBlueprint({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.brandProfileId,
    required this.name,
    this.status = 'draft',
    this.defaultArchetype = 'ugc_ad',
    this.sceneRulesJson = const <String, dynamic>{},
    this.layoutRulesJson = const <String, dynamic>{},
    this.motionRulesJson = const <String, dynamic>{},
    this.captionRulesJson = const <String, dynamic>{},
    this.ctaRulesJson = const <String, dynamic>{},
    this.audioRulesJson = const <String, dynamic>{},
    this.exportRulesJson = const <String, dynamic>{},
    this.allowedRegenerationLocksJson = const <String, dynamic>{},
    this.revision = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String projectId;
  final String brandProfileId;
  final String name;
  final String status;
  final String defaultArchetype;
  final Map<String, dynamic> sceneRulesJson;
  final Map<String, dynamic> layoutRulesJson;
  final Map<String, dynamic> motionRulesJson;
  final Map<String, dynamic> captionRulesJson;
  final Map<String, dynamic> ctaRulesJson;
  final Map<String, dynamic> audioRulesJson;
  final Map<String, dynamic> exportRulesJson;
  final Map<String, dynamic> allowedRegenerationLocksJson;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';

  factory BrandVideoBlueprint.fromJson(Map<String, dynamic> json) {
    return BrandVideoBlueprint(
      id: _asString(json['id']),
      userId: _asString(json['user_id'] ?? json['userId']),
      projectId: _asString(json['project_id'] ?? json['projectId']),
      brandProfileId: _asString(
        json['brand_profile_id'] ?? json['brandProfileId'],
      ),
      name: _asString(json['name']),
      status: _asString(json['status'] ?? 'draft'),
      defaultArchetype: _asString(
        json['default_archetype'] ?? json['defaultArchetype'] ?? 'ugc_ad',
      ),
      sceneRulesJson: _asMapOrEmpty(json['scene_rules_json'] ?? json['sceneRulesJson']),
      layoutRulesJson: _asMapOrEmpty(json['layout_rules_json'] ?? json['layoutRulesJson']),
      motionRulesJson: _asMapOrEmpty(json['motion_rules_json'] ?? json['motionRulesJson']),
      captionRulesJson: _asMapOrEmpty(
        json['caption_rules_json'] ?? json['captionRulesJson'],
      ),
      ctaRulesJson: _asMapOrEmpty(json['cta_rules_json'] ?? json['ctaRulesJson']),
      audioRulesJson: _asMapOrEmpty(json['audio_rules_json'] ?? json['audioRulesJson']),
      exportRulesJson: _asMapOrEmpty(json['export_rules_json'] ?? json['exportRulesJson']),
      allowedRegenerationLocksJson: _asMapOrEmpty(
        json['allowed_regeneration_locks_json'] ??
            json['allowedRegenerationLocksJson'],
      ),
      revision: _asInt(json['revision'], fallback: 1),
      createdAt: _asDateTime(
        json['created_at'] ??
            json['createdAt'] ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      updatedAt: _asDateTime(
        json['updated_at'] ??
            json['updatedAt'] ??
            DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  String archetypeLabel() {
    return switch (defaultArchetype) {
      'product_demo' => 'Product Demo',
      'faceless_reel' => 'Faceless Reel',
      'talking_head_highlight' => 'Talking-head Highlight',
      'testimonial_cut' => 'Testimonial Cut',
      'recap' => 'Recap',
      _ => 'UGC Ad',
    };
  }

  BrandVideoTemplatePreview previewFor({
    required BrandProfile profile,
    required BrandVideoTemplateFormat format,
  }) {
    final baseMotion = _pickFirst(
      [
        motionRulesJson['intensity']?.toString(),
        motionRulesJson['motionIntensity']?.toString(),
        profile.motionIntensity,
      ],
      fallback: 'medium',
    );
    final transitions = _pickFirst(
      [
        _asStringOrNull(layoutRulesJson['transitionStyle']),
        _asStringOrNull(motionRulesJson['transitionPreset']),
        _asStringOrNull(profile.transitionFamily),
      ],
      fallback: _transitionForArchetype(),
    );
    final cta = _pickFirst(
      [
        _asStringOrNull(ctaRulesJson['copy']),
        _asStringOrNull(ctaRulesJson['primaryText']),
        _asStringOrNull(profile.ctaDefaults?['primaryText']),
        _asStringOrNull(profile.ctaDefaults?['text']),
      ],
      fallback: 'Add call-to-action',
    );
    final caption = _pickFirst(
      [
        _asStringOrNull(captionRulesJson['style']),
        _asStringOrNull(profile.captionStyleDefaults?['style']),
        _asStringOrNull(profile.captionStyleDefaults?['preset']),
      ],
      fallback: 'Readable + contrast',
    );
    final durationHint = _sceneDurationHint(format: format);
    final transitionHint = transitions.isEmpty
        ? 'Fast cut blocks with controlled pauses'
        : transitions;

    return BrandVideoTemplatePreview(
      format: format,
      transitionFamily: transitionHint,
      motionIntensity: _normalizeIntensity(baseMotion),
      ctaStyle: cta,
      captionStyle: caption,
      scenePacing: durationHint,
      archetypeLabel: archetypeLabel(),
    );
  }

  String _transitionForArchetype() {
    return switch (defaultArchetype) {
      'product_demo' => 'Clean cuts + reveal transitions',
      'faceless_reel' => 'Jump cuts + fast wipes',
      'talking_head_highlight' => 'Crossfades + punchy cuts',
      'testimonial_cut' => 'Soft push-ins and confidence pauses',
      'recap' => 'Elliptic pacing and quick transitions',
      _ => 'Simple cuts with branded consistency',
    };
  }

  String _sceneDurationHint({required BrandVideoTemplateFormat format}) {
    final baseFrames = _asInt(sceneRulesJson['sceneDurationFrames'], fallback: 84);
    final sceneFrames = (baseFrames * format.motionMultiplier).round();
    return '$sceneFrames frames per section';
  }
}

class BrandVideoTemplatePreview {
  const BrandVideoTemplatePreview({
    required this.format,
    required this.transitionFamily,
    required this.motionIntensity,
    required this.ctaStyle,
    required this.captionStyle,
    required this.scenePacing,
    required this.archetypeLabel,
  });

  final BrandVideoTemplateFormat format;
  final String transitionFamily;
  final String motionIntensity;
  final String ctaStyle;
  final String captionStyle;
  final String scenePacing;
  final String archetypeLabel;
}

List<BrandVideoTemplatePreview> deriveBrandTemplatePreviews({
  required BrandProfile profile,
  required BrandVideoBlueprint? activeBlueprint,
  required List<BrandVideoTemplateFormat> formats,
}) {
  final blueprint = activeBlueprint ??
      BrandVideoBlueprint(
        id: '',
        userId: '',
        projectId: profile.projectId,
        brandProfileId: profile.id,
        name: 'Fallback',
        status: 'draft',
        defaultArchetype: 'ugc_ad',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
  return formats.map((format) => blueprint.previewFor(format: format, profile: profile)).toList();
}

String _pickFirst(
  List<String?> values, {
  required String fallback,
}) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

Map<String, dynamic> _asMapOrEmpty(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _normalizeIntensity(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized == 'low' ||
      normalized == 'medium' ||
      normalized == 'high') {
    return normalized;
  }
  if (normalized == 'slow') return 'low';
  if (normalized == 'fast' || normalized == 'extreme') return 'high';
  return 'medium';
}

String _asString(dynamic value) {
  final raw = value?.toString();
  final result = raw?.trim();
  if (result == null || result.isEmpty) {
    throw FormatException('Expected non-empty string value.');
  }
  return result;
}

String? _asStringOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

Map<String, dynamic>? _asMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

bool _asBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

int _asInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _asDateTime(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    throw FormatException('Expected valid datetime.');
  }
  return DateTime.parse(text);
}
