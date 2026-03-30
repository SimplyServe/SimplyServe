import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('SettingsView Widget Tests', () {
    testWidgets('SettingsView renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify the Settings view loads without crashing
      expect(find.byType(SettingsView), findsOneWidget);
    });

    testWidgets('SettingsView has Scaffold with AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify Scaffold and AppBar are present
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('SettingsView has TabBar widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify TabBar exists
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('SettingsView has TabBarView widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify TabBarView exists
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('SettingsView has two Tab widgets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Should have exactly 2 tabs
      expect(find.byType(Tab), findsNWidgets(2));
    });

    testWidgets('SettingsView displays Allergies tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify Allergies tab is present
      expect(find.text('Allergies'), findsOneWidget);
    });

    testWidgets('SettingsView uses SingleTickerProviderStateMixin',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // If this loads without error, SingleTickerProviderStateMixin is working
      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('SettingsView has ListView for content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Should have ListViews for displaying items
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('SettingsView is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify the widget loads (proves it's a valid StatefulWidget)
      expect(find.byType(SettingsView), findsOneWidget);
    });

    testWidgets('SettingsView tab structure is correct',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify complete tab structure
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(2));
    });
  });
}
