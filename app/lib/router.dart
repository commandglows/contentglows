import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/app_config.dart';
import 'data/models/app_access_state.dart';
import 'data/models/auth_session.dart';
import 'providers/providers.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/screens/feed/feed_screen.dart';
import 'presentation/screens/editor/editor_screen.dart';
import 'presentation/screens/feedback/feedback_admin_screen.dart';
import 'presentation/screens/feedback/feedback_screen.dart';
import 'presentation/screens/history/history_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/integrations_screen.dart';
import 'presentation/screens/branding/brand_profiles_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/entry/entry_screen.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/ritual/ritual_screen.dart';
import 'presentation/screens/personas/personas_list_screen.dart';
import 'presentation/screens/personas/persona_editor_screen.dart';
import 'presentation/screens/activity/activity_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/content_tools/content_tools_screen.dart';
import 'presentation/screens/capture/capture_screen.dart';
import 'presentation/screens/reels/reels_screen.dart';
import 'presentation/screens/affiliations/affiliations_screen.dart';
import 'presentation/screens/angles/angles_screen.dart';
import 'presentation/screens/calendar/calendar_screen.dart';
import 'presentation/screens/newsletter/newsletter_screen.dart';
import 'presentation/screens/research/research_screen.dart';
import 'presentation/screens/runs/runs_screen.dart';
import 'presentation/screens/performance/performance_screen.dart';
import 'presentation/screens/projects/projects_screen.dart';
import 'presentation/screens/seo/seo_screen.dart';
import 'presentation/screens/templates/templates_screen.dart';
import 'presentation/screens/uptime/uptime_screen.dart';
import 'presentation/screens/idea_pool/idea_pool_screen.dart';
import 'presentation/screens/work_domains/work_domains_screen.dart';
import 'presentation/screens/drip/drip_screen.dart';
import 'presentation/screens/editor/video_timeline_screen.dart';
import 'presentation/screens/editor/video_source_intake_screen.dart';
import 'presentation/screens/project_intelligence/project_intelligence_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AppRouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);
  return createAppRouter(ref, refreshListenable: refreshListenable);
});

GoRouter createAppRouter(Ref ref, {Listenable? refreshListenable}) {
  return GoRouter(
    initialLocation: '/entry',
    refreshListenable: refreshListenable,
    observers: [
      SentryNavigatorObserver(
        enableAutoTransactions: AppConfig.sentryTracesSampleRate > 0,
        setRouteNameAsTransaction: true,
        routeNameExtractor: _sentryRouteSettings,
      ),
    ],
    redirect: (context, state) {
      final accessAsync = ref.read(appAccessStateProvider);
      final authSession = ref.read(authSessionProvider);
      return resolveAppRedirect(
        uri: state.uri,
        appAccessAsync: accessAsync,
        authSession: authSession,
      );
    },
    routes: buildAppRoutes(),
  );
}

RouteSettings? _sentryRouteSettings(RouteSettings? settings) {
  final routeName = settings?.name;
  if (routeName == null || routeName.isEmpty) {
    return const RouteSettings(name: 'unknown');
  }
  return RouteSettings(name: _sanitizeSentryRouteName(routeName));
}

String _sanitizeSentryRouteName(String routeName) {
  if (RegExp(r'^/editor/[^/]+/video/sources$').hasMatch(routeName)) {
    return '/editor/:id/video/sources';
  }
  if (RegExp(r'^/editor/[^/]+/video$').hasMatch(routeName)) {
    return '/editor/:id/video';
  }
  if (routeName.startsWith('/editor/')) {
    return '/editor/:id';
  }
  if (routeName.startsWith('/personas/') && routeName != '/personas/new') {
    return '/personas/:id';
  }
  return routeName;
}

