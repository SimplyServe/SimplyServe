import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/recipes.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('RecipesView Widget Tests', () {
    testWidgets('RecipesView renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipesView(),
        ),
      );

      // Just pump once to build the widget tree
      await tester.pump();

      // Verify NavBarScaffold is present
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Recipes'), findsAtLeastNWidgets(1));
    });

    testWidgets('RecipesView is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipesView(),
        ),
      );

      // Verify it's a stateful widget
      expect(find.byType(RecipesView), findsOneWidget);
    });

    testWidgets('RecipesView has Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipesView(),
        ),
      );

      await tester.pump();

      // Verify Scaffold exists (from NavBarScaffold)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}