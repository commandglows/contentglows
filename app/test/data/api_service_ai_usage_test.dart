import 'dart:convert';
import 'dart:io';

import 'package:app/data/models/ai_usage.dart';
import 'package:app/data/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo mode never invents a current quota', () async {
    final api = ApiService(
      baseUrl: 'http://localhost:8000',
      allowDemoData: true,
    );

    await expectLater(
      api.fetchAiUsageSummary(projectId: 'project_1'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'ai_usage_unavailable')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('offline quota reads fail instead of returning stale state', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.host}:${server.port}';
    await server.close(force: true);
    final api = ApiService(baseUrl: baseUrl);

    await expectLater(
      api.fetchAiUsageSummary(projectId: 'project_1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isOffline,
          'offline classification',
          isTrue,
        ),
      ),
    );
  });

  test('preflight sends only project and typed action', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requestFuture = server.first;
    final api = ApiService(baseUrl: 'http://${server.address.host}:${server.port}');
    final responseFuture = api.preflightAiUsage(
      projectId: 'project_1',
      action: AIUsageAction.fluxImageGeneration,
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/ai-usage/preflight');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      {'projectId': 'project_1', 'action': 'flux_image_generation'},
    );
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(_preflightPayload));
    await request.response.close();

    final response = await responseFuture;
    expect(response.quota.allowed, isTrue);
    expect(response.policy.estimatedUnits, '1.00000000');
  });

  test('maps structured quota errors into actionable fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requestFuture = server.first;
    final api = ApiService(baseUrl: 'http://${server.address.host}:${server.port}');
    final responseFuture = api.preflightAiUsage(
      projectId: 'project_1',
      action: AIUsageAction.fluxImageGeneration,
    );

    final request = await requestFuture;
    request.response
      ..statusCode = 429
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'detail': {
          'code': 'ai_quota_exhausted',
          'kind': 'quota',
          'message': 'Quota exhausted.',
          'action': 'flux_image_generation',
          'billingMode': 'managed',
          'remainingUnits': '0.00000000',
          'requiredUnits': '1.00000000',
          'retryable': false,
          'retryAfterSeconds': 60,
          'details': {'supportEligible': true},
        },
      }));
    await request.response.close();

    await expectLater(
      responseFuture,
      throwsA(
        isA<ApiException>()
            .having((error) => error.action, 'action', 'flux_image_generation')
            .having((error) => error.remainingUnits, 'remaining', '0.00000000')
            .having((error) => error.requiredUnits, 'required', '1.00000000')
            .having((error) => error.retryAfterSeconds, 'retry after', 60)
            .having((error) => error.details['supportEligible'], 'details', true),
      ),
    );
  });
}

final _preflightPayload = {
  'quota': {
    'scope': {'userId': 'user_1', 'projectId': 'project_1'},
    'action': 'flux_image_generation',
    'billingMode': 'managed',
    'allowed': true,
    'entitlementId': 'entitlement_1',
    'unitLimit': '10.00000000',
    'unitReserved': '0.00000000',
    'unitConsumed': '0.00000000',
    'unitRemaining': '10.00000000',
    'requiredUnits': '1.00000000',
    'checkedAt': '2026-08-21T20:00:00Z',
  },
  'policy': {
    'action': 'flux_image_generation',
    'billingMode': 'managed',
    'estimatedUnits': '1.00000000',
    'limitBehavior': 'hard_block',
    'providerFailureBehavior': 'release_before_start_refund_after_start',
  },
};