String? resolveAppRedirect({
  required Uri uri,
  required AsyncValue<AppAccessState> appAccessAsync,
  AuthSession? authSession,
}) {
  final location = uri.path;
  final isRoot = location == '/';
  final isEntry = location == '/entry';
  final isAuth = location == '/auth';
  final isFeedback = location == '/feedback';
  final isFeedbackAdmin = location == '/feedback-admin';
  final isOnboarding = location == '/onboarding';
  final onboardingIntent = uri.queryParameters['intent'];
  final onboardingMode = uri.queryParameters['mode'];
  final allowOnboarding =
      onboardingIntent == 'entry' ||
      onboardingIntent == 'project-manage' ||
      onboardingMode == 'create' ||
      onboardingMode == 'edit';
  final access = appAccessAsync.value;

  if (appAccessAsync.isLoading || access == null) {
    if (isRoot) {
      return '/entry';
    }
    return null;
  }

  switch (access.stage) {
    case AppAccessStage.restoringSession:
    case AppAccessStage.checkingBackend:
    case AppAccessStage.checkingWorkspace:
      if (isRoot) {
        return '/entry';
      }
      return null;
    case AppAccessStage.signedOut:
    case AppAccessStage.bootstrapUnauthorized:
      if (!isEntry && !isAuth && !isFeedback) {
        return '/entry';
      }
      return null;
    case AppAccessStage.demo:
      if (isAuth) {
        return '/entry';
      }
      if (isOnboarding && !allowOnboarding) {
        return '/entry';
      }
      if (access.bootstrap?.shouldOnboard == true &&
          !isEntry &&
          !isOnboarding &&
          !isFeedback) {
        return '/entry';
      }
      if (access.bootstrap?.shouldOnboard == false && isOnboarding) {
        return '/entry';
      }
      return null;
    case AppAccessStage.apiUnavailable:
    case AppAccessStage.bootstrapFailed:
      // Clerk owns the session. A temporarily unavailable FastAPI backend
      // must not make an already authenticated user appear signed out.
      // Workspace-dependent providers remain guarded by canUseWorkspaceData
      // and the shell displays degraded-mode status until the API recovers.
      if (authSession?.isAuthenticated == true) {
        if (isAuth || isEntry) {
          return '/feed';
        }
        return null;
      }
      if (isAuth || isOnboarding) {
        return '/entry';
      }
      if (isEntry && access.bootstrap?.shouldOnboard == false) {
        return '/feed';
      }
      return null;
    case AppAccessStage.needsOnboarding:
      if (isAuth) {
        return '/entry';
      }
      if (isOnboarding && !allowOnboarding) {
        return '/entry';
      }
      if (!isEntry && !isOnboarding && !isFeedback && !isFeedbackAdmin) {
        return '/entry';
      }
      return null;
    case AppAccessStage.ready:
      if (isAuth) {
        return '/entry';
      }
      if (isOnboarding && !allowOnboarding) {
        return '/entry';
      }
      if (isEntry) {
        return '/feed';
      }
      return null;
  }
}

