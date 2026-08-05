import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/project_onboarding_validation.dart';

void main() {
  group('normalizeOptionalText', () {
    test('returns null for blank input', () {
      expect(normalizeOptionalText('   '), isNull);
    });

    test('trims non-empty input', () {
      expect(
        normalizeOptionalText('  https://github.com/openai/openai  '),
        'https://github.com/openai/openai',
      );
    });
  });

  group('isValidGithubRepositoryUrl', () {
    test('accepts a standard github repository URL', () {
      expect(
        isValidGithubRepositoryUrl('https://github.com/openai/openai'),
        isTrue,
      );
    });

    test('rejects blank input', () {
      expect(isValidGithubRepositoryUrl(''), isFalse);
    });

    test('rejects non-github hosts', () {
      expect(
        isValidGithubRepositoryUrl('https://gitlab.com/openai/openai'),
        isFalse,
      );
    });

    test('rejects github URLs without owner and repo segments', () {
      expect(isValidGithubRepositoryUrl('https://github.com/openai'), isFalse);
    });
  });

  group('isValidProjectSourceUrl', () {
    test('accepts a generic https website URL', () {
      expect(isValidProjectSourceUrl('https://example.com'), isTrue);
    });

    test('accepts an http URL', () {
      expect(isValidProjectSourceUrl('http://example.com/docs'), isTrue);
    });

    test('rejects invalid schemes', () {
      expect(isValidProjectSourceUrl('file:///tmp/content.md'), isFalse);
    });

    test('rejects malformed urls', () {
      expect(isValidProjectSourceUrl('not-a-url'), isFalse);
    });
  });

  group('extractGithubRepositoryName', () {
    test('extracts repo name from a standard github URL', () {
      expect(
        extractGithubRepositoryName('https://github.com/openai/openai'),
        'openai',
      );
    });

    test('removes a git suffix', () {
      expect(
        extractGithubRepositoryName('https://github.com/acme/contentglows.git'),
        'contentglows',
      );
    });

    test('ignores non-github URLs', () {
      expect(
        extractGithubRepositoryName('https://gitlab.com/acme/contentglows'),
        isNull,
      );
    });

    test('requires owner and repo segments', () {
      expect(extractGithubRepositoryName('https://github.com/acme'), isNull);
    });
  });

  group('extractApiDetailMessage', () {
    test('formats FastAPI validation detail arrays', () {
      expect(
        extractApiDetailMessage([
          {
            'loc': ['body', 'source_url'],
            'msg': 'Input should be a valid URL',
          },
        ]),
        'source url: Input should be a valid URL',
      );
    });

    test('returns plain string details unchanged', () {
      expect(
        extractApiDetailMessage('Workspace already exists'),
        'Workspace already exists',
      );
    });
  });
}
