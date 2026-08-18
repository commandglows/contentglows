class LinkWebhook {
  const LinkWebhook({
    this.id,
    required this.userId,
    this.projectId,
    required this.url,
    this.secret,
    this.events = const [],
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? id;
  final String userId;
  final String? projectId;
  final String url;
  final String? secret;
  final List<String> events;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LinkWebhook.fromJson(Map<String, dynamic> json) {
    return LinkWebhook(
      id: json['id'] as String?,
      userId: json['userId'] as String? ?? '',
      projectId: json['projectId'] as String?,
      url: json['url'] as String? ?? '',
      secret: json['secret'] as String?,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        'url': url,
        if (secret != null) 'secret': secret,
        'events': events,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class LinkWebhookDelivery {
  const LinkWebhookDelivery({
    this.id,
    required this.webhookId,
    required this.eventType,
    required this.url,
    this.statusCode,
    this.requestBody,
    this.responseBody,
    this.error,
    this.deliveredAt,
    required this.createdAt,
  });

  final String? id;
  final String webhookId;
  final String eventType;
  final String url;
  final int? statusCode;
  final String? requestBody;
  final String? responseBody;
  final String? error;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  factory LinkWebhookDelivery.fromJson(Map<String, dynamic> json) {
    return LinkWebhookDelivery(
      id: json['id'] as String?,
      webhookId: json['webhookId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      url: json['url'] as String? ?? '',
      statusCode: json['statusCode'] as int?,
      requestBody: json['requestBody'] as String?,
      responseBody: json['responseBody'] as String?,
      error: json['error'] as String?,
      deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'webhookId': webhookId,
        'eventType': eventType,
        'url': url,
        if (statusCode != null) 'statusCode': statusCode,
        if (requestBody != null) 'requestBody': requestBody,
        if (responseBody != null) 'responseBody': responseBody,
        if (error != null) 'error': error,
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class LinkConversion {
  const LinkConversion({
    this.id,
    required this.linkId,
    required this.userId,
    this.projectId,
    required this.type,
    this.revenue,
    this.currency,
    this.partnerId,
    this.metadata,
    required this.createdAt,
  });

  final String? id;
  final String linkId;
  final String userId;
  final String? projectId;
  final String type;
  final double? revenue;
  final String? currency;
  final String? partnerId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  factory LinkConversion.fromJson(Map<String, dynamic> json) {
    return LinkConversion(
      id: json['id'] as String?,
      linkId: json['linkId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      projectId: json['projectId'] as String?,
      type: json['type'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      partnerId: json['partnerId'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'linkId': linkId,
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        'type': type,
        if (revenue != null) 'revenue': revenue,
        if (currency != null) 'currency': currency,
        if (partnerId != null) 'partnerId': partnerId,
        if (metadata != null) 'metadata': metadata,
         'createdAt': createdAt.toIso8601String(),
       };
}

