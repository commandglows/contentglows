enum AIUsageAction {
  fluxImageGeneration('flux_image_generation'),
  bunnyUpload('bunny_upload'),
  remotionRender('remotion_render'),
  byokMetadata('byok_metadata');

  const AIUsageAction(this.apiValue);
  final String apiValue;

  static AIUsageAction fromJson(Object? value) => values.firstWhere(
    (candidate) => candidate.apiValue == value,
    orElse: () => throw FormatException('Unknown AI usage action: $value'),
  );
}

class AIUsageScope {
  const AIUsageScope({required this.userId, required this.projectId, this.orgId});
  final String userId;
  final String projectId;
  final String? orgId;

  factory AIUsageScope.fromJson(Map<String, dynamic> json) => AIUsageScope(
    userId: _requiredString(json, 'userId'),
    projectId: _requiredString(json, 'projectId'),
    orgId: _optionalString(json, 'orgId'),
  );
}

class AIQuotaStatus {
  const AIQuotaStatus({
    required this.scope,
    required this.action,
    required this.billingMode,
    required this.allowed,
    required this.unitLimit,
    required this.unitReserved,
    required this.unitConsumed,
    required this.unitRemaining,
    required this.requiredUnits,
    required this.checkedAt,
    this.entitlementId,
    this.reasonCode,
    this.resetAt,
  });
  final AIUsageScope scope;
  final AIUsageAction action;
  final String billingMode;
  final bool allowed;
  final String? entitlementId;
  final String unitLimit;
  final String unitReserved;
  final String unitConsumed;
  final String unitRemaining;
  final String requiredUnits;
  final String? reasonCode;
  final DateTime? resetAt;
  final DateTime checkedAt;

  factory AIQuotaStatus.fromJson(Map<String, dynamic> json) => AIQuotaStatus(
    scope: AIUsageScope.fromJson(_requiredMap(json, 'scope')),
    action: AIUsageAction.fromJson(json['action']),
    billingMode: _requiredString(json, 'billingMode'),
    allowed: json['allowed'] as bool? ?? false,
    entitlementId: _optionalString(json, 'entitlementId'),
    unitLimit: _unit(json, 'unitLimit'),
    unitReserved: _unit(json, 'unitReserved'),
    unitConsumed: _unit(json, 'unitConsumed'),
    unitRemaining: _unit(json, 'unitRemaining'),
    requiredUnits: _unit(json, 'requiredUnits'),
    reasonCode: _optionalString(json, 'reasonCode'),
    resetAt: _optionalDate(json, 'resetAt'),
    checkedAt: _requiredDate(json, 'checkedAt'),
  );
}

class AIUsagePolicyMetadata {
  const AIUsagePolicyMetadata({
    required this.action,
    required this.billingMode,
    required this.estimatedUnits,
    required this.limitBehavior,
    required this.providerFailureBehavior,
  });
  final AIUsageAction action;
  final String billingMode;
  final String estimatedUnits;
  final String limitBehavior;
  final String providerFailureBehavior;

  factory AIUsagePolicyMetadata.fromJson(Map<String, dynamic> json) =>
      AIUsagePolicyMetadata(
        action: AIUsageAction.fromJson(json['action']),
        billingMode: _requiredString(json, 'billingMode'),
        estimatedUnits: _unit(json, 'estimatedUnits'),
        limitBehavior: _requiredString(json, 'limitBehavior'),
        providerFailureBehavior: _requiredString(
          json,
          'providerFailureBehavior',
        ),
      );
}

class AIUsageSummary {
  const AIUsageSummary({required this.projectId, required this.quotas});
  final String projectId;
  final List<AIQuotaStatus> quotas;
  factory AIUsageSummary.fromJson(Map<String, dynamic> json) => AIUsageSummary(
    projectId: _requiredString(json, 'projectId'),
    quotas: _mapList(json, 'quotas', AIQuotaStatus.fromJson),
  );
}

class AIUsagePreflightResponse {
  const AIUsagePreflightResponse({required this.quota, required this.policy});
  final AIQuotaStatus quota;
  final AIUsagePolicyMetadata policy;
  factory AIUsagePreflightResponse.fromJson(Map<String, dynamic> json) =>
      AIUsagePreflightResponse(
        quota: AIQuotaStatus.fromJson(_requiredMap(json, 'quota')),
        policy: AIUsagePolicyMetadata.fromJson(_requiredMap(json, 'policy')),
      );
}

