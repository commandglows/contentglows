import 'package:app/data/models/social_placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a placement plan while ignoring unknown future fields', () {
    final plan = PlacementPlan.fromJson({
      'registry_version': '2026-08-08.1',
      'content_id': 'content-1',
      'format_id': 'FMT_SOCIAL_POST',
      'locale': 'fr',
      'future_field': {'safe': true},
      'platforms': [
        {
          'platform_id': 'PLAT_INSTAGRAM',
          'label': 'Instagram',
          'can_publish': false,
          'slots': [
            {
              'placement_id': 'PLC_SOCIAL_POST_IMAGE',
              'label': 'Visuel social',
              'required': true,
              'media_kinds': ['image'],
              'state': 'missing',
              'issues': [
                {
                  'code': 'PFL_MISSING_REQUIRED',
                  'severity': 'blocking',
                  'platform_id': 'PLAT_INSTAGRAM',
                  'message': 'Missing asset',
                },
              ],
            },
          ],
        },
      ],
    });

    expect(plan.registryVersion, '2026-08-08.1');
    expect(plan.platforms.single.canPublish, isFalse);
    expect(plan.platforms.single.slots.single.hasBlockingIssue, isTrue);
  });

  test('serializes platform targets for the server preflight contract', () {
    const target = PublishPlatformTarget(
      platform: 'linkedin',
      accountId: 'account-1',
    );

    expect(target.toJson(), {
      'platform': 'linkedin',
      'account_id': 'account-1',
    });
  });
}
