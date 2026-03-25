import 'package:flutter/foundation.dart';
import 'package:simplyserve/recipe_page.dart';

class PlannedMeal {
  final String recipeTitle;
  final int servings;

  const PlannedMeal({
    required this.recipeTitle,
    required this.servings,
  });
}

class MealPlanService extends ChangeNotifier {
  static final MealPlanService _instance = MealPlanService._internal();
  factory MealPlanService() => _instance;
  MealPlanService._internal();

  final Map<String, List<PlannedMeal>> _plansByDay = {};

  String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<PlannedMeal> mealsForDay(DateTime date) {
    final key = dayKey(date);
    return List.unmodifiable(_plansByDay[key] ?? const <PlannedMeal>[]);
  }

  void setServings({
    required DateTime date,
    required RecipeModel recipe,
    required int servings,
  }) {
    final key = dayKey(date);
    final plans =
        List<PlannedMeal>.from(_plansByDay[key] ?? const <PlannedMeal>[]);
    final index = plans.indexWhere((meal) => meal.recipeTitle == recipe.title);

    if (servings <= 0) {
      if (index >= 0) {
        plans.removeAt(index);
      }
    } else {
      final updated =
          PlannedMeal(recipeTitle: recipe.title, servings: servings);
      if (index >= 0) {
        plans[index] = updated;
      } else {
        plans.add(updated);
      }
    }

    if (plans.isEmpty) {
      _plansByDay.remove(key);
    } else {
      _plansByDay[key] = plans;
    }

    notifyListeners();
  }

  void clearDay(DateTime date) {
    final key = dayKey(date);
    if (_plansByDay.remove(key) != null) {
      notifyListeners();
    }
  }
}
