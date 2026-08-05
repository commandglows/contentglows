import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClerkAuthResult {
  final String bearerToken;
  final String userId;
  final String? email;

  const ClerkAuthResult({
    required this.bearerToken,
    required this.userId,
    this.email,
  });
}

class ClerkAuthException implements Exception {
  const ClerkAuthException(this.code, this.message);
  final String code;
  final String message;
  bool get isCancelled => code == 'cancelled';
  @override
  String toString() => message;
}

class ClerkAuthService {
  ClerkAuthService({
    required this.publishableKey,
    required this.sharedPreferences,
    MethodChannel? channel,
    bool? isAndroid,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  static const _channelName = 'com.contentglows.app/clerk_auth';
  final String publishableKey;
  final SharedPreferences sharedPreferences;
  final MethodChannel _channel;
  final bool _isAndroid;

  Future<ClerkAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) => Future<ClerkAuthResult>.error(
    const ClerkAuthException(
      'unsupported_method',
      'Password authentication is not available in the Android native flow.',
    ),
  );

  Future<ClerkAuthResult> signUpWithPassword({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) => Future<ClerkAuthResult>.error(
    const ClerkAuthException(
      'unsupported_method',
      'Password authentication is not available in the Android native flow.',
    ),
  );

  Future<ClerkAuthResult> signInWithGoogle() async {
    _requireAndroid();
    return _resultFromPlatform(await _invokeMap('signInWithGoogle'));
  }

  Future<void> signOut() async {
    _requireAndroid();
    await _invokeMap('signOut');
  }

  Future<ClerkAuthResult?> restoreSession() async {
    _requireAndroid();
    final value = await _invokeMap('restoreSession');
    return value == null ? null : _resultFromPlatform(value);
  }

  Future<String?> getFreshToken({bool skipCache = false}) async {
    _requireAndroid();
    final value = await _channel.invokeMethod<String>('getFreshToken', {
      'skipCache': skipCache,
    });
    return value?.trim().isEmpty ?? true ? null : value;
  }

  void terminate() {}

  Future<Map<Object?, Object?>?> _invokeMap(String method) async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(method);
    } on PlatformException catch (error) {
      throw ClerkAuthException(
        error.code,
        error.message ?? 'Native Clerk failed.',
      );
    } on MissingPluginException {
      throw const ClerkAuthException(
        'unsupported_platform',
        'The Android Clerk bridge is unavailable on this platform.',
      );
    }
  }

  ClerkAuthResult _resultFromPlatform(Map<Object?, Object?>? value) {
    final token = value?['bearerToken']?.toString() ?? '';
    final userId = value?['userId']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw const ClerkAuthException(
        'invalid_native_result',
        'Android Clerk returned an incomplete session.',
      );
    }
    return ClerkAuthResult(
      bearerToken: token,
      userId: userId,
      email: value?['email']?.toString(),
    );
  }

  void _requireAndroid() {
    if (!_isAndroid) {
      throw const ClerkAuthException(
        'unsupported_platform',
        'The Android Clerk bridge is unavailable on this platform.',
      );
    }
  }
}
