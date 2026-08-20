import 'package:app/data/models/app_access_state.dart';
import 'package:app/data/models/brand_profile.dart';
import 'package:app/data/models/content_item.dart';
import 'package:app/data/models/persona.dart';
import 'package:app/data/models/video_timeline.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/core/app_diagnostics.dart';
import 'package:app/core/shared_preferences_provider.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/data/models/app_settings.dart';
import 'package:app/data/models/project.dart';
import 'package:app/presentation/screens/branding/brand_profiles_screen.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'default brand profile cannot be deleted from the branding screen',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final api = _FakeBrandProfilesApiService();
      final activeProject = _project(id: 'project-1', name: 'Project 1');
      final router = GoRouter(
        initialLocation: '/settings/branding',
        routes: [
          GoRoute(
            path: '/settings/branding',
            builder: (context, state) => const BrandProfilesScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            activeProjectIdProvider.overrideWithValue('project-1'),
            appAccessStateProvider.overrideWith(_FakeReadyAccessNotifier.new),
            appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
            sharedPrefsProvider.overrideWithValue(sharedPreferences),
            projectsStateProvider.overrideWith(
              (ref) async => ProjectsState(items: [activeProject]),
            ),
            activeProjectProvider.overrideWith((ref) => activeProject),
            currentUserSettingsProvider.overrideWith(
              () => _TestUserSettingsNotifier(
                const AppSettings(
                  id: 'settings-1',
                  userId: 'user-1',
                  defaultProjectId: 'project-1',
                  projectSelectionMode: projectSelectionModeSelected,
                ),
              ),
            ),
            brandProfileBlueprintsStateProvider.overrideWith(
              (ref) async => BrandProfileBlueprintsState(
                items: [
                  BrandVideoBlueprint(
                    id: 'blueprint-1',
                    userId: 'user-1',
                    projectId: 'project-1',
                    brandProfileId: 'brand-1',
                    name: 'Default',
                    status: 'active',
                    createdAt: DateTime.utc(2026, 7, 8, 12),
                    updatedAt: DateTime.utc(2026, 7, 8, 12),
                  ),
                ],
              ),
            ),
            pendingContentProvider.overrideWith(
              () => _TestPendingContentNotifier([
                ContentItem(
                  id: 'content-ready',
                  title: 'Ready title',
                  body: 'Ready body',
                  type: ContentType.blogPost,
                  status: ContentStatus.pending,
                  metadata: const {'content_complete': true},
                  createdAt: DateTime.utc(2026, 7, 8, 12),
                ),
              ]),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Set another profile as default before deleting this one.'),
        findsOneWidget,
      );

      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(deleteButton.onPressed, isNull);
    },
  );

  testWidgets(
    'preview impact routes through canonical branded generation and opens the editor',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final api = _FakeBrandProfilesApiService();
      final activeProject = _project(id: 'project-1', name: 'Project 1');
      final router = GoRouter(
        initialLocation: '/settings/branding',
        routes: [
          GoRoute(
            path: '/settings/branding',
            builder: (context, state) => const BrandProfilesScreen(),
          ),
          GoRoute(
            path: '/editor/:id/video',
            builder: (context, state) => Scaffold(
              body: Text('video timeline ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            activeProjectIdProvider.overrideWithValue('project-1'),
            appAccessStateProvider.overrideWith(_FakeReadyAccessNotifier.new),
            appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
            sharedPrefsProvider.overrideWithValue(sharedPreferences),
            projectsStateProvider.overrideWith(
              (ref) async => ProjectsState(items: [activeProject]),
            ),
            activeProjectProvider.overrideWith((ref) => activeProject),
            currentUserSettingsProvider.overrideWith(
              () => _TestUserSettingsNotifier(
                const AppSettings(
                  id: 'settings-1',
                  userId: 'user-1',
                  defaultProjectId: 'project-1',
                  projectSelectionMode: projectSelectionModeSelected,
                ),
              ),
            ),
            brandProfileBlueprintsStateProvider.overrideWith(
              (ref) async => BrandProfileBlueprintsState(
                items: [
                  BrandVideoBlueprint(
                    id: 'blueprint-1',
                    userId: 'user-1',
                    projectId: 'project-1',
                    brandProfileId: 'brand-1',
                    name: 'Default',
                    status: 'active',
                    createdAt: DateTime.utc(2026, 7, 8, 12),
                    updatedAt: DateTime.utc(2026, 7, 8, 12),
                  ),
                ],
              ),
            ),
            pendingContentProvider.overrideWith(
              () => _TestPendingContentNotifier([
                ContentItem(
                  id: 'content-ready',
                  title: 'Ready title',
                  body: 'Ready body',
                  type: ContentType.blogPost,
                  status: ContentStatus.pending,
                  metadata: const {'content_complete': true},
                  createdAt: DateTime.utc(2026, 7, 8, 12),
                ),
              ]),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previewButtonFinder = find.widgetWithText(
        OutlinedButton,
        'Generate video preview',
      );
      expect(previewButtonFinder, findsOneWidget);
      final previewButton = tester.widget<OutlinedButton>(previewButtonFinder);
      expect(previewButton.onPressed, isNotNull);
      await tester.tap(previewButtonFinder);
      await tester.pumpAndSettle();
      expect(
        find.text('No complete content is ready to preview branding yet.'),
        findsNothing,
      );
      expect(find.text('Preview branding impact'), findsOneWidget);
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('video timeline content-ready'), findsOneWidget);
      expect(api.brandedGenerationCalls, hasLength(1));
      expect(api.brandedGenerationCalls.single.brandProfileId, 'brand-1');
      expect(api.brandedGenerationCalls.single.contentId, 'content-ready');
      expect(
        api.brandedGenerationCalls.single.triggerSource,
        'branding_profiles_screen',
      );
    },
  );

  testWidgets(
    'preview content identifies its linked persona',
    (tester) async {
      final api = await _pumpBrandProfilesScreen(
        tester,
        personas: const [Persona(id: 'persona-1', name: 'Founder')],
        contentMetadata: const {
          'content_complete': true,
          'persona_id': 'persona-1',
        },
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Generate video preview'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Audience: Founder'), findsOneWidget);
      expect(api.brandedGenerationCalls, isEmpty);
    },
  );

  testWidgets(
    'preview content keeps a neutral state when its persona is unavailable',
    (tester) async {
      final api = await _pumpBrandProfilesScreen(
        tester,
        contentMetadata: const {
          'content_complete': true,
          'persona_id': 'deleted-persona',
        },
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Generate video preview'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Audience unavailable'), findsOneWidget);
      expect(api.brandedGenerationCalls, isEmpty);
    },
  );

  testWidgets(
    'preview requires video style setup before generation',
    (tester) async {
      final api = await _pumpBrandProfilesScreen(
        tester,
        hasActiveBlueprint: false,
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Generate video preview'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set up a video style'), findsOneWidget);
      expect(
        find.textContaining(
          'prepare a branded video preview for this profile',
        ),
        findsOneWidget,
      );
      expect(api.brandedGenerationCalls, isEmpty);
    },
  );
}

Future<_FakeBrandProfilesApiService> _pumpBrandProfilesScreen(
  WidgetTester tester, {
  List<Persona> personas = const [],
  Map<String, dynamic> contentMetadata = const {'content_complete': true},
  bool hasActiveBlueprint = true,
}) async {
  tester.view.physicalSize = const Size(1280, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final api = _FakeBrandProfilesApiService();
  final activeProject = _project(id: 'project-1', name: 'Project 1');
  final router = GoRouter(
    initialLocation: '/settings/branding',
    routes: [
      GoRoute(
        path: '/settings/branding',
        builder: (context, state) => const BrandProfilesScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        activeProjectIdProvider.overrideWithValue('project-1'),
        appAccessStateProvider.overrideWith(_FakeReadyAccessNotifier.new),
        appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
        sharedPrefsProvider.overrideWithValue(sharedPreferences),
        projectsStateProvider.overrideWith(
          (ref) async => ProjectsState(items: [activeProject]),
        ),
        activeProjectProvider.overrideWith((ref) => activeProject),
        currentUserSettingsProvider.overrideWith(
          () => _TestUserSettingsNotifier(
            const AppSettings(
              id: 'settings-1',
              userId: 'user-1',
              defaultProjectId: 'project-1',
              projectSelectionMode: projectSelectionModeSelected,
            ),
          ),
        ),
        brandProfileBlueprintsStateProvider.overrideWith(
          (ref) async => BrandProfileBlueprintsState(
            items: hasActiveBlueprint
                ? [
                    BrandVideoBlueprint(
                      id: 'blueprint-1',
                      userId: 'user-1',
                      projectId: 'project-1',
                      brandProfileId: 'brand-1',
                      name: 'Default',
                      status: 'active',
                      createdAt: DateTime.utc(2026, 7, 8, 12),
                      updatedAt: DateTime.utc(2026, 7, 8, 12),
                    ),
                  ]
                : const [],
          ),
        ),
        pendingContentProvider.overrideWith(
          () => _TestPendingContentNotifier([
            ContentItem(
              id: 'content-ready',
              title: 'Ready title',
              body: 'Ready body',
              type: ContentType.blogPost,
              status: ContentStatus.pending,
              metadata: contentMetadata,
              createdAt: DateTime.utc(2026, 7, 8, 12),
            ),
          ]),
        ),
        personasProvider.overrideWith((ref) async => personas),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

class _FakeReadyAccessNotifier extends AppAccessNotifier {
  @override
  Future<AppAccessState> build() async {
    return AppAccessState(stage: AppAccessStage.ready);
  }
}

class _FakeBrandProfilesApiService extends ApiService {
  _FakeBrandProfilesApiService() : super(baseUrl: 'http://test');

  final List<_BrandedGenerationCall> brandedGenerationCalls = [];

  @override
  Future<List<BrandProfile>> fetchBrandProfiles({
    required String projectId,
  }) async {
    return [
      BrandProfile(
        id: 'brand-1',
        userId: 'user-1',
        projectId: projectId,
        name: 'Primary',
        primaryColors: const ['#111111'],
        isDefault: true,
        revision: 1,
        createdAt: DateTime.utc(2026, 7, 8, 12),
        updatedAt: DateTime.utc(2026, 7, 8, 12),
      ),
    ];
  }

  @override
  Future<List<BrandVideoBlueprint>> fetchBrandProfilesBlueprintsForProject({
    required String projectId,
  }) async {
    return [
      BrandVideoBlueprint(
        id: 'blueprint-1',
        userId: 'user-1',
        projectId: projectId,
        brandProfileId: 'brand-1',
        name: 'Default',
        status: 'active',
        createdAt: DateTime.utc(2026, 7, 8, 12),
        updatedAt: DateTime.utc(2026, 7, 8, 12),
      ),
    ];
  }

  @override
  Future<List<ContentItem>> fetchPendingContent({String? projectId}) async {
    return [
      ContentItem(
        id: 'content-draft',
        title: 'Draft title',
        body: 'Draft body',
        type: ContentType.blogPost,
        status: ContentStatus.pending,
        createdAt: DateTime.utc(2026, 7, 8, 12),
      ),
      ContentItem(
        id: 'content-ready',
        title: 'Ready title',
        body: 'Ready body',
        type: ContentType.blogPost,
        status: ContentStatus.pending,
        metadata: const {'content_complete': true},
        createdAt: DateTime.utc(2026, 7, 8, 12),
      ),
    ];
  }

  @override
  Future<BrandedVideoGenerationResponse> generateBrandedVideoFromContent({
    required String contentId,
    String formatPreset = 'vertical_9_16',
    String? brandProfileId,
    String? blueprintId,
    String? triggerSource,
    String? clientRequestId,
  }) async {
    brandedGenerationCalls.add(
      _BrandedGenerationCall(
        contentId: contentId,
        brandProfileId: brandProfileId,
        blueprintId: blueprintId,
        triggerSource: triggerSource,
        clientRequestId: clientRequestId,
      ),
    );

    final createdAt = DateTime.utc(2026, 7, 8, 12);
    final document = const VideoTimelineDocument(
      schemaVersion: '1.0',
      formatPreset: 'vertical_9_16',
      fps: 30,
      durationFrames: 150,
      tracks: [],
      clips: [],
    );
    final version = VideoTimelineVersion(
      versionId: 'version-1',
      timelineId: 'timeline-1',
      versionNumber: 1,
      timeline: document,
      rendererProps: const {},
      createdAt: createdAt,
    );
    final timeline = VideoTimelineResponse(
      timelineId: 'timeline-1',
      contentId: contentId,
      projectId: 'project-1',
      userId: 'user-1',
      formatPreset: formatPreset,
      currentVersionId: version.versionId,
      draftRevision: 1,
      draft: document,
      latestVersion: version,
      previewStatus: 'queued',
      finalStatus: 'missing',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final previewJob = VideoTimelineRenderJob(
      jobId: 'job-1',
      timelineId: timeline.timelineId,
      versionId: version.versionId,
      renderMode: 'preview',
      status: 'queued',
      progress: 0,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    return BrandedVideoGenerationResponse(
      timeline: timeline,
      version: version,
      previewJob: previewJob,
      readiness: 'ready',
      blockers: const [],
    );
  }
}

class _TestUserSettingsNotifier extends UserSettingsNotifier {
  _TestUserSettingsNotifier(this._settings);

  final AppSettings _settings;

  @override
  Future<AppSettings?> build() async {
    return _settings;
  }
}

class _TestPendingContentNotifier extends PendingContentNotifier {
  _TestPendingContentNotifier(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> build() async {
    return _items;
  }
}

Project _project({required String id, required String name}) {
  return Project(
    id: id,
    name: name,
    url: 'https://example.com/$id',
    createdAt: DateTime(2026, 4, 25),
  );
}

class _BrandedGenerationCall {
  const _BrandedGenerationCall({
    required this.contentId,
    required this.brandProfileId,
    required this.blueprintId,
    required this.triggerSource,
    required this.clientRequestId,
  });

  final String contentId;
  final String? brandProfileId;
  final String? blueprintId;
  final String? triggerSource;
  final String? clientRequestId;
}
