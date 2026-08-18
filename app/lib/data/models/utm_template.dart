class UtmTemplate {
  const UtmTemplate({
    this.id,
    required this.userId,
    this.projectId,
    required this.name,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? id;
  final String userId;
  final String? projectId;
  final String name;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmTerm;
  final String? utmContent;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UtmTemplate.fromJson(Map<String, dynamic> json) {
    return UtmTemplate(
      id: json['id'] as String?,
      userId: json['userId'] as String? ?? '',
      projectId: json['projectId'] as String?,
      name: json['name'] as String? ?? '',
      utmSource: json['utmSource'] as String?,
      utmMedium: json['utmMedium'] as String?,
      utmCampaign: json['utmCampaign'] as String?,
      utmTerm: json['utmTerm'] as String?,
      utmContent: json['utmContent'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        'name': name,
        if (utmSource != null) 'utmSource': utmSource,
        if (utmMedium != null) 'utmMedium': utmMedium,
        if (utmCampaign != null) 'utmCampaign': utmCampaign,
        if (utmTerm != null) 'utmTerm': utmTerm,
        if (utmContent != null) 'utmContent': utmContent,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
