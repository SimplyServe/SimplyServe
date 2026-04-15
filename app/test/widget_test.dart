import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('Widget tests for MyApp', () {
    testWidgets('MyApp launches successfully', (WidgetTester tester) async {
      // Pump the full app
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      // Verify app loads
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('MyApp with isLoggedIn=true loads successfully',
        (WidgetTester tester) async {
      // Pump the app with logged in state
      await tester.pumpWidget(const MyApp(isLoggedIn: true));

      // Verify app loads
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('MyApp has MaterialApp widget', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      // Verify MaterialApp exists
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MyApp initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      // App should render without errors
      expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
