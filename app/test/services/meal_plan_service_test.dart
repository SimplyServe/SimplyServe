import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/meal_plan_service.dart';
import 'package:simplyserve/recipe_page.dart';

const _testRecipe = RecipeModel(
  title: 'Planned Recipe',
  summary: 'Test',
  imageUrl: '',
  prepTime: '10 min',
  cookTime: '20 min',
  totalTime: '30 min',
  servings: 2,
  difficulty: 'Easy',
  nutrition: NutritionInfo(
    calories: 350,
    protein: '20g',
    carbs: '40g',
    fats: '12g',
  ),
  ingredients: [],
  steps: [],
);

void main() {
  group('PlannedMeal', () {
    test('stores recipe title and servings', () {
      const meal = PlannedMeal(recipeTitle: 'Pasta', servings: 3);
      expect(meal.recipeTitle, equals('Pasta'));
      expect(meal.servings, equals(3));
    });
  });

  group('MealPlanService', () {
    late MealPlanService service;

    setUp(() {
      service = MealPlanService();
    });

    group('dayKey', () {
      test('formats date as YYYY-MM-DD', () {
        expect(service.dayKey(DateTime(2026, 3, 7)), equals('2026-03-07'));
        expect(service.dayKey(DateTime(2026, 11, 25)), equals('2026-11-25'));
      });
    });

    group('mealsForDay', () {
      test('returns empty list for unplanned day', () {
        final date = DateTime(2098, 1, 1);
        service.clearDay(date);
        expect(service.mealsForDay(date), isEmpty);
      });

      test('returns unmodifiable list', () {
        final date = DateTime(2098, 1, 2);
        service.clearDay(date);
        final meals = service.mealsForDay(date);
        expect(() => meals.add(const PlannedMeal(recipeTitle: 'x', servings: 1)),
            throwsA(isA<UnsupportedError>()));
      });
    });

    group('setServings', () {
      test('adds planned meal to empty day', () {
        final date = DateTime(2098, 2, 1);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 2);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(1));
        expect(meals.first.recipeTitle, equals('Planned Recipe'));
        expect(meals.first.servings, equals(2));
      });

      test('updates servings for existing planned meal', () {
        final date = DateTime(2098, 2, 2);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 1);
        service.setServings(date: date, recipe: _testRecipe, servings: 4);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(1));
        expect(meals.first.servings, equals(4));
      });

      test('removes planned meal when servings set to 0', () {
        final date = DateTime(2098, 2, 3);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 3);
        service.setServings(date: date, recipe: _testRecipe, servings: 0);

        expect(service.mealsForDay(date), isEmpty);
      });

      test('removes planned meal when servings set negative', () {
        final date = DateTime(2098, 2, 4);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 2);
        service.setServings(date: date, recipe: _testRecipe, servings: -1);

        expect(service.mealsForDay(date), isEmpty);
      });

      test('handles multiple different recipes on same day', () {
        final date = DateTime(2098, 2, 5);
        service.clearDay(date);

        const recipe2 = RecipeModel(
          title: 'Another Recipe',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 200, protein: '10g', carbs: '25g', fats: '8g',
          ),
          ingredients: [],
          steps: [],
        );

        service.setServings(date: date, recipe: _testRecipe, servings: 1);
        service.setServings(date: date, recipe: recipe2, servings: 2);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(2));
      });

      test('does nothing when removing non-existent recipe', () {
        final date = DateTime(2098, 2, 6);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 1);

        const otherRecipe = RecipeModel(
          title: 'Not Added',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 100, protein: '5g', carbs: '10g', fats: '3g',
          ),
          ingredients: [],
          steps: [],
        );

        service.setServings(date: date, recipe: otherRecipe, servings: 0);

        // Original meal should still be there
        expect(service.mealsForDay(date).length, equals(1));
      });
    });

    group('clearDay', () {
      test('removes all plans for a specific date', () {
        final date = DateTime(2098, 3, 1);
        service.clearDay(date);

        service.setServings(date: date, recipe: _testRecipe, servings: 2);
        service.clearDay(date);

        expect(service.mealsForDay(date), isEmpty);
      });

      test('does not affect other dates', () {
        final date1 = DateTime(2098, 3, 2);
        final date2 = DateTime(2098, 3, 3);
        service.clearDay(date1);
        service.clearDay(date2);

        service.setServings(date: date1, recipe: _testRecipe, servings: 1);
        service.setServings(date: date2, recipe: _testRecipe, servings: 2);

        service.clearDay(date1);

        expect(service.mealsForDay(date1), isEmpty);
        expect(service.mealsForDay(date2).length, equals(1));
      });
    });
  });
}
