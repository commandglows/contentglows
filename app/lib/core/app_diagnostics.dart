import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_access_state.dart';
import '../data/models/auth_session.dart';
import 'app_config.dart';

final appDiagnosticsProvider = Provider<AppDiagnostics>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

enum AppDiagnosticLevel { info, warning, error }

class AppDiagnosticEntry {
  const AppDiagnosticEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.scope,
    required this.message,
    this.error,
    this.stackTrace,
    this.context = const <String, String>{},
  });

  final int id;
  final DateTime timestamp;
  final AppDiagnosticLevel level;
  final String scope;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, String> context;
}

class AppDiagnostics {
  AppDiagnostics({this.maxEntries = 250});

  final int maxEntries;
  final List<AppDiagnosticEntry> _entries = <AppDiagnosticEntry>[];
  int _nextId = 0;

  void info({
    required String scope,
    required String message,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    record(
      level: AppDiagnosticLevel.info,
      scope: scope,
      message: message,
      context: context,
    );
  }

  void warning({
    required String scope,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    record(
      level: AppDiagnosticLevel.warning,
      scope: scope,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void error({
    required String scope,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    record(
      level: AppDiagnosticLevel.error,
      scope: scope,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void record({
    required AppDiagnosticLevel level,
    required String scope,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final entry = AppDiagnosticEntry(
      id: ++_nextId,
      timestamp: DateTime.now().toUtc(),
      level: level,
      scope: scope.trim().isEmpty ? 'unknown' : scope.trim(),
      message: _normalizeMessage(message, fallback: formatError(error)),
      error: error == null ? null : formatError(error),
      stackTrace: _normalizeStackTrace(stackTrace),
      context: _sanitizeContext(context),
    );

    _entries.add(entry);
    final overflow = _entries.length - maxEntries;
    if (overflow > 0) {
      _entries.removeRange(0, overflow);
    }

    debugPrint(_formatConsoleEntry(entry));
    if (entry.stackTrace != null && entry.stackTrace!.isNotEmpty) {
      debugPrint(entry.stackTrace);
    }
  }

  List<AppDiagnosticEntry> snapshot({int limit = 25}) {
    if (_entries.isEmpty) {
      return const <AppDiagnosticEntry>[];
    }

    final takeCount = limit < _entries.length ? limit : _entries.length;
    final start = _entries.length - takeCount;
    return List<AppDiagnosticEntry>.unmodifiable(
      _entries.sublist(start).reversed,
    );
  }

  String buildReport({
    required String title,
    required AuthSession authSession,
    required AppAccessState? accessState,
    String? scope,
    String? currentError,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
    List<String> extraLines = const <String>[],
    int recentEntryLimit = 25,
  }) {
    final currentErrorText = _normalizeCurrentError(
      currentError: currentError,
      error: error,
    );
    final sanitizedContext = _sanitizeContext(context);
    final lines = <String>[
      ...AppConfig.buildIdentityHeader(),
      title,
      'Generated at: ${DateTime.now().toUtc().toIso8601String()}',
      'Build id: ${AppConfig.buildId}',
      'Build commit: ${AppConfig.buildCommitSha}',
      'Build environment: ${AppConfig.buildEnvironment}',
      'Build timestamp: ${AppConfig.buildTimestamp}',
      'Build mode: ${_buildModeLabel()}',
      'API_BASE_URL: ${AppConfig.apiBaseUrl}',
      'APP_SITE_URL: ${AppConfig.siteUrl}',
      'Effective website URL: ${AppConfig.effectiveSiteUrl}',
      'APP_WEB_URL: ${AppConfig.appWebUrl}',
      'SENTRY_DSN: ${AppConfig.sentryDsn.isEmpty ? 'missing' : 'configured'}',
      'SENTRY_ENVIRONMENT: ${AppConfig.effectiveSentryEnvironment}',
      'SENTRY_RELEASE: ${AppConfig.effectiveSentryRelease.isEmpty ? 'unknown' : AppConfig.effectiveSentryRelease}',
      'SENTRY_DIST: ${AppConfig.effectiveSentryDist.isEmpty ? 'unknown' : AppConfig.effectiveSentryDist}',
      'SENTRY_SEND_DEFAULT_PII: ${AppConfig.sentrySendDefaultPii ? 'true' : 'false'}',
      'SENTRY_TRACES_SAMPLE_RATE: ${AppConfig.sentryTracesSampleRate}',
      'CLERK_PUBLISHABLE_KEY: ${AppConfig.clerkPublishableKey.isEmpty ? 'missing' : 'configured'}',
      'Key preview: ${_maskPublishableKey(AppConfig.clerkPublishableKey)}',
      'Session state: ${authSession.status.name}',
      'Session email: ${authSession.email ?? 'none'}',
      'Bearer token: ${_maskValue('bearer_token', authSession.bearerToken)}',
      'Onboarding complete: ${authSession.onboardingComplete ? 'yes' : 'no'}',
      'Access stage: ${accessState?.diagnosticsLabel ?? 'loading'}',
      'Backend reachable: ${accessState?.backendReachable == true ? 'yes' : 'no'}',
      'Backend status: ${accessState?.backendStatusLabel ?? 'unknown'}',
      'Backend git_sha: ${accessState?.backendHealth?['git_sha']?.toString() ?? 'unknown'}',
      'Bootstrap status: ${accessState?.bootstrapStatusLabel ?? 'not_started'}',
      'Last API status code: ${accessState?.statusCode?.toString() ?? 'none'}',
      'Last API message: ${accessState?.message ?? 'none'}',
      'Current URL: ${kIsWeb ? Uri.base.toString() : 'not-web'}',
      'Current origin: ${kIsWeb ? Uri.base.origin : 'not-web'}',
      'Current host: ${kIsWeb ? Uri.base.host : 'not-web'}',
      'Current path: ${kIsWeb ? Uri.base.path : 'not-web'}',
      'Current scope: ${scope == null || scope.isEmpty ? 'none' : scope}',
      'Current error: $currentErrorText',
    ];

    if (sanitizedContext.isNotEmpty) {
      lines.add('Current context:');
      for (final entry in sanitizedContext.entries) {
        lines.add('  ${entry.key}: ${entry.value}');
      }
    }

    final normalizedStack = _normalizeStackTrace(stackTrace);
    if (normalizedStack != null && normalizedStack.isNotEmpty) {
      lines.add('Current stack trace:');
      for (final line in normalizedStack.split('\n').take(12)) {
        lines.add('  $line');
      }
    }

    if (extraLines.isNotEmpty) {
      lines.addAll(extraLines);
    }

    final recentEntries = snapshot(limit: recentEntryLimit);
    lines.add('Recent diagnostic events: ${recentEntries.length}');
    if (recentEntries.isEmpty) {
      lines.add('  none');
    } else {
      for (final entry in recentEntries) {
        lines.add(_formatReportEntry(entry));
      }
    }

    return lines.join('\n');
  }

  static String formatError(Object? error) {
    if (error == null) {
      return 'Unexpected error.';
    }

    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Unexpected error.';
    }

    return raw.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

  String _normalizeCurrentError({String? currentError, Object? error}) {
    final explicit = currentError?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (error != null) {
      return formatError(error);
    }
    return 'none';
  }

  String _normalizeMessage(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback.isEmpty ? 'Unexpected diagnostic event.' : fallback;
  }

  String? _normalizeStackTrace(StackTrace? stackTrace) {
    final raw = stackTrace?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  Map<String, String> _sanitizeContext(Map<String, Object?> context) {
    final sanitized = <String, String>{};
    for (final entry in context.entries) {
      if (entry.value == null) {
        continue;
      }
      sanitized[entry.key] = _maskValue(entry.key, entry.value);
    }
    return sanitized;
  }

  static String _buildModeLabel() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  static String _maskPublishableKey(String value) {
    if (value.isEmpty) return 'missing';
    if (value.length <= 18) return value;
    return '${value.substring(0, 10)}...${value.substring(value.length - 5)} (len=${value.length})';
  }

  static String _maskValue(String key, Object? value) {
    if (value == null) {
      return 'none';
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return 'none';
    }

    final normalizedKey = key.toLowerCase();
    final isSensitive =
        normalizedKey.contains('token') ||
        normalizedKey.contains('authorization') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('cookie') ||
        normalizedKey.contains('jwt');

    if (isSensitive) {
      if (text.length <= 14) {
        return text;
      }
      return '${text.substring(0, 8)}...${text.substring(text.length - 4)}';
    }

    final redactedText = _redactUrlQueryTokens(text);
    return redactedText.length <= 500
        ? redactedText
        : '${redactedText.substring(0, 497)}...';
  }

  static String _redactUrlQueryTokens(String text) {
    return text.replaceAllMapped(RegExp(r'https?:\/\/[^\s"<>}\]]+'), (match) {
      final raw = match.group(0);
      if (raw == null || raw.isEmpty) {
        return raw ?? '';
      }
      final queryStart = raw.indexOf('?');
      if (queryStart < 0) {
        return raw;
      }
      return '${raw.substring(0, queryStart)}?[redacted]';
    });
  }

  String _formatConsoleEntry(AppDiagnosticEntry entry) {
    final buffer = StringBuffer(
      '[ContentGlows][${entry.level.name.toUpperCase()}][${entry.scope}] ${entry.message}',
    );
    if (entry.error != null && entry.error != entry.message) {
      buffer.write(' | error=${entry.error}');
    }
    if (entry.context.isNotEmpty) {
      buffer.write(
        ' | ${entry.context.entries.map((item) => '${item.key}=${item.value}').join(' ')}',
      );
    }
    return buffer.toString();
  }

  String _formatReportEntry(AppDiagnosticEntry entry) {
    final buffer = StringBuffer(
      '  [${entry.timestamp.toIso8601String()}] ${entry.level.name.toUpperCase()} ${entry.scope}: ${entry.message}',
    );
    if (entry.error != null && entry.error != entry.message) {
      buffer.write(' | error=${entry.error}');
    }
    if (entry.context.isNotEmpty) {
      buffer.write(
        ' | ${entry.context.entries.map((item) => '${item.key}=${item.value}').join(', ')}',
      );
    }
    return buffer.toString();
  }
}

final class AppDiagnosticsObserver extends ProviderObserver {
  AppDiagnosticsObserver(this.diagnostics);

  final AppDiagnostics diagnostics;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnostics.error(
      scope: 'riverpod.provider',
      message: 'Provider failure detected.',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{'provider': context.provider.toString()},
    );
  }
}
