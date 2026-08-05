import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:app/data/models/brand_profile.dart';
import 'package:app/data/models/ritual.dart';
import 'package:app/data/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fetches and mutates brand profiles through the canonical API paths',
    () async {
      final capturedRequests = <_CapturedRequest>[];
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((request) async {
          final body = await utf8.decoder.bind(request).join();
          capturedRequests.add(
            _CapturedRequest(
              method: request.method,
              path: request.uri.path,
              query: request.uri.queryParameters,
              body: body,
            ),
          );

          request.response.headers.contentType = io.ContentType.json;
          switch ('${request.method} ${request.uri.path}') {
            case 'GET /api/brand-profiles':
              request.response.write(
                jsonEncode([
                  {
                    'id': 'brand-1',
                    'user_id': 'user-1',
                    'project_id': 'project-1',
                    'name': 'Primary',
                    'primary_colors': ['#000000'],
                    'secondary_colors': ['#FFFFFF'],
                    'motion_intensity': 'medium',
                    'intro_module_enabled': true,
                    'outro_module_enabled': true,
                    'is_default': true,
                    'revision': 1,
                    'created_at': '2026-07-08T12:00:00Z',
                    'updated_at': '2026-07-08T12:00:00Z',
                  },
                ]),
              );
              break;
            case 'POST /api/brand-profiles':
              request.response.statusCode = 201;
              request.response.write(
                jsonEncode({
                  'id': 'brand-2',
                  'user_id': 'user-1',
                  'project_id': 'project-1',
                  'name': jsonDecode(body)['name'],
                  'primary_colors': ['#111111'],
                  'secondary_colors': [],
                  'motion_intensity': 'high',
                  'intro_module_enabled': true,
                  'outro_module_enabled': true,
                  'is_default': false,
                  'revision': 1,
                  'created_at': '2026-07-08T12:10:00Z',
                  'updated_at': '2026-07-08T12:10:00Z',
                }),
              );
              break;
            case 'PATCH /api/brand-profiles/brand-2':
              request.response.write(
                jsonEncode({
                  'id': 'brand-2',
                  'user_id': 'user-1',
                  'project_id': 'project-1',
                  'name': jsonDecode(body)['name'] ?? 'Updated',
                  'primary_colors': ['#222222'],
                  'secondary_colors': [],
                  'motion_intensity': 'low',
                  'intro_module_enabled': true,
                  'outro_module_enabled': false,
                  'is_default': true,
                  'revision': 2,
                  'created_at': '2026-07-08T12:10:00Z',
                  'updated_at': '2026-07-08T12:20:00Z',
                }),
              );
              break;
            case 'DELETE /api/brand-profiles/brand-2':
              request.response.write('{"success":true}');
              break;
            case 'GET /api/brand-video-blueprints':
              request.response.write(
                jsonEncode([
                  {
                    'id': 'blueprint-1',
                    'status': 'active',
                    'brand_profile_id': 'brand-2',
                  },
                ]),
              );
              break;
            case 'POST /api/brand-video-blueprints':
              request.response.statusCode = 201;
              request.response.write(
                jsonEncode({
                  'id': 'blueprint-2',
                  'status': jsonDecode(body)['status'],
                  'brand_profile_id': jsonDecode(body)['brand_profile_id'],
                }),
              );
              break;
            case 'POST /api/psychology/dispatch-pipeline':
              request.response.write(
                jsonEncode({
                  'task_id': 'task-1',
                  'content_record_id': 'content-1',
                  'format': 'article',
                  'status': 'running',
                }),
              );
              break;
            default:
              request.response.statusCode = 404;
              request.response.write('{"detail":"not found"}');
          }
          await request.response.close();
        }),
      );

      final api = ApiService(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );

      final profiles = await api.fetchBrandProfiles(projectId: 'project-1');
      final created = await api.createBrandProfile(
        projectId: 'project-1',
        draft: const BrandProfileDraft(
          name: 'Fresh',
          primaryColors: ['#111111'],
        ),
      );
      final updated = await api.updateBrandProfile(
        brandProfileId: 'brand-2',
        draft: const BrandProfileDraft(
          name: 'Updated',
          primaryColors: ['#222222'],
          outroModuleEnabled: false,
          isDefault: true,
        ),
      );
      final blueprints = await api.fetchBrandVideoBlueprints(
        projectId: 'project-1',
        brandProfileId: 'brand-2',
      );
      final blueprint = await api.createBrandVideoBlueprint(
        projectId: 'project-1',
        brandProfileId: 'brand-2',
        name: 'Short-form',
        defaultArchetype: 'faceless_reel',
      );
      final dispatch = await api.dispatchPipeline(
        angle: const AngleSuggestion(
          title: 'Persona-aware angle',
          hook: 'Hook',
          angle: 'Angle',
          contentType: 'blog_post',
          narrativeThread: 'Thread',
          painPointAddressed: 'Pain point',
          confidence: 90,
        ),
        personaId: 'persona-1',
      );
      await api.deleteBrandProfile(brandProfileId: 'brand-2');

      expect(profiles.single.name, 'Primary');
      expect(created.id, 'brand-2');
      expect(updated.isDefault, isTrue);
      expect(blueprints.single['status'], 'active');
      expect(blueprint['id'], 'blueprint-2');
      expect(dispatch?['content_record_id'], 'content-1');
      expect(
        capturedRequests
            .map((entry) => '${entry.method} ${entry.path}')
            .toList(),
        [
          'GET /api/brand-profiles',
          'POST /api/brand-profiles',
          'PATCH /api/brand-profiles/brand-2',
          'GET /api/brand-video-blueprints',
          'POST /api/brand-video-blueprints',
          'POST /api/psychology/dispatch-pipeline',
          'DELETE /api/brand-profiles/brand-2',
        ],
      );
      expect(capturedRequests.first.query['projectId'], 'project-1');
      expect(capturedRequests[3].query, {
        'projectId': 'project-1',
        'brandProfileId': 'brand-2',
      });
      expect(
        jsonDecode(capturedRequests[5].body)['angle_data']['persona_id'],
        'persona-1',
      );
    },
  );
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final String body;
}
