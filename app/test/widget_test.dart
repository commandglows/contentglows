import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/app_diagnostics.dart';
import 'package:app/core/shared_preferences_provider.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('ContentGlows app uses persisted theme preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_theme_preference': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appDiagnosticsProvider.overrideWithValue(AppDiagnostics()),
        ],
        child: const ContentGlowsApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
