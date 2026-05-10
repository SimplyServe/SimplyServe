import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/recipe_page.dart';

RecipeModel _recipe(String title, List<String> ingredientNames) {
  return RecipeModel(
    title: title,
    summary: '',
    imageUrl: '',
    prepTime: '',
    cookTime: '',
    totalTime: '',
    servings: 1,
    difficulty: 'Easy',
    nutrition: const NutritionInfo(
      calories: 100, protein: '5g', carbs: '10g', fats: '3g',
    ),
    ingredients: ingredientNames
        .map((n) => IngredientEntry(name: n, quantity: 1, unit: 'pcs'))
        .toList(),
    steps: [],
  );
}

void main() {
  group('AllergenFilterService', () {
    group('recipeContainsAnyAllergen', () {
      test('returns false when allergies list is empty', () {
        final recipe = _recipe('Pasta', ['pasta', 'tomato']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, []),
          isFalse,
        );
      });

      test('detects gluten allergen from wheat ingredient', () {
        final recipe = _recipe('Bread', ['wheat flour', 'water', 'yeast']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['gluten']),
          isTrue,
        );
      });

      test('detects dairy allergen from milk ingredient', () {
        final recipe = _recipe('Cereal', ['oats', 'milk', 'honey']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['dairy']),
          isTrue,
        );
      });

      test('detects egg allergen', () {
        final recipe = _recipe('Omelette', ['eggs', 'cheese', 'pepper']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['eggs']),
          isTrue,
        );
      });

      test('returns false when no allergens match', () {
        final recipe = _recipe('Salad', ['lettuce', 'tomato', 'cucumber']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['gluten', 'dairy']),
          isFalse,
        );
      });

      test('handles case-insensitive matching', () {
        final recipe = _recipe('Toast', ['Bread', 'Butter']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['Gluten']),
          isTrue,
        );
      });

      test('detects allergen from synonym (cheese -> dairy)', () {
        final recipe = _recipe('Pizza', ['dough', 'mozzarella', 'tomato sauce']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['dairy']),
          isTrue,
        );
      });

      test('detects peanut allergen', () {
        final recipe = _recipe('PB Sandwich', ['bread', 'peanut butter']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['peanuts']),
          isTrue,
        );
      });

      test('detects fish allergen from salmon', () {
        final recipe = _recipe('Sushi', ['rice', 'salmon', 'nori']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['fish']),
          isTrue,
        );
      });

      test('detects shellfish allergen from shrimp', () {
        final recipe = _recipe('Scampi', ['shrimp', 'garlic', 'butter']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['shellfish']),
          isTrue,
        );
      });

      test('detects soy allergen from tofu', () {
        final recipe = _recipe('Stir Fry', ['tofu', 'broccoli', 'rice']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['soy']),
          isTrue,
        );
      });

      test('detects sesame allergen from tahini', () {
        final recipe = _recipe('Hummus', ['chickpeas', 'tahini', 'lemon']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['sesame']),
          isTrue,
        );
      });

      test('skips empty/whitespace-only allergy entries', () {
        final recipe = _recipe('Rice Bowl', ['rice', 'vegetables']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['', '  ']),
          isFalse,
        );
      });

      test('detects tree nut allergen from almond', () {
        final recipe = _recipe('Trail Mix', ['almond', 'raisins', 'chocolate']);
        expect(
          AllergenFilterService.recipeContainsAnyAllergen(recipe, ['tree nuts']),
          isTrue,
        );
      });
    });

    group('hiddenRecipes', () {
      test('returns only recipes containing allergens', () {
        final recipes = [
          _recipe('Bread', ['wheat flour', 'water']),
          _recipe('Salad', ['lettuce', 'tomato']),
          _recipe('Cake', ['flour', 'eggs', 'sugar']),
        ];

        final hidden = AllergenFilterService.hiddenRecipes(recipes, ['gluten']);
        expect(hidden.length, equals(2));
        expect(hidden.map((r) => r.title), containsAll(['Bread', 'Cake']));
      });

      test('returns empty list when no recipes match allergens', () {
        final recipes = [
          _recipe('Salad', ['lettuce', 'tomato']),
          _recipe('Rice', ['rice', 'water']),
        ];

        final hidden = AllergenFilterService.hiddenRecipes(recipes, ['dairy']);
        expect(hidden, isEmpty);
      });

      test('returns empty list with no allergies', () {
        final recipes = [
          _recipe('Anything', ['flour', 'milk', 'eggs']),
        ];

        final hidden = AllergenFilterService.hiddenRecipes(recipes, []);
        expect(hidden, isEmpty);
      });
    });

    group('canonicalLabel', () {
      test('returns canonical label for known allergen', () {
        expect(AllergenFilterService.canonicalLabel('gluten'), equals('gluten'));
        expect(AllergenFilterService.canonicalLabel('dairy'), equals('dairy'));
      });

      test('returns canonical label for synonym', () {
        expect(AllergenFilterService.canonicalLabel('wheat'), equals('gluten'));
        expect(AllergenFilterService.canonicalLabel('milk'), equals('dairy'));
        expect(AllergenFilterService.canonicalLabel('tofu'), equals('soy'));
      });

      test('returns null for unknown allergen', () {
        expect(AllergenFilterService.canonicalLabel('strawberry'), isNull);
        expect(AllergenFilterService.canonicalLabel('chocolate'), isNull);
      });

      test('trims and lowercases input', () {
        expect(AllergenFilterService.canonicalLabel('  Gluten  '), equals('gluten'));
        expect(AllergenFilterService.canonicalLabel('DAIRY'), equals('dairy'));
      });
    });

    group('knownAllergens', () {
      test('returns list of allergen categories', () {
        final allergens = AllergenFilterService.knownAllergens;
        expect(allergens, contains('gluten'));
        expect(allergens, contains('dairy'));
        expect(allergens, contains('eggs'));
        expect(allergens, contains('peanuts'));
        expect(allergens, contains('tree nuts'));
        expect(allergens, contains('fish'));
        expect(allergens, contains('shellfish'));
        expect(allergens, contains('soy'));
        expect(allergens, contains('sesame'));
      });

      test('includes all 12 major allergen categories', () {
        final allergens = AllergenFilterService.knownAllergens;
        expect(allergens.length, greaterThanOrEqualTo(12));
      });
    });
  });
}
