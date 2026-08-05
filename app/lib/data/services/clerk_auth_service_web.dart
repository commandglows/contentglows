import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
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
  });

  final String publishableKey;
  final SharedPreferences sharedPreferences;

  Future<ClerkAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw StateError(
      'Password auth through the Flutter beta SDK has been removed from web production. '
      'Use the dedicated ClerkJS sign-in route instead.',
    );
  }

  Future<ClerkAuthResult> signInWithGoogle() async {
    throw const ClerkAuthException(
      'web_redirect_required',
      'Use the dedicated ClerkJS sign-in route on web.',
    );
  }

  Future<ClerkAuthResult> signUpWithPassword({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    throw StateError(
      'Sign-up through the Flutter beta SDK has been removed from web production. '
      'Use the dedicated ClerkJS sign-in route instead.',
    );
  }

  Future<void> signOut() async {
    final bridge = await _loadBridge();
    await _promiseToFuture<JSAny?>(
      bridge.callMethodVarArgs('signOut'.toJS, <JSAny?>[]),
    );
  }

  Future<ClerkAuthResult?> restoreSession() async {
    final bridge = await _loadBridge();
    final signedIn = (await _promiseToFuture<JSBoolean>(
      bridge.callMethodVarArgs('isSignedIn'.toJS, <JSAny?>[]),
    )).toDart;
    if (!signedIn) {
      return null;
    }

    final token = await getFreshToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final user = await _promiseToFuture<JSAny?>(
      bridge.callMethodVarArgs('getUser'.toJS, <JSAny?>[]),
    );
    final userMap = _mapFromJs(user);
    final userId = userMap['id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw StateError('ClerkJS did not return a user id.');
    }

    return ClerkAuthResult(
      bearerToken: token,
      userId: userId,
      email: userMap['primaryEmailAddress']?.toString(),
    );
  }

  Future<String?> getFreshToken({bool skipCache = false}) async {
    final bridge = await _loadBridge();
    final token = await _promiseToFuture<JSAny?>(
      bridge.callMethodVarArgs('getToken'.toJS, <JSAny?>[
        <String, Object?>{'skipCache': skipCache}.jsify(),
      ]),
    );
    final value = token?.dartify()?.toString();
    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }
    return value;
  }

  void terminate() {}

  Future<JSObject> _loadBridge() async {
    final bridge = JSObject.fromInteropObject(
      web.window,
    )['contentglowsClerkBridge'];
    if (bridge == null) {
      throw StateError(
        'ClerkJS bridge is missing from the web runtime. '
        'Make sure clerk-runtime.js is bundled into build/web.',
      );
    }

    final bridgeObject = bridge as JSObject;
    await _promiseToFuture<JSAny?>(
      bridgeObject.callMethodVarArgs('load'.toJS, <JSAny?>[]),
    );
    return bridgeObject;
  }

  Future<T> _promiseToFuture<T extends JSAny?>(JSAny? promise) {
    if (promise == null) {
      return Future<T>.error(StateError('ClerkJS bridge returned no value.'));
    }
    return (promise as JSPromise<T>).toDart;
  }

  Map<String, dynamic> _mapFromJs(JSAny? value) {
    if (value == null) {
      return const <String, dynamic>{};
    }

    final dartValue = value.dartify();
    if (dartValue is Map) {
      return Map<String, dynamic>.from(dartValue);
    }
    return const <String, dynamic>{};
  }
}
