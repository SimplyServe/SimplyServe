import 'package:flutter/foundation.dart';
import 'package:simplyserve/recipe_page.dart';

class LoggedMeal {
  final String recipeTitle;
  final int servings;
  final int caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatsPerServing;

  const LoggedMeal({
    required this.recipeTitle,
    required this.servings,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatsPerServing,
  });

  LoggedMeal copyWith({int? servings}) {
    return LoggedMeal(
      recipeTitle: recipeTitle,
      servings: servings ?? this.servings,
      caloriesPerServing: caloriesPerServing,
      proteinPerServing: proteinPerServing,
      carbsPerServing: carbsPerServing,
      fatsPerServing: fatsPerServing,
    );
  }

  factory LoggedMeal.fromRecipe({
    required RecipeModel recipe,
    required int servings,
  }) {
    return LoggedMeal(
      recipeTitle: recipe.title,
      servings: servings,
      caloriesPerServing: recipe.nutrition.calories,
      proteinPerServing: _parseNumber(recipe.nutrition.protein),
      carbsPerServing: _parseNumber(recipe.nutrition.carbs),
      fatsPerServing: _parseNumber(recipe.nutrition.fats),
    );
  }

  static double _parseNumber(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

class DailyNutritionTotals {
  final int totalRecipes;
  final int totalServings;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  const DailyNutritionTotals({
    required this.totalRecipes,
    required this.totalServings,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  bool get hasData => totalServings > 0;
}

class MealLogService extends ChangeNotifier {
  static final MealLogService _instance = MealLogService._internal();
  factory MealLogService() => _instance;
  MealLogService._internal();

  final Map<String, List<LoggedMeal>> _mealsByDay = {};

  String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<LoggedMeal> mealsForDay(DateTime date) {
    final key = dayKey(date);
    return List.unmodifiable(_mealsByDay[key] ?? const <LoggedMeal>[]);
  }

  int servingsForRecipe(DateTime date, String recipeTitle) {
    final meals = mealsForDay(date);
    final index = meals.indexWhere((meal) => meal.recipeTitle == recipeTitle);
    if (index == -1) {
      return 0;
    }
    return meals[index].servings;
  }

  void setServings({
    required DateTime date,
    required RecipeModel recipe,
    required int servings,
  }) {
    final key = dayKey(date);
    final meals =
        List<LoggedMeal>.from(_mealsByDay[key] ?? const <LoggedMeal>[]);
    final index = meals.indexWhere((meal) => meal.recipeTitle == recipe.title);

    if (servings <= 0) {
      if (index >= 0) {
        meals.removeAt(index);
      }
    } else {
      final updated = LoggedMeal.fromRecipe(recipe: recipe, servings: servings);
      if (index >= 0) {
        meals[index] = updated;
      } else {
        meals.add(updated);
      }
    }

    if (meals.isEmpty) {
      _mealsByDay.remove(key);
    } else {
      _mealsByDay[key] = meals;
    }

    notifyListeners();
  }

  void clearDay(DateTime date) {
    final key = dayKey(date);
    if (_mealsByDay.remove(key) != null) {
      notifyListeners();
    }
  }

  void removeMeal(DateTime date, String recipeTitle) {
    final key = dayKey(date);
    final meals =
        List<LoggedMeal>.from(_mealsByDay[key] ?? const <LoggedMeal>[]);
    final index = meals.indexWhere((meal) => meal.recipeTitle == recipeTitle);

    if (index == -1) {
      return;
    }

    meals.removeAt(index);

    if (meals.isEmpty) {
      _mealsByDay.remove(key);
    } else {
      _mealsByDay[key] = meals;
    }

    notifyListeners();
  }

  void addMeal({required DateTime date, required LoggedMeal meal}) {
    final key = dayKey(date);
    final meals =
        List<LoggedMeal>.from(_mealsByDay[key] ?? const <LoggedMeal>[]);
    final index =
        meals.indexWhere((m) => m.recipeTitle == meal.recipeTitle);

    if (index >= 0) {
      meals[index] = meals[index].copyWith(
        servings: meals[index].servings + meal.servings,
      );
    } else {
      meals.add(meal);
    }

    _mealsByDay[key] = meals;
    notifyListeners();
  }

  DailyNutritionTotals totalsForDay(DateTime date) {
    final meals = mealsForDay(date);
    var totalServings = 0;
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fats = 0.0;

    for (final meal in meals) {
      totalServings += meal.servings;
      calories += meal.caloriesPerServing * meal.servings;
      protein += meal.proteinPerServing * meal.servings;
      carbs += meal.carbsPerServing * meal.servings;
      fats += meal.fatsPerServing * meal.servings;
    }

    return DailyNutritionTotals(
      totalRecipes: meals.length,
      totalServings: totalServings,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }
}
