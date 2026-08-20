import 'package:app/data/models/app_access_state.dart';
import 'package:app/data/models/app_settings.dart';
import 'package:app/data/models/content_item.dart';
import 'package:app/data/models/video_timeline.dart';
import 'package:app/data/services/api_service.dart';
import 'package:app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'direct approve publishes the fetched full body, not the preview body',
    () async {
      final api = _FakeApiService(body: 'Full body from endpoint');
      final container = _container(
        api,
        items: [_contentItem(body: 'Preview text only')],
      );
      addTearDown(container.dispose);
      await container.read(pendingContentProvider.future);

      final result = await container
          .read(pendingContentProvider.notifier)
          .approve('content-1');

      expect(result.approved, isTrue);
      expect(result.published, isTrue);
      expect(api.approveCalls, 1);
      expect(api.bodyFetchAllowStaleCache, isFalse);
      expect(api.publishedContent, 'Full body from endpoint');
    },
  );

  test(
    'direct approve restores pending state when full body is unavailable',
    () async {
      final api = _FakeApiService(
        bodyError: const ApiException(
          ApiErrorType.server,
          'No content body found',
          statusCode: 404,
        ),
      );
      final item = _contentItem(body: 'Preview text only');
      final container = _container(api, items: [item]);
      addTearDown(container.dispose);
      await container.read(pendingContentProvider.future);

      final result = await container
          .read(pendingContentProvider.notifier)
          .approve('content-1');

      expect(result.approved, isFalse);
      expect(result.published, isFalse);
      expect(api.approveCalls, 0);
      expect(api.publishCalls, 0);
      expect(
        container.read(pendingContentProvider).value!.map((entry) => entry.id),
        contains('content-1'),
      );
    },
  );

  test(
    'video approve publishes prepared candidate without last-minute generation',
    () async {
      final api = _FakeApiService(body: 'Full body from endpoint');
      final item = _contentItem(
        body: 'Preview text only',
        type: ContentType.videoScript,
        metadata: const {
          'content_complete_at': '2026-07-08T00:00:00Z',
          'video_generation_readiness': 'ready_to_publish',
          'video_generation_timeline_id': 'timeline-1',
          'video_generation_version_id': 'version-1',
          'video_generation_preview_job_id': 'preview-1',
        },
      );
      final container = _container(api, items: [item]);
      addTearDown(container.dispose);
      await container.read(pendingContentProvider.future);

      final result = await container
          .read(pendingContentProvider.notifier)
          .approve('content-1');

      expect(result.approved, isTrue);
      expect(result.published, isTrue);
      expect(api.generateBrandedCalls, 0);
      expect(api.refreshPreparedCalls, 0);
      expect(api.swipePublishCalls, 1);
      expect(api.swipeTimelineId, 'timeline-1');
      expect(api.swipeVersionId, 'version-1');
    },
  );

  test(
    'video approve refreshes candidate and blocks while preparation is pending',
    () async {
      final api = _FakeApiService(
        body: 'Full body from endpoint',
        refreshedCandidates: const [
          {
            'content_id': 'content-1',
            'status': 'preview_render',
            'readiness': 'preparing',
            'blockers': <String>[],
          },
        ],
      );
      final item = _contentItem(
        body: 'Preview text only',
        type: ContentType.videoScript,
        metadata: const {'content_complete_at': '2026-07-08T00:00:00Z'},
      );
      final container = _container(api, items: [item]);
      addTearDown(container.dispose);
      await container.read(pendingContentProvider.future);

      final result = await container
          .read(pendingContentProvider.notifier)
          .approve('content-1');

      expect(result.approved, isFalse);
      expect(result.openVideoEditor, isTrue);
      expect(result.message, contains('still preparing'));
      expect(api.refreshPreparedCalls, 1);
      expect(api.refreshedProjectId, 'project-1');
      expect(api.refreshedContentIds, ['content-1']);
      expect(api.refreshTriggerSource, 'feed_swipe_publish');
      expect(api.generateBrandedCalls, 0);
      expect(api.swipePublishCalls, 0);
    },
  );
}

