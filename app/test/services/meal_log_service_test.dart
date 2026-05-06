import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/recipe_page.dart';

void main() {
  group('LoggedMeal', () {
    test('stores all nutrition fields', () {
      const meal = LoggedMeal(
        recipeTitle: 'Pasta',
        servings: 2,
        caloriesPerServing: 400,
        proteinPerServing: 20,
        carbsPerServing: 50,
        fatsPerServing: 15,
      );

      expect(meal.recipeTitle, equals('Pasta'));
      expect(meal.servings, equals(2));
      expect(meal.caloriesPerServing, equals(400));
      expect(meal.proteinPerServing, equals(20));
      expect(meal.carbsPerServing, equals(50));
      expect(meal.fatsPerServing, equals(15));
    });

    test('copyWith updates servings only', () {
      const original = LoggedMeal(
        recipeTitle: 'Salad',
        servings: 1,
        caloriesPerServing: 200,
        proteinPerServing: 10,
        carbsPerServing: 25,
        fatsPerServing: 8,
      );

      final updated = original.copyWith(servings: 3);

      expect(updated.servings, equals(3));
      expect(updated.recipeTitle, equals('Salad'));
      expect(updated.caloriesPerServing, equals(200));
    });

    test('copyWith without arguments preserves original', () {
      const original = LoggedMeal(
        recipeTitle: 'Soup',
        servings: 2,
        caloriesPerServing: 150,
        proteinPerServing: 8,
        carbsPerServing: 20,
        fatsPerServing: 5,
      );

      final copy = original.copyWith();
      expect(copy.servings, equals(2));
      expect(copy.recipeTitle, equals('Soup'));
    });

    test('fromRecipe parses nutrition strings correctly', () {
      const recipe = RecipeModel(
        title: 'Test Recipe',
        summary: 'Test',
        imageUrl: '',
        prepTime: '10 min',
        cookTime: '20 min',
        totalTime: '30 min',
        servings: 2,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 300,
          protein: '25g',
          carbs: '40g',
          fats: '12g',
        ),
        ingredients: [],
        steps: [],
      );

      final meal = LoggedMeal.fromRecipe(recipe: recipe, servings: 3);

      expect(meal.recipeTitle, equals('Test Recipe'));
      expect(meal.servings, equals(3));
      expect(meal.caloriesPerServing, equals(300));
      expect(meal.proteinPerServing, closeTo(25, 0.01));
      expect(meal.carbsPerServing, closeTo(40, 0.01));
      expect(meal.fatsPerServing, closeTo(12, 0.01));
    });

    test('fromRecipe handles nutrition strings without units', () {
      const recipe = RecipeModel(
        title: 'Plain',
        summary: '',
        imageUrl: '',
        prepTime: '',
        cookTime: '',
        totalTime: '',
        servings: 1,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 100,
          protein: '10',
          carbs: '15',
          fats: '5',
        ),
        ingredients: [],
        steps: [],
      );

      final meal = LoggedMeal.fromRecipe(recipe: recipe, servings: 1);
      expect(meal.proteinPerServing, closeTo(10, 0.01));
      expect(meal.carbsPerServing, closeTo(15, 0.01));
      expect(meal.fatsPerServing, closeTo(5, 0.01));
    });

    test('fromRecipe handles non-numeric nutrition gracefully', () {
      const recipe = RecipeModel(
        title: 'Bad Data',
        summary: '',
        imageUrl: '',
        prepTime: '',
        cookTime: '',
        totalTime: '',
        servings: 1,
        difficulty: 'Easy',
        nutrition: NutritionInfo(
          calories: 0,
          protein: 'N/A',
          carbs: 'unknown',
          fats: '',
        ),
        ingredients: [],
        steps: [],
      );

      final meal = LoggedMeal.fromRecipe(recipe: recipe, servings: 1);
      expect(meal.proteinPerServing, equals(0));
      expect(meal.carbsPerServing, equals(0));
      expect(meal.fatsPerServing, equals(0));
    });
  });

  group('DailyNutritionTotals', () {
    test('hasData returns true when totalServings > 0', () {
      const totals = DailyNutritionTotals(
        totalRecipes: 1,
        totalServings: 2,
        calories: 400,
        protein: 20,
        carbs: 50,
        fats: 15,
      );
      expect(totals.hasData, isTrue);
    });

    test('hasData returns false when totalServings is 0', () {
      const totals = DailyNutritionTotals(
        totalRecipes: 0,
        totalServings: 0,
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
      );
      expect(totals.hasData, isFalse);
    });
  });

  group('MealLogService', () {
    late MealLogService service;

    setUp(() {
      service = MealLogService();
    });

    group('dayKey', () {
      test('formats date with zero-padded month and day', () {
        expect(service.dayKey(DateTime(2026, 1, 5)), equals('2026-01-05'));
        expect(service.dayKey(DateTime(2026, 12, 31)), equals('2026-12-31'));
      });
    });

    group('mealsForDay / setServings', () {
      final testDate = DateTime(2099, 1, 1);

      setUp(() {
        service.clearDay(testDate);
      });

      test('returns empty list for day with no meals', () {
        final meals = service.mealsForDay(DateTime(2099, 6, 15));
        expect(meals, isEmpty);
      });

      test('adds a meal via setServings', () {
        const recipe = RecipeModel(
          title: 'Omelette',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 250,
            protein: '18g',
            carbs: '2g',
            fats: '20g',
          ),
          ingredients: [],
          steps: [],
        );

        service.setServings(date: testDate, recipe: recipe, servings: 2);

        final meals = service.mealsForDay(testDate);
        expect(meals.length, equals(1));
        expect(meals.first.recipeTitle, equals('Omelette'));
        expect(meals.first.servings, equals(2));
      });

      test('updates servings for existing meal', () {
        const recipe = RecipeModel(
          title: 'UpdateTest',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 100, protein: '10g', carbs: '10g', fats: '5g',
          ),
          ingredients: [],
          steps: [],
        );

        final date = DateTime(2099, 2, 1);
        service.clearDay(date);

        service.setServings(date: date, recipe: recipe, servings: 1);
        service.setServings(date: date, recipe: recipe, servings: 4);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(1));
        expect(meals.first.servings, equals(4));
      });

      test('removes meal when servings set to 0', () {
        const recipe = RecipeModel(
          title: 'RemoveTest',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 100, protein: '10g', carbs: '10g', fats: '5g',
          ),
          ingredients: [],
          steps: [],
        );

        final date = DateTime(2099, 3, 1);
        service.clearDay(date);

        service.setServings(date: date, recipe: recipe, servings: 2);
        service.setServings(date: date, recipe: recipe, servings: 0);

        expect(service.mealsForDay(date), isEmpty);
      });

      test('removes meal when servings set to negative', () {
        const recipe = RecipeModel(
          title: 'NegTest',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 100, protein: '10g', carbs: '10g', fats: '5g',
          ),
          ingredients: [],
          steps: [],
        );

        final date = DateTime(2099, 4, 1);
        service.clearDay(date);

        service.setServings(date: date, recipe: recipe, servings: 3);
        service.setServings(date: date, recipe: recipe, servings: -1);

        expect(service.mealsForDay(date), isEmpty);
      });
    });

    group('servingsForRecipe', () {
      test('returns 0 when recipe not logged', () {
        final date = DateTime(2099, 5, 1);
        service.clearDay(date);
        expect(service.servingsForRecipe(date, 'Nonexistent'), equals(0));
      });

      test('returns correct servings for logged recipe', () {
        const recipe = RecipeModel(
          title: 'ServingsCheck',
          summary: '',
          imageUrl: '',
          prepTime: '',
          cookTime: '',
          totalTime: '',
          servings: 1,
          difficulty: 'Easy',
          nutrition: NutritionInfo(
            calories: 100, protein: '10g', carbs: '10g', fats: '5g',
          ),
          ingredients: [],
          steps: [],
        );

        final date = DateTime(2099, 5, 2);
        service.clearDay(date);

        service.setServings(date: date, recipe: recipe, servings: 5);
        expect(service.servingsForRecipe(date, 'ServingsCheck'), equals(5));
      });
    });

    group('addMeal', () {
      test('adds new meal to empty day', () {
        final date = DateTime(2099, 6, 1);
        service.clearDay(date);

        const meal = LoggedMeal(
          recipeTitle: 'AddTest',
          servings: 2,
          caloriesPerServing: 300,
          proteinPerServing: 20,
          carbsPerServing: 30,
          fatsPerServing: 10,
        );

        service.addMeal(date: date, meal: meal);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(1));
        expect(meals.first.servings, equals(2));
      });

      test('merges servings when same recipe added again', () {
        final date = DateTime(2099, 6, 2);
        service.clearDay(date);

        const meal = LoggedMeal(
          recipeTitle: 'MergeTest',
          servings: 2,
          caloriesPerServing: 300,
          proteinPerServing: 20,
          carbsPerServing: 30,
          fatsPerServing: 10,
        );

        service.addMeal(date: date, meal: meal);
        service.addMeal(date: date, meal: meal);

        final meals = service.mealsForDay(date);
        expect(meals.length, equals(1));
        expect(meals.first.servings, equals(4));
      });
    });

    group('removeMeal', () {
      test('removes meal by recipe title', () {
        final date = DateTime(2099, 7, 1);
        service.clearDay(date);

        const meal = LoggedMeal(
          recipeTitle: 'RemoveMealTest',
          servings: 1,
          caloriesPerServing: 200,
          proteinPerServing: 10,
          carbsPerServing: 20,
          fatsPerServing: 8,
        );

        service.addMeal(date: date, meal: meal);
        service.removeMeal(date, 'RemoveMealTest');

        expect(service.mealsForDay(date), isEmpty);
      });

      test('does nothing when removing nonexistent meal', () {
        final date = DateTime(2099, 7, 2);
        service.clearDay(date);

        const meal = LoggedMeal(
          recipeTitle: 'KeepMe',
          servings: 1,
          caloriesPerServing: 200,
          proteinPerServing: 10,
          carbsPerServing: 20,
          fatsPerServing: 8,
        );

        service.addMeal(date: date, meal: meal);
        service.removeMeal(date, 'Nonexistent');

        expect(service.mealsForDay(date).length, equals(1));
      });
    });

    group('clearDay', () {
      test('removes all meals for the given date', () {
        final date = DateTime(2099, 8, 1);
        service.clearDay(date);

        service.addMeal(
          date: date,
          meal: const LoggedMeal(
            recipeTitle: 'A',
            servings: 1,
            caloriesPerServing: 100,
            proteinPerServing: 5,
            carbsPerServing: 10,
            fatsPerServing: 3,
          ),
        );
        service.addMeal(
          date: date,
          meal: const LoggedMeal(
            recipeTitle: 'B',
            servings: 2,
            caloriesPerServing: 200,
            proteinPerServing: 10,
            carbsPerServing: 20,
            fatsPerServing: 8,
          ),
        );

        service.clearDay(date);
        expect(service.mealsForDay(date), isEmpty);
      });
    });

    group('totalsForDay', () {
      test('returns zero totals for empty day', () {
        final date = DateTime(2099, 9, 1);
        service.clearDay(date);

        final totals = service.totalsForDay(date);
        expect(totals.totalRecipes, equals(0));
        expect(totals.totalServings, equals(0));
        expect(totals.calories, equals(0));
        expect(totals.protein, equals(0));
        expect(totals.carbs, equals(0));
        expect(totals.fats, equals(0));
        expect(totals.hasData, isFalse);
      });

      test('calculates totals correctly for multiple meals', () {
        final date = DateTime(2099, 9, 2);
        service.clearDay(date);

        service.addMeal(
          date: date,
          meal: const LoggedMeal(
            recipeTitle: 'Meal1',
            servings: 2,
            caloriesPerServing: 300,
            proteinPerServing: 20,
            carbsPerServing: 40,
            fatsPerServing: 10,
          ),
        );
        service.addMeal(
          date: date,
          meal: const LoggedMeal(
            recipeTitle: 'Meal2',
            servings: 1,
            caloriesPerServing: 500,
            proteinPerServing: 30,
            carbsPerServing: 60,
            fatsPerServing: 20,
          ),
        );

        final totals = service.totalsForDay(date);

        expect(totals.totalRecipes, equals(2));
        expect(totals.totalServings, equals(3));
        // 300*2 + 500*1 = 1100
        expect(totals.calories, closeTo(1100, 0.01));
        // 20*2 + 30*1 = 70
        expect(totals.protein, closeTo(70, 0.01));
        // 40*2 + 60*1 = 140
        expect(totals.carbs, closeTo(140, 0.01));
        // 10*2 + 20*1 = 40
        expect(totals.fats, closeTo(40, 0.01));
        expect(totals.hasData, isTrue);
      });
    });

    group('hasAnyMeals', () {
      test('returns true when meals exist', () {
        final date = DateTime(2099, 10, 1);
        service.clearDay(date);

        service.addMeal(
          date: date,
          meal: const LoggedMeal(
            recipeTitle: 'HasMeals',
            servings: 1,
            caloriesPerServing: 100,
            proteinPerServing: 5,
            carbsPerServing: 10,
            fatsPerServing: 3,
          ),
        );

        expect(service.hasAnyMeals, isTrue);
      });
    });
  });
}
