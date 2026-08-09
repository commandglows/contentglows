import 'dart:async';

import 'package:app/data/models/project.dart';
import 'package:app/data/models/project_asset.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores stale responses when active project changes', () async {
    final api = _FakeAssetApiService();
    final activeProject =
        StateNotifierProvider<_ActiveProjectNotifier, Project?>(
          (ref) => _ActiveProjectNotifier(
            Project(
              id: 'project-a',
              name: 'A',
              url: '',
              isArchived: false,
              isDeleted: false,
              createdAt: DateTime.utc(2026, 5, 11, 18, 0),
            ),
          ),
        );

    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        projectAssetCategoryLocaleProvider.overrideWithValue('en'),
        activeProjectProvider.overrideWith((ref) => ref.watch(activeProject)),
      ],
    );
    addTearDown(container.dispose);

    final firstFuture = container.read(projectAssetLibraryProvider.future);
    container
        .read(activeProject.notifier)
        .setProject(
          Project(
            id: 'project-b',
            name: 'B',
            url: '',
            isArchived: false,
            isDeleted: false,
            createdAt: DateTime.utc(2026, 5, 11, 18, 0),
          ),
        );
    final state = await container.read(projectAssetLibraryProvider.future);
    await firstFuture;

    expect(state.projectId, 'project-b');
    expect(state.assets.single.id, 'asset-b');
  });

  test(
    'selectForTarget skips refresh and reselection when context becomes stale',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleMutationScenario(
        api: api,
        runMutation: (notifier) {
          return notifier.selectForTarget(
            assetId: 'asset-a',
            targetType: 'content',
            targetId: 'content-1',
            usageAction: 'select_for_content',
          );
        },
      );
    },
  );

  test(
    'selectForTarget skips reselection when context changes during refresh',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleRefreshReselectScenario(
        api: api,
        runMutation: (notifier) {
          return notifier.selectForTarget(
            assetId: 'asset-a',
            targetType: 'content',
            targetId: 'content-1',
            usageAction: 'select_for_content',
          );
        },
      );
    },
  );

  test(
    'setPrimary skips refresh and reselection when context becomes stale',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleMutationScenario(
        api: api,
        runMutation: (notifier) {
          return notifier.setPrimary(
            assetId: 'asset-a',
            targetType: 'content',
            targetId: 'content-1',
            usageAction: 'set_primary',
          );
        },
      );
    },
  );

  test(
    'setPrimary skips reselection when context changes during refresh',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleRefreshReselectScenario(
        api: api,
        runMutation: (notifier) {
          return notifier.setPrimary(
            assetId: 'asset-a',
            targetType: 'content',
            targetId: 'content-1',
            usageAction: 'set_primary',
          );
        },
      );
    },
  );

  test('clearPrimary skips refresh when context becomes stale', () async {
    final api = _FakeAssetApiService();
    await _runStaleMutationScenario(
      api: api,
      runMutation: (notifier) {
        return notifier.clearPrimary(
          targetType: 'content',
          targetId: 'content-1',
        );
      },
      expectReselect: false,
    );
  });

  test(
    'tombstoneAsset skips refresh and reselection when context becomes stale',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleMutationScenario(
        api: api,
        runMutation: (notifier) => notifier.tombstoneAsset('asset-a'),
      );
    },
  );

  test(
    'tombstoneAsset skips reselection when context changes during refresh',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleRefreshReselectScenario(
        api: api,
        runMutation: (notifier) => notifier.tombstoneAsset('asset-a'),
      );
    },
  );

  test(
    'restoreAsset skips refresh and reselection when context becomes stale',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleMutationScenario(
        api: api,
        runMutation: (notifier) => notifier.restoreAsset('asset-a'),
      );
    },
  );

  test(
    'restoreAsset skips reselection when context changes during refresh',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleRefreshReselectScenario(
        api: api,
        runMutation: (notifier) => notifier.restoreAsset('asset-a'),
      );
    },
  );

  test('loads category catalog and sends exact category filter', () async {
    final api = _FakeAssetApiService();
    final activeProject =
        StateNotifierProvider<_ActiveProjectNotifier, Project?>(
          (ref) => _ActiveProjectNotifier(_project('project-a', 'A')),
        );
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        projectAssetCategoryLocaleProvider.overrideWithValue('en'),
        activeProjectProvider.overrideWith((ref) => ref.watch(activeProject)),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(projectAssetLibraryProvider.future);
    expect(
      initial.categoryCatalog?.categories.single.categoryId,
      'editorial_visual',
    );

    container
        .read(projectAssetLibraryProvider.notifier)
        .setCategoryFilter('editorial_visual');
    final filtered = await container.read(projectAssetLibraryProvider.future);

    expect(filtered.categoryFilter, 'editorial_visual');
    expect(api.categoryFilters.last, 'editorial_visual');
  });

  test(
    'assignCategory sends canonical ids without stale state bleed',
    () async {
      final api = _FakeAssetApiService();
      await _runStaleMutationScenario(
        api: api,
        runMutation: (notifier) => notifier.assignCategory(
          assetId: 'asset-a',
          categoryId: 'editorial_visual',
          subcategoryId: 'infographic',
        ),
      );

      expect(api.assignmentCalls, [
        'project-a:asset-a:editorial_visual:infographic',
      ]);
    },
  );
}