ProviderContainer _container(
  _FakeApiService api, {
  required List<ContentItem> items,
}) {
  return ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      appAccessStateProvider.overrideWith(() => _TestAccessNotifier()),
      activeProjectProvider.overrideWith((ref) => null),
      activeProjectIdProvider.overrideWith((ref) => 'project-1'),
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
            PublishAccount(
              id: 'account-2',
              projectId: 'project-1',
              provider: 'late',
              platform: 'youtube',
              providerAccountId: 'late-account-2',
              username: 'creator-video',
              displayName: 'Creator Video',
              isDefault: true,
            ),
          ],
        ),
      ),
      contentHistoryProvider.overrideWith((ref) async => const <ContentItem>[]),
      pendingContentProvider.overrideWith(
        () => _TestPendingContentNotifier(items),
      ),
    ],
  );
}

ContentItem _contentItem({
  required String body,
  ContentType type = ContentType.blogPost,
  Map<String, dynamic>? metadata,
}) {
  return ContentItem(
    id: 'content-1',
    title: 'Draft title',
    body: body,
    summary: 'Preview text only',
    type: type,
    status: ContentStatus.pending,
    channels: type == ContentType.videoScript
        ? const [PublishingChannel.youtube]
        : const [PublishingChannel.twitter],
    createdAt: DateTime(2026, 5, 2),
    metadata: metadata,
  );
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

class _FakeApiService extends ApiService {
  _FakeApiService({
    this.body,
    this.bodyError,
    this.refreshedCandidates = const [],
  }) : super(baseUrl: 'http://test');

  final String? body;
  final ApiException? bodyError;
  final List<Map<String, dynamic>> refreshedCandidates;

  int approveCalls = 0;
  int publishCalls = 0;
  int generateBrandedCalls = 0;
  int refreshPreparedCalls = 0;
  int swipePublishCalls = 0;
  bool? bodyFetchAllowStaleCache;
  String? publishedContent;
  String? swipeTimelineId;
  String? swipeVersionId;
  String? refreshedProjectId;
  List<String>? refreshedContentIds;
  String? refreshTriggerSource;

  @override
  Future<String?> fetchContentBody(
    String id, {
    bool allowStaleCache = true,
  }) async {
    bodyFetchAllowStaleCache = allowStaleCache;
    final error = bodyError;
    if (error != null) {
      throw error;
    }
    return body;
  }

  @override
  Future<void> approveContent(String id) async {
    approveCalls++;
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
    generateBrandedCalls++;
    throw UnimplementedError('Should not be called in these tests');
  }

  @override
  Future<List<Map<String, dynamic>>> refreshPreparedVideoCandidates({
    required String projectId,
    List<String> contentIds = const [],
    String formatPreset = 'vertical_9_16',
    String? triggerSource,
  }) async {
    refreshPreparedCalls++;
    refreshedProjectId = projectId;
    refreshedContentIds = List<String>.from(contentIds);
    refreshTriggerSource = triggerSource;
    return refreshedCandidates;
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
    publishCalls++;
    publishedContent = content;
    return {'success': true};
  }

  @override
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
    swipePublishCalls++;
    swipeTimelineId = timelineId;
    swipeVersionId = versionId;
    return VideoTimelineSwipePublishResponse(
      state: 'published',
      version: VideoTimelineVersion(
        versionId: 'version-1',
        timelineId: 'timeline-1',
        versionNumber: 1,
        timeline: VideoTimelineDocument(
          tracks: [],
          clips: [],
          durationFrames: 90,
        ),
        rendererProps: {},
        approvedPreviewJobId: 'preview-1',
        previewApprovedAt: null,
        createdAt: DateTime.utc(2026, 7, 8),
      ),
      finalJob: null,
      publishResult: {'success': true},
      blockers: [],
    );
  }
}
