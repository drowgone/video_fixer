// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:video_fixer/main.dart';
import 'package:video_fixer/services/settings_provider.dart';
import 'package:video_fixer/services/video_processing_provider.dart';

void main() {
  testWidgets('VideoFixer app renders root scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => VideoProcessingProvider()),
        ],
        child: const MaterialApp(
          home: MainTabScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MainTabScreen), findsOneWidget);
  });
}
