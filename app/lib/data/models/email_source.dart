class EmailSourceStatus {
  const EmailSourceStatus({
    required this.configured,
    required this.validationStatus,
    this.email,
    this.host = 'imap.gmail.com',
    this.sourceFolder = 'Newsletters',
    this.archiveFolder = 'CONTENTGLOWS_DONE',
    this.projectId,
    this.lastValidatedAt,
    this.updatedAt,
  });

  final bool configured;
  final String? email;
  final String host;
  final String sourceFolder;
  final String archiveFolder;
  final String? projectId;
  final String validationStatus;
  final DateTime? lastValidatedAt;
  final DateTime? updatedAt;

  bool get isValid => validationStatus == 'valid';
  bool get isInvalid => validationStatus == 'invalid';
  bool get isMissing => validationStatus == 'missing';

  factory EmailSourceStatus.fromJson(Map<String, dynamic> json) {
    return EmailSourceStatus(
      configured: json['configured'] as bool? ?? false,
      email: json['email']?.toString(),
      host: (json['host'] ?? 'imap.gmail.com').toString(),
      sourceFolder: (json['sourceFolder'] ?? 'Newsletters').toString(),
      archiveFolder: (json['archiveFolder'] ?? 'CONTENTGLOWS_DONE').toString(),
      projectId: json['projectId']?.toString(),
      validationStatus: (json['validationStatus'] ?? 'unknown').toString(),
      lastValidatedAt: _parseDateTime(json['lastValidatedAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class EmailSourceValidationResult {
  const EmailSourceValidationResult({
    required this.valid,
    required this.validationStatus,
    required this.message,
  });

  final bool valid;
  final String validationStatus;
  final String message;

  factory EmailSourceValidationResult.fromJson(Map<String, dynamic> json) {
    return EmailSourceValidationResult(
      valid: json['valid'] as bool? ?? false,
      validationStatus: (json['validationStatus'] ?? 'unknown').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
