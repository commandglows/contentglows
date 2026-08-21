import 'package:app/data/models/ai_runtime.dart';
import 'package:app/data/models/ai_usage.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/presentation/screens/settings/integrations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  testWidgets('renders runtime providers and selected mode', (tester) async {
    final settings = AIRuntimeSettings.fromJson({
      'mode': 'byok',
      'availableModes': [
        {'mode': 'byok', 'enabled': true},
        {'mode': 'platform', 'enabled': true},
      ],
      'providers': [
        {
          'provider': 'openrouter',
          'kind': 'llm',
          'byok': {'configured': true},
          'platform': {'configured': true, 'available': true},
        },
        {
          'provider': 'exa',
          'kind': 'search',
          'byok': {'configured': false},
          'platform': {'configured': false, 'available': false},
        },
      ],
    });

    await tester.pumpWidget(
      wrap(
        AiRuntimeSettingsCard(
          settings: settings,
          canManage: true,
          isUpdating: false,
          onModeSelected: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('ai-runtime-mode-byok')), findsOneWidget);
    expect(
      find.byKey(const Key('ai-runtime-provider-openrouter')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-runtime-provider-exa')), findsOneWidget);
  });

  testWidgets('disables platform mode when unavailable', (tester) async {
    final settings = AIRuntimeSettings.fromJson({
      'mode': 'byok',
      'availableModes': [
        {'mode': 'byok', 'enabled': true},
        {
          'mode': 'platform',
          'enabled': false,
          'message': 'Platform-paid mode is not enabled for this account.',
        },
      ],
      'providers': [],
    });

    String? selectedMode;

    await tester.pumpWidget(
      wrap(
        AiRuntimeSettingsCard(
          settings: settings,
          canManage: true,
          isUpdating: false,
          onModeSelected: (mode) async {
            selectedMode = mode;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ai-runtime-mode-platform')));
    await tester.pump();

    expect(selectedMode, isNull);
    expect(
      find.text('Platform-paid mode is not enabled for this account.'),
      findsOneWidget,
    );
  });

  testWidgets('shows managed quota without exposing prices', (tester) async {
    final snapshot = AIUsageSnapshot(
      projectId: 'project-1',
      fetchedAt: DateTime.utc(2026, 8, 21, 20),
      summary: AIUsageSummary(
        projectId: 'project-1',
        quotas: [
          AIQuotaStatus(
            scope: const AIUsageScope(
              userId: 'user-1',
              projectId: 'project-1',
            ),
            action: AIUsageAction.fluxImageGeneration,
            billingMode: 'managed',
            allowed: true,
            entitlementId: 'entitlement-1',
            unitLimit: '10.00000000',
            unitReserved: '1.00000000',
            unitConsumed: '2.00000000',
            unitRemaining: '7.00000000',
            requiredUnits: '1.00000000',
            checkedAt: DateTime.utc(2026, 8, 21, 20),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      wrap(
        AIUsageQuotaCard(
          state: AsyncData(snapshot),
          selectedMode: 'platform',
          onRefresh: () {},
        ),
      ),
    );

    expect(find.text('AI image generation'), findsOneWidget);
    expect(find.text('7 of 10 units remaining'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('shows a recoverable quota error action', (tester) async {
    var refreshCount = 0;
    const error = ApiException(
      ApiErrorType.server,
      'Quota exhausted.',
      code: 'ai_quota_exhausted',
      retryable: false,
    );

    await tester.pumpWidget(
      wrap(
        AIUsageQuotaCard(
          state: AsyncError(error, StackTrace.empty),
          selectedMode: 'platform',
          onRefresh: () => refreshCount++,
          onContactSupport: () {},
        ),
      ),
    );

    expect(find.text('Usage unavailable'), findsOneWidget);
    expect(
      find.textContaining('blocked before provider costs'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-usage-error-refresh')));
    expect(refreshCount, 1);
    expect(find.byKey(const Key('ai-usage-contact-support')), findsOneWidget);
  });

  testWidgets('explains that BYOK does not consume managed units', (
    tester,
  ) async {
    final snapshot = AIUsageSnapshot(
      projectId: 'project-1',
      fetchedAt: DateTime.utc(2026, 8, 21, 20),
      summary: const AIUsageSummary(projectId: 'project-1', quotas: []),
    );

    await tester.pumpWidget(
      wrap(
        AIUsageQuotaCard(
          state: AsyncData(snapshot),
          selectedMode: 'byok',
          onRefresh: () {},
        ),
      ),
    );

    expect(
      find.text('BYOK does not consume managed usage units'),
      findsOneWidget,
    );
    expect(find.textContaining('units remaining'), findsNothing);
  });

  testWidgets('never presents cached quota on provider failure', (
    tester,
  ) async {
    const error = ApiException(
      ApiErrorType.server,
      'Provider unavailable.',
      code: 'ai_provider_unavailable',
      retryable: true,
    );

    await tester.pumpWidget(
      wrap(
        AIUsageQuotaCard(
          state: AsyncError(error, StackTrace.empty),
          selectedMode: 'platform',
          onRefresh: () {},
        ),
      ),
    );

    expect(
      find.text(
        'Current AI usage is unavailable. No cached quota is shown for paid actions.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('units remaining'), findsNothing);
  });
}
