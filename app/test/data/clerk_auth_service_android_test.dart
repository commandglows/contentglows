import 'package:app/data/services/clerk_auth_service_android.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.contentglows.app/clerk_auth');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a native session without persisting its token', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'restoreSession');
          return <String, Object?>{
            'bearerToken': 'memory-only-token',
            'userId': 'user_123',
            'email': 'user@example.test',
          };
        });
    final prefs = await SharedPreferences.getInstance();
    final service = ClerkAuthService(
      publishableKey: 'pk_test_placeholder',
      sharedPreferences: prefs,
      channel: channel,
      isAndroid: true,
    );

    final session = await service.restoreSession();

    expect(session?.userId, 'user_123');
    expect(session?.bearerToken, 'memory-only-token');
    expect(prefs.getKeys(), isEmpty);
  });

  test('maps a cancelled native operation to a typed exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'cancelled', message: 'cancelled');
        });
    final service = ClerkAuthService(
      publishableKey: 'pk_test_placeholder',
      sharedPreferences: await SharedPreferences.getInstance(),
      channel: channel,
      isAndroid: true,
    );

    expect(
      service.signInWithGoogle(),
      throwsA(
        isA<ClerkAuthException>().having(
          (error) => error.isCancelled,
          'isCancelled',
          true,
        ),
      ),
    );
  });
}
