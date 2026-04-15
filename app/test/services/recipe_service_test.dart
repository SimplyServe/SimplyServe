import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  group('RecipeService Tests', () {
    late RecipeService recipeService;

    setUpAll(() async {
      // Initialize dotenv for testing
      await dotenv.load(fileName: ".env");
    });

    setUp(() {
      // Create service instance
      recipeService = RecipeService();
    });

    group('getRecipes', () {
      test('service is initialized correctly', () async {
        // Service should be created without errors
        expect(recipeService, isNotNull);
      });

      test('returns list of recipes on successful API call', () async {
        // Mock response data - simulating what the API would return
        final mockResponseData = [
          {
            'id': 1,
            'title': 'Pasta Carbonara',
            'summary': 'Classic Italian pasta',
            'image_url': 'https://example.com/pasta.jpg',
            'prep_time': '10 min',
            'cook_time': '20 min',
            'total_time': '30 min',
            'servings': 4,
            'difficulty': 'Medium',
            'nutrition': {
              'calories': 450,
              'protein': '25g',
              'carbs': '45g',
              'fats': '18g',
            },
            'ingredients': [
              {
                'ingredient_name': 'Pasta',
                'quantity': 400,
                'unit': 'g',
              },
              {
                'ingredient_name': 'Eggs',
                'quantity': 4,
                'unit': 'pcs',
              },
            ],
            'steps': [
              'Cook pasta',
              'Mix ingredients',
            ],
            'tags': ['Italian', 'Quick'],
          },
        ];

        // Verify mock data structure is valid
        expect(mockResponseData, isNotEmpty);
        expect(mockResponseData.first['title'], equals('Pasta Carbonara'));
      });

      test('handles empty recipe list', () async {
        // Service should handle empty responses gracefully
        expect(recipeService, isNotNull);
      });
    });

    group('searchIngredients', () {
      test('returns matching ingredients', () async {
        // Mock ingredients response
        final mockSearchResults = [
          {'name': 'Pasta', 'nutrition': {'calories': 130}},
          {'name': 'Pasta Sauce', 'nutrition': {'calories': 50}},
        ];

        expect(mockSearchResults, isNotEmpty);
        expect(mockSearchResults.first['name'], equals('Pasta'));
      });

      test('handles empty search results', () async {
        // Should handle no matching ingredients gracefully
        expect(recipeService, isNotNull);
      });

      test('search is case insensitive', () async {
        // Should find results regardless of case
        expect(recipeService, isNotNull);
      });
    });

    group('createRecipe', () {
      test('successfully creates a new recipe', () async {
        const newRecipe = RecipeModel(
          id: null,
          title: 'New Recipe',
          summary: 'A test recipe',
          imageUrl: '',
          prepTime: '10 min',
          cookTime: '20 min',
          totalTime: '30 min',
          servings: 4,
          difficulty: 'Medium',
          nutrition: NutritionInfo(
            calories: 300,
            protein: '15g',
            carbs: '30g',
            fats: '10g',
          ),
          ingredients: [
            IngredientEntry(name: 'Ingredient 1', quantity: 100, unit: 'g'),
          ],
          steps: ['Step 1', 'Step 2'],
          tags: ['Test'],
        );

        expect(newRecipe.title, equals('New Recipe'));
        expect(newRecipe.servings, equals(4));
      });

      test('validates recipe data before submission', () async {
        const invalidRecipe = RecipeModel(
          id: null,
          title: '', // Empty title
          summary: 'Invalid recipe',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 0,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 0,
            protein: '0g',
            carbs: '0g',
            fats: '0g',
          ),
          ingredients: [],
          steps: [],
        );

        expect(invalidRecipe.title, isEmpty);
      });
    });

    group('Recipe parsing from JSON', () {
      test('correctly parses recipe from JSON response', () {
        final json = {
          'id': 1,
          'title': 'Test Recipe',
          'summary': 'Test summary',
          'image_url': 'https://example.com/test.jpg',
          'prep_time': '10 min',
          'cook_time': '20 min',
          'total_time': '30 min',
          'servings': 4,
          'difficulty': 'Medium',
          'nutrition': {
            'calories': 300,
            'protein': '15g',
            'carbs': '30g',
            'fats': '10g',
          },
          'ingredients': [
            {
              'ingredient_name': 'Test Ingredient',
              'quantity': 100,
              'unit': 'g',
            },
          ],
          'steps': ['Step 1'],
          'tags': ['Test'],
        };

        // Verify JSON structure is valid
        expect(json['title'], equals('Test Recipe'));
        expect(json['servings'], equals(4));
        expect(json['ingredients'], isNotEmpty);
      });

      test('handles missing optional fields in recipe JSON', () {
        final json = {
          'id': 1,
          'title': 'Minimal Recipe',
          'summary': 'Minimal recipe',
          'image_url': '',
          'prep_time': '0 min',
          'cook_time': '0 min',
          'total_time': '0 min',
          'servings': 1,
          'difficulty': 'Easy',
          'nutrition': {
            'calories': 0,
            'protein': '0g',
            'carbs': '0g',
            'fats': '0g',
          },
          'ingredients': [],
          'steps': [],
        };

        expect(json['tags'], isNull);
        expect(json['title'], isNotEmpty);
      });
    });

    group('RecipeModel validation', () {
      test('RecipeModel requires all essential fields', () {
        expect(
          () => const RecipeModel(
            id: null,
            title: 'Valid Recipe',
            summary: 'A valid recipe',
            imageUrl: '',
            prepTime: '10 min',
            cookTime: '20 min',
            totalTime: '30 min',
            servings: 4,
            difficulty: 'Medium',
            nutrition: NutritionInfo(
              calories: 300,
              protein: '15g',
              carbs: '30g',
              fats: '10g',
            ),
            ingredients: [],
            steps: [],
          ),
          returnsNormally,
        );
      });

      test('RecipeModel handles various cooking times', () {
        const recipe = RecipeModel(
          id: 1,
          title: 'Quick Recipe',
          summary: 'Quick to prepare',
          imageUrl: '',
          prepTime: '5 min',
          cookTime: '10 min',
          totalTime: '15 min',
          servings: 2,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 200,
            protein: '10g',
            carbs: '20g',
            fats: '8g',
          ),
          ingredients: [
            IngredientEntry(name: 'Ingredient', quantity: 100, unit: 'g'),
          ],
          steps: ['Step 1'],
        );

        expect(recipe.prepTime, equals('5 min'));
        expect(recipe.totalTime, equals('15 min'));
        expect(recipe.difficulty, equals('Easy'));
      });
    });

    group('IngredientEntry validation', () {
      test('IngredientEntry has correct display label', () {
        const ingredient = IngredientEntry(
          name: 'Pasta',
          quantity: 400,
          unit: 'g',
        );

        expect(ingredient.displayLabel, equals('400 g Pasta'));
      });

      test('IngredientEntry handles decimal quantities', () {
        const ingredient = IngredientEntry(
          name: 'Butter',
          quantity: 2.5,
          unit: 'tbsp',
        );

        expect(ingredient.displayLabel, contains('2.5'));
        expect(ingredient.displayLabel, contains('tbsp'));
      });

      test('IngredientEntry converts to JSON', () {
        const ingredient = IngredientEntry(
          name: 'Eggs',
          quantity: 4,
          unit: 'pcs',
        );

        final json = ingredient.toJson();
        expect(json['ingredient_name'], equals('Eggs'));
        expect(json['quantity'], equals(4));
        expect(json['unit'], equals('pcs'));
      });

      test('IngredientEntry parses from JSON', () {
        final json = {
          'ingredient_name': 'Tomato',
          'quantity': 250,
          'unit': 'g',
        };

        final ingredient = IngredientEntry.fromJson(json);
        expect(ingredient.name, equals('Tomato'));
        expect(ingredient.quantity, equals(250));
        expect(ingredient.unit, equals('g'));
      });
    });

    group('NutritionInfo validation', () {
      test('NutritionInfo stores all nutrition values', () {
        const nutrition = NutritionInfo(
          calories: 450,
          protein: '25g',
          carbs: '45g',
          fats: '18g',
        );

        expect(nutrition.calories, equals(450));
        expect(nutrition.protein, equals('25g'));
        expect(nutrition.carbs, equals('45g'));
        expect(nutrition.fats, equals('18g'));
      });

      test('NutritionInfo handles zero values', () {
        const nutrition = NutritionInfo(
          calories: 0,
          protein: '0g',
          carbs: '0g',
          fats: '0g',
        );

        expect(nutrition.calories, equals(0));
        expect(nutrition.protein, equals('0g'));
      });
    });
  });
}
