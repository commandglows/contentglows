import 'package:app/core/app_diagnostics.dart';
import 'package:app/data/models/app_access_state.dart';
import 'package:app/data/models/app_settings.dart';
import 'package:app/data/models/content_audit.dart';
import 'package:app/data/models/content_item.dart';
import 'package:app/data/models/project.dart';
import 'package:app/data/models/project_asset.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/presentation/screens/editor/editor_screen.dart';
import 'package:app/presentation/widgets/project_asset_picker.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('editing toolbar applies bold formatting to the body selection', (
    tester,
  ) async {
    final item = _contentItem(body: 'Original full body');
    final api = _EditorFakeApiService(item);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _OpenEditor()),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) =>
              EditorScreen(contentId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
          apiServiceProvider.overrideWithValue(api),
          appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
          publishAccountsStateProvider.overrideWith(
            (ref) async => const PublishAccountsState(accounts: []),
          ),
          contentHistoryProvider.overrideWith(
            (ref) async => const <ContentItem>[],
          ),
          pendingContentProvider.overrideWith(
            () => _TestPendingContentNotifier([item]),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bold'), findsOneWidget);

    final bodyField = tester.widget<TextField>(find.byType(TextField).last);
    final controller = bodyField.controller!;
    controller.value = controller.value.copyWith(
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
    );

    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    expect(controller.text, '**Original full body**');
  });

  testWidgets(
    'save and publish saves body before metadata and publishes edited body',
    (tester) async {
      final item = _contentItem(body: 'Original full body');
      final api = _EditorFakeApiService(item);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _OpenEditor()),
          GoRoute(
            path: '/editor/:id',
            builder: (context, state) =>
                EditorScreen(contentId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
            apiServiceProvider.overrideWithValue(api),
            appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
            publishAccountsStateProvider.overrideWith(
              (ref) async => const PublishAccountsState(
                accounts: [
                  PublishAccount(
                    id: 'account-1',
                    projectId: 'project-1',
                    provider: 'late',
                    platform: 'twitter',
                    providerAccountId: 'late-account-1',
                    username: 'creator',
                    displayName: 'Creator',
                    isDefault: true,
                  ),
                ],
              ),
            ),
            contentHistoryProvider.overrideWith(
              (ref) async => const <ContentItem>[],
            ),
            pendingContentProvider.overrideWith(
              () => _TestPendingContentNotifier([item]),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Edited full body');
      await tester.pump();

      await tester.tap(find.text('Save & Publish'));
      await tester.pumpAndSettle();

      expect(api.mutatingCalls, <String>[
        'saveContentBody',
        'updateContent',
        'approveContent',
        'publishContent',
      ]);
      expect(api.savedBody, 'Edited full body');
      expect(api.publishedContent, 'Edited full body');
    },
  );

  testWidgets('opens project asset picker from editor app bar', (tester) async {
    final item = _contentItem(body: 'Original full body');
    final api = _EditorFakeApiService(item);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _OpenEditor()),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) =>
              EditorScreen(contentId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
          apiServiceProvider.overrideWithValue(api),
          appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
          publishAccountsStateProvider.overrideWith(
            (ref) async => const PublishAccountsState(accounts: []),
          ),
          contentHistoryProvider.overrideWith(
            (ref) async => const <ContentItem>[],
          ),
          pendingContentProvider.overrideWith(
            () => _TestPendingContentNotifier([item]),
          ),
          activeProjectProvider.overrideWith((ref) => _project()),
          projectAssetLibraryProvider.overrideWith(() => _TestAssetNotifier()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Project assets'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectAssetPicker), findsOneWidget);
    expect(find.text('cover.png'), findsOneWidget);
  });

  testWidgets(
    'project assets button is disabled when no active project is selected',
    (tester) async {
      final item = _contentItem(body: 'Original full body');
      final api = _EditorFakeApiService(item);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _OpenEditor()),
          GoRoute(
            path: '/editor/:id',
            builder: (context, state) =>
                EditorScreen(contentId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
            apiServiceProvider.overrideWithValue(api),
            appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
            publishAccountsStateProvider.overrideWith(
              (ref) async => const PublishAccountsState(accounts: []),
            ),
            contentHistoryProvider.overrideWith(
              (ref) async => const <ContentItem>[],
            ),
            pendingContentProvider.overrideWith(
              () => _TestPendingContentNotifier([item]),
            ),
            activeProjectProvider.overrideWith((ref) => null),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Project assets'),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(ProjectAssetPicker), findsNothing);
    },
  );

  testWidgets('video timeline action opens /editor/:id/video', (tester) async {
    final item = _contentItem(body: 'Original full body');
    final api = _EditorFakeApiService(item);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _OpenEditor()),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) =>
              EditorScreen(contentId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/editor/:id/video',
          builder: (context, state) => Scaffold(
            body: Text('Video Route ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
          apiServiceProvider.overrideWithValue(api),
          appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
          publishAccountsStateProvider.overrideWith(
            (ref) async => const PublishAccountsState(accounts: []),
          ),
          contentHistoryProvider.overrideWith(
            (ref) async => const <ContentItem>[],
          ),
          pendingContentProvider.overrideWith(
            () => _TestPendingContentNotifier([item]),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Video timeline'));
    await tester.pumpAndSettle();

    expect(find.text('Video Route content-1'), findsOneWidget);
  });
}

ContentItem _contentItem({required String body}) {
  return ContentItem(
    id: 'content-1',
    title: 'Draft title',
    body: body,
    summary: 'Preview text only',
    type: ContentType.blogPost,
    status: ContentStatus.pending,
    channels: const [PublishingChannel.twitter],
    createdAt: DateTime(2026, 5, 2),
  );
}

class _OpenEditor extends StatelessWidget {
  const _OpenEditor();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.push('/editor/content-1'),
          child: const Text('Open editor'),
        ),
      ),
    );
  }
}

