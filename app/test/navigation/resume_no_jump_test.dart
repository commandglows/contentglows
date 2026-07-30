import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app/data/models/app_access_state.dart';
import 'package:app/data/models/app_bootstrap.dart';
import 'package:app/data/models/auth_session.dart';
import 'package:app/router.dart';

void main() {
  group('resolveAppRedirect (resume no jump)', () {
    test('keeps /feed stable during transient checking stage', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/feed'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.checkingWorkspace),
        ),
      );

      expect(redirect, isNull);
    });

    test('keeps /editor/:id stable during transient checking stage', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/editor/123'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.checkingBackend),
        ),
      );

      expect(redirect, isNull);
    });

    test('keeps onboarding route with intent=entry', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/onboarding?intent=entry'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.needsOnboarding),
        ),
      );

      expect(redirect, isNull);
    });

    test('redirects to /entry on unauthorized terminal stage', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/feed'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.bootstrapUnauthorized),
        ),
      );

      expect(redirect, '/entry');
    });

    test('unauthorized redirects once to /entry then does not loop', () {
      final fromProtectedRoute = resolveAppRedirect(
        uri: Uri.parse('/settings'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.bootstrapUnauthorized),
        ),
      );
      expect(fromProtectedRoute, '/entry');

      final fromEntry = resolveAppRedirect(
        uri: Uri.parse('/entry'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.bootstrapUnauthorized),
        ),
      );
      expect(fromEntry, isNull);
    });

    test(
      'keeps current route in degraded mode when backend is unavailable',
      () {
        const bootstrap = AppBootstrap(
          user: AppBootstrapUser(userId: 'u1', workspaceExists: true),
          projectsCount: 1,
          defaultProjectId: 'p1',
          workspaceStatus: 'ready',
        );
        final redirect = resolveAppRedirect(
          uri: Uri.parse('/feed'),
          appAccessAsync: const AsyncValue.data(
            AppAccessState(
              stage: AppAccessStage.apiUnavailable,
              bootstrap: bootstrap,
            ),
          ),
        );

        expect(redirect, isNull);
      },
    );

    test(
      'keeps an authenticated user in the app when backend is unavailable',
      () {
        final redirect = resolveAppRedirect(
          uri: Uri.parse('/entry'),
          appAccessAsync: const AsyncValue.data(
            AppAccessState(stage: AppAccessStage.apiUnavailable),
          ),
          authSession: const AuthSession(
            status: AuthStatus.authenticated,
            bearerToken: 'redacted-test-token',
          ),
        );

        expect(redirect, '/feed');
      },
    );

    test('does not bypass reauthentication when bootstrap returns 401', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/feed'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.bootstrapUnauthorized),
        ),
        authSession: const AuthSession(
          status: AuthStatus.authenticated,
          bearerToken: 'redacted-test-token',
        ),
      );

      expect(redirect, '/entry');
    });

    test('keeps deep in-app route stable during checking stage', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/analytics'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.checkingWorkspace),
        ),
      );

      expect(redirect, isNull);
    });

    test('keeps /settings stable during transient checking stage', () {
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/settings'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.checkingBackend),
        ),
      );

      expect(redirect, isNull);
    });

    test('redirects /entry to /feed when ready', () {
      const bootstrap = AppBootstrap(
        user: AppBootstrapUser(userId: 'u1', workspaceExists: true),
        projectsCount: 1,
        defaultProjectId: 'p1',
        workspaceStatus: 'ready',
      );
      final redirect = resolveAppRedirect(
        uri: Uri.parse('/entry'),
        appAccessAsync: const AsyncValue.data(
          AppAccessState(stage: AppAccessStage.ready, bootstrap: bootstrap),
        ),
      );

      expect(redirect, '/feed');
    });
  });

  group('GoRouter matching', () {
    testWidgets('does not match differently cased paths as app routes', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/Feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Text('feed route matched'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('feed route matched'), findsNothing);
    });
  });
}
