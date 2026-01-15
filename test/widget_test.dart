// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aq_cheats_tool/main.dart';
import 'package:aq_cheats_tool/core/providers/app_provider.dart';
import 'package:aq_cheats_tool/core/providers/activation_provider.dart';
import 'package:aq_cheats_tool/core/providers/zgw_provider.dart';
import 'package:aq_cheats_tool/core/providers/cc_messages_provider.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => ActivationProvider()),
          ChangeNotifierProvider(create: (_) => ZGWProvider()),
          ChangeNotifierProvider(create: (_) => CCMessagesProvider()),
        ],
        child: const AQCheatsToolApp(),
      ),
    );

    // Wait for animations
    await tester.pumpAndSettle();

    // Verify app launches successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
