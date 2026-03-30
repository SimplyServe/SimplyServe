import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/recipe_page.dart';

void main() {
  group('RecipePage Widget Tests', () {
    const testRecipe = RecipeModel(
      id: 1,
      title: 'Pasta Carbonara',
      imageUrl: 'https://example.com/pasta.jpg',
      prepTime: '10 mins',
      cookTime: '20 mins',
      totalTime: '30 mins',
      servings: 4,
      difficulty: 'Medium',
      summary: 'Classic Italian pasta dish',
      nutrition: NutritionInfo(
        calories: 450,
        protein: '25g',
        carbs: '45g',
        fats: '18g',
      ),
      ingredients: [
        IngredientEntry(name: 'Pasta', quantity: 400, unit: 'g'),
        IngredientEntry(name: 'Eggs', quantity: 4, unit: 'pcs'),
        IngredientEntry(name: 'Bacon', quantity: 200, unit: 'g'),
        IngredientEntry(name: 'Parmesan', quantity: 100, unit: 'g'),
      ],
      steps: [
        'Cook pasta in salted water',
        'Fry bacon until crispy',
        'Mix eggs with parmesan',
        'Combine all ingredients',
      ],
      tags: ['Italian', 'Pasta', 'Quick'],
    );

    testWidgets('RecipePage displays recipe title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      expect(find.text('Pasta Carbonara'), findsOneWidget);
    });

    testWidgets('RecipePage displays difficulty level', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('RecipePage displays servings', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('RecipePage displays cooking times', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      // Check for time information
      expect(find.textContaining('30'), findsWidgets);
    });

    testWidgets('RecipePage displays all ingredients', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      // Check that ingredients are displayed
      expect(find.textContaining('Pasta'), findsWidgets);
      expect(find.textContaining('Eggs'), findsWidgets);
      expect(find.textContaining('Bacon'), findsWidgets);
      expect(find.textContaining('Parmesan'), findsWidgets);
    });

    testWidgets('RecipePage displays cooking steps',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      // Check that steps are displayed
      expect(find.textContaining('Cook pasta'), findsOneWidget);
      expect(find.textContaining('Fry bacon'), findsOneWidget);
    });

    testWidgets('RecipePage has Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RecipePage displays summary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecipePage(recipe: testRecipe),
        ),
      );

      expect(find.textContaining('Classic Italian pasta dish'), findsOneWidget);
    });
  });
}