class AIUsageReservation {
  const AIUsageReservation({
    required this.reservationId,
    required this.idempotencyKey,
    required this.scope,
    required this.action,
    required this.billingMode,
    required this.status,
    required this.units,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.entitlementId,
    this.provider,
    this.model,
    this.jobId,
    this.providerStartedAt,
  });
  final String reservationId;
  final String idempotencyKey;
  final String? entitlementId;
  final AIUsageScope scope;
  final AIUsageAction action;
  final String billingMode;
  final String status;
  final String units;
  final String? provider;
  final String? model;
  final String? jobId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? providerStartedAt;

  factory AIUsageReservation.fromJson(Map<String, dynamic> json) =>
      AIUsageReservation(
        reservationId: _requiredString(json, 'reservationId'),
        idempotencyKey: _requiredString(json, 'idempotencyKey'),
        entitlementId: _optionalString(json, 'entitlementId'),
        scope: AIUsageScope.fromJson(_requiredMap(json, 'scope')),
        action: AIUsageAction.fromJson(json['action']),
        billingMode: _requiredString(json, 'billingMode'),
        status: _requiredString(json, 'status'),
        units: _unit(json, 'units'),
        provider: _optionalString(json, 'provider'),
        model: _optionalString(json, 'model'),
        jobId: _optionalString(json, 'jobId'),
        createdAt: _requiredDate(json, 'createdAt'),
        updatedAt: _requiredDate(json, 'updatedAt'),
        expiresAt: _requiredDate(json, 'expiresAt'),
        providerStartedAt: _optionalDate(json, 'providerStartedAt'),
      );
}

class AIProviderCostMetadata {
  const AIProviderCostMetadata({
    required this.provider,
    required this.providerAction,
    required this.costUnit,
    required this.confidence,
    required this.capturedAt,
    required this.evidence,
    this.model,
    this.providerRequestId,
    this.estimatedCost,
    this.actualCost,
    this.currency,
    this.inputMp,
    this.outputMp,
    this.pricingTableVersion,
  });
  final String provider;
  final String providerAction;
  final String? model;
  final String? providerRequestId;
  final String? estimatedCost;
  final String? actualCost;
  final String costUnit;
  final String? currency;
  final String? inputMp;
  final String? outputMp;
  final String? pricingTableVersion;
  final String confidence;
  final DateTime capturedAt;
  final Map<String, dynamic> evidence;

  factory AIProviderCostMetadata.fromJson(Map<String, dynamic> json) =>
      AIProviderCostMetadata(
        provider: _requiredString(json, 'provider'),
        providerAction: _requiredString(json, 'providerAction'),
        model: _optionalString(json, 'model'),
        providerRequestId: _optionalString(json, 'providerRequestId'),
        estimatedCost: _optionalUnit(json, 'estimatedCost'),
        actualCost: _optionalUnit(json, 'actualCost'),
        costUnit: _requiredString(json, 'costUnit'),
        currency: _optionalString(json, 'currency'),
        inputMp: _optionalUnit(json, 'inputMp'),
        outputMp: _optionalUnit(json, 'outputMp'),
        pricingTableVersion: _optionalString(json, 'pricingTableVersion'),
        confidence: _requiredString(json, 'confidence'),
        capturedAt: _requiredDate(json, 'capturedAt'),
        evidence: _optionalMap(json, 'evidence'),
      );
}