List<RouteBase> buildAppRoutes() {
  return [
    GoRoute(path: '/', name: 'root', redirect: (context, state) => '/entry'),
    GoRoute(
      path: '/entry',
      name: 'entry',
      pageBuilder: (context, state) => const MaterialPage(child: EntryScreen()),
    ),
    GoRoute(
      path: '/auth',
      name: 'auth',
      pageBuilder: (context, state) => const MaterialPage(child: AuthScreen()),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/feed',
          name: 'feed',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FeedScreen()),
        ),
        GoRoute(
          path: '/calendar',
          name: 'calendar',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CalendarScreen()),
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: '/activity',
          name: 'activity',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ActivityScreen()),
        ),
        GoRoute(
          path: '/affiliations',
          name: 'affiliations',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AffiliationsScreen()),
        ),
        GoRoute(
          path: '/runs',
          name: 'runs',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RunsScreen()),
        ),
        GoRoute(
          path: '/templates',
          name: 'templates',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TemplatesScreen()),
        ),
        GoRoute(
          path: '/newsletter',
          name: 'newsletter',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: NewsletterScreen()),
        ),
        GoRoute(
          path: '/research',
          name: 'research',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ResearchScreen()),
        ),
        GoRoute(
          path: '/reels',
          name: 'reels',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReelsScreen()),
        ),
        GoRoute(
          path: '/seo',
          name: 'seo',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SeoScreen()),
        ),
        GoRoute(
          path: '/drip',
          name: 'drip',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DripScreen()),
        ),
        GoRoute(
          path: '/content-tools',
          name: 'content-tools',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ContentToolsScreen()),
        ),
        GoRoute(
          path: '/capture',
          name: 'capture',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CaptureScreen()),
        ),
        GoRoute(
          path: '/analytics',
          name: 'analytics',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AnalyticsScreen()),
        ),
        GoRoute(
          path: '/idea-pool',
          name: 'idea-pool',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: IdeaPoolScreen()),
        ),
        GoRoute(
          path: '/project-intelligence',
          name: 'project-intelligence',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProjectIntelligenceScreen()),
        ),
        GoRoute(
          path: '/work-domains',
          name: 'work-domains',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WorkDomainsScreen()),
        ),
        GoRoute(
          path: '/performance',
          name: 'performance',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: PerformanceScreen()),
        ),
        GoRoute(
          path: '/uptime',
          name: 'uptime',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UptimeScreen()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/branding',
          name: 'settings-branding',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BrandProfilesScreen()),
        ),
        GoRoute(
          path: '/projects',
          name: 'projects',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProjectsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/feedback',
      name: 'feedback',
      pageBuilder: (context, state) =>
          const MaterialPage(child: FeedbackScreen()),
    ),
    GoRoute(
      path: '/feedback-admin',
      name: 'feedback-admin',
      pageBuilder: (context, state) =>
          const MaterialPage(child: FeedbackAdminScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) =>
          const MaterialPage(child: OnboardingScreen()),
    ),
    GoRoute(
      path: '/editor/:id/video/sources',
      name: 'editor-video-sources',
      pageBuilder: (context, state) => MaterialPage(
        child: VideoSourceIntakeScreen(contentId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/editor/:id/video',
      name: 'editor-video',
      pageBuilder: (context, state) => MaterialPage(
        child: VideoTimelineScreen(contentId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/editor/:id',
      name: 'editor-detail',
      pageBuilder: (context, state) => MaterialPage(
        child: EditorScreen(contentId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/ritual',
      name: 'ritual',
      pageBuilder: (context, state) =>
          const MaterialPage(child: RitualScreen()),
    ),
    GoRoute(
      path: '/personas',
      name: 'personas',
      pageBuilder: (context, state) =>
          const MaterialPage(child: PersonasListScreen()),
    ),
    GoRoute(
      path: '/personas/new',
      name: 'personas-new',
      pageBuilder: (context, state) =>
          const MaterialPage(child: PersonaEditorScreen()),
    ),
    GoRoute(
      path: '/personas/:id',
      name: 'personas-detail',
      pageBuilder: (context, state) => MaterialPage(
        child: PersonaEditorScreen(personaId: state.pathParameters['id']),
      ),
    ),
    GoRoute(
      path: '/angles',
      name: 'angles',
      pageBuilder: (context, state) =>
          const MaterialPage(child: AnglesScreen()),
    ),
    GoRoute(
      path: '/settings/integrations',
      name: 'settings-integrations',
      pageBuilder: (context, state) =>
          const MaterialPage(child: IntegrationsScreen()),
    ),
  ];
}

class _AppRouterRefreshListenable extends ChangeNotifier {
  _AppRouterRefreshListenable(Ref ref) {
    ref.listen<AsyncValue<AppAccessState>>(appAccessStateProvider, (
      previous,
      next,
    ) {
      if (previous != next) {
        notifyListeners();
      }
    });
    ref.listen<AuthSession>(authSessionProvider, (previous, next) {
      if (previous != next) {
        notifyListeners();
      }
    });
  }
}
