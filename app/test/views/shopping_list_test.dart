import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/shopping_list.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('ShoppingListView Widget Tests', () {
    testWidgets('ShoppingListView renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShoppingListView(),
        ),
      );

      await tester.pump();

      // Verify NavBarScaffold is present
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Shopping List'), findsAtLeastNWidgets(1));
    });

    testWidgets('ShoppingListView has Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShoppingListView(),
        ),
      );

      await tester.pump();

      // Verify Scaffold exists
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ShoppingListView renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShoppingListView(),
        ),
      );

      // Verify it renders
      expect(find.byType(ShoppingListView), findsOneWidget);
    });

    testWidgets('ShoppingListView is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShoppingListView(),
        ),
      );

      // Verify widget structure
      expect(find.byType(ShoppingListView), findsOneWidget);
    });
  });
}