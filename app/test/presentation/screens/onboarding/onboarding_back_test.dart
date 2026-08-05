import 'package:app/core/app_diagnostics.dart';
import 'package:app/core/shared_preferences_provider.dart';
import 'package:app/data/models/auth_session.dart';
import 'package:app/data/models/project.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Android back returns to the previous demo onboarding step before exit confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpDemoOnboarding(tester);

      await tester.tap(find.text('Relire la config démo'));
      await tester.pumpAndSettle();

      expect(find.text('Quel contenu voulez-vous ?'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Connectez la source de votre projet'), findsOneWidget);
      expect(find.text('Fermer ContentGlows ?'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Fermer ContentGlows ?'), findsOneWidget);
      expect(
        find.text('Est-ce que vous êtes sûr de vouloir fermer l’application ?'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpDemoOnboarding(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'demo_mode_enabled': true,
    'demo_onboarding_complete': false,
  });
  final sharedPreferences = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/onboarding?intent=entry',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
        sharedPrefsProvider.overrideWithValue(sharedPreferences),
        authSessionProvider.overrideWith(
          (ref) => _DemoAuthSessionNotifier(ref),
        ),
        projectsProvider.overrideWith((ref) async => const <Project>[]),
        githubIntegrationStatusProvider.overrideWith(
          (ref) async => const GithubIntegrationState(),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _DemoAuthSessionNotifier extends AuthSessionNotifier {
  _DemoAuthSessionNotifier(super.ref) {
    state = const AuthSession(
      status: AuthStatus.demo,
      onboardingComplete: false,
    );
  }
}
