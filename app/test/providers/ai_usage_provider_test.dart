import 'package:app/data/models/ai_usage.dart';
import 'package:app/data/models/app_access_state.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads active-project quota with an explicit freshness timestamp',
    () async {
      final api = _FakeAIUsageApiService();
      final fetchedAt = DateTime.utc(2026, 8, 21, 20);
      final container = _container(api, fetchedAt);
      addTearDown(container.dispose);

      await container.read(appAccessStateProvider.future);
      final snapshot = await container.read(aiUsageStateProvider.future);

      expect(snapshot?.projectId, 'project-1');
      expect(snapshot?.summary.quotas.single.allowed, isTrue);
      expect(snapshot?.fetchedAt, fetchedAt);
      expect(api.summaryProjectIds, ['project-1']);
    },
  );

  test(
    'per-action preflight updates quota state from the server response',
    () async {
      final api = _FakeAIUsageApiService();
      final container = _container(api, DateTime.utc(2026, 8, 21, 20));
      addTearDown(container.dispose);
      await container.read(appAccessStateProvider.future);
      await container.read(aiUsageStateProvider.future);

      final result = await container
          .read(aiUsageStateProvider.notifier)
          .preflight(AIUsageAction.fluxImageGeneration);
      final snapshot = container.read(aiUsageStateProvider).value;

      expect(result.quota.requiredUnits, '2.00000000');
      expect(
        snapshot?.preflights[AIUsageAction.fluxImageGeneration],
        same(result),
      );
      expect(api.preflightProjectIds, ['project-1']);
    },
  );

  test(
    'failed refresh exposes an error without retaining stale quota data',
    () async {
      final api = _FakeAIUsageApiService();
      final container = _container(api, DateTime.utc(2026, 8, 21, 20));
      addTearDown(container.dispose);
      await container.read(appAccessStateProvider.future);
      await container.read(aiUsageStateProvider.future);
      api.failSummary = true;

      await container.read(aiUsageStateProvider.notifier).refresh();
      final state = container.read(aiUsageStateProvider);

      expect(state.hasError, isTrue);
      expect(state.hasValue, isFalse);
    },
  );

  test(
    'generation completion refreshes the server-authoritative summary',
    () async {
      final api = _FakeAIUsageApiService();
      final container = _container(api, DateTime.utc(2026, 8, 21, 20));
      addTearDown(container.dispose);
      await container.read(appAccessStateProvider.future);
      await container.read(aiUsageStateProvider.future);

      await container
          .read(aiUsageStateProvider.notifier)
          .refreshAfterGeneration();

      expect(api.summaryProjectIds, ['project-1', 'project-1']);
    },
  );
}

ProviderContainer _container(ApiService api, DateTime fetchedAt) {
  return ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      activeProjectIdProvider.overrideWithValue('project-1'),
      appAccessStateProvider.overrideWith(_FakeReadyAccessNotifier.new),
      aiUsageClockProvider.overrideWithValue(() => fetchedAt),
    ],
  );
}

class _FakeReadyAccessNotifier extends AppAccessNotifier {
  @override
  Future<AppAccessState> build() async {
    return const AppAccessState(stage: AppAccessStage.ready);
  }
}

class _FakeAIUsageApiService extends ApiService {
  _FakeAIUsageApiService() : super(baseUrl: 'http://test');

  final List<String> summaryProjectIds = [];
  final List<String> preflightProjectIds = [];
  bool failSummary = false;

  @override
  Future<AIUsageSummary> fetchAiUsageSummary({
    required String projectId,
  }) async {
    summaryProjectIds.add(projectId);
    if (failSummary) {
      throw const ApiException(
        ApiErrorType.offline,
        'Offline.',
        retryable: true,
      );
    }
    return AIUsageSummary(projectId: projectId, quotas: [_quota(projectId)]);
  }

  @override
  Future<AIUsagePreflightResponse> preflightAiUsage({
    required String projectId,
    required AIUsageAction action,
  }) async {
    preflightProjectIds.add(projectId);
    return AIUsagePreflightResponse(
      quota: _quota(projectId, requiredUnits: '2.00000000'),
      policy: const AIUsagePolicyMetadata(
        action: AIUsageAction.fluxImageGeneration,
        billingMode: 'managed',
        estimatedUnits: '2.00000000',
        limitBehavior: 'hard_block',
        providerFailureBehavior: 'refund',
      ),
    );
  }
}

AIQuotaStatus _quota(
  String projectId, {
  String requiredUnits = '1.00000000',
}) {
  return AIQuotaStatus(
    scope: AIUsageScope(userId: 'user-1', projectId: projectId),
    action: AIUsageAction.fluxImageGeneration,
    billingMode: 'managed',
    allowed: true,
    entitlementId: 'entitlement-1',
    unitLimit: '10.00000000',
    unitReserved: '0.00000000',
    unitConsumed: '0.00000000',
    unitRemaining: '10.00000000',
    requiredUnits: requiredUnits,
    checkedAt: DateTime.utc(2026, 8, 21, 20),
  );
}
