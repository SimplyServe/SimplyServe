import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/recipe_page.dart';

void main() {
  group('RecipeModel Unit Tests', () {
    test('RecipeModel can be created with all required fields', () {
      const nutrition = NutritionInfo(
        calories: 350,
        protein: '25g',
        carbs: '45g',
        fats: '12g',
      );

      const recipe = RecipeModel(
        title: 'Pasta Carbonara',
        summary: 'Classic Italian pasta dish',
        imageUrl: 'https://example.com/pasta.jpg',
        prepTime: '10 minutes',
        cookTime: '20 minutes',
        totalTime: '30 minutes',
        servings: 4,
        difficulty: 'Easy',
        nutrition: nutrition,
        ingredients: [],
        steps: [],
        tags: ['Italian', 'Quick'],
        id: 1,
      );

      expect(recipe.title, equals('Pasta Carbonara'));
      expect(recipe.summary, equals('Classic Italian pasta dish'));
      expect(recipe.servings, equals(4));
      expect(recipe.difficulty, equals('Easy'));
      expect(recipe.id, equals(1));
      expect(recipe.tags.length, equals(2));
    });

    test('RecipeModel can be created without optional fields', () {
      const nutrition = NutritionInfo(
        calories: 100,
        protein: '5g',
        carbs: '20g',
        fats: '2g',
      );

      const recipe = RecipeModel(
        title: 'Salad',
        summary: 'Fresh salad',
        imageUrl: 'https://example.com/salad.jpg',
        prepTime: '5 minutes',
        cookTime: '0 minutes',
        totalTime: '5 minutes',
        servings: 2,
        difficulty: 'Very Easy',
        nutrition: nutrition,
        ingredients: [],
        steps: [],
      );

      expect(recipe.title, equals('Salad'));
      expect(recipe.tags, isEmpty);
      expect(recipe.id, isNull);
    });

    test('RecipeModel copyWith preserves existing fields', () {
      const nutrition1 = NutritionInfo(
        calories: 100,
        protein: '5g',
        carbs: '20g',
        fats: '2g',
      );

      const recipe1 = RecipeModel(
        title: 'Recipe1',
        summary: 'Summary1',
        imageUrl: 'url1',
        prepTime: '10',
        cookTime: '20',
        totalTime: '30',
        servings: 4,
        difficulty: 'Easy',
        nutrition: nutrition1,
        ingredients: [],
        steps: [],
      );

      const nutrition2 = NutritionInfo(
        calories: 200,
        protein: '10g',
        carbs: '40g',
        fats: '5g',
      );

      final recipe2 = recipe1.copyWith(nutrition: nutrition2);

      expect(recipe2.title, equals(recipe1.title));
      expect(recipe2.nutrition.calories, equals(200));
      expect(recipe2.nutrition.protein, equals('10g'));
    });

    test('RecipeModel copyWith without changes returns equivalent recipe', () {
      const nutrition = NutritionInfo(
        calories: 150,
        protein: '8g',
        carbs: '30g',
        fats: '3g',
      );

      const recipe1 = RecipeModel(
        title: 'Original',
        summary: 'Original Summary',
        imageUrl: 'url',
        prepTime: '15',
        cookTime: '25',
        totalTime: '40',
        servings: 3,
        difficulty: 'Medium',
        nutrition: nutrition,
        ingredients: [],
        steps: [],
      );

      final recipe2 = recipe1.copyWith();

      expect(recipe2.title, equals(recipe1.title));
      expect(recipe2.summary, equals(recipe1.summary));
      expect(recipe2.nutrition.calories, equals(recipe1.nutrition.calories));
      expect(recipe2.servings, equals(recipe1.servings));
    });

    test('NutritionInfo can be created with valid values', () {
      const nutrition = NutritionInfo(
        calories: 500,
        protein: '30g',
        carbs: '60g',
        fats: '15g',
      );

      expect(nutrition.calories, equals(500));
      expect(nutrition.protein, equals('30g'));
      expect(nutrition.carbs, equals('60g'));
      expect(nutrition.fats, equals('15g'));
    });

    test('NutritionInfo with zero calories', () {
      const nutrition = NutritionInfo(
        calories: 0,
        protein: '0g',
        carbs: '0g',
        fats: '0g',
      );

      expect(nutrition.calories, equals(0));
      expect(nutrition.protein, equals('0g'));
    });

    test('IngredientEntry can be created with required fields', () {
      const ingredient = IngredientEntry(
        name: 'Flour',
        quantity: 2.5,
        unit: 'cups',
      );

      expect(ingredient.name, equals('Flour'));
      expect(ingredient.quantity, equals(2.5));
      expect(ingredient.unit, equals('cups'));
      expect(ingredient.isCustom, isFalse);
    });

    test('IngredientEntry with custom nutrition values', () {
      const ingredient = IngredientEntry(
        name: 'Custom Ingredient',
        quantity: 1,
        unit: 'serving',
        calories: 150,
        protein: 10,
        carbs: 20,
        fats: 5,
        isCustom: true,
      );

      expect(ingredient.name, equals('Custom Ingredient'));
      expect(ingredient.calories, equals(150));
      expect(ingredient.protein, equals(10));
      expect(ingredient.isCustom, isTrue);
    });

    test('IngredientEntry displayLabel formats correctly', () {
      const ingredient1 = IngredientEntry(
        name: 'Salt',
        quantity: 1,
        unit: 'pcs',
      );

      // For quantity=1 and unit='pcs', just shows name
      expect(ingredient1.displayLabel, equals('Salt'));

      const ingredient2 = IngredientEntry(
        name: 'Flour',
        quantity: 2.5,
        unit: 'cups',
      );

      // For other quantities/units, shows formatted string
      expect(ingredient2.displayLabel, contains('2'));
      expect(ingredient2.displayLabel, contains('cups'));
      expect(ingredient2.displayLabel, contains('Flour'));
    });

    test('IngredientEntry displayLabel rounds whole numbers', () {
      const ingredient = IngredientEntry(
        name: 'Sugar',
        quantity: 3,
        unit: 'tablespoons',
      );

      // Should display as '3' not '3.0'
      expect(ingredient.displayLabel, equals('3 tablespoons Sugar'));
    });

    test('IngredientEntry toJson includes all fields for custom ingredient', () {
      const ingredient = IngredientEntry(
        name: 'Custom',
        quantity: 2,
        unit: 'grams',
        calories: 100,
        protein: 5,
        carbs: 15,
        fats: 2,
        isCustom: true,
      );

      final json = ingredient.toJson();

      expect(json['ingredient_name'], equals('Custom'));
      expect(json['quantity'], equals(2));
      expect(json['unit'], equals('grams'));
      expect(json['calories'], equals(100));
      expect(json['is_custom'], isTrue);
    });

    test('IngredientEntry toJson excludes nutrition for non-custom', () {
      const ingredient = IngredientEntry(
        name: 'Tomato',
        quantity: 1,
        unit: 'piece',
        isCustom: false,
      );

      final json = ingredient.toJson();

      expect(json['ingredient_name'], equals('Tomato'));
      expect(json.containsKey('is_custom'), isFalse);
      expect(json.containsKey('calories'), isFalse);
    });

    test('IngredientEntry fromJson creates instance correctly', () {
      final json = {
        'ingredient_name': 'Butter',
        'quantity': 0.5,
        'unit': 'cup',
      };

      final ingredient = IngredientEntry.fromJson(json);

      expect(ingredient.name, equals('Butter'));
      expect(ingredient.quantity, equals(0.5));
      expect(ingredient.unit, equals('cup'));
    });

    test('IngredientEntry fromJson handles missing fields with defaults', () {
      final json = {
        'ingredient_name': 'Unknown',
      };

      final ingredient = IngredientEntry.fromJson(json);

      expect(ingredient.name, equals('Unknown'));
      expect(ingredient.quantity, equals(1));
      expect(ingredient.unit, equals('pcs'));
    });

    test('IngredientEntry fromJson handles custom nutrition data', () {
      final json = {
        'ingredient_name': 'Custom',
        'quantity': 100,
        'unit': 'grams',
        'calories': 200,
        'protein': 15,
        'carbs': 25,
        'fats': 8,
        'is_custom': true,
      };

      final ingredient = IngredientEntry.fromJson(json);

      expect(ingredient.calories, equals(200));
      expect(ingredient.protein, equals(15));
      expect(ingredient.isCustom, isTrue);
    });

    test('IngredientEntry fromLegacy creates instance from string', () {
      final ingredient = IngredientEntry.fromLegacy('2 cups flour');

      expect(ingredient.name, equals('2 cups flour'));
      expect(ingredient.quantity, equals(1));
      expect(ingredient.unit, equals('pcs'));
    });

    test('Multiple recipes with different difficulties', () {
      const nutrition = NutritionInfo(
        calories: 200,
        protein: '10g',
        carbs: '30g',
        fats: '5g',
      );

      final recipes = [
        const RecipeModel(
          title: 'Easy Recipe',
          summary: 'Easy',
          imageUrl: 'url',
          prepTime: '5',
          cookTime: '10',
          totalTime: '15',
          servings: 2,
          difficulty: 'Very Easy',
          nutrition: nutrition,
          ingredients: [],
          steps: [],
        ),
        const RecipeModel(
          title: 'Hard Recipe',
          summary: 'Hard',
          imageUrl: 'url',
          prepTime: '30',
          cookTime: '120',
          totalTime: '150',
          servings: 8,
          difficulty: 'Hard',
          nutrition: nutrition,
          ingredients: [],
          steps: [],
        ),
      ];

      expect(recipes[0].difficulty, equals('Very Easy'));
      expect(recipes[1].difficulty, equals('Hard'));
      expect(recipes[1].servings, equals(8));
    });

    test('Recipe with many ingredients', () {
      const nutrition = NutritionInfo(
        calories: 300,
        protein: '15g',
        carbs: '45g',
        fats: '10g',
      );

      final ingredients = [
        const IngredientEntry(name: 'Ingredient1', quantity: 1, unit: 'unit1'),
        const IngredientEntry(name: 'Ingredient2', quantity: 2, unit: 'unit2'),
        const IngredientEntry(name: 'Ingredient3', quantity: 3, unit: 'unit3'),
        const IngredientEntry(name: 'Ingredient4', quantity: 4, unit: 'unit4'),
        const IngredientEntry(name: 'Ingredient5', quantity: 5, unit: 'unit5'),
      ];

      final recipe = RecipeModel(
        title: 'Complex Recipe',
        summary: 'Has many ingredients',
        imageUrl: 'url',
        prepTime: '20',
        cookTime: '45',
        totalTime: '65',
        servings: 4,
        difficulty: 'Medium',
        nutrition: nutrition,
        ingredients: ingredients,
        steps: [],
      );

      expect(recipe.ingredients.length, equals(5));
      expect(recipe.ingredients[0].name, equals('Ingredient1'));
    });

    test('Recipe with many steps', () {
      const nutrition = NutritionInfo(
        calories: 250,
        protein: '12g',
        carbs: '40g',
        fats: '8g',
      );

      final steps = [
        'Step 1',
        'Step 2',
        'Step 3',
        'Step 4',
        'Step 5',
        'Step 6',
      ];

      final recipe = RecipeModel(
        title: 'Detailed Recipe',
        summary: 'Has many steps',
        imageUrl: 'url',
        prepTime: '15',
        cookTime: '30',
        totalTime: '45',
        servings: 3,
        difficulty: 'Medium',
        nutrition: nutrition,
        ingredients: [],
        steps: steps,
      );

      expect(recipe.steps.length, equals(6));
      expect(recipe.steps[0], equals('Step 1'));
      expect(recipe.steps[5], equals('Step 6'));
    });
  });
}
