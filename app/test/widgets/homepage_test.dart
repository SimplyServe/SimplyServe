import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/homepage.dart';

void main() {
  group('HomePage Widget Tests', () {
    testWidgets('HomePage renders with welcome message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Check for welcome text
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('HomePage displays dashboard message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Look for dashboard text
      expect(find.text('Hello! This is the dashboard.'), findsOneWidget);
    });

    testWidgets('HomePage has nutrition button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Button should be present
      expect(find.text('View Nutrition Information and Meal Plans'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Nutrition button shows SnackBar when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Tap the nutrition button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Check if SnackBar appears
      expect(find.text('Here you can view nutrition information and meal plans!'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('HomePage renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Should render successfully
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('HomePage has Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Should have Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('HomePage has PreferredSize widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Should have PreferredSize for AppBar
      expect(find.byType(PreferredSize), findsOneWidget);
    });

    testWidgets('Text widgets render properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );

      // Check for Text widgets
      final texts = find.byType(Text);
      expect(texts, findsWidgets);
    });
  });
}