class AIUsageLedgerEntry {
  const AIUsageLedgerEntry({
    required this.entryId,
    required this.idempotencyKey,
    required this.scope,
    required this.action,
    required this.billingMode,
    required this.event,
    required this.units,
    required this.createdAt,
    required this.metadata,
    this.reservationId,
    this.unitDirection,
    this.providerCost,
    this.jobId,
    this.actorId,
    this.reason,
  });
  final String entryId;
  final String idempotencyKey;
  final String? reservationId;
  final AIUsageScope scope;
  final AIUsageAction action;
  final String billingMode;
  final String event;
  final String units;
  final String? unitDirection;
  final AIProviderCostMetadata? providerCost;
  final String? jobId;
  final String? actorId;
  final String? reason;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory AIUsageLedgerEntry.fromJson(Map<String, dynamic> json) =>
      AIUsageLedgerEntry(
        entryId: _requiredString(json, 'entryId'),
        idempotencyKey: _requiredString(json, 'idempotencyKey'),
        reservationId: _optionalString(json, 'reservationId'),
        scope: AIUsageScope.fromJson(_requiredMap(json, 'scope')),
        action: AIUsageAction.fromJson(json['action']),
        billingMode: _requiredString(json, 'billingMode'),
        event: _requiredString(json, 'event'),
        units: _unit(json, 'units'),
        unitDirection: _optionalString(json, 'unitDirection'),
        providerCost: json['providerCost'] is Map
            ? AIProviderCostMetadata.fromJson(
                Map<String, dynamic>.from(json['providerCost'] as Map),
              )
            : null,
        jobId: _optionalString(json, 'jobId'),
        actorId: _optionalString(json, 'actorId'),
        reason: _optionalString(json, 'reason'),
        createdAt: _requiredDate(json, 'createdAt'),
        metadata: _optionalMap(json, 'metadata'),
      );
}

class AIUsageHistory {
  const AIUsageHistory({required this.projectId, required this.entries});
  final String projectId;
  final List<AIUsageLedgerEntry> entries;
  factory AIUsageHistory.fromJson(Map<String, dynamic> json) => AIUsageHistory(
    projectId: _requiredString(json, 'projectId'),
    entries: _mapList(json, 'entries', AIUsageLedgerEntry.fromJson),
  );
}

class AIUsagePendingReservations {
  const AIUsagePendingReservations({required this.projectId, required this.reservations});
  final String projectId;
  final List<AIUsageReservation> reservations;
  factory AIUsagePendingReservations.fromJson(Map<String, dynamic> json) =>
      AIUsagePendingReservations(
        projectId: _requiredString(json, 'projectId'),
        reservations: _mapList(
          json,
          'reservations',
          AIUsageReservation.fromJson,
        ),
      );
}

class AIUsagePolicyList {
  const AIUsagePolicyList({required this.policies});
  final List<AIUsagePolicyMetadata> policies;
  factory AIUsagePolicyList.fromJson(Map<String, dynamic> json) =>
      AIUsagePolicyList(
        policies: _mapList(json, 'policies', AIUsagePolicyMetadata.fromJson),
      );
}

class AIUsageSnapshot {
  AIUsageSnapshot({
    required this.projectId,
    required this.summary,
    required this.fetchedAt,
    Map<AIUsageAction, AIUsagePreflightResponse> preflights =
        const <AIUsageAction, AIUsagePreflightResponse>{},
  }) : preflights = Map<AIUsageAction, AIUsagePreflightResponse>.unmodifiable(
         preflights,
       );

  final String projectId;
  final AIUsageSummary summary;
  final DateTime fetchedAt;
  final Map<AIUsageAction, AIUsagePreflightResponse> preflights;

  AIUsageSnapshot withPreflight(
    AIUsageAction action,
    AIUsagePreflightResponse preflight, {
    required DateTime fetchedAt,
  }) {
    final quotas = <AIQuotaStatus>[
      for (final quota in summary.quotas)
        if (quota.action != action) quota,
      preflight.quota,
    ];
    return AIUsageSnapshot(
      projectId: projectId,
      summary: AIUsageSummary(projectId: projectId, quotas: quotas),
      fetchedAt: fetchedAt,
      preflights: {...preflights, action: preflight},
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) throw FormatException('Missing $key');
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _unit(Map<String, dynamic> json, String key) =>
    _optionalUnit(json, key) ?? (throw FormatException('Missing $key'));
String? _optionalUnit(Map<String, dynamic> json, String key) =>
    json[key]?.toString();
Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing $key');
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

DateTime _requiredDate(Map<String, dynamic> json, String key) =>
    DateTime.parse(_requiredString(json, key));
DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  return value == null ? null : DateTime.parse(value);
}

List<T> _mapList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) throw FormatException('Missing $key');
  return List<T>.unmodifiable(
    value.map((entry) => parse(Map<String, dynamic>.from(entry as Map))),
  );
}
