class LinkClick {
  const LinkClick({
    this.id,
    required this.linkId,
    required this.userId,
    this.projectId,
    required this.slug,
    required this.destinationUrl,
    this.variantIndex = 0,
    this.country,
    this.device,
    this.referrer,
    this.userAgent,
    required this.createdAt,
  });

  final String? id;
  final String linkId;
  final String userId;
  final String? projectId;
  final String slug;
  final String destinationUrl;
  final int variantIndex;
  final String? country;
  final String? device;
  final String? referrer;
  final String? userAgent;
  final DateTime createdAt;

  factory LinkClick.fromJson(Map<String, dynamic> json) {
    return LinkClick(
      id: json['id'] as String?,
      linkId: json['linkId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      projectId: json['projectId'] as String?,
      slug: json['slug'] as String? ?? '',
      destinationUrl: json['destinationUrl'] as String? ?? '',
      variantIndex: (json['variantIndex'] as int?) ?? 0,
      country: json['country'] as String?,
      device: json['device'] as String?,
      referrer: json['referrer'] as String?,
      userAgent: json['userAgent'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'linkId': linkId,
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        'slug': slug,
        'destinationUrl': destinationUrl,
        'variantIndex': variantIndex,
        if (country != null) 'country': country,
        if (device != null) 'device': device,
        if (referrer != null) 'referrer': referrer,
        if (userAgent != null) 'userAgent': userAgent,
        'createdAt': createdAt.toIso8601String(),
      };
}

class LinkVariant {
  const LinkVariant({
    this.id,
    required this.linkId,
    required this.userId,
    required this.url,
    this.weight = 1,
    this.country,
    this.device,
    this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? id;
  final String linkId;
  final String userId;
  final String url;
  final int weight;
  final String? country;
  final String? device;
  final String? language;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LinkVariant.fromJson(Map<String, dynamic> json) {
    return LinkVariant(
      id: json['id'] as String?,
      linkId: json['linkId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      weight: (json['weight'] as int?) ?? 1,
      country: json['country'] as String?,
      device: json['device'] as String?,
      language: json['language'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'linkId': linkId,
        'userId': userId,
        'url': url,
        'weight': weight,
        if (country != null) 'country': country,
        if (device != null) 'device': device,
        if (language != null) 'language': language,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class LinkClickSummary {
  const LinkClickSummary({
    required this.totalClicks,
    this.countries = const [],
    this.devices = const [],
    this.referrers = const [],
    this.daily = const [],
  });

  final int totalClicks;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> referrers;
  final List<Map<String, dynamic>> daily;

  factory LinkClickSummary.fromJson(Map<String, dynamic> json) {
    return LinkClickSummary(
      totalClicks: (json['totalClicks'] as int?) ?? 0,
      countries: (json['countries'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      referrers: (json['referrers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      daily: (json['daily'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'totalClicks': totalClicks,
        'countries': countries,
        'devices': devices,
        'referrers': referrers,
        'daily': daily,
      };
}