class _TestPendingContentNotifier extends PendingContentNotifier {
  _TestPendingContentNotifier(this.items);

  final List<ContentItem> items;

  @override
  Future<List<ContentItem>> build() async => items;
}

class _TestAccessNotifier extends AppAccessNotifier {
  @override
  Future<AppAccessState> build() async =>
      const AppAccessState(stage: AppAccessStage.ready);
}

class _EditorFakeApiService extends ApiService {
  _EditorFakeApiService(this.item) : super(baseUrl: 'http://test');

  final ContentItem item;
  final List<String> mutatingCalls = [];
  String? savedBody;
  String? publishedContent;

  @override
  Future<ContentItem> fetchContentDetail(
    String id, {
    ContentItem? fallback,
    bool allowStaleBodyCache = true,
  }) async {
    return item;
  }

  @override
  Future<ContentAuditTrail> fetchContentAuditTrail(String id) async {
    return const ContentAuditTrail(transitions: [], edits: []);
  }

  @override
  Future<bool> saveContentBody(
    String id,
    String body, {
    String? editNote,
  }) async {
    mutatingCalls.add('saveContentBody');
    savedBody = body;
    return true;
  }

  @override
  Future<bool> updateContent(String id, {String? title, String? body}) async {
    mutatingCalls.add('updateContent');
    return true;
  }

  @override
  Future<void> approveContent(String id) async {
    mutatingCalls.add('approveContent');
  }

  @override
  Future<Map<String, dynamic>> publishContent({
    required String content,
    required List<Map<String, String>> platforms,
    required String contentRecordId,
    String? title,
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    bool publishNow = true,
  }) async {
    mutatingCalls.add('publishContent');
    publishedContent = content;
    return {'success': true};
  }
}

Project _project() {
  return Project(
    id: 'project-1',
    name: 'Project One',
    url: 'https://example.com',
    createdAt: DateTime(2026, 5, 2),
  );
}

class _TestAssetNotifier extends ProjectAssetLibraryNotifier {
  @override
  Future<ProjectAssetLibraryState> build() async {
    return ProjectAssetLibraryState(
      projectId: 'project-1',
      assets: [
        ProjectAsset(
          id: 'asset-1',
          projectId: 'project-1',
          userId: 'user-1',
          mediaKind: 'image',
          source: 'image_robot',
          status: 'active',
          metadata: const {},
          storageDescriptor: const {'provider': 'bunny'},
          fileName: 'cover.png',
          createdAt: DateTime.utc(2026, 5, 11, 18),
          updatedAt: DateTime.utc(2026, 5, 11, 18),
        ),
      ],
      total: 1,
    );
  }
}
