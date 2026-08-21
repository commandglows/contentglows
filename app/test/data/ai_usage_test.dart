import 'package:app/data/models/ai_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = {'userId': 'user_1', 'projectId': 'project_1'};

  test('quota parsing preserves exact decimal units', () {
    final quota = AIQuotaStatus.fromJson({
      'scope': scope,
      'action': 'flux_image_generation',
      'billingMode': 'managed',
      'allowed': true,
      'entitlementId': 'entitlement_1',
      'unitLimit': '1234567890123456.12345678',
      'unitReserved': 2,
      'unitConsumed': '3.25',
      'unitRemaining': '1234567890123450.87345678',
      'requiredUnits': '1.5',
      'checkedAt': '2026-08-21T20:00:00Z',
    });

    expect(quota.action, AIUsageAction.fluxImageGeneration);
    expect(quota.unitLimit, '1234567890123456.12345678');
    expect(quota.unitReserved, '2');
    expect(quota.checkedAt.isUtc, isTrue);
  });

  test('history parses provider-cost evidence without monetary coercion', () {
    final history = AIUsageHistory.fromJson({
      'projectId': 'project_1',
      'entries': [
        {
          'entryId': 'entry_1',
          'idempotencyKey': 'key_1',
          'reservationId': 'reservation_1',
          'scope': scope,
          'action': 'flux_image_generation',
          'billingMode': 'managed',
          'event': 'completed',
          'units': '1.00000000',
          'providerCost': {
            'provider': 'bfl',
            'providerAction': 'flux_image_generation',
            'providerRequestId': 'request_1',
            'actualCost': '0.12500000',
            'costUnit': 'provider_credit',
            'confidence': 'exact',
            'capturedAt': '2026-08-21T20:01:00Z',
            'evidence': {'source': 'provider_response'},
          },
          'createdAt': '2026-08-21T20:01:00Z',
          'metadata': {'delivery': 'durable'},
        },
      ],
    });

    expect(history.entries.single.providerCost?.actualCost, '0.12500000');
    expect(history.entries.single.providerCost?.costUnit, 'provider_credit');
    expect(history.entries.single.metadata['delivery'], 'durable');
  });

  test('unknown actions fail closed instead of silently changing meaning', () {
    expect(
      () => AIUsageAction.fromJson('future_paid_action'),
      throwsA(isA<FormatException>()),
    );
  });
}
