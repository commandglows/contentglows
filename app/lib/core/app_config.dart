class AppConfig {
  static const canonicalSiteUrl = 'https://contentglows.com';
  static const _defaultApiBaseUrl = 'https://api.contentglows.com';

  static const _apiBaseUrlRaw = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
  static final apiBaseUrl = normalizeHttpOrigin(
    _apiBaseUrlRaw,
    fallback: _defaultApiBaseUrl,
  );

  static const clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const devAuthBypass = bool.fromEnvironment(
    'CONTENTGLOWS_DEV_AUTH_BYPASS',
    defaultValue: false,
  );

  static const siteUrl = String.fromEnvironment(
    'APP_SITE_URL',
    defaultValue: canonicalSiteUrl,
  );

  static const appWebUrl = String.fromEnvironment(
    'APP_WEB_URL',
    defaultValue: 'https://app.contentglows.com',
  );

  static const buildCommitSha = String.fromEnvironment(
    'BUILD_COMMIT_SHA',
    defaultValue: 'unknown',
  );

  static const buildId = String.fromEnvironment(
    'BUILD_ID',
    defaultValue: 'unknown',
  );

  static const buildEnvironment = String.fromEnvironment(
    'BUILD_ENVIRONMENT',
    defaultValue: 'unknown',
  );

  static const buildTimestamp = String.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 'unknown',
  );

  static const buildAtParis = String.fromEnvironment(
    'BUILD_AT_PARIS',
    defaultValue: 'unknown',
  );

  static const buildAtUtc = String.fromEnvironment(
    'BUILD_AT_UTC',
    defaultValue: buildTimestamp,
  );

  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: buildEnvironment,
  );

  static const sentryRelease = String.fromEnvironment(
    'SENTRY_RELEASE',
    defaultValue: '',
  );

  static const sentryDist = String.fromEnvironment(
    'SENTRY_DIST',
    defaultValue: '',
  );

  static const sentryTracesSampleRateValue = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.0',
  );

  static const sentrySendDefaultPii = bool.fromEnvironment(
    'SENTRY_SEND_DEFAULT_PII',
    defaultValue: false,
  );

  static const sentryDebug = bool.fromEnvironment(
    'SENTRY_DEBUG',
    defaultValue: false,
  );

  static String get effectiveSentryEnvironment {
    final configured = sentryEnvironment.trim();
    return configured.isEmpty ? 'unknown' : configured;
  }

  static String get effectiveSentryRelease {
    final configured = sentryRelease.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    final commit = buildCommitSha.trim();
    if (commit.isEmpty || commit == 'unknown') {
      return '';
    }

    return 'contentglows_app@$commit';
  }

  static String get effectiveSentryDist {
    final configured = sentryDist.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    final timestamp = buildTimestamp.trim();
    if (timestamp.isEmpty || timestamp == 'unknown') {
      return '';
    }

    return timestamp;
  }

  static double get sentryTracesSampleRate {
    return _parseSampleRate(sentryTracesSampleRateValue, fallback: 0.0);
  }

  static bool get siteUrlPointsToAppHost {
    final configured = Uri.tryParse(siteUrl);
    final app = Uri.tryParse(appWebUrl);
    if (configured == null || configured.host.isEmpty) {
      return false;
    }
    if (app == null || app.host.isEmpty) {
      return false;
    }
    return configured.host == app.host;
  }

  static String normalizeHttpOrigin(String? raw, {required String fallback}) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return fallback;
    }

    final withScheme = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return fallback;
    }

    return uri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  static String get effectiveSiteUrl {
    final configured = Uri.tryParse(siteUrl);
    if (configured == null || configured.host.isEmpty) {
      return canonicalSiteUrl;
    }
    if (siteUrlPointsToAppHost) {
      return canonicalSiteUrl;
    }
    return siteUrl;
  }

  static double _parseSampleRate(String value, {required double fallback}) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0.0 || parsed > 1.0) {
      return fallback;
    }
    return parsed;
  }

  static String buildIdentityValue() {
    final build = buildId.trim();
    if (build.isNotEmpty && build != 'unknown') {
      return build;
    }
    return buildCommitSha;
  }

  static List<String> buildIdentityHeader() {
    return <String>[
      'commit/build: ${buildIdentityValue()}',
      'build_at_paris: $buildAtParis',
      'build_at_utc: $buildAtUtc',
    ];
  }
}
