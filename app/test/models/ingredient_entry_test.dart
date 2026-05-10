import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/recipe_page.dart';

void main() {
  group('IngredientEntry', () {
    group('constructor', () {
      test('stores name, quantity, and unit', () {
        const entry = IngredientEntry(name: 'Flour', quantity: 2, unit: 'cup');
        expect(entry.name, equals('Flour'));
        expect(entry.quantity, equals(2));
        expect(entry.unit, equals('cup'));
      });
    });

    group('displayLabel', () {
      test('returns name only for legacy ingredients (1 pcs)', () {
        const entry = IngredientEntry(name: '2 salmon fillets', quantity: 1, unit: 'pcs');
        expect(entry.displayLabel, equals('2 salmon fillets'));
      });

      test('formats quantity unit name for structured ingredients', () {
        const entry = IngredientEntry(name: 'flour', quantity: 2, unit: 'cup');
        expect(entry.displayLabel, equals('2 cup flour'));
      });

      test('shows integer quantity without decimals', () {
        const entry = IngredientEntry(name: 'sugar', quantity: 3, unit: 'tbsp');
        expect(entry.displayLabel, equals('3 tbsp sugar'));
      });

      test('shows fractional quantity with decimals', () {
        const entry = IngredientEntry(name: 'salt', quantity: 0.5, unit: 'tsp');
        expect(entry.displayLabel, equals('0.5 tsp salt'));
      });
    });

    group('toJson', () {
      test('produces correct JSON map', () {
        const entry = IngredientEntry(name: 'Egg', quantity: 2, unit: 'pcs');
        final json = entry.toJson();
        expect(json['ingredient_name'], equals('Egg'));
        expect(json['quantity'], equals(2));
        expect(json['unit'], equals('pcs'));
      });
    });

    group('fromJson', () {
      test('parses ingredient_name key', () {
        final entry = IngredientEntry.fromJson({
          'ingredient_name': 'Milk',
          'quantity': 1,
          'unit': 'cup',
        });
        expect(entry.name, equals('Milk'));
        expect(entry.quantity, equals(1));
        expect(entry.unit, equals('cup'));
      });

      test('falls back to name key', () {
        final entry = IngredientEntry.fromJson({
          'name': 'Butter',
          'quantity': 50,
          'unit': 'g',
        });
        expect(entry.name, equals('Butter'));
      });

      test('defaults quantity to 1 if missing', () {
        final entry = IngredientEntry.fromJson({'ingredient_name': 'Salt'});
        expect(entry.quantity, equals(1));
      });

      test('defaults unit to pcs if missing', () {
        final entry = IngredientEntry.fromJson({'ingredient_name': 'Egg'});
        expect(entry.unit, equals('pcs'));
      });

      test('handles empty map gracefully', () {
        final entry = IngredientEntry.fromJson({});
        expect(entry.name, equals(''));
        expect(entry.quantity, equals(1));
        expect(entry.unit, equals('pcs'));
      });

      test('converts integer quantity to double', () {
        final entry = IngredientEntry.fromJson({
          'ingredient_name': 'Rice',
          'quantity': 2,
          'unit': 'cup',
        });
        expect(entry.quantity, equals(2.0));
        expect(entry.quantity, isA<double>());
      });
    });

    group('fromLegacy', () {
      test('creates entry with default quantity and unit', () {
        final entry = IngredientEntry.fromLegacy('2 cups flour');
        expect(entry.name, equals('2 cups flour'));
        expect(entry.quantity, equals(1));
        expect(entry.unit, equals('pcs'));
      });
    });
  });

  group('NutritionInfo', () {
    test('stores all fields', () {
      const info = NutritionInfo(
        calories: 350,
        protein: '20g',
        carbs: '45g',
        fats: '12g',
      );
      expect(info.calories, equals(350));
      expect(info.protein, equals('20g'));
      expect(info.carbs, equals('45g'));
      expect(info.fats, equals('12g'));
    });
  });

  group('RecipeModel', () {
    test('stores all required fields', () {
      const recipe = RecipeModel(
        title: 'Test Recipe',
        summary: 'A test',
        imageUrl: 'http://example.com/img.png',
        prepTime: '10 min',
        cookTime: '20 min',
        totalTime: '30 min',
        servings: 4,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 300,
          protein: '15g',
          carbs: '40g',
          fats: '10g',
        ),
        ingredients: [],
        steps: ['Step 1', 'Step 2'],
      );

      expect(recipe.title, equals('Test Recipe'));
      expect(recipe.servings, equals(4));
      expect(recipe.steps.length, equals(2));
    });

    test('tags default to empty list', () {
      const recipe = RecipeModel(
        title: 'No Tags',
        summary: '',
        imageUrl: '',
        prepTime: '',
        cookTime: '',
        totalTime: '',
        servings: 1,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 0, protein: '0g', carbs: '0g', fats: '0g',
        ),
        ingredients: [],
        steps: [],
      );
      expect(recipe.tags, isEmpty);
    });

    test('id defaults to null', () {
      const recipe = RecipeModel(
        title: 'No ID',
        summary: '',
        imageUrl: '',
        prepTime: '',
        cookTime: '',
        totalTime: '',
        servings: 1,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 0, protein: '0g', carbs: '0g', fats: '0g',
        ),
        ingredients: [],
        steps: [],
      );
      expect(recipe.id, isNull);
    });

    test('id can be set', () {
      const recipe = RecipeModel(
        title: 'With ID',
        summary: '',
        imageUrl: '',
        prepTime: '',
        cookTime: '',
        totalTime: '',
        servings: 1,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 0, protein: '0g', carbs: '0g', fats: '0g',
        ),
        ingredients: [],
        steps: [],
        id: 42,
      );
      expect(recipe.id, equals(42));
    });
  });
}
