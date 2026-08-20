import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:app/data/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'branded video generation uses the canonical endpoint and payload',
    () async {
      late String requestMethod;
      late String requestPath;
      late Map<String, dynamic> requestBody;
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((request) async {
          requestMethod = request.method;
          requestPath = request.uri.path;
          requestBody = jsonDecode(await utf8.decoder.bind(request).join());
          request.response
            ..statusCode = 201
            ..headers.contentType = io.ContentType.json
            ..write(jsonEncode(_generationResponse));
          await request.response.close();
        }),
      );

      final api = ApiService(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      final generation = await api.generateBrandedVideoFromContent(
        contentId: 'content-42',
        formatPreset: 'landscape_16_9',
        brandProfileId: 'brand-1',
        blueprintId: 'blueprint-1',
        triggerSource: 'manual_create',
        clientRequestId: 'request-1',
      );

      expect(requestMethod, 'POST');
      expect(requestPath, '/api/video-timelines/from-content/branded-generate');
      expect(requestBody, {
        'content_id': 'content-42',
        'brand_profile_id': 'brand-1',
        'blueprint_id': 'blueprint-1',
        'format_preset': 'landscape_16_9',
        'trigger_source': 'manual_create',
        'client_request_id': 'request-1',
      });
      expect(generation.timeline.contentId, 'content-42');
      expect(generation.timeline.timelineId, 'timeline-1');
      expect(generation.readiness, 'ready');
    },
  );
}

const _timelineDocument = {
  'schema_version': '1.0',
  'format_preset': 'landscape_16_9',
  'fps': 30,
  'duration_frames': 90,
  'tracks': <Map<String, dynamic>>[],
  'clips': <Map<String, dynamic>>[],
};

const _version = {
  'version_id': 'version-1',
  'timeline_id': 'timeline-1',
  'version_number': 1,
  'timeline': _timelineDocument,
  'renderer_props': <String, dynamic>{},
  'created_at': '2026-07-08T12:00:00Z',
};

const _generationResponse = {
  'brand_profile_id': 'brand-1',
  'brand_template_id': 'blueprint-1',
  'brand_template_revision': 1,
  'timeline': {
    'timeline_id': 'timeline-1',
    'content_id': 'content-42',
    'project_id': 'project-1',
    'user_id': 'user-1',
    'format_preset': 'landscape_16_9',
    'current_version_id': 'version-1',
    'draft_revision': 1,
    'draft': _timelineDocument,
    'latest_version': _version,
    'preview_status': 'queued',
    'final_status': 'missing',
    'created_at': '2026-07-08T12:00:00Z',
    'updated_at': '2026-07-08T12:00:00Z',
  },
  'version': _version,
  'preview_job': {
    'job_id': 'preview-1',
    'timeline_id': 'timeline-1',
    'version_id': 'version-1',
    'render_mode': 'preview',
    'status': 'queued',
    'progress': 0,
    'created_at': '2026-07-08T12:00:00Z',
    'updated_at': '2026-07-08T12:00:00Z',
  },
  'readiness': 'ready',
  'blockers': <String>[],
};
