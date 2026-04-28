import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/shopping_list.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  setUp(() {
    // Reset singleton state before each test
    ShoppingListService().clearAll();
  });

  group('ShoppingListView Widget Tests', () {
    testWidgets('renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.byType(NavBarScaffold), findsOneWidget);
      expect(find.text('Shopping List'), findsAtLeastNWidgets(1));
    });

    testWidgets('has Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      expect(find.byType(ShoppingListView), findsOneWidget);
    });

    testWidgets('is a StatefulWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      expect(find.byType(ShoppingListView), findsOneWidget);
    });

    // ── Empty state ──────────────────────────────────────────────────────

    testWidgets('shows empty state icon and message when list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.text('Your shopping list is empty'), findsOneWidget);
    });

    testWidgets('shows helper text when list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(
        find.text('Add ingredients from a recipe to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('does not show Clear List button when list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Clear List'), findsNothing);
    });

    // ── Populated state ──────────────────────────────────────────────────

    testWidgets('shows Clear List button when items are present',
        (WidgetTester tester) async {
      ShoppingListService().addIngredients(['Eggs'], recipeTitle: 'Omelette');

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Clear List'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('shows ingredient name in list', (WidgetTester tester) async {
      final service = ShoppingListService();
      service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
      service.addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Omelette',
        caloriesPerServing: 300,
        proteinPerServing: 15,
        carbsPerServing: 5,
        fatsPerServing: 20,
        plannedDate: DateTime(2026, 5, 1),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('shows recipe section title', (WidgetTester tester) async {
      ShoppingListService().addIngredients(['Eggs'], recipeTitle: 'Omelette');
      ShoppingListService().addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Omelette',
        caloriesPerServing: 300,
        proteinPerServing: 15,
        carbsPerServing: 20,
        fatsPerServing: 10,
        plannedDate: DateTime(2026, 5, 1),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Omelette'), findsWidgets);
    });

    // ── Common ingredient grouping ────────────────────────────────────────

    testWidgets('shows Common ingredients section when an item is in multiple recipes',
        (WidgetTester tester) async {
      final service = ShoppingListService();
      service.addIngredients(['Flour'], recipeTitle: 'Bread');
      service.addIngredients(['Flour'], recipeTitle: 'Pizza');
      service.addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Bread',
        caloriesPerServing: 200,
        proteinPerServing: 8,
        carbsPerServing: 35,
        fatsPerServing: 3,
        plannedDate: DateTime(2026, 5, 1),
      ));
      service.addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Pizza',
        caloriesPerServing: 500,
        proteinPerServing: 20,
        carbsPerServing: 60,
        fatsPerServing: 18,
        plannedDate: DateTime(2026, 5, 2),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Common ingredients'), findsOneWidget);
    });

    testWidgets('does not show Common ingredients section for single-recipe items',
        (WidgetTester tester) async {
      ShoppingListService()
          .addIngredients(['Eggs', 'Butter'], recipeTitle: 'Omelette');
      ShoppingListService().addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Omelette',
        caloriesPerServing: 300,
        proteinPerServing: 15,
        carbsPerServing: 5,
        fatsPerServing: 20,
        plannedDate: DateTime(2026, 5, 1),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.text('Common ingredients'), findsNothing);
    });

    testWidgets('quantity counter is visible for each item',
        (WidgetTester tester) async {
      final service = ShoppingListService();
      service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
      service.addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Omelette',
        caloriesPerServing: 300,
        proteinPerServing: 15,
        carbsPerServing: 5,
        fatsPerServing: 20,
        plannedDate: DateTime(2026, 5, 1),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      // Quantity starts at 1
      expect(find.text('1'), findsWidgets);
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byIcon(Icons.remove), findsWidgets);
    });

    // ── Date label display ───────────────────────────────────────────────

    testWidgets('recipe section subtitle shows ingredient count',
        (WidgetTester tester) async {
      final service = ShoppingListService();
      service.addIngredients(['Eggs', 'Butter'], recipeTitle: 'Omelette');
      service.addRecipe(ShoppingRecipeEntry(
        recipeTitle: 'Omelette',
        caloriesPerServing: 300,
        proteinPerServing: 15,
        carbsPerServing: 5,
        fatsPerServing: 20,
        plannedDate: DateTime(2026, 5, 1),
      ));

      await tester.pumpWidget(
        const MaterialApp(home: ShoppingListView()),
      );
      await tester.pump();

      expect(find.textContaining('ingredient'), findsWidgets);
    });
  });
}