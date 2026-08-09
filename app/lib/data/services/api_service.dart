import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import '../../core/app_diagnostics.dart';
import '../../core/project_onboarding_validation.dart';
import '../demo/demo_seed.dart';
import '../models/affiliate_link.dart';
import '../models/ai_image_generation.dart';
import '../models/ai_runtime.dart';
import '../models/brand_profile.dart';
import '../models/app_bootstrap.dart';
import '../models/app_settings.dart';
import '../models/capture_asset.dart';
import '../models/content_audit.dart';
import '../models/content_item.dart';
import '../models/creator_profile.dart';
import '../models/drip_plan.dart';
import '../models/email_source.dart';
import '../models/feedback_entry.dart';
import '../models/idea.dart';
import '../models/offline_sync.dart';
import '../models/openrouter_credential.dart';
import '../models/persona.dart';
import '../models/project.dart';
import '../models/project_asset.dart';
import '../models/project_intelligence.dart';
import '../models/ritual.dart';
import '../models/search_console.dart';
import '../models/social_placement.dart';
import '../models/video_timeline.dart';
import '../models/video_source_intake.dart';
import 'offline_storage_service.dart';

enum ApiErrorType { unauthorized, offline, server, invalidResponse, unknown }

class ApiException implements Exception {
  const ApiException(
    this.type,
    this.message, {
    this.statusCode,
    this.responseBody,
    this.responseHeaders = const <String, String>{},
    this.method,
    this.path,
    this.code,
    this.kind,
    this.provider,
    this.settingsPath,
    this.retryable,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final String? responseBody;
  final Map<String, String> responseHeaders;
  final String? method;
  final String? path;
  final String? code;
  final String? kind;
  final String? provider;
  final String? settingsPath;
  final bool? retryable;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;
  bool get isOffline => type == ApiErrorType.offline;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    required String baseUrl,
    String? authToken,
    this.authTokenProvider,
    this.allowDemoData = false,
    this.diagnostics,
    this.onUnauthorized,
    this.cacheStore,
    this.queueStore,
    this.idMappingStore,
    this.offlineScope = 'signed_out',
    this.onCacheKeyFresh,
    this.onCacheKeyStale,
    this.onQueueUpdated,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (authToken != null && authToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $authToken';
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final provider = authTokenProvider;
          if (provider != null) {
            final token = await provider();
            if (token == null || token.isEmpty) {
              options.headers.remove('Authorization');
            } else {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          final requestId = ++_requestSequence;
          options.extra['requestId'] = requestId;
          options.extra['requestStartedAtMs'] =
              DateTime.now().millisecondsSinceEpoch;
          diagnostics?.info(
            scope: 'api.request',
            message: '${options.method.toUpperCase()} ${options.path}',
            context: {
              'requestId': requestId,
              'baseUrl': options.baseUrl,
              'path': options.path,
              'query': options.queryParameters.isEmpty
                  ? 'none'
                  : options.queryParameters,
              'hasAuthorization': options.headers.containsKey('Authorization'),
            },
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          diagnostics?.info(
            scope: 'api.response',
            message:
                '${response.requestOptions.method.toUpperCase()} ${response.requestOptions.path} -> ${response.statusCode ?? 'unknown'}',
            context: {
              'requestId': response.requestOptions.extra['requestId'],
              'statusCode': response.statusCode,
              'durationMs': _requestDurationMs(response.requestOptions),
            },
          );
          handler.next(response);
        },
        onError: (error, handler) {
          diagnostics?.error(
            scope: 'api.error',
            message:
                '${error.requestOptions.method.toUpperCase()} ${error.requestOptions.path} failed.',
            error: error,
            stackTrace: error.stackTrace,
            context: {
              'requestId': error.requestOptions.extra['requestId'],
              'statusCode': error.response?.statusCode,
              'durationMs': _requestDurationMs(error.requestOptions),
              'responseBody': _safeDiagnosticResponseBody(
                error.requestOptions,
                error.response?.data,
              ),
              'responseHeaders': _flattenHeaders(error.response?.headers),
            },
          );
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final Future<String?> Function()? authTokenProvider;
  final bool allowDemoData;
  final AppDiagnostics? diagnostics;
  final void Function()? onUnauthorized;
  final OfflineCacheStore? cacheStore;
  final OfflineQueueStore? queueStore;
  final OfflineIdMappingStore? idMappingStore;
  final String offlineScope;
  final Future<void> Function(String cacheKey)? onCacheKeyFresh;
  final Future<void> Function(String cacheKey)? onCacheKeyStale;
  final Future<void> Function(List<QueuedOfflineAction> queue)? onQueueUpdated;
  int _requestSequence = 0;

  static const _bootstrapCacheKey = 'bootstrap';
  static const _projectsCacheKey = 'projects';
  static const _settingsCacheKey = 'settings';
  static const _creatorProfileCacheKey = 'creator_profile';
  static const _pendingContentCacheKey = 'content.pending_review';
  static const _contentHistoryCacheKey = 'content.history';
  static const _personasCacheKey = 'personas';
  static const _publishAccountsCacheKey = 'publish.accounts';
  static const _feedbackAdminCacheKey = 'feedback.admin';
  static const _affiliationsCacheKey = 'affiliations';
  static const _brandProfilesCacheKey = 'brand_profiles';
  static const _ideasCacheKey = 'ideas';
  static const _dripPlansCacheKey = 'drip.plans';
  static const _searchConsoleStatusCacheKey = 'search_console.status';
  static const _projectIntelligenceStatusCacheKey =
      'project_intelligence.status';

  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void updateAuthToken(String? authToken) {
    if (authToken == null || authToken.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return;
    }
    _dio.options.headers['Authorization'] = 'Bearer $authToken';
  }

  Map<String, dynamic> _compactMap(Map<String, dynamic> values) {
    values.removeWhere((_, value) => value == null);
    return values;
  }

  String _queryFingerprint(Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return '';
    }
    final entries = queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}=${entry.value}').join('&');
  }

  String _cacheKeyFor(String base, [Map<String, dynamic>? queryParameters]) {
    final fingerprint = _queryFingerprint(queryParameters);
    if (fingerprint.isEmpty) {
      return base;
    }
    return '$base?$fingerprint';
  }

  Future<dynamic> _getCachedData(
    String path, {
    String? cacheKey,
    Map<String, dynamic>? queryParameters,
  }) async {
    final resolvedCacheKey = cacheKey ?? _cacheKeyFor(path, queryParameters);

    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      await cacheStore?.write(offlineScope, resolvedCacheKey, response.data);
      await onCacheKeyFresh?.call(resolvedCacheKey);
      return response.data;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isUnauthorized) {
        final cached = await cacheStore?.read(offlineScope, resolvedCacheKey);
        if (cached != null) {
          await onCacheKeyStale?.call(resolvedCacheKey);
          return cached.data;
        }
      }
      throw mapped;
    }
  }

  Future<Map<String, dynamic>?> _readCachedMap(String cacheKey) async {
    final cached = await cacheStore?.read(offlineScope, cacheKey);
    return _asMapOrNull(cached?.data);
  }

  Future<List<dynamic>?> _readCachedList(String cacheKey) async {
    final cached = await cacheStore?.read(offlineScope, cacheKey);
    final data = cached?.data;
    if (data is List) {
      return data;
    }
    return null;
  }

  Future<void> _writeCachedData(String cacheKey, Object? data) async {
    await cacheStore?.write(offlineScope, cacheKey, data);
    await onCacheKeyFresh?.call(cacheKey);
  }

  Future<AppBootstrap?> loadCachedBootstrap() async {
    final cached = await _readCachedMap(_bootstrapCacheKey);
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return AppBootstrap.fromJson(cached);
  }

  Future<Map<String, String>> _loadIdMappings() async {
    return await idMappingStore?.load(offlineScope) ?? const <String, String>{};
  }

  bool _isOfflineTempId(String? id) {
    return id != null && id.startsWith('offline-');
  }

  String _resolveEntityId(String id, [Map<String, String>? idMappings]) {
    final mappings = idMappings ?? const <String, String>{};
    return mappings[id] ?? id;
  }

  List<String> _dependsOnTempIdsForIds(
    Iterable<String?> ids, [
    Map<String, String>? idMappings,
  ]) {
    final mappings = idMappings ?? const <String, String>{};
    final unresolved = <String>{};
    for (final id in ids) {
      if (_isOfflineTempId(id) && !mappings.containsKey(id)) {
        unresolved.add(id!);
      }
    }
    return unresolved.toList()..sort();
  }

  Map<String, dynamic> _offlineActionMeta({
    String? entityType,
    String? entityId,
    String? tempId,
    List<String> dependsOnTempIds = const <String>[],
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return {
      if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
      if (entityId != null && entityId.isNotEmpty) 'entityId': entityId,
      if (tempId != null && tempId.isNotEmpty) 'tempId': tempId,
      if (dependsOnTempIds.isNotEmpty) 'dependsOnTempIds': dependsOnTempIds,
      ...extra,
    };
  }

  String _newOfflineTempId(String resourceType) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'offline-$resourceType-$timestamp';
  }

  Future<List<Project>> _readCachedProjects() async {
    return (await _readCachedList(_projectsCacheKey) ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => Project.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> _upsertCachedProject(Project project) async {
    final projects = await _readCachedProjects();
    final nextProjects = [
      for (final entry in projects)
        if (entry.id != project.id) entry,
      project,
    ];
    await _writeCachedData(
      _projectsCacheKey,
      nextProjects.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> _syncCachedProjectDefaults(String? defaultProjectId) async {
    final projects = await _readCachedProjects();
    if (projects.isEmpty) {
      return;
    }

    final nextProjects = projects
        .map(
          (entry) => entry.copyWith(
            isDefault: defaultProjectId != null && entry.id == defaultProjectId,
          ),
        )
        .toList();
    await _writeCachedData(
      _projectsCacheKey,
      nextProjects.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> _syncBootstrapCache({
    String? defaultProjectId,
    bool updateDefaultProject = false,
    bool syncProjectDefaults = true,
    bool? workspaceExists,
    String? workspaceStatus,
    int? projectsCount,
  }) async {
    final current = await _readCachedMap(_bootstrapCacheKey);
    final user = <String, dynamic>{
      ...?_asMapOrNull(current?['user']),
      'user_id': _asMapOrNull(current?['user'])?['user_id'] ?? offlineScope,
    };
    final cachedProjectsCount =
        (await _readCachedList(_projectsCacheKey))?.length ?? 0;
    final currentProjectsCount =
        (current?['projects_count'] as num?)?.toInt() ?? cachedProjectsCount;
    final resolvedProjectsCount =
        projectsCount ??
        (currentProjectsCount > cachedProjectsCount
            ? currentProjectsCount
            : cachedProjectsCount);
    final resolvedWorkspaceExists =
        workspaceExists ??
        (resolvedProjectsCount > 0 || user['workspace_exists'] == true);

    user['workspace_exists'] = resolvedWorkspaceExists;
    if (updateDefaultProject) {
      user['default_project_id'] = defaultProjectId;
    }

    final next = <String, dynamic>{
      ...?current,
      'user': user,
      'projects_count': resolvedProjectsCount,
      'workspace_status':
          workspaceStatus ??
          (resolvedWorkspaceExists
              ? 'ready'
              : (current?['workspace_status'] ?? 'missing')),
    };
    if (updateDefaultProject) {
      next['default_project_id'] = defaultProjectId;
    }

    await _writeCachedData(_bootstrapCacheKey, next);
    if (updateDefaultProject && syncProjectDefaults) {
      await _syncCachedProjectDefaults(defaultProjectId);
    }
  }

  Future<void> _upsertCachedPersona(Persona persona) async {
    final personas =
        (await _readCachedList(_personasCacheKey) ?? const <dynamic>[])
            .map((entry) => Persona.fromJson(_normalizePersonaJson(entry)))
            .toList();
    final nextPersonas = [
      for (final entry in personas)
        if (entry.id != persona.id) entry,
      persona,
    ];
    await _writeCachedData(
      _personasCacheKey,
      nextPersonas.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> _upsertCachedAffiliation(AffiliateLink link) async {
    final cacheKeys = <String>{_cacheKeyFor(_affiliationsCacheKey)};
    if (link.projectId != null && link.projectId!.trim().isNotEmpty) {
      cacheKeys.add(
        _cacheKeyFor(_affiliationsCacheKey, {'projectId': link.projectId}),
      );
    }

    for (final cacheKey in cacheKeys) {
      final cached = await _readCachedList(cacheKey) ?? const <dynamic>[];
      final cachedLinks = cached
          .whereType<Map>()
          .map(
            (entry) => AffiliateLink.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
      final next = [
        for (final entry in cachedLinks)
          if (entry.id != link.id) entry,
        link,
      ];
      await _writeCachedData(
        cacheKey,
        next.map((entry) => entry.toJson()).toList(),
      );
    }
  }

  Future<List<ContentItem>> _readCachedPendingContentItems() async {
    return (await _readCachedList(_pendingContentCacheKey) ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => ContentItem.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> _upsertCachedPendingContentItem(ContentItem item) async {
    final current = await _readCachedPendingContentItems();
    final next = [
      for (final entry in current)
        if (entry.id != item.id) entry,
      item,
    ];
    await _writeCachedData(
      _pendingContentCacheKey,
      next.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> _removeCachedPendingContentItem(String id) async {
    final current = await _readCachedPendingContentItems();
    final next = current.where((entry) => entry.id != id).toList();
    await _writeCachedData(
      _pendingContentCacheKey,
      next.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<List<DripPlan>> _readCachedDripPlans() async {
    return (await _readCachedList(_dripPlansCacheKey) ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => DripPlan.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  String _dripPlanCacheKey(String planId) => 'drip.plan.$planId';
  String _dripStatsCacheKey(String planId) => 'drip.stats.$planId';

  Future<void> _upsertCachedDripPlan(DripPlan plan) async {
    final current = await _readCachedDripPlans();
    final next = [
      for (final entry in current)
        if (entry.id != plan.id) entry,
      plan,
    ];
    await _writeCachedData(
      _dripPlansCacheKey,
      next.map((entry) => entry.toJson()).toList(),
    );
    await _writeCachedData(_dripPlanCacheKey(plan.id), plan.toJson());
  }

  Future<DripPlan?> _readCachedDripPlan(String planId) async {
    final cached = await _readCachedMap(_dripPlanCacheKey(planId));
    if (cached != null && cached.isNotEmpty) {
      return DripPlan.fromJson(cached);
    }
    final plans = await _readCachedDripPlans();
    for (final plan in plans) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  Future<void> _writeCachedDripStats(
    String planId,
    Map<String, dynamic> stats,
  ) async {
    await _writeCachedData(_dripStatsCacheKey(planId), stats);
  }

  Future<List<QueuedOfflineAction>> _enqueueOfflineAction({
    required String resourceType,
    required String actionType,
    required String label,
    required String method,
    required String path,
    required String dedupeKey,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> meta = const <String, dynamic>{},
    bool mergePayload = true,
  }) async {
    final store = queueStore;
    if (store == null) {
      return const <QueuedOfflineAction>[];
    }

    final idMappings = await _loadIdMappings();
    final rewrittenPath = rewriteOfflineIdsInString(path, idMappings);
    final rewrittenDedupeKey = rewriteOfflineIdsInString(dedupeKey, idMappings);
    final rewrittenPayload = _asMapOrNull(
      rewriteOfflineIdsInValue(payload, idMappings),
    );
    final rewrittenQueryParameters = _asMapOrNull(
      rewriteOfflineIdsInValue(queryParameters, idMappings),
    );
    final rewrittenMeta =
        _asMapOrNull(rewriteOfflineIdsInValue(meta, idMappings)) ??
        const <String, dynamic>{};

    final now = DateTime.now();
    final nextAction = QueuedOfflineAction(
      id: '${now.microsecondsSinceEpoch}-${_requestSequence + 1}',
      userScope: offlineScope,
      resourceType: resourceType,
      actionType: actionType,
      label: label,
      method: method.toUpperCase(),
      path: rewrittenPath,
      dedupeKey: rewrittenDedupeKey,
      payload: rewrittenPayload,
      queryParameters: rewrittenQueryParameters,
      meta: rewrittenMeta,
      createdAt: now,
      updatedAt: now,
    );

    final current = await store.load(offlineScope);
    final index = current.indexWhere(
      (entry) =>
          entry.dedupeKey == rewrittenDedupeKey &&
          entry.status != OfflineQueueStatus.cancelled,
    );

    final next = [...current];
    if (index >= 0) {
      final previous = next[index];
      next[index] = previous.copyWith(
        resourceType: resourceType,
        actionType: actionType,
        label: label,
        method: method.toUpperCase(),
        path: rewrittenPath,
        dedupeKey: rewrittenDedupeKey,
        payload: mergePayload
            ? _mergeMaps(previous.payload, rewrittenPayload)
            : rewrittenPayload,
        queryParameters: rewrittenQueryParameters ?? previous.queryParameters,
        meta: {...previous.meta, ...rewrittenMeta},
        status: OfflineQueueStatus.pending,
        updatedAt: now,
        attemptCount: 0,
        clearLastError: true,
      );
    } else {
      next.add(nextAction);
    }

    await store.save(offlineScope, next);
    await onQueueUpdated?.call(next);
    return next;
  }

  Future<dynamic> replayQueuedAction(QueuedOfflineAction action) async {
    final idMappings = await _loadIdMappings();
    final resolvedAction = action.rewriteIds(idMappings);
    try {
      final response = await _dio.request<dynamic>(
        resolvedAction.path,
        data: resolvedAction.payload,
        queryParameters: resolvedAction.queryParameters,
        options: Options(method: resolvedAction.method),
      );
      return response.data;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (resolvedAction.resourceType == 'projects' &&
          resolvedAction.actionType == 'create' &&
          (mapped.statusCode == 404 || mapped.statusCode == 405)) {
        final name = resolvedAction.payload?['name']?.toString() ?? '';
        final sourceUrl = normalizeOptionalText(
          resolvedAction.payload?['source_url']?.toString() ??
              resolvedAction.payload?['github_url']?.toString(),
        );
        await onboardProject(sourceUrl, name);
        final projects = await fetchProjects();
        final normalizedName = name.trim().toLowerCase();
        final project = projects.firstWhere(
          (entry) => entry.name.trim().toLowerCase() == normalizedName,
          orElse: () => projects.first,
        );
        return project.toJson();
      }
      throw mapped;
    }
  }

  Future<ApiException> _queueOrThrow({
    required ApiException error,
    required String resourceType,
    required String actionType,
    required String label,
    required String method,
    required String path,
    required String dedupeKey,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> meta = const <String, dynamic>{},
    bool mergePayload = true,
    String? blockedMessage,
  }) async {
    if (!error.isOffline) {
      return error;
    }

    if (blockedMessage != null) {
      return ApiException(
        ApiErrorType.offline,
        blockedMessage,
        statusCode: error.statusCode,
        responseBody: error.responseBody,
        responseHeaders: error.responseHeaders,
        method: error.method,
        path: error.path,
      );
    }

    await _enqueueOfflineAction(
      resourceType: resourceType,
      actionType: actionType,
      label: label,
      method: method,
      path: path,
      dedupeKey: dedupeKey,
      payload: payload,
      queryParameters: queryParameters,
      meta: meta,
      mergePayload: mergePayload,
    );
    return ApiException(
      ApiErrorType.offline,
      '$label queued until FastAPI is available again.',
      statusCode: error.statusCode,
      responseBody: error.responseBody,
      responseHeaders: error.responseHeaders,
      method: method,
      path: path,
    );
  }

  Map<String, dynamic>? _asMapOrNull(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Map<String, dynamic>? _mergeMaps(
    Map<String, dynamic>? current,
    Map<String, dynamic>? next,
  ) {
    if (current == null) {
      return next;
    }
    if (next == null) {
      return current;
    }
    return {...current, ...next};
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return _asMap(response.data, fallback: const {'status': 'offline'});
    } on DioException {
      return {'status': 'offline'};
    }
  }

  Future<List<Project>> fetchProjects() async {
    if (allowDemoData) {
      return _mockProjects();
    }

    final data = await _getCachedData(
      '/api/projects',
      cacheKey: _projectsCacheKey,
    );
    final items = data is List ? data : (_asMap(data)['projects'] ?? []);
    if (items is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid projects response from FastAPI.',
      );
    }
    return items
        .map((json) => Project.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<BrandProfile>> fetchBrandProfiles({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <BrandProfile>[];
    }

    final data = await _getCachedData(
      '/api/brand-profiles',
      cacheKey: _cacheKeyFor(_brandProfilesCacheKey, {'projectId': projectId}),
      queryParameters: {'projectId': projectId},
    );
    final items = data is List ? data : (_asMap(data)['items'] ?? []);
    if (items is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid brand profiles response from FastAPI.',
      );
    }
    return items.map((json) => BrandProfile.fromJson(_asMap(json))).toList();
  }

  Future<BrandProfile> createBrandProfile({
    required String projectId,
    required BrandProfileDraft draft,
  }) async {
    final payload = _compactMap({
      'project_id': projectId,
      ...draft.toCreateJson(),
    });
    try {
      final response = await _dio.post('/api/brand-profiles', data: payload);
      return BrandProfile.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<BrandProfile> updateBrandProfile({
    required String brandProfileId,
    required BrandProfileDraft draft,
  }) async {
    final payload = _compactMap(draft.toUpdateJson());
    try {
      final response = await _dio.patch(
        '/api/brand-profiles/$brandProfileId',
        data: payload,
      );
      return BrandProfile.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<BrandProfile> setDefaultBrandProfile({
    required String brandProfileId,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/brand-profiles/$brandProfileId',
        data: {'is_default': true},
      );
      return BrandProfile.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> deleteBrandProfile({required String brandProfileId}) async {
    try {
      await _dio.delete('/api/brand-profiles/$brandProfileId');
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchBrandVideoBlueprints({
    required String projectId,
    required String brandProfileId,
  }) async {
    if (allowDemoData) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final response = await _dio.get(
        '/api/brand-video-blueprints',
        queryParameters: {
          'projectId': projectId,
          'brandProfileId': brandProfileId,
        },
      );
      final data = response.data;
      if (data is! List) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid brand video blueprints response from FastAPI.',
        );
      }
      return data.whereType<Map>().map((item) => _asMap(item)).toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> createBrandVideoBlueprint({
    required String projectId,
    required String brandProfileId,
    required String name,
    required String defaultArchetype,
  }) async {
    try {
      final response = await _dio.post(
        '/api/brand-video-blueprints',
        data: {
          'project_id': projectId,
          'brand_profile_id': brandProfileId,
          'name': name,
          'status': 'active',
          'default_archetype': defaultArchetype,
        },
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> onboardProject(String? sourceUrl, String name) async {
    try {
      await _dio.post(
        '/api/projects/onboard',
        data: _compactMap({
          'source_url': normalizeOptionalText(sourceUrl),
          'name': name.trim(),
        }),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Project> createProject({
    required String name,
    String? sourceUrl,
    List<ContentTypeConfig> contentTypes = const <ContentTypeConfig>[],
  }) async {
    final normalizedName = name.trim();
    final normalizedSourceUrl = normalizeOptionalText(sourceUrl);
    final payload = _compactMap({
      'name': normalizedName,
      'source_url': normalizedSourceUrl,
      'content_types': contentTypes.map((entry) => entry.toJson()).toList(),
    });
    try {
      final response = await _dio.post('/api/projects', data: payload);
      final project = Project.fromJson(_asMap(response.data));
      await _upsertCachedProject(project);
      await _syncBootstrapCache(
        workspaceExists: true,
        workspaceStatus: 'ready',
      );
      return project;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.statusCode == 404 || mapped.statusCode == 405) {
        await onboardProject(normalizedSourceUrl, normalizedName);
        final projects = await fetchProjects();
        final loweredName = normalizedName.toLowerCase();
        return projects.firstWhere(
          (project) => project.name.trim().toLowerCase() == loweredName,
          orElse: () => projects.first,
        );
      }
      if (!mapped.isOffline) {
        throw mapped;
      }

      final tempId = _newOfflineTempId('project');
      final optimistic = Project(
        id: tempId,
        name: normalizedName,
        url: normalizedSourceUrl ?? '',
        settings: ProjectSettings(contentTypes: contentTypes),
        createdAt: DateTime.now(),
      );
      await _upsertCachedProject(optimistic);
      await _syncBootstrapCache(
        workspaceExists: true,
        workspaceStatus: 'ready',
      );
      await _enqueueOfflineAction(
        resourceType: 'projects',
        actionType: 'create',
        label: 'Create project',
        method: 'POST',
        path: '/api/projects',
        dedupeKey: 'projects:create:${normalizedName.toLowerCase()}',
        payload: payload,
        meta: _offlineActionMeta(
          entityType: 'project',
          entityId: tempId,
          tempId: tempId,
        ),
      );
      return optimistic;
    }
  }

  Future<Project> updateProject({
    required String projectId,
    required String name,
    String? sourceUrl,
    List<ContentTypeConfig> contentTypes = const <ContentTypeConfig>[],
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([projectId], idMappings);
    final payload = _compactMap({
      'name': name.trim(),
      'source_url': normalizeOptionalText(sourceUrl),
      'content_types': contentTypes.map((entry) => entry.toJson()).toList(),
    });
    try {
      final response = await _dio.patch(
        '/api/projects/$resolvedProjectId',
        data: payload,
      );
      final project = Project.fromJson(_asMap(response.data));
      final cached =
          (await _readCachedList(_projectsCacheKey) ?? const <dynamic>[])
              .map((entry) => Project.fromJson(entry as Map<String, dynamic>))
              .toList();
      final nextProjects =
          cached.any(
            (entry) => entry.id == projectId || entry.id == resolvedProjectId,
          )
          ? cached
                .map(
                  (entry) =>
                      entry.id == projectId || entry.id == resolvedProjectId
                      ? project
                      : entry,
                )
                .toList()
          : [...cached, project];
      await _writeCachedData(
        _projectsCacheKey,
        nextProjects.map((entry) => entry.toJson()).toList(),
      );
      return project;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final cachedProjects =
          (await _readCachedList(_projectsCacheKey) ?? const <dynamic>[])
              .map((entry) => Project.fromJson(entry as Map<String, dynamic>))
              .toList();
      final nextProjects = cachedProjects
          .map(
            (entry) => entry.id == projectId || entry.id == resolvedProjectId
                ? entry.copyWith(
                    name: name.trim(),
                    url: normalizeOptionalText(sourceUrl) ?? entry.url,
                    settings: entry.settings?.copyWith(
                      contentTypes: contentTypes,
                    ),
                  )
                : entry,
          )
          .toList();
      await _writeCachedData(
        _projectsCacheKey,
        nextProjects.map((entry) => entry.toJson()).toList(),
      );
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'projects',
          actionType: 'update',
          label: 'Update project',
          method: 'PATCH',
          path: '/api/projects/$resolvedProjectId',
          dedupeKey: 'projects:update:$resolvedProjectId',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'project',
            entityId: resolvedProjectId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return nextProjects.firstWhere(
          (entry) => entry.id == projectId || entry.id == resolvedProjectId,
          orElse: () => Project(
            id: projectId,
            name: name.trim(),
            url: normalizeOptionalText(sourceUrl) ?? '',
            settings: ProjectSettings(contentTypes: contentTypes),
            createdAt: DateTime.now(),
          ),
        );
      }
      throw mapped;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete('/api/projects/$projectId');
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> archiveProject(String projectId) async {
    try {
      await _dio.post('/api/projects/$projectId/archive');
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> unarchiveProject(String projectId) async {
    try {
      await _dio.post('/api/projects/$projectId/unarchive');
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> fetchProjectContentTree({
    required String projectId,
    String? path,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final queryParameters = _compactMap({
      'path': path?.trim().isEmpty == true ? null : path?.trim(),
    });
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/content-tree',
        queryParameters: queryParameters,
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AppBootstrap> fetchBootstrap() async {
    final data = await _getCachedData(
      '/api/bootstrap',
      cacheKey: _bootstrapCacheKey,
    );
    return AppBootstrap.fromJson(_asMap(data));
  }

  Future<AppSettings> fetchSettings() async {
    if (allowDemoData) {
      return const AppSettings(id: 'offline-settings', userId: 'offline-user');
    }

    try {
      final data = await _getCachedData(
        '/api/settings',
        cacheKey: _settingsCacheKey,
      );
      return AppSettings.fromJson(_asMap(data));
    } on ApiException catch (error) {
      if (error.isOffline) {
        return const AppSettings(
          id: 'offline-settings',
          userId: 'offline-user',
        );
      }
      rethrow;
    }
  }

  Future<AppSettings> updateSettings(Map<String, dynamic> updates) async {
    final idMappings = await _loadIdMappings();
    final resolvedUpdates =
        _asMapOrNull(rewriteOfflineIdsInValue(updates, idMappings)) ?? updates;
    final hasSelectionModeUpdate = resolvedUpdates.containsKey(
      'projectSelectionMode',
    );
    final requestedSelectionMode = hasSelectionModeUpdate
        ? normalizeProjectSelectionMode(
            resolvedUpdates['projectSelectionMode']?.toString(),
          )
        : null;
    final dependsOnTempIds = _dependsOnTempIdsForIds([
      updates['defaultProjectId']?.toString(),
    ], idMappings);
    try {
      final response = await _dio.patch('/api/settings', data: resolvedUpdates);
      final settings = AppSettings.fromJson(_asMap(response.data));
      await _writeCachedData(_settingsCacheKey, settings.toJson());
      if (resolvedUpdates.containsKey('defaultProjectId') ||
          resolvedUpdates.containsKey('projectSelectionMode')) {
        final bootstrapDefaultProjectId =
            requestedSelectionMode == projectSelectionModeNone
            ? null
            : settings.defaultProjectId;
        await _syncBootstrapCache(
          updateDefaultProject: true,
          syncProjectDefaults:
              requestedSelectionMode != projectSelectionModeNone,
          defaultProjectId: bootstrapDefaultProjectId,
        );
      }
      return settings;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final current = await _readCachedMap(_settingsCacheKey);
      final merged = {...?current, ...resolvedUpdates};
      merged.putIfAbsent('id', () => 'offline-settings');
      merged.putIfAbsent('userId', () => offlineScope);
      await _writeCachedData(_settingsCacheKey, merged);
      if (resolvedUpdates.containsKey('defaultProjectId') ||
          resolvedUpdates.containsKey('projectSelectionMode')) {
        final bootstrapDefaultProjectId =
            requestedSelectionMode == projectSelectionModeNone
            ? null
            : resolvedUpdates['defaultProjectId']?.toString();
        await _syncBootstrapCache(
          updateDefaultProject: true,
          syncProjectDefaults:
              requestedSelectionMode != projectSelectionModeNone,
          defaultProjectId: bootstrapDefaultProjectId,
        );
      }
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'settings',
          actionType: 'update',
          label: 'Update settings',
          method: 'PATCH',
          path: '/api/settings',
          dedupeKey: 'settings:update',
          payload: resolvedUpdates,
          meta: _offlineActionMeta(dependsOnTempIds: dependsOnTempIds),
        );
        return AppSettings.fromJson(merged);
      }
      throw mapped;
    }
  }

  Future<CreatorProfile?> fetchCreatorProfile({String? projectId}) async {
    final params = <String, dynamic>{};
    if (projectId != null && projectId.trim().isNotEmpty) {
      params['projectId'] = projectId;
    }
    final cacheKey = params.isEmpty
        ? _creatorProfileCacheKey
        : _cacheKeyFor(_creatorProfileCacheKey, params);
    final data = await _getCachedData(
      '/api/creator-profile',
      cacheKey: cacheKey,
      queryParameters: params,
    );
    if (data == null) {
      return null;
    }
    final map = _asMap(data, fallback: const {});
    return map.isEmpty ? null : CreatorProfile.fromJson(map);
  }

  Future<CreatorProfile> saveCreatorProfile({
    String? projectId,
    String? displayName,
    Map<String, dynamic>? voice,
    Map<String, dynamic>? positioning,
    List<String>? values,
    String? currentChapterId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({
      'projectId': resolvedProjectId,
      'displayName': displayName,
      'voice': voice,
      'positioning': positioning,
      'values': values,
      'currentChapterId': currentChapterId,
    });
    try {
      final response = await _dio.put('/api/creator-profile', data: payload);
      final profile = CreatorProfile.fromJson(_asMap(response.data));
      final cacheKey = _cacheKeyFor(
        _creatorProfileCacheKey,
        resolvedProjectId == null ? null : {'projectId': resolvedProjectId},
      );
      await _writeCachedData(cacheKey, profile.toJson());
      return profile;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final current = await _readCachedMap(
        _cacheKeyFor(
          _creatorProfileCacheKey,
          resolvedProjectId == null ? null : {'projectId': resolvedProjectId},
        ),
      );
      final merged = {...?current, ...payload};
      final now = DateTime.now().toIso8601String();
      merged.putIfAbsent('id', () => 'offline-creator-profile');
      merged.putIfAbsent('userId', () => offlineScope);
      merged.putIfAbsent('createdAt', () => now);
      merged['updatedAt'] = now;
      final cacheKey = _cacheKeyFor(
        _creatorProfileCacheKey,
        resolvedProjectId == null ? null : {'projectId': resolvedProjectId},
      );
      await _writeCachedData(cacheKey, merged);
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'creator_profile',
          actionType: 'save',
          label: 'Save creator profile',
          method: 'PUT',
          path: '/api/creator-profile',
          dedupeKey: 'creator_profile:save',
          payload: payload,
          meta: _offlineActionMeta(
            dependsOnTempIds: _dependsOnTempIdsForIds([projectId], idMappings),
          ),
        );
        return CreatorProfile.fromJson(merged);
      }
      throw mapped;
    }
  }

  Future<List<ContentItem>> fetchPendingContent({String? projectId}) async {
    if (allowDemoData) {
      return _mockContent();
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final queryParameters = <String, dynamic>{'status': 'pending_review'};
    if (resolvedProjectId != null) {
      queryParameters['project_id'] = resolvedProjectId;
    }

    final data = await _getCachedData(
      '/api/status/content',
      cacheKey: _cacheKeyFor(_pendingContentCacheKey, queryParameters),
      queryParameters: queryParameters,
    );
    final items = _parseContentList(data);
    return _mergePreparedVideoCandidates(
      items,
      await _safeRefreshPreparedVideoCandidates(
        projectId: resolvedProjectId,
        contentIds: items
            .where(_usesCanonicalVideoPublishFlow)
            .map((item) => item.id)
            .toList(),
      ),
    );
  }

  Future<List<ContentItem>> seedTestContentBatch({String? projectId}) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final now = DateTime.now();

    ContentItem item({
      required String suffix,
      required String title,
      required String body,
      required ContentType type,
      required List<PublishingChannel> channels,
      Map<String, dynamic>? metadata,
      Duration createdAgo = Duration.zero,
    }) {
      return ContentItem.fromJson({
        'id': 'test-$suffix',
        'title': title,
        'body': body,
        'content_preview': body.split('\n').first,
        'content_type': switch (type) {
          ContentType.blogPost => 'blog_post',
          ContentType.socialPost => 'social_post',
          ContentType.newsletter => 'newsletter',
          ContentType.videoScript => 'video_script',
          ContentType.reel => 'reel',
          ContentType.short => 'short',
        },
        'status': 'pending_review',
        'project_id': resolvedProjectId,
        'project_name': DemoSeed.projectName,
        'created_at': now.subtract(createdAgo).toIso8601String(),
        'channels': channels.map((c) => c.name).toList(),
        ...metadata == null
            ? const <String, Object?>{}
            : {'metadata': metadata},
      });
    }

    final seeded = <ContentItem>[
      item(
        suffix: 'blog',
        title: 'Guide: Structurer un article SEO en 2026',
        type: ContentType.blogPost,
        channels: [PublishingChannel.ghost],
        createdAgo: const Duration(minutes: 18),
        body:
            '# Guide: Structurer un article SEO en 2026\n\n## Intro\nUn cadre simple pour produire un article clair, utile et diffusable.\n\n## 1. Intention de recherche\n- Informer\n- Comparer\n- Décider\n\n## 2. Plan recommandé\n- Hook\n- Problème\n- Solution\n- Checklist\n\n## Conclusion\nPublie une version utile puis itère.',
      ),
      item(
        suffix: 'newsletter',
        title: 'Newsletter hebdo: Roadmap contenu',
        type: ContentType.newsletter,
        channels: [PublishingChannel.ghost],
        createdAgo: const Duration(minutes: 14),
        body:
            '# Newsletter hebdo\n\n## Cette semaine\n- 2 articles publiés\n- 1 script vidéo validé\n- 3 idées en attente\n\n## Focus\nAméliorer les intros pour augmenter le taux de lecture.\n\n## CTA\nRéponds avec ton plus gros blocage contenu.',
      ),
      item(
        suffix: 'social',
        title: 'Post social: arrêter le contenu “générique”',
        type: ContentType.socialPost,
        channels: [PublishingChannel.linkedin, PublishingChannel.twitter],
        createdAgo: const Duration(minutes: 11),
        body:
            'Le vrai problème n’est pas de produire plus.\n\nC’est de produire plus clair.\n\n3 règles:\n1) Une idée par post\n2) Un exemple concret\n3) Une fin actionnable\n\n#content #marketing #productivity',
      ),
      item(
        suffix: 'video',
        title: 'Script vidéo: de l’idée au plan éditorial',
        type: ContentType.videoScript,
        channels: [PublishingChannel.youtube],
        createdAgo: const Duration(minutes: 8),
        body:
            'HOOK (0:00-0:10)\n"Tu n\'as pas besoin de plus d’idées, tu as besoin d’un système."\n\nPARTIE 1 (0:10-1:20)\nChoisir 3 piliers éditoriaux.\n\nPARTIE 2 (1:20-2:40)\nTransformer chaque idée en 3 formats.\n\nCTA (2:40-3:00)\n"Commente PLAN pour recevoir le template."',
      ),
      item(
        suffix: 'reel',
        title: 'Reel: checklist publication 30s',
        type: ContentType.reel,
        channels: [PublishingChannel.instagram, PublishingChannel.tiktok],
        createdAgo: const Duration(minutes: 5),
        body:
            'REEL 30s\n\n[0-3s] Hook visuel\n[3-15s] 2 conseils\n[15-25s] exemple\n[25-30s] CTA\n\nSous-titres obligatoires.\n\n#reels #creator',
      ),
      item(
        suffix: 'short',
        title: 'Short YouTube: Hook/Proof/CTA',
        type: ContentType.short,
        channels: [PublishingChannel.youtube],
        createdAgo: const Duration(minutes: 2),
        metadata: {
          'platform': 'youtube_shorts',
          'duration_seconds': 45,
          'hashtags': ['#shorts', '#content', '#creator'],
        },
        body:
            'SHORT 45s\n\nHook: "Voici pourquoi ton contenu ne convertit pas."\nProof: mini exemple avant/après.\nCTA: "Teste ce framework sur ton prochain post."',
      ),
    ];

    for (final content in seeded) {
      await _upsertCachedPendingContentItem(content);
      await _writeCachedData('content.body.${content.id}', {
        'body': content.body,
      });
    }

    return seeded;
  }

  Future<List<ContentItem>> fetchContentHistory({String? projectId}) async {
    if (allowDemoData) {
      return _mockHistory();
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final queryParameters = <String, dynamic>{
      'status': 'published,rejected,approved',
    };
    if (resolvedProjectId != null) {
      queryParameters['project_id'] = resolvedProjectId;
    }

    final data = await _getCachedData(
      '/api/status/content',
      cacheKey: _cacheKeyFor(_contentHistoryCacheKey, queryParameters),
      queryParameters: queryParameters,
    );
    return _parseContentList(data);
  }

  Future<ContentItem> fetchContentDetail(
    String id, {
    ContentItem? fallback,
    bool allowStaleBodyCache = true,
  }) async {
    if (allowDemoData) {
      final demo = _demoContentById(id);
      if (demo != null) return demo;
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    ContentItem? item = fallback;

    try {
      final data = _asMap(
        await _getCachedData(
          '/api/status/content/$resolvedId',
          cacheKey: 'content.detail.$resolvedId',
        ),
      );
      item = ContentItem.fromJson(data);
    } on ApiException catch (error) {
      if (fallback == null || error.isUnauthorized) {
        rethrow;
      }
    }

    final body = await fetchContentBody(
      id,
      allowStaleCache: allowStaleBodyCache,
    );
    if (body == null || body.trim().isEmpty) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Full content body is unavailable. Retry after sync before editing or publishing.',
      );
    }

    final resolvedItem = item ?? fallback;
    if (resolvedItem == null) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Content metadata is unavailable.',
      );
    }

    return resolvedItem.copyWith(body: body);
  }

  Future<String?> fetchContentBody(
    String id, {
    bool allowStaleCache = true,
  }) async {
    if (allowDemoData) {
      return _demoContentById(id)?.body;
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final cacheKey = 'content.body.$resolvedId';

    late final Map<String, dynamic> data;
    try {
      final response = await _dio.get('/api/status/content/$resolvedId/body');
      data = _asMap(response.data);
      await _writeCachedData(cacheKey, data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (allowStaleCache && mapped.isOffline) {
        final cached = await cacheStore?.read(offlineScope, cacheKey);
        if (cached != null) {
          await onCacheKeyStale?.call(cacheKey);
          data = _asMap(cached.data);
        } else {
          throw mapped;
        }
      } else {
        throw mapped;
      }
    }
    return data['body'] as String? ?? data['content'] as String?;
  }

  Future<List<ContentStatusChange>> fetchContentStatusHistory(String id) async {
    if (allowDemoData) {
      return const [];
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);

    final data = await _getCachedData(
      '/api/status/content/$resolvedId/history',
      cacheKey: 'content.transition_history.$resolvedId',
    );
    if (data is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid content history response from FastAPI.',
      );
    }
    return data
        .map(
          (json) => ContentStatusChange.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ContentEditEvent>> fetchContentEditHistory(String id) async {
    if (allowDemoData) {
      return const [];
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);

    final data = await _getCachedData(
      '/api/status/content/$resolvedId/body/history',
      cacheKey: 'content.body_history.$resolvedId',
    );
    if (data is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid content edit history response from FastAPI.',
      );
    }
    return data
        .map((json) => ContentEditEvent.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ContentAuditTrail> fetchContentAuditTrail(String id) async {
    final results = await Future.wait([
      fetchContentStatusHistory(id),
      fetchContentEditHistory(id),
    ]);
    return ContentAuditTrail(
      transitions: results[0] as List<ContentStatusChange>,
      edits: results[1] as List<ContentEditEvent>,
    );
  }

  Future<bool> saveContentBody(
    String id,
    String body, {
    String? editNote,
  }) async {
    if (allowDemoData) {
      return true;
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([id], idMappings);
    final payload = _compactMap({'body': body, 'edit_note': editNote});

    try {
      await _dio.put('/api/status/content/$resolvedId/body', data: payload);
      await _writeCachedData('content.body.$resolvedId', payload);
      final current = await _readCachedPendingContentItems();
      final next = current
          .map(
            (entry) => entry.id == id || entry.id == resolvedId
                ? entry.copyWith(body: body)
                : entry,
          )
          .toList();
      await _writeCachedData(
        _pendingContentCacheKey,
        next.map((entry) => entry.toJson()).toList(),
      );
      return true;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        await _writeCachedData('content.body.$resolvedId', payload);
        final current = await _readCachedPendingContentItems();
        final next = current
            .map(
              (entry) => entry.id == id || entry.id == resolvedId
                  ? entry.copyWith(body: body)
                  : entry,
            )
            .toList();
        await _writeCachedData(
          _pendingContentCacheKey,
          next.map((entry) => entry.toJson()).toList(),
        );
        await _enqueueOfflineAction(
          resourceType: 'content',
          actionType: 'save_body',
          label: 'Save content body',
          method: 'PUT',
          path: '/api/status/content/$resolvedId/body',
          dedupeKey: 'content:body:$resolvedId',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'content',
            entityId: resolvedId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return false;
      }
      throw mapped;
    }
  }

  Future<void> transitionContent(
    String id,
    String toStatus, {
    String? reason,
  }) async {
    if (allowDemoData) {
      return;
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([id], idMappings);
    final payload = _compactMap({'to_status': toStatus, 'reason': reason});

    try {
      await _dio.post(
        '/api/status/content/$resolvedId/transition',
        data: payload,
      );
      if (toStatus != 'pending' && toStatus != 'pending_review') {
        await _removeCachedPendingContentItem(id);
        if (resolvedId != id) {
          await _removeCachedPendingContentItem(resolvedId);
        }
      }
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        if (toStatus != 'pending' && toStatus != 'pending_review') {
          await _removeCachedPendingContentItem(id);
          if (resolvedId != id) {
            await _removeCachedPendingContentItem(resolvedId);
          }
        }
        await _enqueueOfflineAction(
          resourceType: 'content',
          actionType: 'transition',
          label: 'Update content status',
          method: 'POST',
          path: '/api/status/content/$resolvedId/transition',
          dedupeKey: 'content:transition:$resolvedId',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'content',
            entityId: resolvedId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return;
      }
      throw mapped;
    }
  }

  Future<void> approveContent(String id) => transitionContent(id, 'approved');

  Future<void> rejectContent(String id) => transitionContent(id, 'rejected');

  Future<ContentItem> completeContent(String id) async {
    if (allowDemoData) {
      final current = await fetchContentDetail(id);
      return current.copyWith(
        metadata: {
          ...(current.metadata ?? const <String, dynamic>{}),
          'content_complete': true,
          'content_complete_at': DateTime.now().toUtc().toIso8601String(),
          'video_generation_state': 'ready',
        },
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final payload = {
      'metadata': {
        'content_complete': true,
        'content_complete_at': DateTime.now().toUtc().toIso8601String(),
        'video_generation_state': 'ready',
      },
    };

    try {
      final response = await _dio.post(
        '/api/status/content/$resolvedId/complete',
        data: payload,
      );
      final data = _asMap(response.data);
      final current = await fetchContentDetail(id);
      return current.copyWith(
        metadata: data['metadata'] as Map<String, dynamic>? ?? current.metadata,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<bool> updateContent(String id, {String? title, String? body}) async {
    if (allowDemoData) {
      return true;
    }

    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([id], idMappings);
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;

    try {
      await _dio.patch('/api/status/content/$resolvedId', data: data);
      final pending = await _readCachedPendingContentItems();
      final nextPending = pending
          .map(
            (entry) => entry.id == id || entry.id == resolvedId
                ? entry.copyWith(
                    title: title ?? entry.title,
                    body: body ?? entry.body,
                  )
                : entry,
          )
          .toList();
      await _writeCachedData(
        _pendingContentCacheKey,
        nextPending.map((entry) => entry.toJson()).toList(),
      );
      return true;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final pending = await _readCachedPendingContentItems();
      final nextPending = pending
          .map(
            (entry) => entry.id == id || entry.id == resolvedId
                ? entry.copyWith(
                    title: title ?? entry.title,
                    body: body ?? entry.body,
                  )
                : entry,
          )
          .toList();
      await _writeCachedData(
        _pendingContentCacheKey,
        nextPending.map((entry) => entry.toJson()).toList(),
      );
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'content',
          actionType: 'update',
          label: 'Update content metadata',
          method: 'PATCH',
          path: '/api/status/content/$resolvedId',
          dedupeKey: 'content:update:$resolvedId',
          payload: data,
          meta: _offlineActionMeta(
            entityType: 'content',
            entityId: resolvedId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return true;
      }
      throw mapped;
    }
  }

  Future<ContentItem> createContentDraftFromCapture({
    required CaptureAsset asset,
    required String projectId,
  }) async {
    if (allowDemoData) {
      return ContentItem.fromJson({
        'id': 'demo-capture-content-${asset.id}',
        'title': _captureDraftTitle(asset),
        'body': _captureDraftBody(asset),
        'content_type': 'manual',
        'status': 'pending_review',
        'project_id': projectId,
        'source_robot': 'manual',
        'created_at': DateTime.now().toIso8601String(),
        'metadata': _captureAssetMetadata(asset),
      });
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final body = _captureDraftBody(asset);
    final payload = {
      'title': _captureDraftTitle(asset),
      'content_type': 'manual',
      'source_robot': 'manual',
      'status': 'pending_review',
      'project_id': resolvedProjectId,
      'content_preview': _capturePreview(asset),
      'priority': 3,
      'tags': ['device_capture', asset.kind.name],
      'metadata': {
        'created_from': 'device_capture',
        'capture_asset': _captureAssetMetadata(asset),
      },
    };

    try {
      final response = await _dio.post('/api/status/content', data: payload);
      final data = _asMap(response.data);
      final contentId = data['id']?.toString();
      if (contentId == null || contentId.isEmpty) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Backend did not return a content id.',
        );
      }

      await saveContentBody(
        contentId,
        body,
        editNote: 'Created from local device capture',
      );
      await attachCaptureAssetToContent(contentId: contentId, asset: asset);

      final item = ContentItem.fromJson({
        ...payload,
        ...data,
        'id': contentId,
        'body': body,
        'status': data['status'] ?? 'pending_review',
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      });
      await _upsertCachedPendingContentItem(item);
      return item;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>?> attachCaptureAssetToContent({
    required String contentId,
    required CaptureAsset asset,
  }) async {
    if (allowDemoData) {
      return {'id': 'demo-content-asset-${asset.id}', 'status': 'local_only'};
    }

    final idMappings = await _loadIdMappings();
    final resolvedContentId = _resolveEntityId(contentId, idMappings);
    final payload = {
      'client_asset_id': asset.id,
      'source': 'device_capture',
      'kind': asset.kind.name,
      'mime_type': asset.mimeType,
      'file_name': _fileNameFromPath(asset.path),
      'byte_size': asset.byteSize,
      'width': asset.width,
      'height': asset.height,
      'duration_ms': asset.durationMs,
      'status': 'local_only',
      'metadata': _captureAssetMetadata(asset),
    };

    try {
      final response = await _dio.post(
        '/api/status/content/$resolvedContentId/assets',
        data: payload,
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineResponse> createOrLoadVideoTimelineFromContent({
    required String contentId,
    String formatPreset = 'vertical_9_16',
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/from-content',
        data: _compactMap({
          'content_id': contentId,
          'format_preset': formatPreset,
          'client_request_id': clientRequestId,
        }),
      );
      return VideoTimelineResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<BrandedVideoGenerationResponse> generateBrandedVideoFromContent({
    required String contentId,
    String formatPreset = 'vertical_9_16',
    String? brandProfileId,
    String? blueprintId,
    String? triggerSource,
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/from-content/branded-generate',
        data: _compactMap({
          'content_id': contentId,
          'brand_profile_id': brandProfileId,
          'blueprint_id': blueprintId,
          'format_preset': formatPreset,
          'trigger_source': triggerSource,
          'client_request_id': clientRequestId,
        }),
      );
      return BrandedVideoGenerationResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> refreshPreparedVideoCandidates({
    required String projectId,
    List<String> contentIds = const <String>[],
    String formatPreset = 'vertical_9_16',
    String? triggerSource,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/feed-candidates/refresh',
        data: _compactMap({
          'project_id': projectId,
          'content_ids': contentIds.isEmpty ? null : contentIds,
          'format_preset': formatPreset,
          'limit': contentIds.isEmpty ? 20 : contentIds.length,
          'trigger_source': triggerSource,
        }),
      );
      final payload = _asMap(response.data);
      final items = payload['items'];
      if (items is! List) {
        return const <Map<String, dynamic>>[];
      }
      return items
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineSwipePublishResponse> swipePublishVideoTimeline({
    required String timelineId,
    required String versionId,
    String? previewJobId,
    required String content,
    required List<Map<String, String>> platforms,
    String? title,
    String? scheduledFor,
    bool publishNow = true,
    List<String> tags = const [],
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/$timelineId/versions/$versionId/swipe-publish',
        data: _compactMap({
          'preview_job_id': previewJobId,
          'content': content,
          'platforms': platforms,
          'title': title,
          'scheduled_for': scheduledFor,
          'publish_now': publishNow,
          'tags': tags.isEmpty ? null : tags,
          'client_request_id': clientRequestId,
        }),
      );
      return VideoTimelineSwipePublishResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineResponse> getVideoTimeline(String timelineId) async {
    try {
      final response = await _dio.get('/api/video-timelines/$timelineId');
      return VideoTimelineResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineDraftResponse> saveVideoTimelineDraft({
    required String timelineId,
    required int draftRevision,
    required VideoTimelineDocument timeline,
    String? baseVersionId,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/video-timelines/$timelineId/draft',
        data: _compactMap({
          'base_version_id': baseVersionId,
          'draft_revision': draftRevision,
          'timeline': timeline.toJson(),
        }),
      );
      return VideoTimelineDraftResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineVersion> createVideoTimelineVersion({
    required String timelineId,
    required int draftRevision,
    required VideoTimelineDocument timeline,
    String? baseVersionId,
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/$timelineId/versions',
        data: _compactMap({
          'base_version_id': baseVersionId,
          'draft_revision': draftRevision,
          'timeline': timeline.toJson(),
          'client_request_id': clientRequestId,
        }),
      );
      return VideoTimelineVersion.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineRenderJob> requestVideoTimelinePreview({
    required String timelineId,
    required String versionId,
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/$timelineId/versions/$versionId/preview',
        data: _compactMap({'client_request_id': clientRequestId}),
      );
      return VideoTimelineRenderJob.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineVersion> approveVideoTimelinePreview({
    required String timelineId,
    required String versionId,
    required String previewJobId,
    bool approved = true,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/$timelineId/versions/$versionId/preview/$previewJobId/approve',
        data: {'approved': approved},
      );
      return VideoTimelineVersion.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineRenderJob> requestVideoTimelineFinalRender({
    required String timelineId,
    required String versionId,
    required String previewJobId,
    String? clientRequestId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/video-timelines/$timelineId/versions/$versionId/render-final',
        data: _compactMap({
          'preview_job_id': previewJobId,
          'client_request_id': clientRequestId,
        }),
      );
      return VideoTimelineRenderJob.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoTimelineRenderJob> requestVideoTimelineFinal({
    required String timelineId,
    required String versionId,
    required String previewJobId,
    String? clientRequestId,
  }) {
    return requestVideoTimelineFinalRender(
      timelineId: timelineId,
      versionId: versionId,
      previewJobId: previewJobId,
      clientRequestId: clientRequestId,
    );
  }

  Future<VideoTimelineRenderJob> getVideoTimelineJob({
    required String timelineId,
    required String jobId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/video-timelines/$timelineId/jobs/$jobId',
      );
      return VideoTimelineRenderJob.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

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
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final queryParameters = _compactMap({
      'media_kind': normalizeOptionalText(mediaKind),
      'source': normalizeOptionalText(source),
      'category_id': normalizeOptionalText(categoryId),
      'subcategory_id': normalizeOptionalText(subcategoryId),
      'include_tombstoned': includeTombstoned,
      'limit': limit,
      'offset': offset,
    });
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets',
        queryParameters: queryParameters,
      );
      return ProjectAssetListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAssetCategoryCatalog> getProjectAssetCategoryCatalog({
    required String projectId,
    String? locale,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/categories',
        queryParameters: _compactMap({'locale': normalizeOptionalText(locale)}),
      );
      return ProjectAssetCategoryCatalog.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> getProjectAssetDetail({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId',
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> assignProjectAssetCategory({
    required String projectId,
    required String assetId,
    String? categoryId,
    String? subcategoryId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.patch(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/category',
        data: {
          'category_id': normalizeOptionalText(categoryId),
          'subcategory_id': normalizeOptionalText(subcategoryId),
        },
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<ProjectAssetUsage>> getProjectAssetUsage({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/usage',
      );
      final payload = response.data;
      if (payload is! List) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid project asset usage response from FastAPI.',
        );
      }
      return payload
          .map((entry) => ProjectAssetUsage.fromJson(_asMap(entry)))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<ProjectAssetEvent>> getProjectAssetEvents({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/events',
      );
      final payload = response.data;
      if (payload is! List) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid project asset events response from FastAPI.',
        );
      }
      return payload
          .map((entry) => ProjectAssetEvent.fromJson(_asMap(entry)))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAssetEligibility> getProjectAssetEligibility({
    required String projectId,
    required String assetId,
    required String usageAction,
    String? targetType,
    String? targetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final resolvedTargetId = targetId == null
        ? null
        : _resolveEntityId(targetId, idMappings);
    final payload = _compactMap({
      'usage_action': usageAction.trim(),
      'target_type': normalizeOptionalText(targetType),
      'target_id': resolvedTargetId,
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/eligibility',
        data: payload,
      );
      return ProjectAssetEligibility.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

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
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final resolvedTargetId = _resolveEntityId(targetId, idMappings);
    final payload = _compactMap({
      'target_type': targetType.trim(),
      'target_id': resolvedTargetId,
      'usage_action': usageAction.trim(),
      'placement': normalizeOptionalText(placement),
      'is_primary': isPrimary,
      'metadata': metadata,
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/select',
        data: payload,
      );
      return ProjectAssetUsage.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAssetUsage> setProjectAssetPrimary({
    required String projectId,
    required String assetId,
    required String targetType,
    required String targetId,
    required String usageAction,
    String? placement,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final resolvedTargetId = _resolveEntityId(targetId, idMappings);
    final payload = _compactMap({
      'target_type': targetType.trim(),
      'target_id': resolvedTargetId,
      'usage_action': usageAction.trim(),
      'placement': normalizeOptionalText(placement),
      'metadata': metadata,
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/primary',
        data: payload,
      );
      return ProjectAssetUsage.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<int> clearProjectAssetPrimary({
    required String projectId,
    required String targetType,
    required String targetId,
    String? placement,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedTargetId = _resolveEntityId(targetId, idMappings);
    final payload = _compactMap({
      'target_type': targetType.trim(),
      'target_id': resolvedTargetId,
      'placement': normalizeOptionalText(placement),
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/clear-primary',
        data: payload,
      );
      final data = _asMap(response.data);
      return (data['cleared_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> refreshProjectAssetPreview({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/preview-refresh',
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> tombstoneProjectAsset({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/tombstone',
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> restoreProjectAsset({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/restore',
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAssetCleanupReport> getProjectAssetCleanupReport({
    required String projectId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/cleanup-report',
      );
      return ProjectAssetCleanupReport.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AssetUnderstandingJob> queueProjectAssetUnderstanding({
    required String projectId,
    required String assetId,
    required String idempotencyKey,
    String provider = 'gemini_compatible',
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final payload = _compactMap({
      'idempotency_key': idempotencyKey.trim(),
      'provider': provider.trim(),
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/understanding/queue',
        data: payload,
      );
      return AssetUnderstandingJob.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AssetUnderstandingStatusResponse> getProjectAssetUnderstandingStatus({
    required String projectId,
    required String assetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    try {
      final response = await _dio.get(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/understanding/status',
      );
      return AssetUnderstandingStatusResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AssetUnderstandingJob> retryProjectAssetUnderstanding({
    required String projectId,
    required String assetId,
    required String jobId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final payload = _compactMap({'job_id': jobId.trim()});
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/understanding/retry',
        data: payload,
      );
      return AssetUnderstandingJob.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AssetUnderstandingStatusResponse> moderateProjectAssetTags({
    required String projectId,
    required String assetId,
    List<Map<String, dynamic>> decisions = const <Map<String, dynamic>>[],
    List<String> manualTags = const <String>[],
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedAssetId = _resolveEntityId(assetId, idMappings);
    final payload = _compactMap({
      'decisions': decisions,
      'manual_tags': manualTags,
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/$resolvedAssetId/understanding/tags/moderate',
        data: payload,
      );
      return AssetUnderstandingStatusResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAssetRecommendationResponse> recommendProjectAssets({
    required String projectId,
    List<String> desiredTags = const <String>[],
    int limit = 10,
    bool includeGlobalCandidates = false,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({
      'desired_tags': desiredTags,
      'limit': limit,
      'include_global_candidates': includeGlobalCandidates,
    });
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/recommend',
        data: payload,
      );
      return ProjectAssetRecommendationResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectAsset> attachGlobalProjectAsset({
    required String projectId,
    required String globalAssetId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({'global_asset_id': globalAssetId.trim()});
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/assets/attach-global',
        data: payload,
      );
      return ProjectAsset.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageProfileListResponse> listImageProfiles({
    required String projectId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.get(
        '/api/images/profiles',
        queryParameters: {'project_id': resolvedProjectId},
      );
      return ImageProfileListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<GenerateImageFromProfileResult> queueImageGenerationFromProfile({
    required String projectId,
    required String profileId,
    required String titleText,
    String? subtitleText,
    String? fileName,
    String? altText,
    String? customPrompt,
    String? styleGuideOverride,
    String? pathTypeOverride,
    String? templateIdOverride,
    List<String> referenceIds = const <String>[],
    bool useVisualMemory = true,
    int? seed,
    String outputFormat = 'jpeg',
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({
      'project_id': resolvedProjectId,
      'profile_id': profileId.trim(),
      'title_text': titleText.trim(),
      'subtitle_text': normalizeOptionalText(subtitleText),
      'file_name': normalizeOptionalText(fileName),
      'alt_text': normalizeOptionalText(altText),
      'custom_prompt': normalizeOptionalText(customPrompt),
      'style_guide_override': normalizeOptionalText(styleGuideOverride),
      'path_type_override': normalizeOptionalText(pathTypeOverride),
      'template_id_override': normalizeOptionalText(templateIdOverride),
      'reference_ids': referenceIds,
      'use_visual_memory': useVisualMemory,
      'seed': seed,
      'output_format': outputFormat,
    });
    try {
      final response = await _dio.post(
        '/api/images/generate-from-profile',
        data: payload,
      );
      return GenerateImageFromProfileResult.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageGenerationListResponse> listImageGenerations({
    required String projectId,
    int limit = 30,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.get(
        '/api/images/generations',
        queryParameters: {'project_id': resolvedProjectId, 'limit': limit},
      );
      return ImageGenerationListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageGenerationRecord> getImageGeneration({
    required String generationId,
  }) async {
    try {
      final response = await _dio.get('/api/images/generations/$generationId');
      return ImageGenerationRecord.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageReferenceListResponse> listImageReferences({
    required String projectId,
    bool approvedOnly = false,
    int limit = 50,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.get(
        '/api/images/references',
        queryParameters: {
          'project_id': resolvedProjectId,
          'approved_only': approvedOnly,
          'limit': limit,
        },
      );
      return ImageReferenceListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageReferenceRecord> createImageReference({
    required String projectId,
    required String cdnUrl,
    String? primaryUrl,
    String mimeType = 'image/jpeg',
    int? width,
    int? height,
    String? label,
    String referenceType = 'project_asset',
    bool approved = true,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({
      'project_id': resolvedProjectId,
      'cdn_url': cdnUrl.trim(),
      'primary_url': normalizeOptionalText(primaryUrl),
      'mime_type': mimeType,
      'width': width,
      'height': height,
      'label': normalizeOptionalText(label),
      'reference_type': referenceType,
      'approved': approved,
    });
    try {
      final response = await _dio.post('/api/images/references', data: payload);
      return ImageReferenceRecord.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ImageReferenceRecord> updateImageReference({
    required String projectId,
    required String referenceId,
    bool? approved,
    String? label,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final payload = _compactMap({
      'approved': approved,
      'label': normalizeOptionalText(label),
    });
    try {
      final response = await _dio.patch(
        '/api/images/references/$referenceId',
        queryParameters: {'project_id': resolvedProjectId},
        data: payload,
      );
      return ImageReferenceRecord.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> deleteImageReference({
    required String projectId,
    required String referenceId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      await _dio.delete(
        '/api/images/references/$referenceId',
        queryParameters: {'project_id': resolvedProjectId},
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<NarrativeSynthesisResult> synthesizeNarrative({
    required String profileId,
    required List<RitualEntry> entries,
    Map<String, dynamic>? currentVoice,
    Map<String, dynamic>? currentPositioning,
    String? chapterTitle,
  }) async {
    try {
      final response = await _dio.post(
        '/api/psychology/synthesize-narrative',
        data: _compactMap({
          'profile_id': profileId,
          'entries': entries
              .where((entry) => !entry.isEmpty)
              .map((entry) => entry.toJson())
              .toList(),
          'current_voice': currentVoice,
          'current_positioning': currentPositioning,
          'chapter_title': chapterTitle,
        }),
      );
      final taskId = _extractAsyncJobId(
        _asMap(response.data),
        label: 'Narrative synthesis',
      );
      final result = await _pollAsyncJobResult(
        jobId: taskId,
        label: 'Narrative synthesis',
        fetchStatus: _fetchSynthesisStatus,
      );
      return NarrativeSynthesisResult.fromJson(result);
    } on DioException catch (error) {
      if (allowDemoData) {
        return _mockNarrativeResult();
      }
      throw _mapDioException(error);
    }
  }

  Future<List<Persona>> fetchPersonas({String? projectId}) async {
    if (allowDemoData) {
      return _mockPersonas();
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final queryParameters = <String, dynamic>{};
    if (resolvedProjectId != null) {
      queryParameters['projectId'] = resolvedProjectId;
    }

    final data = await _getCachedData(
      '/api/personas',
      cacheKey: _cacheKeyFor(_personasCacheKey, queryParameters),
      queryParameters: queryParameters,
    );
    if (data is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid personas response from FastAPI.',
      );
    }
    return data
        .map((json) => Persona.fromJson(_normalizePersonaJson(json)))
        .toList();
  }

  Future<Persona> savePersona(Persona persona) async {
    if (allowDemoData) {
      return persona.copyWith(
        id: persona.id ?? 'mock-${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    final idMappings = await _loadIdMappings();
    final payload = persona.toJson()
      ..remove('id')
      ..removeWhere((key, value) => value == null);
    final resolvedPersonaId = persona.id == null
        ? null
        : _resolveEntityId(persona.id!, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([persona.id], idMappings);

    try {
      final Response<dynamic> response;
      if (resolvedPersonaId case final id?) {
        response = await _dio.put('/api/personas/$id', data: payload);
      } else {
        response = await _dio.post('/api/personas', data: payload);
      }
      final saved = Persona.fromJson(
        _normalizePersonaJson(_asMap(response.data)),
      );
      await _upsertCachedPersona(saved);
      return saved;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (persona.id == null) {
        if (!mapped.isOffline) {
          throw mapped;
        }

        final tempId = _newOfflineTempId('persona');
        final optimistic = persona.copyWith(id: tempId);
        await _upsertCachedPersona(optimistic);
        await _enqueueOfflineAction(
          resourceType: 'personas',
          actionType: 'create',
          label: 'Create persona',
          method: 'POST',
          path: '/api/personas',
          dedupeKey: 'personas:create:${persona.name.trim().toLowerCase()}',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'persona',
            entityId: tempId,
            tempId: tempId,
          ),
        );
        return optimistic;
      }

      final personas =
          (await _readCachedList(_personasCacheKey) ?? const <dynamic>[])
              .map((entry) => Persona.fromJson(_normalizePersonaJson(entry)))
              .toList();
      final nextPersonas = personas
          .map(
            (entry) => entry.id == persona.id || entry.id == resolvedPersonaId
                ? persona
                : entry,
          )
          .toList();
      await _writeCachedData(
        _personasCacheKey,
        nextPersonas.map((entry) => entry.toJson()).toList(),
      );
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'personas',
          actionType: 'update',
          label: 'Update persona',
          method: 'PUT',
          path: '/api/personas/$resolvedPersonaId',
          dedupeKey: 'personas:update:$resolvedPersonaId',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'persona',
            entityId: resolvedPersonaId ?? persona.id,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return persona;
      }
      throw mapped;
    }
  }

  Future<Map<String, dynamic>> generatePersonaDraftFromProject({
    required String projectId,
    required String repoUrl,
  }) async {
    if (allowDemoData) {
      return {
        'name': 'Pragmatic Buyer Persona',
        'avatar': '🧭',
        'demographics': {'role': 'Founder', 'industry': 'Digital business'},
        'pain_points': ['Inconsistent growth'],
        'goals': ['Generate steady pipeline'],
        'language': {
          'vocabulary': ['clarity', 'traction'],
          'objections': ['Not enough time'],
        },
        'confidence': 55,
      };
    }

    final response = await _createPersonaDraftJob(
      projectId: projectId,
      repoSource: 'project_repo',
      repoUrl: repoUrl,
      mode: 'suggest_from_repo',
    );
    final jobId = (response['job_id'] ?? '').toString();
    if (jobId.isEmpty) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Persona draft job did not return a job ID.',
      );
    }

    const maxAttempts = 45;
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final job = await _fetchPersonaDraftJob(jobId);
      final status = (job['status'] ?? '').toString().toLowerCase();

      if (status == 'completed') {
        final result = _asMapOrNull(job['result']);
        final draft = _asMapOrNull(result?['persona_draft']);
        if (draft == null || draft.isEmpty) {
          throw const ApiException(
            ApiErrorType.invalidResponse,
            'Persona draft completed without usable draft data.',
          );
        }
        return draft;
      }

      if (status == 'failed') {
        throw _personaDraftJobFailure(job);
      }
    }

    throw const ApiException(
      ApiErrorType.server,
      'Persona draft generation timed out. Please retry.',
    );
  }

  Future<Map<String, dynamic>> _createPersonaDraftJob({
    required String projectId,
    required String repoSource,
    required String mode,
    String? repoUrl,
    String? manualUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/api/personas/draft',
        data: _compactMap({
          'project_id': projectId,
          'repo_source': repoSource,
          'repo_url': repoUrl,
          'manual_url': manualUrl,
          'mode': mode,
        }),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _fetchPersonaDraftJob(String jobId) async {
    try {
      final response = await _dio.get('/api/personas/draft-jobs/$jobId');
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> refinePersona(Persona persona) async {
    try {
      final response = await _dio.post(
        '/api/psychology/refine-persona',
        data: {'current_persona': persona.toJson()},
      );
      final taskId = _extractAsyncJobId(
        _asMap(response.data),
        label: 'Persona refinement',
      );
      return _pollAsyncJobResult(
        jobId: taskId,
        label: 'Persona refinement',
        fetchStatus: _fetchRefinementStatus,
      );
    } on DioException catch (error) {
      if (allowDemoData) {
        return {
          'suggested_updates': <String, dynamic>{},
          'new_confidence': persona.confidence,
        };
      }
      throw _mapDioException(error);
    }
  }

  Future<List<AngleSuggestion>> generateAngles({
    Map<String, dynamic>? creatorVoice,
    Map<String, dynamic>? creatorPositioning,
    String? narrativeSummary,
    required Map<String, dynamic> personaData,
    String? contentType,
    int count = 3,
  }) async {
    try {
      final response = await _dio.post(
        '/api/psychology/generate-angles',
        data: _compactMap({
          'creator_voice': creatorVoice,
          'creator_positioning': creatorPositioning,
          'narrative_summary': narrativeSummary,
          'persona_data': personaData,
          'content_type': contentType,
          'count': count,
        }),
      );
      final taskId = _extractAsyncJobId(
        _asMap(response.data),
        label: 'Angle generation',
      );
      final result = await _pollAsyncJobResult(
        jobId: taskId,
        label: 'Angle generation',
        fetchStatus: _fetchAnglesStatus,
      );
      final angles = result['angles'] ?? const [];
      if (angles is! List) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid angles response from FastAPI.',
        );
      }
      return angles
          .map((json) => AngleSuggestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      if (allowDemoData) {
        return _mockAngles();
      }
      throw _mapDioException(error);
    }
  }

  String _extractAsyncJobId(
    Map<String, dynamic> response, {
    required String label,
  }) {
    final jobId = (response['task_id'] ?? response['job_id'] ?? '')
        .toString()
        .trim();
    if (jobId.isEmpty) {
      throw ApiException(
        ApiErrorType.invalidResponse,
        '$label did not return a job ID.',
      );
    }
    return jobId;
  }

  Future<Map<String, dynamic>> _pollAsyncJobResult({
    required String jobId,
    required String label,
    required Future<Map<String, dynamic>> Function(String jobId) fetchStatus,
    int maxAttempts = 45,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final job = await fetchStatus(jobId);
      final status = (job['status'] ?? '').toString().toLowerCase();

      if (status == 'completed') {
        final result = _asMapOrNull(job['result']);
        if (result == null) {
          throw ApiException(
            ApiErrorType.invalidResponse,
            '$label completed without usable result data.',
          );
        }
        return result;
      }

      if (status == 'failed') {
        final errorMessage = (job['error'] ?? '$label failed.')
            .toString()
            .trim();
        throw ApiException(
          ApiErrorType.server,
          errorMessage.isEmpty ? '$label failed.' : errorMessage,
        );
      }
    }

    throw ApiException(ApiErrorType.server, '$label timed out. Please retry.');
  }

  Future<Map<String, dynamic>> _fetchSynthesisStatus(String taskId) async {
    try {
      final response = await _dio.get(
        '/api/psychology/synthesis-status/$taskId',
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _fetchRefinementStatus(String taskId) async {
    try {
      final response = await _dio.get(
        '/api/psychology/refinement-status/$taskId',
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _fetchAnglesStatus(String taskId) async {
    try {
      final response = await _dio.get('/api/psychology/angles-status/$taskId');
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>?> createContentFromAngle({
    required AngleSuggestion angle,
    String? projectId,
  }) async {
    if (allowDemoData) {
      return {'success': true, 'id': 'demo-angle-content'};
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final contentType = switch (angle.contentType) {
      'blog_post' => 'article',
      'social_post' => 'article',
      'video_script' => 'video_script',
      'reel' => 'video_script',
      _ => angle.contentType,
    };
    final sourceRobot = switch (angle.contentType) {
      'newsletter' => 'newsletter',
      _ => 'manual',
    };
    final payload = _compactMap({
      'title': angle.title,
      'content_type': contentType,
      'source_robot': sourceRobot,
      'status': 'todo',
      'project_id': resolvedProjectId,
      'content_preview': angle.hook,
      'priority': angle.confidence >= 80 ? 4 : 3,
      'tags': [
        angle.contentType,
        if (angle.narrativeThread.isNotEmpty) angle.narrativeThread,
      ],
      'metadata': {
        'angle': angle.angle,
        'hook': angle.hook,
        'narrative_thread': angle.narrativeThread,
        'pain_point_addressed': angle.painPointAddressed,
        'confidence': angle.confidence,
        'generated_from': 'angles_screen',
      },
    });
    final dependsOnTempIds = _dependsOnTempIdsForIds([projectId], idMappings);

    try {
      final response = await _dio.post('/api/status/content', data: payload);
      final data = _asMap(response.data);
      if (data['id'] != null) {
        final created = ContentItem.fromJson({
          ...payload,
          ...data,
          'id': data['id'],
          'body': data['body'] ?? angle.hook,
          'content_preview': data['content_preview'] ?? angle.hook,
          'status': data['status'] ?? 'pending_review',
        });
        await _upsertCachedPendingContentItem(created);
      }
      return data;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      final tempId = _newOfflineTempId('content');
      final optimistic = ContentItem.fromJson({
        'id': tempId,
        'title': angle.title,
        'body': angle.hook,
        'content_preview': angle.hook,
        'content_type': contentType,
        'status': 'pending_review',
        'project_id': resolvedProjectId,
        'priority': angle.confidence >= 80 ? 4 : 3,
        'tags': [
          angle.contentType,
          if (angle.narrativeThread.isNotEmpty) angle.narrativeThread,
        ],
        'source_robot': sourceRobot,
        'metadata': payload['metadata'],
        'created_at': DateTime.now().toIso8601String(),
      });
      await _upsertCachedPendingContentItem(optimistic);
      await _writeCachedData('content.body.$tempId', {'body': angle.hook});
      await _enqueueOfflineAction(
        resourceType: 'content',
        actionType: 'create',
        label: 'Create content from angle',
        method: 'POST',
        path: '/api/status/content',
        dedupeKey: 'content:create:$tempId',
        payload: payload,
        meta: _offlineActionMeta(
          entityType: 'content',
          entityId: tempId,
          tempId: tempId,
          dependsOnTempIds: dependsOnTempIds,
        ),
        mergePayload: false,
      );
      return {...optimistic.toJson(), 'queued': true};
    }
  }

  /// Dispatch an angle to the real content generation pipeline.
  /// Returns {task_id, content_record_id, format, status}.
  Future<Map<String, dynamic>?> dispatchPipeline({
    required AngleSuggestion angle,
    Map<String, dynamic>? creatorVoice,
    String? personaId,
    String? projectId,
  }) async {
    if (allowDemoData) {
      return {
        'task_id': 'demo-task',
        'content_record_id': 'demo-record',
        'format': angle.contentType,
        'status': 'running',
      };
    }

    // Map angle content_type to pipeline format
    final targetFormat = switch (angle.contentType) {
      'blog_post' => 'article',
      'social_post' => 'social_post',
      'newsletter' => 'newsletter',
      'short' || 'reel' => 'short',
      'video_script' => 'article',
      _ => angle.contentType,
    };

    try {
      final response = await _dio.post(
        '/api/psychology/dispatch-pipeline',
        data: _compactMap({
          'angle_data': {
            'title': angle.title,
            'hook': angle.hook,
            'angle': angle.angle,
            'content_type': angle.contentType,
            'narrative_thread': angle.narrativeThread,
            'pain_point_addressed': angle.painPointAddressed,
            'confidence': angle.confidence,
            'persona_id': personaId,
          },
          'target_format': targetFormat,
          'creator_voice': creatorVoice,
          'project_id': projectId,
        }),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// Poll pipeline dispatch status.
  Future<Map<String, dynamic>?> getPipelineStatus(String taskId) async {
    try {
      final response = await _dio.get(
        '/api/psychology/pipeline-status/$taskId',
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchScheduleJobs() async {
    if (allowDemoData) {
      return const [];
    }

    final data = await _getCachedData(
      '/api/scheduler/jobs',
      cacheKey: 'scheduler.jobs',
    );
    final jobs = data is List ? data : (_asMap(data)['jobs'] ?? []);
    if (jobs is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid schedule jobs response from FastAPI.',
      );
    }
    return jobs.cast<Map<String, dynamic>>();
  }

  Future<void> scheduleContent(String contentId, DateTime scheduledFor) async {
    if (allowDemoData) {
      return;
    }

    final idMappings = await _loadIdMappings();
    final resolvedContentId = _resolveEntityId(contentId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([contentId], idMappings);
    final payload = {'scheduled_for': scheduledFor.toIso8601String()};
    try {
      await _dio.patch(
        '/api/status/content/$resolvedContentId/schedule',
        data: payload,
      );
      final current = await _readCachedPendingContentItems();
      final next = current
          .map(
            (entry) => entry.id == contentId || entry.id == resolvedContentId
                ? entry.copyWith(
                    metadata: {
                      ...?entry.metadata,
                      'scheduled_for': scheduledFor.toIso8601String(),
                    },
                  )
                : entry,
          )
          .toList();
      await _writeCachedData(
        _pendingContentCacheKey,
        next.map((entry) => entry.toJson()).toList(),
      );
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        final current = await _readCachedPendingContentItems();
        final next = current
            .map(
              (entry) => entry.id == contentId || entry.id == resolvedContentId
                  ? entry.copyWith(
                      metadata: {
                        ...?entry.metadata,
                        'scheduled_for': scheduledFor.toIso8601String(),
                      },
                    )
                  : entry,
            )
            .toList();
        await _writeCachedData(
          _pendingContentCacheKey,
          next.map((entry) => entry.toJson()).toList(),
        );
        await _enqueueOfflineAction(
          resourceType: 'content',
          actionType: 'schedule',
          label: 'Schedule content',
          method: 'PATCH',
          path: '/api/status/content/$resolvedContentId/schedule',
          dedupeKey: 'content:schedule:$resolvedContentId',
          payload: payload,
          meta: _offlineActionMeta(
            entityType: 'content',
            entityId: resolvedContentId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return;
      }
      throw mapped;
    }
  }

  Future<List<PublishAccount>> fetchPublishAccounts({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const [];
    }

    final query = {'project_id': projectId};
    try {
      final data = await _getCachedData(
        '/api/publish/accounts',
        queryParameters: query,
        cacheKey: _cacheKeyFor(_publishAccountsCacheKey, query),
      );
      final accounts = _asMap(data)['accounts'] ?? [];
      if (accounts is! List) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid publish accounts response from FastAPI.',
        );
      }
      return accounts
          .map((json) => PublishAccount.fromJson(json as Map<String, dynamic>))
          .where(
            (account) => account.id.isNotEmpty && account.platform.isNotEmpty,
          )
          .toList();
    } on ApiException catch (mapped) {
      final detail = mapped.message.toLowerCase();
      final path = mapped.path ?? '';
      final isOptionalServerConfigFailure =
          path == '/api/publish/accounts' &&
          mapped.statusCode == 503 &&
          detail.contains('not configured');
      if (isOptionalServerConfigFailure ||
          mapped.type == ApiErrorType.offline) {
        return const [];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchGithubIntegrationStatus() async {
    if (allowDemoData) {
      return const {'connected': false};
    }

    try {
      return _asMap((await _dio.get('/api/integrations/github/status')).data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<String?> getGithubConnectUrl() async {
    if (allowDemoData) return null;

    try {
      final response = await _dio.get('/api/integrations/github/connect');
      final data = _asMap(response.data);
      return data['connect_url']?.toString();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<bool> disconnectGithubIntegration() async {
    if (allowDemoData) return false;

    try {
      await _dio.delete('/api/integrations/github/disconnect');
      return true;
    } on DioException {
      return false;
    }
  }

  // ─── Search Console ─────────────────────────────────────

  String _searchConsoleStatusKey(String projectId) =>
      _cacheKeyFor(_searchConsoleStatusCacheKey, {'projectId': projectId});

  String _searchConsoleSummaryKey(String projectId, String period) =>
      _cacheKeyFor('search_console.summary', {
        'period': period,
        'projectId': projectId,
      });

  String _projectIntelligenceStatusKey(String projectId) => _cacheKeyFor(
    _projectIntelligenceStatusCacheKey,
    {'projectId': projectId},
  );

  String _projectIntelligenceRecommendationsKey(String projectId) =>
      _cacheKeyFor('project_intelligence.recommendations', {
        'projectId': projectId,
      });

  Future<SearchConsoleConnectionStatus> fetchSearchConsoleStatus({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return SearchConsoleConnectionStatus.missing(projectId);
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final query = {'projectId': resolvedProjectId};
    final data = await _getCachedData(
      '/api/search-console/status',
      queryParameters: query,
      cacheKey: _searchConsoleStatusKey(resolvedProjectId),
    );
    return SearchConsoleConnectionStatus.fromJson(_asMap(data));
  }

  Future<SearchConsoleOAuthStart> startSearchConsoleOAuth({
    required String projectId,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Google Search Console cannot be connected in demo mode.',
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/search-console/oauth/start',
        queryParameters: {'projectId': resolvedProjectId},
      );
      return SearchConsoleOAuthStart.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.statusCode == 404 || mapped.statusCode == 405) {
        try {
          final response = await _dio.get(
            '/api/search-console/oauth/connect',
            queryParameters: {'projectId': resolvedProjectId},
          );
          return SearchConsoleOAuthStart.fromJson(_asMap(response.data));
        } on DioException catch (fallbackError) {
          throw _mapDioException(fallbackError);
        }
      }
      throw mapped;
    }
  }

  Future<List<SearchConsoleProperty>> fetchSearchConsoleProperties({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <SearchConsoleProperty>[];
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final query = {'projectId': resolvedProjectId};
    final data = _asMap(
      await _getCachedData(
        '/api/search-console/properties',
        queryParameters: query,
        cacheKey: _cacheKeyFor('search_console.properties', query),
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <SearchConsoleProperty>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) =>
              SearchConsoleProperty.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((entry) => entry.siteUrl.isNotEmpty)
        .toList();
  }

  Future<SearchConsoleConnectionStatus> setSearchConsoleProperty({
    required String projectId,
    required String propertyUrl,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/search-console/property',
        data: {'projectId': resolvedProjectId, 'propertyUrl': propertyUrl},
      );
      final status = SearchConsoleConnectionStatus.fromJson(
        _asMap(response.data),
      );
      await _writeCachedData(
        _searchConsoleStatusKey(resolvedProjectId),
        response.data,
      );
      return status;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<SearchConsoleConnectionStatus> validateSearchConsole({
    required String projectId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/search-console/validate',
        queryParameters: {'projectId': resolvedProjectId},
      );
      final status = SearchConsoleConnectionStatus.fromJson(
        _asMap(response.data),
      );
      await _writeCachedData(
        _searchConsoleStatusKey(resolvedProjectId),
        response.data,
      );
      return status;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<SearchConsoleConnectionStatus> disconnectSearchConsole({
    required String projectId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.delete(
        '/api/search-console/connection',
        queryParameters: {'projectId': resolvedProjectId},
      );
      final status = SearchConsoleConnectionStatus.fromJson(
        _asMap(response.data),
      );
      await _writeCachedData(
        _searchConsoleStatusKey(resolvedProjectId),
        response.data,
      );
      return status;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<SearchConsoleSummary> fetchSearchConsoleSummary({
    required String projectId,
    String period = '30d',
  }) async {
    if (allowDemoData) {
      return SearchConsoleSummary(
        projectId: projectId,
        period: period,
        periodName: period,
        overview:
            'Google Search Console is not connected in the demo workspace.',
        googleSearch: SearchConsoleSourceSection(
          source: 'search_console',
          sourceLabel: 'Google Search',
          period: period,
          stale: true,
          summary: 'Connect Google Search Console to populate this section.',
        ),
        siteTraffic: SearchConsoleSiteTrafficSection(
          source: 'private_analytics',
          sourceLabel: 'Site traffic (private tracker)',
          period: period,
          stale: true,
          message: 'No private analytics data available in demo mode.',
        ),
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final query = {'projectId': resolvedProjectId, 'period': period};
    final data = await _getCachedData(
      '/api/search-console/summary',
      queryParameters: query,
      cacheKey: _searchConsoleSummaryKey(resolvedProjectId, period),
    );
    return SearchConsoleSummary.fromJson(_asMap(data));
  }

  Future<SearchConsoleSummary> syncSearchConsole({
    required String projectId,
    String period = '30d',
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Search Console sync is unavailable in demo mode.',
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/search-console/sync',
        queryParameters: {'projectId': resolvedProjectId, 'period': period},
      );
      final summary = SearchConsoleSummary.fromJson(_asMap(response.data));
      await _writeCachedData(
        _searchConsoleSummaryKey(resolvedProjectId, period),
        response.data,
      );
      return summary;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<SearchConsoleOpportunity>> fetchSearchConsoleOpportunities({
    required String projectId,
    String period = '30d',
  }) async {
    if (allowDemoData) {
      return const <SearchConsoleOpportunity>[];
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final query = {'projectId': resolvedProjectId, 'period': period};
    final data = _asMap(
      await _getCachedData(
        '/api/search-console/opportunities',
        queryParameters: query,
        cacheKey: _cacheKeyFor('search_console.opportunities', query),
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <SearchConsoleOpportunity>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) => SearchConsoleOpportunity.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  Future<SearchConsoleIngestResponse> ingestSearchConsoleOpportunities({
    required String projectId,
    required List<SearchConsoleOpportunity> opportunities,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Adding Search Console opportunities is unavailable in demo mode.',
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/search-console/opportunities/ingest',
        data: {
          'projectId': resolvedProjectId,
          'opportunities': opportunities
              .map((entry) => entry.toIngestJson())
              .toList(growable: false),
        },
      );
      return SearchConsoleIngestResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  // ─── Project Intelligence ───────────────────────────────

  Future<ProjectIntelligenceStatus> fetchProjectIntelligenceStatus({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return ProjectIntelligenceStatus.empty(projectId);
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = await _getCachedData(
      '/api/projects/$resolvedProjectId/intelligence/status',
      cacheKey: _projectIntelligenceStatusKey(resolvedProjectId),
    );
    return ProjectIntelligenceStatus.fromJson(_asMap(data));
  }

  // ─── Multimodal video source intake ───────────────────

  String _videoSourceFolderPath(String projectId, String contentId) =>
      '/api/projects/$projectId/contents/$contentId/video-sources';

  VideoSourceFolder _videoSourceFolderFromData(Object? data) {
    final payload = _asMap(data);
    final nested = payload['folder'];
    return VideoSourceFolder.fromJson(
      nested is Map ? Map<String, dynamic>.from(nested) : payload,
    );
  }

  Future<VideoSourceFolder> openVideoSourceFolder({
    required String projectId,
    required String contentId,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Video source intake is unavailable in demo mode.',
      );
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final resolvedContentId = _resolveEntityId(contentId, idMappings);
    try {
      final response = await _dio.post(
        '${_videoSourceFolderPath(resolvedProjectId, resolvedContentId)}/folder',
        data: {'projectId': resolvedProjectId, 'contentId': resolvedContentId},
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceFolder> addVideoSourceText({
    required String projectId,
    required String contentId,
    required String folderId,
    required int revision,
    required String text,
    required String idempotencyKey,
    String? label,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.post(
        '$base/folder/$folderId/text',
        data: _compactMap({
          'expectedRevision': revision,
          'idempotencyKey': idempotencyKey,
          'text': text,
        }),
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceFolder> addVideoSourceLink({
    required String projectId,
    required String contentId,
    required String folderId,
    required int revision,
    required String url,
    required String idempotencyKey,
    String? label,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.post(
        '$base/folder/$folderId/link',
        data: _compactMap({
          'expectedRevision': revision,
          'idempotencyKey': idempotencyKey,
          'url': url,
        }),
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceFolder> uploadVideoSourceFile({
    required String projectId,
    required String contentId,
    required String folderId,
    required int revision,
    required VideoSourceUploadFile file,
    String? replaceSourceId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final repeatableFile = await _repeatableVideoSourceFile(file);
      final digest = await sha256
          .bind(await _videoSourceReadStream(repeatableFile))
          .first;
      final uploadIdempotencyKey =
          'video-source-upload-${sha256.convert(utf8.encode('$folderId:$revision:${digest.toString()}:${replaceSourceId ?? ''}'))}';
      final sessionResponse = await _dio.post(
        '$base/folder/$folderId/uploads',
        data: _compactMap({
          'sourceType': _videoSourceTypeForMime(repeatableFile.mimeType),
          'fileName': repeatableFile.fileName,
          'mimeType': repeatableFile.mimeType,
          'byteSize': repeatableFile.sizeBytes,
          'checksumSha256': digest.toString(),
          'expectedRevision': revision,
          'idempotencyKey': uploadIdempotencyKey,
          'replaceSourceId': replaceSourceId,
        }),
      );
      final session = VideoSourceUploadSession.fromJson(
        _asMap(sessionResponse.data),
      );
      if (session.transport == VideoSourceUploadTransport.proxy) {
        final multipart = await _multipartForVideoSource(repeatableFile);
        final uploadResponse = await _dio.post(
          '$base/folder/$folderId/uploads/${session.sessionId}/content',
          data: FormData.fromMap({'file': multipart}),
          onSendProgress: onProgress,
        );
        return _videoSourceFolderFromData(uploadResponse.data);
      }
      final receipts = await _uploadVideoSourceParts(
        base: base,
        folderId: folderId,
        session: session,
        file: repeatableFile,
        onProgress: onProgress,
      );
      final completeResponse = await _dio.post(
        '$base/folder/$folderId/uploads/${session.sessionId}/complete',
        data: {'parts': receipts},
      );
      return _videoSourceFolderFromData(completeResponse.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> _uploadVideoSourceParts({
    required String base,
    required String folderId,
    required VideoSourceUploadSession session,
    required VideoSourceUploadFile file,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (session.parts.isEmpty) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The multipart upload has no part instructions.',
      );
    }
    final uploadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 2),
        followRedirects: false,
      ),
    );
    final receipts = <Map<String, dynamic>>[];
    final builder = BytesBuilder(copy: false);
    var partIndex = 0;
    var sentTotal = 0;
    try {
      await for (final chunk in await _videoSourceReadStream(file)) {
        var offset = 0;
        while (offset < chunk.length) {
          if (partIndex >= session.parts.length) {
            throw const ApiException(
              ApiErrorType.invalidResponse,
              'The selected file exceeds its upload instructions.',
            );
          }
          final instruction = session.parts[partIndex];
          final remaining = instruction.sizeBytes - builder.length;
          final available = chunk.length - offset;
          final take = remaining < available ? remaining : available;
          builder.add(chunk.sublist(offset, offset + take));
          offset += take;
          if (builder.length != instruction.sizeBytes) continue;
          final bytes = builder.takeBytes();
          final checksum = sha256.convert(bytes).toString();
          final signResponse = await _dio.post(
            '$base/folder/$folderId/uploads/${session.sessionId}/parts/${instruction.partNumber}/sign',
            data: {
              'partNumber': instruction.partNumber,
              'checksumSha256': checksum,
              'sizeBytes': bytes.length,
            },
          );
          final signed = VideoSourceUploadPart.fromJson(
            _asMap(signResponse.data),
          );
          final uploadUrl = signed.uploadUrl;
          if (signed.partNumber != instruction.partNumber ||
              signed.sizeBytes != bytes.length ||
              uploadUrl == null ||
              uploadUrl.isEmpty) {
            throw const ApiException(
              ApiErrorType.invalidResponse,
              'The signed multipart instruction is invalid.',
            );
          }
          final response = await uploadDio.putUri(
            Uri.parse(uploadUrl),
            data: Stream<List<int>>.value(bytes),
            options: Options(
              contentType: file.mimeType,
              headers: {
                ...signed.headers,
                Headers.contentLengthHeader: bytes.length,
              },
            ),
          );
          final etag = response.headers.value('etag');
          if (etag == null || etag.trim().isEmpty) {
            throw const ApiException(
              ApiErrorType.invalidResponse,
              'The storage service did not return a part receipt.',
            );
          }
          receipts.add({
            'partNumber': instruction.partNumber,
            'etag': etag,
            'checksumSha256': checksum,
            'sizeBytes': bytes.length,
          });
          sentTotal += bytes.length;
          onProgress?.call(sentTotal, file.sizeBytes);
          partIndex++;
        }
      }
    } finally {
      uploadDio.close(force: true);
    }
    if (builder.length != 0 ||
        partIndex != session.parts.length ||
        sentTotal != file.sizeBytes) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The selected file does not match its upload instructions.',
      );
    }
    return receipts;
  }

  Future<MultipartFile> _multipartForVideoSource(
    VideoSourceUploadFile file,
  ) async {
    final bytes = file.bytes;
    if (bytes != null) {
      return MultipartFile.fromBytes(bytes, filename: file.fileName);
    }
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return MultipartFile.fromFile(path, filename: file.fileName);
    }
    final stream = file.readStream;
    if (stream != null) {
      return MultipartFile.fromStream(
        () => stream,
        file.sizeBytes,
        filename: file.fileName,
      );
    }
    throw const ApiException(
      ApiErrorType.invalidResponse,
      'The selected file cannot be read on this platform.',
    );
  }

  Future<VideoSourceUploadFile> _repeatableVideoSourceFile(
    VideoSourceUploadFile file,
  ) async {
    if (file.bytes != null || (file.path?.isNotEmpty ?? false)) return file;
    final source = file.readStream;
    if (source == null || file.sizeBytes > 10 * 1024 * 1024) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The selected file cannot be read safely on this platform.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      builder.add(chunk);
      if (builder.length > file.sizeBytes ||
          builder.length > 10 * 1024 * 1024) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'The selected file exceeds its declared size.',
        );
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.length != file.sizeBytes) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The selected file is incomplete.',
      );
    }
    return VideoSourceUploadFile(
      clientFileId: file.clientFileId,
      fileName: file.fileName,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      bytes: bytes,
    );
  }

  Future<Stream<List<int>>> _videoSourceReadStream(
    VideoSourceUploadFile file,
  ) async {
    final bytes = file.bytes;
    if (bytes != null) return Stream<List<int>>.value(bytes);
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return (await MultipartFile.fromFile(path)).finalize();
    }
    final stream = file.readStream;
    if (stream != null) return stream;
    throw const ApiException(
      ApiErrorType.invalidResponse,
      'The selected file cannot be read on this platform.',
    );
  }

  String _videoSourceTypeForMime(String mimeType) {
    if (mimeType.startsWith('image/')) return 'binary_image';
    if (mimeType.startsWith('video/')) return 'binary_video';
    if (mimeType.startsWith('audio/')) return 'binary_audio';
    throw const ApiException(
      ApiErrorType.invalidResponse,
      'This file type is not supported.',
    );
  }

  Future<VideoSourceFolder> removeVideoSource({
    required String projectId,
    required String contentId,
    required String folderId,
    required String sourceId,
    required int revision,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.delete(
        '$base/folder/$folderId/sources/$sourceId',
        data: {'revision': revision},
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceFolder> retryVideoSource({
    required String projectId,
    required String contentId,
    required String folderId,
    required String sourceId,
    required int revision,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.post(
        '$base/folder/$folderId/sources/$sourceId/retry',
        data: {'revision': revision},
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceFolder> markVideoSourcesReady({
    required String projectId,
    required String contentId,
    required String folderId,
    required int revision,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.post(
        '$base/folder/$folderId/ready',
        data: {'revision': revision},
      );
      return _videoSourceFolderFromData(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<VideoSourceGenerateResult> generateVideoFromSources({
    required String projectId,
    required String contentId,
    required VideoSourceGenerateCommand command,
  }) async {
    final base = _videoSourceFolderPath(projectId, contentId);
    try {
      final response = await _dio.post(
        '$base/folder/${command.folderId}/generate',
        data: command.toJson(),
      );
      return VideoSourceGenerateResult.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ProjectIntelligenceUploadResult> uploadProjectIntelligenceFiles({
    required String projectId,
    required List<ProjectIntelligenceUploadFile> files,
    bool includeAiSynthesis = false,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Project Intelligence uploads are unavailable in demo mode.',
      );
    }

    if (files.isEmpty) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Select at least one file.',
      );
    }

    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final formData = FormData.fromMap({
      'files': files
          .map(
            (entry) =>
                MultipartFile.fromBytes(entry.bytes, filename: entry.fileName),
          )
          .toList(growable: false),
    });

    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/intelligence/upload',
        queryParameters: {'includeAiSynthesis': includeAiSynthesis},
        data: formData,
      );
      final result = ProjectIntelligenceUploadResult.fromJson(
        _asMap(response.data),
      );
      return result;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        throw ApiException(
          ApiErrorType.offline,
          'File uploads are unavailable until FastAPI is back.',
          statusCode: mapped.statusCode,
          responseBody: mapped.responseBody,
          responseHeaders: mapped.responseHeaders,
          method: mapped.method,
          path: mapped.path,
        );
      }
      throw mapped;
    }
  }

  Future<ProjectIntelligenceUploadResult> syncProjectIntelligence({
    required String projectId,
    List<String> connectors = const <String>[],
    bool includeAiSynthesis = false,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Project Intelligence sync is unavailable in demo mode.',
      );
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/intelligence/sync',
        data: {
          'connectors': connectors,
          'includeAiSynthesis': includeAiSynthesis,
        },
      );
      return ProjectIntelligenceUploadResult.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<ProjectIntelligenceJob>> fetchProjectIntelligenceJobs({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <ProjectIntelligenceJob>[];
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = _asMap(
      await _getCachedData(
        '/api/projects/$resolvedProjectId/intelligence/jobs',
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <ProjectIntelligenceJob>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) =>
              ProjectIntelligenceJob.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  Future<List<ProjectIntelligenceSource>> fetchProjectIntelligenceSources({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <ProjectIntelligenceSource>[];
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = _asMap(
      await _getCachedData(
        '/api/projects/$resolvedProjectId/intelligence/sources',
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <ProjectIntelligenceSource>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) => ProjectIntelligenceSource.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  Future<void> removeProjectIntelligenceSource({
    required String projectId,
    required String sourceId,
  }) async {
    if (allowDemoData) {
      return;
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      await _dio.delete(
        '/api/projects/$resolvedProjectId/intelligence/sources/$sourceId',
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<ProjectIntelligenceDocument>> fetchProjectIntelligenceDocuments({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <ProjectIntelligenceDocument>[];
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = _asMap(
      await _getCachedData(
        '/api/projects/$resolvedProjectId/intelligence/documents',
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <ProjectIntelligenceDocument>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) => ProjectIntelligenceDocument.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  Future<List<ProjectIntelligenceFact>> fetchProjectIntelligenceFacts({
    required String projectId,
  }) async {
    if (allowDemoData) {
      return const <ProjectIntelligenceFact>[];
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = _asMap(
      await _getCachedData(
        '/api/projects/$resolvedProjectId/intelligence/facts',
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <ProjectIntelligenceFact>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) => ProjectIntelligenceFact.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  Future<List<ProjectIntelligenceRecommendation>>
  fetchProjectIntelligenceRecommendations({required String projectId}) async {
    if (allowDemoData) {
      return const <ProjectIntelligenceRecommendation>[];
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = _asMap(
      await _getCachedData(
        '/api/projects/$resolvedProjectId/intelligence/recommendations',
        cacheKey: _projectIntelligenceRecommendationsKey(resolvedProjectId),
      ),
    );
    final items = data['items'];
    if (items is! List) {
      return const <ProjectIntelligenceRecommendation>[];
    }
    return items
        .whereType<Map>()
        .map(
          (entry) => ProjectIntelligenceRecommendation.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  Future<ProjectIntelligenceProviderReadiness>
  fetchProjectIntelligenceProviderReadiness({required String projectId}) async {
    if (allowDemoData) {
      return const ProjectIntelligenceProviderReadiness(
        projectId: '',
        readiness: 'needs_evidence',
        score: 0,
        rationale: '',
        recommendedNextStep: '',
      );
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    final data = await _getCachedData(
      '/api/projects/$resolvedProjectId/intelligence/provider-readiness',
      cacheKey: _cacheKeyFor('project_intelligence.readiness', {
        'projectId': resolvedProjectId,
      }),
    );
    return ProjectIntelligenceProviderReadiness.fromJson(_asMap(data));
  }

  Future<ProjectIntelligenceIdeaPoolActionResult>
  addProjectIntelligenceRecommendationToIdeaPool({
    required String projectId,
    required String recommendationId,
  }) async {
    if (allowDemoData) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Idea Pool action is unavailable in demo mode.',
      );
    }
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = _resolveEntityId(projectId, idMappings);
    try {
      final response = await _dio.post(
        '/api/projects/$resolvedProjectId/intelligence/recommendations/$recommendationId/idea-pool',
      );
      return ProjectIntelligenceIdeaPoolActionResult.fromJson(
        _asMap(response.data),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AIRuntimeSettings> fetchAiRuntimeSettings() async {
    if (allowDemoData) {
      return AIRuntimeSettings.fallback();
    }

    try {
      final response = await _dio.get('/api/settings/ai-runtime');
      return AIRuntimeSettings.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AIRuntimeSettings> updateAiRuntimeMode(String mode) async {
    if (allowDemoData) {
      return AIRuntimeSettings.fallback();
    }

    try {
      final response = await _dio.put(
        '/api/settings/ai-runtime',
        data: {'mode': mode},
      );
      return AIRuntimeSettings.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AIProviderCredentialStatus> fetchProviderCredentialStatus(
    String provider,
  ) async {
    if (allowDemoData) {
      return AIProviderCredentialStatus(
        provider: provider,
        configured: false,
        validationStatus: 'unknown',
      );
    }

    try {
      final response = await _dio.get('/api/settings/integrations/$provider');
      return AIProviderCredentialStatus.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<AIProviderCredentialStatus> saveProviderCredential(
    String provider,
    String secret,
  ) async {
    if (allowDemoData) {
      return AIProviderCredentialStatus(
        provider: provider,
        configured: true,
        validationStatus: 'unknown',
      );
    }

    try {
      final response = await _dio.put(
        '/api/settings/integrations/$provider',
        data: {'secret': secret},
      );
      return AIProviderCredentialStatus.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<bool> deleteProviderCredential(String provider) async {
    if (allowDemoData) {
      return true;
    }

    try {
      final response = await _dio.delete(
        '/api/settings/integrations/$provider',
      );
      final payload = _asMapOrNull(response.data);
      if (payload == null) {
        return true;
      }
      return payload['deleted'] as bool? ?? true;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  OpenRouterCredentialStatus _toOpenRouterStatus(
    AIProviderCredentialStatus status,
  ) {
    return OpenRouterCredentialStatus(
      provider: status.provider,
      configured: status.configured,
      maskedSecret: status.maskedSecret,
      validationStatus: status.validationStatus,
      lastValidatedAt: status.lastValidatedAt,
      updatedAt: status.updatedAt,
    );
  }

  Future<OpenRouterCredentialStatus> fetchOpenRouterCredentialStatus() async {
    final status = await fetchProviderCredentialStatus('openrouter');
    return _toOpenRouterStatus(status);
  }

  Future<OpenRouterCredentialStatus> saveOpenRouterCredential(
    String apiKey,
  ) async {
    final status = await saveProviderCredential('openrouter', apiKey);
    return _toOpenRouterStatus(status);
  }

  Future<OpenRouterCredentialValidationResult>
  validateOpenRouterCredential() async {
    if (allowDemoData) {
      return const OpenRouterCredentialValidationResult(
        provider: 'openrouter',
        valid: false,
        validationStatus: 'missing',
        message: 'No OpenRouter key configured.',
      );
    }

    try {
      final response = await _dio.post(
        '/api/settings/integrations/openrouter/validate',
      );
      return OpenRouterCredentialValidationResult.fromJson(
        _asMap(response.data),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<bool> deleteOpenRouterCredential() async {
    return deleteProviderCredential('openrouter');
  }

  Future<EmailSourceStatus> fetchEmailSourceStatus() async {
    if (allowDemoData) {
      return const EmailSourceStatus(
        configured: false,
        validationStatus: 'missing',
      );
    }

    try {
      final response = await _dio.get(
        '/api/settings/integrations/email-source',
      );
      return EmailSourceStatus.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<EmailSourceStatus> saveEmailSource({
    required String email,
    required String host,
    required String sourceFolder,
    required String archiveFolder,
    String? projectId,
    String? appPassword,
  }) async {
    try {
      final payload = <String, dynamic>{
        'email': email,
        'host': host,
        'sourceFolder': sourceFolder,
        'archiveFolder': archiveFolder,
        'projectId': projectId,
      };
      final password = appPassword?.trim();
      if (password != null && password.isNotEmpty) {
        payload['appPassword'] = password;
      }
      final response = await _dio.put(
        '/api/settings/integrations/email-source',
        data: payload,
      );
      return EmailSourceStatus.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<EmailSourceValidationResult> validateEmailSource() async {
    try {
      final response = await _dio.post(
        '/api/settings/integrations/email-source/validate',
      );
      return EmailSourceValidationResult.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<bool> deleteEmailSource() async {
    try {
      final response = await _dio.delete(
        '/api/settings/integrations/email-source',
      );
      final payload = _asMapOrNull(response.data);
      return payload?['deleted'] as bool? ?? true;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchGithubRepos({
    String? query,
    int perPage = 100,
    int page = 1,
  }) async {
    if (allowDemoData) {
      return const [];
    }

    try {
      final response = await _dio.get(
        '/api/integrations/github/repos',
        queryParameters: _compactMap({
          'query': query?.trim().isEmpty == true ? null : query?.trim(),
          'per_page': perPage,
          'page': page,
        }),
      );
      final data = _asMap(response.data);
      final repos = data['repos'];
      if (repos is List) {
        return repos
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }
      if (repos is List<Map<String, dynamic>>) {
        return repos;
      }
      return const [];
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        return const [];
      }
      throw mapped;
    }
  }

  Future<Map<String, dynamic>> fetchGithubRepoTree({
    required String owner,
    required String repo,
    String path = '',
  }) async {
    if (allowDemoData) {
      return const {};
    }

    try {
      return _asMap(
        (await _dio.get(
          '/api/integrations/github/repo-tree',
          queryParameters: _compactMap({
            'owner': owner.trim(),
            'repo': repo.trim(),
            'path': path.trim().isEmpty ? null : path.trim(),
          }),
        )).data,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// Get OAuth connect URL for a platform. Opens in browser to authorize.
  Future<String?> getConnectUrl(
    String platform, {
    required String projectId,
  }) async {
    if (allowDemoData) return null;

    try {
      final response = await _dio.get(
        '/api/publish/connect/$platform',
        queryParameters: {'project_id': projectId},
      );
      final data = _asMap(response.data);
      return (data['connect_url'] ?? data['authUrl']) as String?;
    } on DioException {
      return null;
    }
  }

  /// Disconnect a social account.
  Future<bool> disconnectAccount(
    String accountId, {
    required String projectId,
  }) async {
    if (allowDemoData) return false;

    try {
      await _dio.delete(
        '/api/publish/accounts/$accountId',
        queryParameters: {'project_id': projectId},
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>> publishContent({
    required String content,
    required List<Map<String, String>> platforms,
    required String contentRecordId,
    String? title,
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    bool publishNow = true,
    bool useAssetPlacements = true,
  }) async {
    if (allowDemoData) {
      return {
        'success': false,
        'error': 'Publishing is disabled in demo mode.',
      };
    }

    final payload = _compactMap({
      'content': content,
      'platforms': platforms,
      'title': title,
      'media_contract_version': useAssetPlacements
          ? 'asset_placements.v1'
          : null,
      'media_urls': !useAssetPlacements && mediaUrls.isNotEmpty
          ? mediaUrls
          : null,
      'tags': tags.isEmpty ? null : tags,
      'content_record_id': contentRecordId,
      'publish_now': publishNow,
    });
    try {
      final response = await _dio.post('/api/publish', data: payload);
      return _asMap(response.data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'publish',
        actionType: 'publish',
        label: 'Publish content',
        method: 'POST',
        path: '/api/publish',
        dedupeKey:
            'publish:$contentRecordId:${platforms.map((entry) => entry['platform']).join(',')}',
        payload: payload,
        blockedMessage:
            'Publishing is unavailable until FastAPI and publish integrations are back.',
      );
    }
  }

  Future<SocialPlacementRegistry> fetchPlacementRegistry({
    String locale = 'en',
  }) async {
    try {
      final response = await _dio.get(
        '/api/placement-registry',
        queryParameters: {'locale': locale},
      );
      return SocialPlacementRegistry.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<PlacementPlan> fetchPlacementPlan({
    required String contentId,
    required List<String> platforms,
    String locale = 'en',
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedContentId = _resolveEntityId(contentId, idMappings);
    try {
      final response = await _dio.get(
        '/api/content/$resolvedContentId/placement-plan',
        queryParameters: {'platform': platforms, 'locale': locale},
        options: Options(listFormat: ListFormat.multi),
      );
      return PlacementPlan.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<PublishPreflightResponse> preflightPublish({
    required String contentRecordId,
    required List<PublishPlatformTarget> platforms,
    String? registryVersion,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedContentId = _resolveEntityId(contentRecordId, idMappings);
    final payload = _compactMap({
      'content_record_id': resolvedContentId,
      'platforms': platforms.map((target) => target.toJson()).toList(),
      'registry_version': normalizeOptionalText(registryVersion),
    });
    try {
      final response = await _dio.post('/api/publish/preflight', data: payload);
      return PublishPreflightResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  // ─── Feedback ─────────────────────────────────────────────

  Future<FeedbackEntry> createTextFeedback({
    required String message,
    required String platform,
    required String locale,
    String? userEmail,
  }) async {
    final payload = _compactMap({
      'message': message,
      'platform': platform,
      'locale': locale,
      'userEmail': userEmail,
    });
    try {
      final response = await _dio.post('/api/feedback/text', data: payload);
      return FeedbackEntry.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }
      await _enqueueOfflineAction(
        resourceType: 'feedback',
        actionType: 'create_text',
        label: 'Submit text feedback',
        method: 'POST',
        path: '/api/feedback/text',
        dedupeKey: 'feedback:text:${message.trim().hashCode}',
        payload: payload,
      );
      return FeedbackEntry(
        id: 'queued-feedback-${DateTime.now().millisecondsSinceEpoch}',
        type: FeedbackEntryType.text,
        message: message,
        platform: platform,
        locale: locale,
        userEmail: userEmail,
        createdAt: DateTime.now(),
        status: FeedbackEntryStatus.newEntry,
      );
    }
  }

  Future<FeedbackUploadTarget> getFeedbackUploadUrl({
    required String mimeType,
    required String fileName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/feedback/audio/upload-url',
        data: {'mimeType': mimeType, 'fileName': fileName},
      );
      return FeedbackUploadTarget.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> uploadFeedbackAudio(
    FeedbackUploadTarget target,
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final headers = <String, dynamic>{
      Headers.contentTypeHeader: mimeType,
      ...target.headers,
    };

    try {
      await Dio().request<void>(
        target.uploadUrl,
        data: bytes,
        options: Options(
          method: target.method,
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<FeedbackEntry> createAudioFeedback({
    required String storageId,
    required int durationMs,
    required String platform,
    required String locale,
    String? userEmail,
  }) async {
    final payload = _compactMap({
      'audioStorageId': storageId,
      'durationMs': durationMs,
      'platform': platform,
      'locale': locale,
      'userEmail': userEmail,
    });
    try {
      final response = await _dio.post('/api/feedback/audio', data: payload);
      return FeedbackEntry.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'feedback',
        actionType: 'create_audio',
        label: 'Submit audio feedback',
        method: 'POST',
        path: '/api/feedback/audio',
        dedupeKey: 'feedback:audio:$storageId',
        payload: payload,
        blockedMessage: 'Audio uploads are unavailable until FastAPI is back.',
      );
    }
  }

  Future<bool> fetchFeedbackAdminCapability() async {
    if (allowDemoData) {
      return false;
    }

    try {
      final response = await _dio.get('/api/feedback/admin/capability');
      final payload = response.data;
      if (payload is bool) {
        return payload;
      }

      final json = _asMap(payload);
      final canAccess = _asBool(
        json['canAccess'] ??
            json['can_access'] ??
            json['allowed'] ??
            json['isAdmin'] ??
            json['is_admin'] ??
            json['enabled'],
      );
      if (canAccess == null) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'Invalid feedback admin capability response from FastAPI.',
        );
      }
      return canAccess;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return false;
      }
      throw _mapDioException(error);
    }
  }

  Future<List<FeedbackEntry>> listAdminFeedback({
    String? status,
    String? type,
  }) async {
    final query = _compactMap({'status': status, 'type': type});
    final cacheKey = _cacheKeyFor(_feedbackAdminCacheKey, query);
    dynamic data;
    try {
      final response = await _dio.get(
        '/api/feedback/admin',
        queryParameters: query,
      );
      data = response.data;
      await _writeCachedData(cacheKey, data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final statusCode = error.response?.statusCode;
      if (mapped.isUnauthorized || statusCode == 403) {
        throw mapped;
      }
      final cached = await cacheStore?.read(offlineScope, cacheKey);
      if (cached == null) {
        throw mapped;
      }
      await onCacheKeyStale?.call(cacheKey);
      data = cached.data;
    }

    final items = data is List
        ? data
        : (_asMap(data)['items'] ?? _asMap(data)['entries'] ?? []);
    if (items is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid admin feedback response from FastAPI.',
      );
    }
    return items
        .map((json) => FeedbackEntry.fromJson(json as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> markFeedbackReviewed(String feedbackId) async {
    try {
      await _dio.post('/api/feedback/admin/$feedbackId/review');
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'feedback',
          actionType: 'mark_reviewed',
          label: 'Mark feedback reviewed',
          method: 'POST',
          path: '/api/feedback/admin/$feedbackId/review',
          dedupeKey: 'feedback:review:$feedbackId',
          payload: const <String, dynamic>{},
        );
        return;
      }
      throw mapped;
    }
  }

  // ─── Reels ────────────────────────────────────────────────

  Future<Map<String, dynamic>> downloadReel({
    required String url,
    required String userId,
    String? bunnyStorageKey,
    String? bunnyCdnHostname,
  }) async {
    try {
      final response = await _dio.post(
        '/api/reels/download',
        data: _compactMap({
          'url': url,
          'user_id': userId,
          'bunny_storage_key': bunnyStorageKey,
          'bunny_cdn_hostname': bunnyCdnHostname,
        }),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> getReelsCookieStatus(String userId) async {
    try {
      final data = await _getCachedData(
        '/api/reels/cookies/status',
        cacheKey: 'reels.cookies.$userId',
        queryParameters: {'user_id': userId},
      );
      return _asMap(data);
    } on ApiException {
      if (allowDemoData) return {'has_cookies': false};
      rethrow;
    }
  }

  // ─── Content Tools ───────────────────────────────────────

  Future<Map<String, dynamic>> fetchPendingValidations({
    String? projectId,
    int daysAhead = 7,
  }) async {
    if (allowDemoData) return {'total': 0, 'articles': []};
    final params = <String, dynamic>{'days_ahead': daysAhead};
    if (projectId != null) params['project_id'] = projectId;
    final data = await _getCachedData(
      '/api/content/pending-validations',
      cacheKey: _cacheKeyFor('content.pending_validations', params),
      queryParameters: params,
    );
    return _asMap(data);
  }

  // ─── Work Domains ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWorkDomains({
    String? projectId,
  }) async {
    if (allowDemoData) return const [];
    final params = <String, dynamic>{};
    if (projectId != null) params['projectId'] = projectId;
    final data = await _getCachedData(
      '/api/work-domains',
      cacheKey: _cacheKeyFor('work_domains', params),
      queryParameters: params,
    );
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── Activity ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActivity({
    String? projectId,
    int limit = 50,
  }) async {
    if (allowDemoData) return const [];
    final params = <String, dynamic>{'limit': limit};
    if (projectId != null) params['projectId'] = projectId;
    final data = await _getCachedData(
      '/api/activity',
      cacheKey: _cacheKeyFor('activity', params),
      queryParameters: params,
    );
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── Runs ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRuns({
    String? robotName,
    String? status,
    int limit = 20,
  }) async {
    if (allowDemoData) return const [];
    final params = <String, dynamic>{'limit': limit};
    if (robotName != null) params['robot_name'] = robotName;
    if (status != null) params['status'] = status;
    final data = await _getCachedData(
      '/runs',
      cacheKey: _cacheKeyFor('runs', params),
      queryParameters: params,
    );
    if (data is List) return data.cast<Map<String, dynamic>>();
    return (_asMap(data)['runs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // ─── Templates ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDefaultTemplates() async {
    if (allowDemoData) return const [];
    final data = await _getCachedData(
      '/api/templates/defaults',
      cacheKey: 'templates.defaults',
    );
    if (data is List) return data.cast<Map<String, dynamic>>();
    return (_asMap(data)['templates'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
  }

  // ─── Newsletter ───────────────────────────────────────────

  Future<Map<String, dynamic>> checkNewsletterConfig() async {
    if (allowDemoData) return {'configured': false};
    final data = await _getCachedData(
      '/api/newsletter/config/check',
      cacheKey: 'newsletter.config',
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> generateNewsletter({
    required String name,
    required List<String> topics,
    required String targetAudience,
    String tone = 'professional',
    int maxSections = 5,
  }) async {
    try {
      final response = await _dio.post(
        '/api/newsletter/generate-async',
        data: {
          'name': name,
          'topics': topics,
          'target_audience': targetAudience,
          'tone': tone,
          'max_sections': maxSections,
        },
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> getNewsletterJobStatus(String jobId) async {
    try {
      final response = await _dio.get('/api/newsletter/jobs/$jobId');
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  // ─── Research ─────────────────────────────────────────────

  Future<Map<String, dynamic>> runCompetitorAnalysis({
    required String targetUrl,
    required List<String> competitors,
    List<String> keywords = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/api/research/competitor-analysis',
        data: {
          'target_url': targetUrl,
          'competitors': competitors,
          if (keywords.isNotEmpty) 'keywords': keywords,
        },
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  // ─── SEO Mesh ─────────────────────────────────────────────

  Future<Map<String, dynamic>> analyzeMesh({required String repoUrl}) async {
    try {
      final response = await _dio.post(
        '/api/mesh/analyze',
        data: {'repo_url': repoUrl},
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  // ─── Affiliations ──────────────────────────────────────────

  Future<List<AffiliateLink>> fetchAffiliations({String? projectId}) async {
    if (allowDemoData) return const [];
    final idMappings = await _loadIdMappings();
    final queryParams = <String, dynamic>{};
    if (projectId != null) {
      queryParams['projectId'] = _resolveEntityId(projectId, idMappings);
    }
    final data = await _getCachedData(
      '/api/affiliations',
      cacheKey: _cacheKeyFor(_affiliationsCacheKey, queryParams),
      queryParameters: queryParams,
    );
    if (data is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid affiliations response from FastAPI.',
      );
    }
    return data
        .map((json) => AffiliateLink.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<AffiliateLink> createAffiliation(Map<String, dynamic> data) async {
    final idMappings = await _loadIdMappings();
    final resolvedData =
        _asMapOrNull(rewriteOfflineIdsInValue(data, idMappings)) ?? data;
    final dependsOnTempIds = _dependsOnTempIdsForIds([
      data['projectId']?.toString(),
    ], idMappings);
    try {
      final response = await _dio.post('/api/affiliations', data: resolvedData);
      final affiliation = AffiliateLink.fromJson(_asMap(response.data));
      await _upsertCachedAffiliation(affiliation);
      return affiliation;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      final tempId = _newOfflineTempId('affiliation');
      final optimistic = AffiliateLink(
        id: tempId,
        projectId: resolvedData['projectId']?.toString(),
        name: resolvedData['name']?.toString() ?? '',
        url: resolvedData['url']?.toString() ?? '',
        description: resolvedData['description']?.toString(),
        contactUrl: resolvedData['contactUrl']?.toString(),
        loginUrl: resolvedData['loginUrl']?.toString(),
        category: resolvedData['category']?.toString(),
        commission: resolvedData['commission']?.toString(),
        keywords:
            (resolvedData['keywords'] as List?)
                ?.map((entry) => entry.toString())
                .toList() ??
            const <String>[],
        status: resolvedData['status']?.toString() ?? 'active',
        notes: resolvedData['notes']?.toString(),
        expiresAt: resolvedData['expiresAt'] == null
            ? null
            : DateTime.tryParse(resolvedData['expiresAt'].toString()),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _upsertCachedAffiliation(optimistic);
      await _enqueueOfflineAction(
        resourceType: 'affiliations',
        actionType: 'create',
        label: 'Create affiliation',
        method: 'POST',
        path: '/api/affiliations',
        dedupeKey:
            'affiliations:create:${(resolvedData['name'] ?? '').toString().trim().toLowerCase()}',
        payload: resolvedData,
        meta: _offlineActionMeta(
          entityType: 'affiliation',
          entityId: tempId,
          tempId: tempId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return optimistic;
    }
  }

  Future<AffiliateLink> updateAffiliation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final idMappings = await _loadIdMappings();
    final resolvedId = _resolveEntityId(id, idMappings);
    final resolvedData =
        _asMapOrNull(rewriteOfflineIdsInValue(data, idMappings)) ?? data;
    final dependsOnTempIds = _dependsOnTempIdsForIds([
      id,
      data['projectId']?.toString(),
    ], idMappings);
    try {
      final response = await _dio.put(
        '/api/affiliations/$resolvedId',
        data: resolvedData,
      );
      final saved = AffiliateLink.fromJson(_asMap(response.data));
      final queryKey = _cacheKeyFor(_affiliationsCacheKey);
      final cached = await _readCachedList(queryKey) ?? const <dynamic>[];
      final next = cached
          .map((entry) => AffiliateLink.fromJson(entry as Map<String, dynamic>))
          .map(
            (entry) => entry.id == id || entry.id == resolvedId ? saved : entry,
          )
          .toList();
      await _writeCachedData(
        queryKey,
        next.map((entry) => entry.toJson()).toList(),
      );
      return saved;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      final queryKey = _cacheKeyFor(_affiliationsCacheKey);
      final cached = await _readCachedList(queryKey) ?? const <dynamic>[];
      final next = cached
          .map((entry) => AffiliateLink.fromJson(entry as Map<String, dynamic>))
          .map(
            (entry) => entry.id == id || entry.id == resolvedId
                ? entry.copyWith(
                    name: resolvedData['name']?.toString(),
                    url: resolvedData['url']?.toString(),
                    projectId: resolvedData['projectId']?.toString(),
                    description: resolvedData['description']?.toString(),
                    contactUrl: resolvedData['contactUrl']?.toString(),
                    loginUrl: resolvedData['loginUrl']?.toString(),
                    category: resolvedData['category']?.toString(),
                    commission: resolvedData['commission']?.toString(),
                    keywords: (resolvedData['keywords'] as List?)
                        ?.cast<String>(),
                    status: resolvedData['status']?.toString(),
                    notes: resolvedData['notes']?.toString(),
                    expiresAt: resolvedData['expiresAt'] == null
                        ? null
                        : DateTime.tryParse(
                            resolvedData['expiresAt'].toString(),
                          ),
                  )
                : entry,
          )
          .toList();
      await _writeCachedData(
        queryKey,
        next.map((entry) => entry.toJson()).toList(),
      );
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'affiliations',
          actionType: 'update',
          label: 'Update affiliation',
          method: 'PUT',
          path: '/api/affiliations/$resolvedId',
          dedupeKey: 'affiliations:update:$resolvedId',
          payload: resolvedData,
          meta: _offlineActionMeta(
            entityType: 'affiliation',
            entityId: resolvedId,
            dependsOnTempIds: dependsOnTempIds,
          ),
        );
        return next.firstWhere(
          (entry) => entry.id == id || entry.id == resolvedId,
          orElse: () => AffiliateLink(
            id: id,
            name: resolvedData['name']?.toString() ?? '',
            url: resolvedData['url']?.toString() ?? '',
          ),
        );
      }
      throw mapped;
    }
  }

  Future<bool> deleteAffiliation(String id) async {
    try {
      await _dio.delete('/api/affiliations/$id');
      return true;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'affiliations',
        actionType: 'delete',
        label: 'Delete affiliation',
        method: 'DELETE',
        path: '/api/affiliations/$id',
        dedupeKey: 'affiliations:delete:$id',
        blockedMessage:
            'Deleting an affiliation is unavailable until FastAPI is back.',
      );
    }
  }

  // ─── Idea Pool ─────────────────────────────────────────────

  Future<List<Idea>> fetchIdeas({
    String? status,
    String? source,
    double? minScore,
    int limit = 50,
    int offset = 0,
    String? projectId,
  }) async {
    final idMappings = await _loadIdMappings();
    final resolvedProjectId = projectId == null
        ? null
        : _resolveEntityId(projectId, idMappings);
    final qp = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status != null) qp['status'] = status;
    if (source != null) qp['source'] = source;
    if (minScore != null) qp['min_score'] = minScore;
    if (resolvedProjectId != null) qp['project_id'] = resolvedProjectId;
    final data = _asMap(
      await _getCachedData(
        '/api/ideas',
        cacheKey: _cacheKeyFor(_ideasCacheKey, qp),
        queryParameters: qp,
      ),
    );
    final items = data['items'] as List? ?? [];
    return items.map((e) => Idea.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchIdeaPoolReadiness() async {
    return _asMap(
      await _getCachedData('/api/ideas/readiness', cacheKey: 'ideas.readiness'),
    );
  }

  Future<Idea> updateIdea(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.patch('/api/ideas/$id', data: updates);
      final saved = Idea.fromJson(_asMap(response.data));
      final defaultKey = _cacheKeyFor(_ideasCacheKey);
      final cached = await _readCachedMap(defaultKey);
      final items = (cached?['items'] as List? ?? const <dynamic>[])
          .map((entry) => Idea.fromJson(entry as Map<String, dynamic>))
          .toList();
      final next = items
          .map((entry) => entry.id == id ? saved : entry)
          .toList();
      await _writeCachedData(defaultKey, {
        'items': next.map((entry) => entry.toJson()).toList(),
      });
      return saved;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped.isOffline) {
        await _enqueueOfflineAction(
          resourceType: 'ideas',
          actionType: 'update',
          label: 'Update idea',
          method: 'PATCH',
          path: '/api/ideas/$id',
          dedupeKey: 'ideas:update:$id',
          payload: updates,
        );
        final defaultKey = _cacheKeyFor(_ideasCacheKey);
        final cachedMap = await _readCachedMap(defaultKey);
        final items = (cachedMap?['items'] as List? ?? const <dynamic>[])
            .map((entry) => Idea.fromJson(entry as Map<String, dynamic>))
            .toList();
        final updated = items.firstWhere(
          (entry) => entry.id == id,
          orElse: () => Idea(
            id: id,
            source: 'manual',
            title: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final next = items
            .map(
              (entry) => entry.id == id
                  ? updated.copyWith(
                      priorityScore: (updates['priority_score'] as num?)
                          ?.toDouble(),
                      status: updates['status']?.toString() ?? entry.status,
                      updatedAt: DateTime.now(),
                    )
                  : entry,
            )
            .toList();
        await _writeCachedData(defaultKey, {
          'items': next.map((entry) => entry.toJson()).toList(),
        });
        return updated.copyWith(
          priorityScore: (updates['priority_score'] as num?)?.toDouble(),
          status: updates['status']?.toString(),
          updatedAt: DateTime.now(),
        );
      }
      throw mapped;
    }
  }

  Future<bool> deleteIdea(String id) async {
    try {
      await _dio.delete('/api/ideas/$id');
      return true;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'ideas',
        actionType: 'delete',
        label: 'Delete idea',
        method: 'DELETE',
        path: '/api/ideas/$id',
        dedupeKey: 'ideas:delete:$id',
        blockedMessage:
            'Deleting an idea is unavailable until FastAPI is back.',
      );
    }
  }

  List<ContentItem> _parseContentList(dynamic data) {
    final items = data is List
        ? data
        : (_asMap(data)['items'] ?? _asMap(data)['content'] ?? []);
    if (items is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid content response from FastAPI.',
      );
    }
    return items
        .map((json) => ContentItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _safeRefreshPreparedVideoCandidates({
    required String? projectId,
    required List<String> contentIds,
  }) async {
    if (projectId == null || contentIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      return await refreshPreparedVideoCandidates(
        projectId: projectId,
        contentIds: contentIds,
        triggerSource: 'feed_refresh',
      );
    } on ApiException catch (error) {
      if (!_isTransientVideoCandidateFailure(error)) {
        rethrow;
      }
      return const <Map<String, dynamic>>[];
    }
  }

  List<ContentItem> _mergePreparedVideoCandidates(
    List<ContentItem> items,
    List<Map<String, dynamic>> candidates,
  ) {
    if (items.isEmpty || candidates.isEmpty) {
      return items;
    }
    final byContentId = <String, Map<String, dynamic>>{
      for (final candidate in candidates)
        if ((candidate['content_id'] ?? candidate['contentId']) != null)
          (candidate['content_id'] ?? candidate['contentId']).toString():
              candidate,
    };
    return items.map((item) {
      final candidate = byContentId[item.id];
      if (candidate == null) {
        return item;
      }
      final metadata = <String, dynamic>{
        ...(item.metadata ?? const <String, dynamic>{}),
        'video_generation_state': candidate['status'],
        'video_generation_readiness': candidate['readiness'],
        'video_generation_blockers': candidate['blockers'] is List
            ? List<String>.from(candidate['blockers'] as List)
            : const <String>[],
        'video_generation_blocker_code':
            candidate['blocker_code'] ?? candidate['blockerCode'],
        'video_generation_blocker_summary':
            candidate['blocker_summary'] ?? candidate['blockerSummary'],
        'video_generation_timeline_id':
            candidate['timeline_id'] ?? candidate['timelineId'],
        'video_generation_version_id':
            candidate['version_id'] ?? candidate['versionId'],
        'video_generation_preview_job_id':
            candidate['preview_job_id'] ?? candidate['previewJobId'],
        'video_generation_final_job_id':
            candidate['final_job_id'] ?? candidate['finalJobId'],
        'video_generation_updated_at':
            candidate['updated_at'] ?? candidate['updatedAt'],
        'video_generation_ready_at':
            candidate['completed_at'] ?? candidate['completedAt'],
      };
      return item.copyWith(metadata: metadata);
    }).toList();
  }

  bool _usesCanonicalVideoPublishFlow(ContentItem item) =>
      item.type == ContentType.videoScript ||
      item.type == ContentType.reel ||
      item.type == ContentType.short;

  bool _isTransientVideoCandidateFailure(ApiException error) =>
      error.type == ApiErrorType.offline || error.type == ApiErrorType.server;

  Map<String, dynamic> _asMap(
    dynamic data, {
    Map<String, dynamic> fallback = const {},
  }) {
    return data is Map<String, dynamic> ? data : fallback;
  }

  bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizePersonaJson(dynamic data) {
    final json = _asMap(data);
    return {
      'id': json['id'],
      'name': json['name'],
      'avatar': json['avatar'],
      'confidence': json['confidence'],
      'demographics': json['demographics'],
      'pain_points': json['painPoints'] ?? json['pain_points'],
      'goals': json['goals'],
      'language': json['language'],
      'content_preferences':
          json['contentPreferences'] ?? json['content_preferences'],
    };
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = _detailMessage(error);
    final responseBody = _stringifyResponseData(error.response?.data);
    final responseHeaders = _flattenHeaders(error.response?.headers);
    final envelope = _apiErrorEnvelope(error.response?.data);

    if (statusCode == 401 || statusCode == 403) {
      final fallbackMessage = statusCode == 403
          ? 'You are not allowed to access this resource.'
          : 'Your Clerk session expired.';
      return ApiException(
        ApiErrorType.unauthorized,
        message.isEmpty ? fallbackMessage : message,
        statusCode: statusCode,
        responseBody: responseBody.isEmpty ? null : responseBody,
        responseHeaders: responseHeaders,
        method: error.requestOptions.method,
        path: error.requestOptions.path,
        code: _stringField(envelope, 'code'),
        kind: _stringField(envelope, 'kind'),
        provider: _stringField(envelope, 'provider'),
        settingsPath:
            _stringField(envelope, 'settingsPath') ??
            _stringField(envelope, 'settings_path'),
        retryable: _boolField(envelope, 'retryable'),
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        ApiErrorType.offline,
        message.isEmpty ? 'FastAPI is unreachable.' : message,
        statusCode: statusCode,
        responseBody: responseBody.isEmpty ? null : responseBody,
        responseHeaders: responseHeaders,
        method: error.requestOptions.method,
        path: error.requestOptions.path,
        code: _stringField(envelope, 'code'),
        kind: _stringField(envelope, 'kind'),
        provider: _stringField(envelope, 'provider'),
        settingsPath:
            _stringField(envelope, 'settingsPath') ??
            _stringField(envelope, 'settings_path'),
        retryable: _boolField(envelope, 'retryable'),
      );
    }

    if (statusCode != null) {
      return ApiException(
        ApiErrorType.server,
        message.isEmpty
            ? 'FastAPI returned an unexpected error ($statusCode).'
            : message,
        statusCode: statusCode,
        responseBody: responseBody.isEmpty ? null : responseBody,
        responseHeaders: responseHeaders,
        method: error.requestOptions.method,
        path: error.requestOptions.path,
        code: _stringField(envelope, 'code'),
        kind: _stringField(envelope, 'kind'),
        provider: _stringField(envelope, 'provider'),
        settingsPath:
            _stringField(envelope, 'settingsPath') ??
            _stringField(envelope, 'settings_path'),
        retryable: _boolField(envelope, 'retryable'),
      );
    }

    return ApiException(
      ApiErrorType.unknown,
      message.isEmpty ? 'Unexpected API error.' : message,
      statusCode: statusCode,
      responseBody: responseBody.isEmpty ? null : responseBody,
      responseHeaders: responseHeaders,
      method: error.requestOptions.method,
      path: error.requestOptions.path,
      code: _stringField(envelope, 'code'),
      kind: _stringField(envelope, 'kind'),
      provider: _stringField(envelope, 'provider'),
      settingsPath:
          _stringField(envelope, 'settingsPath') ??
          _stringField(envelope, 'settings_path'),
      retryable: _boolField(envelope, 'retryable'),
    );
  }

  ApiException _personaDraftJobFailure(Map<String, dynamic> job) {
    final envelope =
        _apiErrorEnvelope(job['error_detail']) ?? _apiErrorEnvelope(job);
    final rawMessage = (job['error_message'] ?? job['error'] ?? '')
        .toString()
        .trim();
    final code =
        _stringField(envelope, 'code') ??
        _stringField(envelope, 'error_code') ??
        job['error_code']?.toString();
    final kind =
        _stringField(envelope, 'kind') ??
        _stringField(envelope, 'error_kind') ??
        job['error_kind']?.toString();
    final provider =
        _stringField(envelope, 'provider') ?? job['provider']?.toString();
    final settingsPath =
        _stringField(envelope, 'settingsPath') ??
        _stringField(envelope, 'settings_path') ??
        job['settings_path']?.toString();
    final retryable =
        _boolField(envelope, 'retryable') ?? _coerceBool(job['retryable']);
    final publicMessage = _personaDraftPublicErrorMessage(
      rawMessage: rawMessage,
      code: code,
      provider: provider,
    );
    final responseBody = envelope == null
        ? null
        : jsonEncode({'detail': envelope});

    return ApiException(
      ApiErrorType.server,
      publicMessage,
      responseBody: responseBody,
      code: code,
      kind: kind,
      provider: provider,
      settingsPath: settingsPath,
      retryable: retryable,
      path: '/api/personas/draft-jobs',
    );
  }

  String _personaDraftPublicErrorMessage({
    required String rawMessage,
    required String? code,
    required String? provider,
  }) {
    if (code == 'ai_runtime_user_credential_missing' &&
        provider == 'openrouter') {
      return 'OpenRouter key required. Save and validate your key in Settings, then retry.';
    }
    if (code == 'ai_runtime_user_credential_invalid' &&
        provider == 'openrouter') {
      return 'OpenRouter key invalid. Validate or replace your key in Settings, then retry.';
    }
    if (code == 'persona_draft_storage_error' ||
        _looksLikeInternalSqlError(rawMessage)) {
      return 'Persona generation failed because the server could not save the AI job state. Please retry; if it persists, copy diagnostics.';
    }
    if (rawMessage.isNotEmpty) {
      return rawMessage;
    }
    return 'Persona draft job failed. Please retry.';
  }

  bool _looksLikeInternalSqlError(String message) {
    final lowered = message.toLowerCase();
    return lowered.contains('hrana') ||
        lowered.contains('sql_parse_error') ||
        lowered.contains('sql string could not be parsed');
  }

  String _detailMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      final message = extractApiDetailMessage(detail);
      if (message.isNotEmpty) {
        return message;
      }
    }

    return error.message ?? '';
  }

  Map<String, dynamic>? _apiErrorEnvelope(Object? data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return detail;
      }
      if (_hasErrorEnvelopeShape(data)) {
        return data;
      }
      return null;
    }
    if (data is Map) {
      final converted = data.map((key, value) => MapEntry('$key', value));
      if (_hasErrorEnvelopeShape(converted)) {
        return converted;
      }
      final detail = converted['detail'];
      if (detail is Map<String, dynamic>) {
        return detail;
      }
      if (detail is Map) {
        final convertedDetail = detail.map(
          (key, value) => MapEntry('$key', value),
        );
        return Map<String, dynamic>.from(convertedDetail);
      }
      return null;
    }
    return null;
  }

  bool _hasErrorEnvelopeShape(Map<String, dynamic> data) {
    return data.containsKey('code') ||
        data.containsKey('error_code') ||
        data.containsKey('kind') ||
        data.containsKey('error_kind');
  }

  String? _stringField(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool? _boolField(Map<String, dynamic>? data, String key) {
    return _coerceBool(data?[key]);
  }

  bool? _coerceBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final lowered = value.toLowerCase();
      if (lowered == 'true') {
        return true;
      }
      if (lowered == 'false') {
        return false;
      }
    }
    return null;
  }

  int? _requestDurationMs(RequestOptions options) {
    final startedAt = options.extra['requestStartedAtMs'];
    if (startedAt is! int) {
      return null;
    }
    return DateTime.now().millisecondsSinceEpoch - startedAt;
  }

  Map<String, String> _flattenHeaders(Headers? headers) {
    if (headers == null) {
      return const <String, String>{};
    }

    final flattened = <String, String>{};
    headers.map.forEach((key, values) {
      if (values.isNotEmpty) {
        flattened[key] = values.join(', ');
      }
    });
    return flattened;
  }

  String _stringifyResponseData(Object? data) {
    if (data == null) {
      return '';
    }
    if (data is String) {
      return data;
    }
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _safeDiagnosticResponseBody(RequestOptions options, Object? data) {
    if (options.path.contains('/video-sources')) {
      return '[REDACTED_VIDEO_SOURCE_INTAKE_RESPONSE]';
    }
    return _stringifyResponseData(data);
  }

  ContentItem? _demoContentById(String id) {
    for (final item in [..._mockContent(), ..._mockHistory()]) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  List<Project> _mockProjects() => [
    Project(
      id: DemoSeed.projectId,
      name: DemoSeed.projectName,
      url: DemoSeed.repoUrl,
      description: DemoSeed.description,
      isDefault: true,
      settings: const ProjectSettings(
        techStack: TechStackDetection(
          framework: Framework.nextjs,
          frameworkVersion: 'latest',
          confidence: 0.95,
        ),
        onboardingStatus: OnboardingStatus.completed,
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  List<Persona> _mockPersonas() => [
    const Persona(
      id: 'persona-1',
      name: 'Tech-Savvy Solopreneur',
      avatar: '🚀',
      confidence: 72,
      demographics: PersonaDemographics(
        role: 'Indie developer / Solopreneur',
        industry: 'SaaS / Tech',
        ageRange: '25-40',
        experienceLevel: '3-8 years',
      ),
      painPoints: [
        'Overwhelmed by too many AI tools, can\'t decide which to use',
        'Wants to ship faster but stuck in analysis paralysis',
      ],
      goals: [
        'Build a profitable SaaS with minimal team',
        'Use AI to multiply productivity without losing quality',
      ],
    ),
  ];

  NarrativeSynthesisResult
  _mockNarrativeResult() => const NarrativeSynthesisResult(
    narrativeSummary:
        'This week\'s narrative centers around a shift from tool accumulation to tool mastery. '
        'The creator is moving from "trying everything" to "mastering the few tools that matter." '
        'This aligns with a new chapter: Radical Pragmatism — choosing depth over breadth.',
    chapterTransition: true,
    suggestedChapterTitle: 'Radical Pragmatism',
    voiceDelta: {
      'tone_shift': 'More direct and opinionated',
      'new_vocabulary': ['ship it', 'good enough', 'pragmatic'],
    },
    positioningDelta: {
      'angle_shift': 'From "AI enthusiast" to "pragmatic AI builder"',
    },
  );

  List<AngleSuggestion> _mockAngles() => [
    const AngleSuggestion(
      title: 'The Filter: I tested 50 AI tools, here are the 3 worth your time',
      hook:
          'Stop hoarding AI subscriptions. I burned \$500/month so you don\'t have to.',
      angle:
          'Pragmatic curation — position as the person who already did the hard work of filtering',
      contentType: 'blog_post',
      narrativeThread: 'Radical Pragmatism',
      painPointAddressed: 'Overwhelmed by too many AI tools',
      confidence: 87,
    ),
    const AngleSuggestion(
      title: 'Your problem isn\'t the tools — it\'s clarity',
      hook:
          'You don\'t need another AI tool. You need to know what you\'re solving.',
      angle:
          'Confrontational mirror — challenge the assumption that more tools = more productivity',
      contentType: 'social_post',
      narrativeThread: 'Radical Pragmatism',
      painPointAddressed: 'Analysis paralysis on tool selection',
      confidence: 79,
    ),
    const AngleSuggestion(
      title: 'My 5-minute AI tool decision framework',
      hook:
          'I\'ve been paralyzed by tool choice too. Here\'s how I broke free in 5 minutes.',
      angle:
          'Empathetic guide — share a personal framework, position as a peer who solved the same problem',
      contentType: 'video_script',
      narrativeThread: 'Radical Pragmatism',
      painPointAddressed: 'Stuck in analysis paralysis',
      confidence: 82,
    ),
  ];

  List<ContentItem> _mockContent() {
    final now = DateTime.now();
    return [
      ContentItem(
        id: '1',
        title: '10 Flutter Tips for Production Apps',
        body:
            '# 10 Flutter Tips for Production Apps\n\nFlutter has become the go-to framework for cross-platform development. Here are 10 tips that will level up your production apps.\n\n## 1. Use Riverpod for State Management\n\nRiverpod provides compile-time safety and automatic disposal of unused providers.\n\n## 2. Implement Proper Error Handling\n\nAlways wrap your async operations in try-catch blocks.\n\n## 3. Optimize Image Loading\n\nUse `cached_network_image` to avoid re-downloading images.\n\n## 4. Profile Before You Optimize\n\nUse Flutter DevTools to identify actual bottlenecks.\n\n## 5. Write Widget Tests\n\nWidget tests are fast and catch most UI regression bugs.',
        summary: 'Essential Flutter tips for production-ready apps.',
        type: ContentType.blogPost,
        status: ContentStatus.pending,
        channels: [PublishingChannel.ghost, PublishingChannel.twitter],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ContentItem(
        id: '2',
        title: 'AI is transforming how we build software',
        body:
            'AI is transforming how we build software.\n\nIn 2026, the best developers aren\'t those who write the most code — they\'re the ones who know how to direct AI.\n\n3 skills that matter:\n→ Prompt engineering\n→ Code review (AI output)\n→ System architecture\n\n#AI #SoftwareEngineering',
        summary: 'Thread about AI in software development',
        type: ContentType.socialPost,
        status: ContentStatus.pending,
        channels: [PublishingChannel.twitter, PublishingChannel.linkedin],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ContentItem(
        id: '3',
        title: 'Weekly Tech Digest #42',
        body:
            '# Weekly Tech Digest #42\n\n## Top Stories\n\n**Flutter 3.41 Released** — Hot reload on web, better Material 3.\n\n**Claude 4.6 Opus** — 1M context window.\n\n## Tutorial of the Week\n\nBuilding real-time dashboards with Flutter + WebSockets.',
        summary: 'Weekly newsletter with top tech stories',
        type: ContentType.newsletter,
        status: ContentStatus.pending,
        channels: [PublishingChannel.ghost],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      ContentItem(
        id: '4',
        title: 'How I Built a SaaS in 30 Days',
        body:
            'HOOK: "I went from idea to \$2K MRR in 30 days."\n\nINTRO (0:00-0:15):\nShow revenue dashboard.\n\nSECTION 1 - The Idea (0:15-1:00):\n"I started with a problem I had myself..."\n\nSECTION 2 - The Build (1:00-3:00):\n"Flutter frontend, Python backend..."\n\nCTA (4:30-5:00):\n"Template link in bio."',
        summary: 'YouTube video script about building a SaaS',
        type: ContentType.videoScript,
        status: ContentStatus.pending,
        channels: [PublishingChannel.youtube],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      ContentItem(
        id: '5',
        title: 'Quick tip: Use sealed classes',
        body:
            'REEL (30s)\n\n"Stop using if-else chains!"\n\n[Show bad code]\n"This? Terrible."\n\n[Show sealed class]\n"The compiler catches every missing case."\n\n"Follow for more Flutter tips."\n\n#Flutter #Dart #CodingTips',
        summary: 'Instagram reel about sealed classes in Dart',
        type: ContentType.reel,
        status: ContentStatus.pending,
        channels: [PublishingChannel.instagram, PublishingChannel.tiktok],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
    ];
  }

  List<ContentItem> _mockHistory() {
    final now = DateTime.now();
    return [
      ContentItem(
        id: 'h1',
        title: 'Getting Started with Riverpod 3.0',
        body: 'Published article about Riverpod 3.0 migration guide...',
        type: ContentType.blogPost,
        status: ContentStatus.published,
        channels: [PublishingChannel.ghost],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(days: 1)),
        publishedAt: now.subtract(const Duration(hours: 20)),
      ),
      ContentItem(
        id: 'h2',
        title: 'The future of cross-platform development',
        body: 'Social post about Flutter vs React Native...',
        type: ContentType.socialPost,
        status: ContentStatus.published,
        channels: [PublishingChannel.twitter, PublishingChannel.linkedin],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(days: 2)),
        publishedAt: now.subtract(const Duration(days: 1, hours: 12)),
      ),
      ContentItem(
        id: 'h3',
        title: 'Bad take on microservices',
        body: 'Rejected post about microservices being dead...',
        type: ContentType.socialPost,
        status: ContentStatus.rejected,
        channels: [PublishingChannel.twitter],
        projectName: DemoSeed.projectName,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}

// ─── Content Drip API ─────────────────────────────────

extension DripApi on ApiService {
  DripPlan _dripPlanFromBody(
    Map<String, dynamic> body, {
    required String id,
    String? status,
  }) {
    final now = DateTime.now().toIso8601String();
    return DripPlan(
      id: id,
      userId: offlineScope,
      projectId:
          body['project_id']?.toString() ?? body['projectId']?.toString(),
      name: body['name']?.toString() ?? 'Untitled drip plan',
      status: status ?? body['status']?.toString() ?? 'draft',
      cadenceConfig: _asMap(body['cadence_config'] ?? body['cadence']),
      clusterStrategy: _asMap(body['cluster_strategy']),
      ssgConfig: _asMap(body['ssg_config']),
      gscConfig: body['gsc_config'] == null ? null : _asMap(body['gsc_config']),
      totalItems: (body['total_items'] as num?)?.toInt() ?? 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  DripPlan _mergeDripPlanResponse(
    Map<String, dynamic> response, {
    DripPlan? current,
    Map<String, dynamic>? requestBody,
    String? fallbackId,
  }) {
    final seeded = <String, dynamic>{
      ...?current?.toJson(),
      if (requestBody != null)
        ..._dripPlanFromBody(
          requestBody,
          id: fallbackId ?? current?.id ?? '',
          status: current?.status,
        ).toJson(),
      ...response,
    };
    return DripPlan.fromJson(seeded);
  }

  DripPlan _applyDripPlanBody(
    DripPlan current,
    Map<String, dynamic> body, {
    String? status,
    String? startedAt,
    String? completedAt,
    String? lastDripAt,
    String? nextDripAt,
    String? scheduleJobId,
  }) {
    return current.copyWith(
      projectId:
          body['project_id']?.toString() ??
          body['projectId']?.toString() ??
          current.projectId,
      name: body['name']?.toString() ?? current.name,
      status: status ?? current.status,
      cadenceConfig:
          body.containsKey('cadence') || body.containsKey('cadence_config')
          ? _asMap(body['cadence_config'] ?? body['cadence'])
          : current.cadenceConfig,
      clusterStrategy: body.containsKey('cluster_strategy')
          ? _asMap(body['cluster_strategy'])
          : current.clusterStrategy,
      ssgConfig: body.containsKey('ssg_config')
          ? _asMap(body['ssg_config'])
          : current.ssgConfig,
      gscConfig: body.containsKey('gsc_config')
          ? (body['gsc_config'] == null ? null : _asMap(body['gsc_config']))
          : current.gscConfig,
      totalItems: (body['total_items'] as num?)?.toInt() ?? current.totalItems,
      startedAt: startedAt ?? current.startedAt,
      completedAt: completedAt ?? current.completedAt,
      lastDripAt: lastDripAt ?? current.lastDripAt,
      nextDripAt: nextDripAt ?? current.nextDripAt,
      scheduleJobId: scheduleJobId ?? current.scheduleJobId,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchDripPlans() async {
    final data = await _getCachedData(
      '/api/drip/plans',
      cacheKey: ApiService._dripPlansCacheKey,
    );
    final items = data is Map ? data['items'] : data;
    if (items is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'Invalid drip plans response from FastAPI.',
      );
    }
    final normalized = items
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    for (final item in normalized) {
      final planId = item['id']?.toString();
      if (planId != null && planId.isNotEmpty) {
        await _writeCachedData(_dripPlanCacheKey(planId), item);
      }
    }
    return normalized;
  }

  Future<Map<String, dynamic>> createDripPlan(Map<String, dynamic> body) async {
    final idMappings = await _loadIdMappings();
    final resolvedBody =
        _asMapOrNull(rewriteOfflineIdsInValue(body, idMappings)) ?? body;
    final dependsOnTempIds = _dependsOnTempIdsForIds([
      body['project_id']?.toString(),
      body['projectId']?.toString(),
    ], idMappings);
    try {
      final response = await _dio.post('/api/drip/plans', data: resolvedBody);
      final raw = _asMap(response.data);
      final plan = _mergeDripPlanResponse(raw, requestBody: resolvedBody);
      await _upsertCachedDripPlan(plan);
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      final tempId = _newOfflineTempId('drip-plan');
      final optimistic = _dripPlanFromBody(resolvedBody, id: tempId);
      await _upsertCachedDripPlan(optimistic);
      await _writeCachedDripStats(tempId, const {});
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'create',
        label: 'Create drip plan',
        method: 'POST',
        path: '/api/drip/plans',
        dedupeKey: 'drip:create:$tempId',
        payload: resolvedBody,
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: tempId,
          tempId: tempId,
          dependsOnTempIds: dependsOnTempIds,
        ),
        mergePayload: false,
      );
      return {...optimistic.toJson(), 'queued': true};
    }
  }

  Future<Map<String, dynamic>> getDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final data = await _getCachedData(
      '/api/drip/plans/$resolvedPlanId',
      cacheKey: _dripPlanCacheKey(resolvedPlanId),
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateDripPlan(
    String planId,
    Map<String, dynamic> body,
  ) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final resolvedBody =
        _asMapOrNull(rewriteOfflineIdsInValue(body, idMappings)) ?? body;
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.patch(
        '/api/drip/plans/$resolvedPlanId',
        data: resolvedBody,
      );
      final raw = _asMap(response.data);
      final plan = _mergeDripPlanResponse(
        raw,
        current: current,
        requestBody: resolvedBody,
        fallbackId: resolvedPlanId,
      );
      await _upsertCachedDripPlan(plan);
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      final optimistic = current == null
          ? _dripPlanFromBody(resolvedBody, id: planId)
          : _applyDripPlanBody(current, resolvedBody);
      await _upsertCachedDripPlan(optimistic);
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'update',
        label: 'Update drip plan',
        method: 'PATCH',
        path: '/api/drip/plans/$resolvedPlanId',
        dedupeKey: 'drip:update:$resolvedPlanId',
        payload: resolvedBody,
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return optimistic.toJson();
    }
  }

  Future<void> deleteDripPlan(String planId) async {
    try {
      final idMappings = await _loadIdMappings();
      final resolvedPlanId = _resolveEntityId(planId, idMappings);
      await _dio.delete('/api/drip/plans/$resolvedPlanId');
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'drip',
        actionType: 'delete',
        label: 'Delete drip plan',
        method: 'DELETE',
        path: '/api/drip/plans/$planId',
        dedupeKey: 'drip:delete:$planId',
        blockedMessage:
            'Deleting a drip plan is unavailable until FastAPI is back.',
      );
    }
  }

  Future<Map<String, dynamic>> getDripStats(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    try {
      final data = await _getCachedData(
        '/api/drip/plans/$resolvedPlanId/stats',
        cacheKey: _dripStatsCacheKey(resolvedPlanId),
      );
      return _asMap(data);
    } on ApiException catch (error) {
      if (error.isOffline) {
        return const {};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> importDripContent(
    String planId,
    String directory, {
    bool excludeDrafts = true,
  }) async {
    try {
      final idMappings = await _loadIdMappings();
      final resolvedPlanId = _resolveEntityId(planId, idMappings);
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/import',
        queryParameters: {
          'directory': directory,
          'exclude_drafts': excludeDrafts,
        },
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'drip',
        actionType: 'import',
        label: 'Import drip content',
        method: 'POST',
        path: '/api/drip/plans/$planId/import',
        dedupeKey: 'drip:import:$planId',
        blockedMessage:
            'Importing drip content is unavailable until FastAPI is back.',
      );
    }
  }

  Future<Map<String, dynamic>> clusterDripPlan(
    String planId, {
    String mode = 'directory',
  }) async {
    try {
      final idMappings = await _loadIdMappings();
      final resolvedPlanId = _resolveEntityId(planId, idMappings);
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/cluster',
        queryParameters: {'mode': mode},
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'drip',
        actionType: 'cluster',
        label: 'Cluster drip plan',
        method: 'POST',
        path: '/api/drip/plans/$planId/cluster',
        dedupeKey: 'drip:cluster:$planId',
        blockedMessage:
            'Clustering drip content is unavailable until FastAPI is back.',
      );
    }
  }

  Future<Map<String, dynamic>> scheduleDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/schedule',
      );
      final raw = _asMap(response.data);
      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(
            current,
            const {},
            scheduleJobId:
                raw['schedule_job_id']?.toString() ?? current.scheduleJobId,
          ),
        );
      }
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(
            current,
            const {},
            scheduleJobId: current.scheduleJobId ?? 'offline-scheduled',
          ),
        );
      }
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'schedule',
        label: 'Schedule drip plan',
        method: 'POST',
        path: '/api/drip/plans/$resolvedPlanId/schedule',
        dedupeKey: 'drip:schedule:$resolvedPlanId',
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return {'total_items': current?.totalItems ?? 0, 'queued': true};
    }
  }

  Future<Map<String, dynamic>> previewDripSchedule(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final response = await _dio.get('/api/drip/plans/$resolvedPlanId/preview');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> preflightDripPlan(String planId) async {
    try {
      final idMappings = await _loadIdMappings();
      final resolvedPlanId = _resolveEntityId(planId, idMappings);
      final response = await _dio.get(
        '/api/drip/plans/$resolvedPlanId/preflight',
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'drip',
        actionType: 'preflight',
        label: 'Preflight drip plan',
        method: 'GET',
        path: '/api/drip/plans/$planId/preflight',
        dedupeKey: 'drip:preflight:$planId',
        blockedMessage:
            'Preflight checks are unavailable until FastAPI is back.',
      );
    }
  }

  Future<Map<String, dynamic>> activateDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/activate',
      );
      final raw = _asMap(response.data);
      if (current != null) {
        await _upsertCachedDripPlan(
          _mergeDripPlanResponse(raw, current: current),
        );
      }
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(
            current,
            const {},
            status: 'active',
            startedAt: current.startedAt ?? DateTime.now().toIso8601String(),
          ),
        );
      }
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'activate',
        label: 'Activate drip plan',
        method: 'POST',
        path: '/api/drip/plans/$resolvedPlanId/activate',
        dedupeKey: 'drip:activate:$resolvedPlanId',
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> pauseDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.post('/api/drip/plans/$resolvedPlanId/pause');
      final raw = _asMap(response.data);
      if (current != null) {
        await _upsertCachedDripPlan(
          _mergeDripPlanResponse(raw, current: current),
        );
      }
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(current, const {}, status: 'paused'),
        );
      }
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'pause',
        label: 'Pause drip plan',
        method: 'POST',
        path: '/api/drip/plans/$resolvedPlanId/pause',
        dedupeKey: 'drip:pause:$resolvedPlanId',
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> resumeDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/resume',
      );
      final raw = _asMap(response.data);
      if (current != null) {
        await _upsertCachedDripPlan(
          _mergeDripPlanResponse(raw, current: current),
        );
      }
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(current, const {}, status: 'active'),
        );
      }
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'resume',
        label: 'Resume drip plan',
        method: 'POST',
        path: '/api/drip/plans/$resolvedPlanId/resume',
        dedupeKey: 'drip:resume:$resolvedPlanId',
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> cancelDripPlan(String planId) async {
    final idMappings = await _loadIdMappings();
    final resolvedPlanId = _resolveEntityId(planId, idMappings);
    final dependsOnTempIds = _dependsOnTempIdsForIds([planId], idMappings);
    final current =
        await _readCachedDripPlan(planId) ??
        await _readCachedDripPlan(resolvedPlanId);
    try {
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/cancel',
      );
      final raw = _asMap(response.data);
      if (current != null) {
        await _upsertCachedDripPlan(
          _mergeDripPlanResponse(raw, current: current),
        );
      }
      return raw;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (!mapped.isOffline) {
        throw mapped;
      }

      if (current != null) {
        await _upsertCachedDripPlan(
          _applyDripPlanBody(
            current,
            const {},
            status: 'cancelled',
            completedAt: DateTime.now().toIso8601String(),
          ),
        );
      }
      await _enqueueOfflineAction(
        resourceType: 'drip',
        actionType: 'cancel',
        label: 'Cancel drip plan',
        method: 'POST',
        path: '/api/drip/plans/$resolvedPlanId/cancel',
        dedupeKey: 'drip:cancel:$resolvedPlanId',
        meta: _offlineActionMeta(
          entityType: 'drip_plan',
          entityId: resolvedPlanId,
          dependsOnTempIds: dependsOnTempIds,
        ),
      );
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> executeDripTick(String planId) async {
    try {
      final idMappings = await _loadIdMappings();
      final resolvedPlanId = _resolveEntityId(planId, idMappings);
      final response = await _dio.post(
        '/api/drip/plans/$resolvedPlanId/execute-tick',
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      throw await _queueOrThrow(
        error: mapped,
        resourceType: 'drip',
        actionType: 'execute_tick',
        label: 'Execute drip tick',
        method: 'POST',
        path: '/api/drip/plans/$planId/execute-tick',
        dedupeKey: 'drip:execute_tick:$planId',
        blockedMessage:
            'Executing a drip tick is unavailable until FastAPI is back.',
      );
    }
  }
}

String _captureDraftTitle(CaptureAsset asset) {
  final kind = asset.isScreenshot ? 'Screenshot' : 'Screen recording';
  final created = asset.createdAt.toLocal().toIso8601String().split('.').first;
  return '$kind $created';
}

String _captureDraftBody(CaptureAsset asset) {
  final kind = asset.isScreenshot ? 'screenshot' : 'screen recording';
  return [
    '# ${_captureDraftTitle(asset)}',
    '',
    'Local $kind attached from Android device capture.',
    '',
    'Notes:',
    '',
  ].join('\n');
}

String _capturePreview(CaptureAsset asset) {
  final kind = asset.isScreenshot ? 'Screenshot' : 'Screen recording';
  final details = [
    '${asset.width}x${asset.height}',
    if (asset.durationMs != null) '${asset.durationMs}ms',
  ].join(' ');
  return '$kind captured locally. $details'.trim();
}

Map<String, dynamic> _captureAssetMetadata(CaptureAsset asset) {
  return {
    'capture_scope_label': asset.captureScopeLabel,
    'microphone_enabled': asset.microphoneEnabled,
    'captured_at': asset.createdAt.toIso8601String(),
  };
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? normalized : parts.last;
}
