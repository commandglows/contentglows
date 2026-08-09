import 'package:app/data/models/project_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectAsset models', () {
    test('parses list response and storage descriptor', () {
      final payload = {
        'items': [
          {
            'id': 'asset-1',
            'project_id': 'proj-1',
            'user_id': 'user-1',
            'media_kind': 'image',
            'source': 'image_robot',
            'mime_type': 'image/png',
            'file_name': 'visual.png',
            'original_file_name': 'Original Visual.png',
            'category_id': 'editorial_visual',
            'subcategory_id': 'infographic',
            'suggested_export_file_name':
                'editorial_visual-infographic-original-visual.png',
            'storage_descriptor': {'provider': 'bunny', 'status': 'ready'},
            'status': 'active',
            'metadata': {'prompt': 'sunset'},
            'created_at': '2026-05-11T18:00:00Z',
            'updated_at': '2026-05-11T18:10:00Z',
          },
        ],
        'total': 1,
      };

      final result = ProjectAssetListResponse.fromJson(payload);

      expect(result.total, 1);
      expect(result.items, hasLength(1));
      expect(result.items.single.id, 'asset-1');
      expect(result.items.single.storageDescriptor['provider'], 'bunny');
      expect(result.items.single.metadata['prompt'], 'sunset');
      expect(result.items.single.originalFileName, 'Original Visual.png');
      expect(result.items.single.categoryId, 'editorial_visual');
      expect(
        result.items.single.suggestedExportFileName,
        'editorial_visual-infographic-original-visual.png',
      );
    });

    test('parses localized category catalog with stable ids', () {
      final catalog = ProjectAssetCategoryCatalog.fromJson({
        'version': '2026-08-07.1',
        'locale': 'fr',
        'supported_locales': ['en', 'fr'],
        'categories': [
          {
            'category_id': 'editorial_visual',
            'label': 'Visuel éditorial',
            'subcategories': [
              {'subcategory_id': 'infographic', 'label': 'Infographie'},
            ],
          },
        ],
      });

      expect(
        catalog.categoryById('editorial_visual')?.label,
        'Visuel éditorial',
      );
      expect(
        catalog
            .categoryById('editorial_visual')
            ?.subcategoryById('infographic')
            ?.label,
        'Infographie',
      );
    });

    test(
      'keeps backend-redacted storage descriptors without raw storage uri',
      () {
        final asset = ProjectAsset.fromJson({
          'id': 'asset-1',
          'project_id': 'proj-1',
          'user_id': 'user-1',
          'media_kind': 'audio',
          'source': 'video_audio_ai',
          'storage_uri': null,
          'storage_descriptor': {
            'state': 'signed_playback',
            'redacted_uri': 'https://assets.b-cdn.net/path/audio.mp3',
            'render_safe': true,
          },
          'status': 'active',
          'metadata': {},
          'created_at': '2026-05-11T18:00:00Z',
          'updated_at': '2026-05-11T18:10:00Z',
        });

        expect(asset.storageUri, isNull);
        expect(asset.storageDescriptor['redacted_uri'], endsWith('/audio.mp3'));
        expect(asset.storageDescriptor.toString(), isNot(contains('token=')));
      },
    );

    test('parses eligibility, usage, events and cleanup report', () {
      final eligibility = ProjectAssetEligibility.fromJson({
        'asset_id': 'asset-1',
        'usage_action': 'select_for_content',
        'target_type': 'content',
        'target_id': 'content-1',
        'eligible': true,
      });
      expect(eligibility.eligible, isTrue);

      final usage = ProjectAssetUsage.fromJson({
        'id': 'usage-1',
        'asset_id': 'asset-1',
        'project_id': 'proj-1',
        'user_id': 'user-1',
        'target_type': 'content',
        'target_id': 'content-1',
        'placement': 'cover',
        'usage_action': 'set_primary',
        'is_primary': true,
        'metadata': {'foo': 'bar'},
        'created_at': '2026-05-11T18:00:00Z',
        'updated_at': '2026-05-11T18:10:00Z',
      });
      expect(usage.isPrimary, isTrue);
      expect(usage.placement, 'cover');

      final event = ProjectAssetEvent.fromJson({
        'id': 'event-1',
        'asset_id': 'asset-1',
        'project_id': 'proj-1',
        'user_id': 'user-1',
        'event_type': 'selected',
        'metadata': {'usage_id': 'usage-1'},
        'created_at': '2026-05-11T18:11:00Z',
      });
      expect(event.eventType, 'selected');

      final cleanup = ProjectAssetCleanupReport.fromJson({
        'cleanup_eligible': [
          {
            'asset_id': 'asset-2',
            'media_kind': 'image',
            'status': 'tombstoned',
          },
        ],
        'degraded': [],
        'missing_storage': [],
        'physical_delete_allowed': false,
      });
      expect(cleanup.cleanupEligible.single.assetId, 'asset-2');
      expect(cleanup.physicalDeleteAllowed, isFalse);
    });

    test('parses understanding status and recommendation candidate fields', () {
      final status = AssetUnderstandingStatusResponse.fromJson({
        'job': {
          'id': 'job-1',
          'asset_id': 'asset-1',
          'project_id': 'proj-1',
          'user_id': 'user-1',
          'media_type': 'video',
          'provider': 'gemini_compatible',
          'status': 'completed',
          'idempotency_key': 'idem-1',
          'attempts': 1,
          'metadata': {},
          'created_at': '2026-05-11T18:00:00Z',
          'updated_at': '2026-05-11T18:10:00Z',
        },
        'result': {
          'asset_id': 'asset-1',
          'project_id': 'proj-1',
          'status': 'completed',
          'tags': [
            {'key': 'deer', 'label': 'Deer', 'confidence': 0.9},
          ],
          'segments': [
            {
              'start_seconds': 0,
              'end_seconds': 2.3,
              'label': 'jump',
              'confidence': 0.8,
            },
          ],
        },
      });
      expect(status.job?.status, 'completed');
      expect(status.result?.tags.single.label, 'Deer');

      final recommendation = ProjectAssetRecommendationItem.fromJson({
        'asset_id': 'asset-global',
        'score': 0.77,
        'candidate_type': 'candidate_global_asset',
        'requires_project_attachment': true,
        'source_project_id': 'proj-source',
        'warnings': ['credit_required'],
      });
      expect(recommendation.candidateGlobalAsset, isTrue);
      expect(recommendation.requiresProjectAttachment, isTrue);
      expect(recommendation.sourceProjectId, 'proj-source');
    });
  });
}
