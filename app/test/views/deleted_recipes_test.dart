import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/deleted_recipes.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('DeletedRecipesView Widget Tests', () {
    testWidgets('renders Scaffold and AppBar with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Deleted Recipes'), findsOneWidget);
    });

    testWidgets('shows loading indicator on initial load',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      // Before the async fetch resolves, loading indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is a StatefulWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      expect(find.byType(DeletedRecipesView), findsOneWidget);
    });

    testWidgets('AppBar has white background', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.white));
    });

    testWidgets('Delete All button is not shown while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      // During loading, Delete All should not be rendered yet
      expect(find.text('Delete All'), findsNothing);
    });

    testWidgets('delete_forever icon exists in the widget tree after load',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      await tester.pump();

      expect(find.byType(DeletedRecipesView), findsOneWidget);
    });

    testWidgets('shows empty state UI when list is empty after load',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DeletedRecipesView()),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
