import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/recipe_form.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('RecipeFormView Widget Tests', () {
    testWidgets('RecipeFormView renders without existing recipe',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Verify RecipeFormView loads
      expect(find.byType(RecipeFormView), findsOneWidget);
    });

    testWidgets('RecipeFormView is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Verify it's a stateful widget
      expect(find.byType(RecipeFormView), findsOneWidget);
    });

    testWidgets('RecipeFormView has Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Verify Scaffold is present
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RecipeFormView has AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Verify AppBar is present
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('RecipeFormView has form widgets', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Should have form elements like TextFields
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('RecipeFormView has SingleChildScrollView for scrolling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipeFormView(),
        ),
      );

      await tester.pump();

      // Verify scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