typedef _MutationRunner =
    Future<dynamic> Function(ProjectAssetLibraryNotifier notifier);

Future<void> _runStaleMutationScenario({
  required _FakeAssetApiService api,
  required _MutationRunner runMutation,
  bool expectReselect = true,
}) async {
  final activeProject = StateNotifierProvider<_ActiveProjectNotifier, Project?>(
    (ref) => _ActiveProjectNotifier(_project('project-a', 'A')),
  );
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      projectAssetCategoryLocaleProvider.overrideWithValue('en'),
      activeProjectProvider.overrideWith((ref) => ref.watch(activeProject)),
    ],
  );
  addTearDown(container.dispose);

  final initial = await container.read(projectAssetLibraryProvider.future);
  expect(initial.projectId, 'project-a');

  final notifier = container.read(projectAssetLibraryProvider.notifier);
  final mutationFuture = runMutation(notifier);
  await Future<void>.delayed(Duration.zero);
  container.read(activeProject.notifier).setProject(_project('project-b', 'B'));
  final stateAfterSwitch = await container.read(
    projectAssetLibraryProvider.future,
  );
  await mutationFuture;

  expect(stateAfterSwitch.projectId, 'project-b');
  expect(stateAfterSwitch.assets.single.id, 'asset-b');
  expect(api.listCallProjectIds, ['project-a', 'project-b']);
  if (expectReselect) {
    expect(api.detailCallPairs, isEmpty);
    expect(api.usageCallPairs, isEmpty);
    expect(api.eventCallPairs, isEmpty);
  }
}

Future<void> _runStaleRefreshReselectScenario({
  required _FakeAssetApiService api,
  required _MutationRunner runMutation,
}) async {
  final activeProject = StateNotifierProvider<_ActiveProjectNotifier, Project?>(
    (ref) => _ActiveProjectNotifier(_project('project-a', 'A')),
  );
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      projectAssetCategoryLocaleProvider.overrideWithValue('en'),
      activeProjectProvider.overrideWith((ref) => ref.watch(activeProject)),
    ],
  );
  addTearDown(container.dispose);

  final initial = await container.read(projectAssetLibraryProvider.future);
  expect(initial.projectId, 'project-a');

  final notifier = container.read(projectAssetLibraryProvider.notifier);
  final mutationFuture = runMutation(notifier);
  await api.secondProjectAListStarted.future;

  container.read(activeProject.notifier).setProject(_project('project-b', 'B'));
  final stateAfterSwitch = await container.read(
    projectAssetLibraryProvider.future,
  );
  await mutationFuture;

  expect(stateAfterSwitch.projectId, 'project-b');
  expect(stateAfterSwitch.assets.single.id, 'asset-b');
  expect(api.listCallProjectIds, ['project-a', 'project-a', 'project-b']);
  expect(api.detailCallPairs, isEmpty);
  expect(api.usageCallPairs, isEmpty);
  expect(api.eventCallPairs, isEmpty);
}

class _ActiveProjectNotifier extends StateNotifier<Project?> {
  _ActiveProjectNotifier(super.state);

  void setProject(Project? value) {
    state = value;
  }
}

class _FakeAssetApiService extends ApiService {
  _FakeAssetApiService() : super(baseUrl: 'http://test');

  final List<String> listCallProjectIds = [];
  final List<String> detailCallPairs = [];
  final List<String> usageCallPairs = [];
  final List<String> eventCallPairs = [];
  final List<String?> categoryFilters = [];
  final List<String> assignmentCalls = [];
  final Completer<void> secondProjectAListStarted = Completer<void>();

  Future<void> _delayForProject(String projectId) async {
    if (projectId == 'project-a') {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  Future<ProjectAssetListResponse> listProjectAssets({
    required String projectId,
    String? mediaKind,
    String? source,
    String? categoryId,
    String? subcategoryId,
    bool includeTombstoned = false,
    int limit = 50,
    int offset = 0,
  }) async {
    listCallProjectIds.add(projectId);
    categoryFilters.add(categoryId);
    if (projectId == 'project-a' &&
        listCallProjectIds.where((id) => id == 'project-a').length == 2 &&
        !secondProjectAListStarted.isCompleted) {
      secondProjectAListStarted.complete();
    }
    await _delayForProject(projectId);
    return ProjectAssetListResponse(
      items: [
        _asset(
          id: projectId == 'project-a' ? 'asset-a' : 'asset-b',
          projectId: projectId,
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<ProjectAssetCategoryCatalog> getProjectAssetCategoryCatalog({
    required String projectId,
    String? locale,
  }) async {
    return const ProjectAssetCategoryCatalog(
      version: '2026-08-07.1',
      locale: 'en',
      supportedLocales: ['en', 'fr'],
      categories: [
        ProjectAssetCategory(
          categoryId: 'editorial_visual',
          label: 'Editorial visual',
          subcategories: [
            ProjectAssetSubcategory(
              subcategoryId: 'infographic',
              label: 'Infographic',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<ProjectAsset> assignProjectAssetCategory({
    required String projectId,
    required String assetId,
    String? categoryId,
    String? subcategoryId,
  }) async {
    assignmentCalls.add('$projectId:$assetId:$categoryId:$subcategoryId');
    await _delayForProject(projectId);
    return _asset(id: assetId, projectId: projectId);
  }

  @override
  Future<ProjectAssetUsage> selectProjectAsset({
    required String projectId,
    required String assetId,
    required String targetType,
    required String targetId,
    required String usageAction,
    String? placement,
    bool isPrimary = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    await _delayForProject(projectId);
    return _usage(
      projectId: projectId,
      assetId: assetId,
      usageAction: usageAction,
    );
  }

  @override
  Future<ProjectAssetUsage> setProjectAssetPrimary({
    required String projectId,
    required String assetId,
    required String targetType,
    required String targetId,
    required String usageAction,
    String? placement,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    await _delayForProject(projectId);
    return _usage(
      projectId: projectId,
      assetId: assetId,
      usageAction: usageAction,
    );
  }

  @override
  Future<int> clearProjectAssetPrimary({
    required String projectId,
    required String targetType,
    required String targetId,
    String? placement,
  }) async {
    await _delayForProject(projectId);
    return 1;
  }

  @override
  Future<ProjectAsset> tombstoneProjectAsset({
    required String projectId,
    required String assetId,
  }) async {
    await _delayForProject(projectId);
    return _asset(id: assetId, projectId: projectId);
  }

  @override
  Future<ProjectAsset> restoreProjectAsset({
    required String projectId,
    required String assetId,
  }) async {
    await _delayForProject(projectId);
    return _asset(id: assetId, projectId: projectId);
  }

  @override
  Future<ProjectAsset> getProjectAssetDetail({
    required String projectId,
    required String assetId,
  }) async {
    detailCallPairs.add('$projectId:$assetId');
    return _asset(id: assetId, projectId: projectId);
  }

  @override
  Future<List<ProjectAssetUsage>> getProjectAssetUsage({
    required String projectId,
    required String assetId,
  }) async {
    usageCallPairs.add('$projectId:$assetId');
    return [
      _usage(
        projectId: projectId,
        assetId: assetId,
        usageAction: 'select_for_content',
      ),
    ];
  }

  @override
  Future<List<ProjectAssetEvent>> getProjectAssetEvents({
    required String projectId,
    required String assetId,
    int limit = 50,
  }) async {
    eventCallPairs.add('$projectId:$assetId');
    return [
      ProjectAssetEvent(
        id: 'event-1',
        assetId: assetId,
        projectId: projectId,
        userId: 'user-1',
        eventType: 'selected',
        metadata: const {},
        createdAt: DateTime.utc(2026, 5, 11, 18, 0),
      ),
    ];
  }
}

Project _project(String id, String name) {
  return Project(
    id: id,
    name: name,
    url: '',
    isArchived: false,
    isDeleted: false,
    createdAt: DateTime.utc(2026, 5, 11, 18, 0),
  );
}

ProjectAsset _asset({required String id, required String projectId}) {
  return ProjectAsset(
    id: id,
    projectId: projectId,
    userId: 'user-1',
    mediaKind: 'image',
    source: 'image_robot',
    status: 'active',
    metadata: const {},
    storageDescriptor: const {'provider': 'bunny'},
    createdAt: DateTime.utc(2026, 5, 11, 18, 0),
    updatedAt: DateTime.utc(2026, 5, 11, 18, 0),
  );
}

ProjectAssetUsage _usage({
  required String projectId,
  required String assetId,
  required String usageAction,
}) {
  return ProjectAssetUsage(
    id: 'usage-$assetId',
    assetId: assetId,
    projectId: projectId,
    userId: 'user-1',
    targetType: 'content',
    targetId: 'content-1',
    usageAction: usageAction,
    isPrimary: false,
    metadata: const {},
    createdAt: DateTime.utc(2026, 5, 11, 18, 0),
    updatedAt: DateTime.utc(2026, 5, 11, 18, 0),
  );
}
