import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';

class RecipeCatalogService {
  RecipeCatalogService({RecipeService? recipeService})
      : _recipeService = recipeService ?? RecipeService();

  final RecipeService _recipeService;

  Future<List<RecipeModel>> getAllRecipes() async {
    List<RecipeModel> apiRecipes = [];
    try {
      apiRecipes = await _recipeService.getRecipes();
    } catch (_) {}

    List<RecipeModel> localRecipes = [];
    try {
      final attrsJson =
          await rootBundle.loadString('assets/data/recipe_attributes.json');
      final ingredientsJson =
          await rootBundle.loadString('assets/data/recipe_ingredients.json');
      final stepsJson =
          await rootBundle.loadString('assets/data/recipe_steps.json');

      final attrs = json.decode(attrsJson) as Map<String, dynamic>;
      final ingredients = json.decode(ingredientsJson) as Map<String, dynamic>;
      final steps = json.decode(stepsJson) as Map<String, dynamic>;

      for (final entry in attrs.entries) {
        final title = entry.key;
        final a = entry.value as Map<String, dynamic>;
        final n = a['nutrition'] as Map<String, dynamic>? ?? {};

        localRecipes.add(
          RecipeModel(
            title: title,
            summary: a['summary'] ?? '',
            imageUrl: a['imageUrl'] ?? '',
            prepTime: a['prepTime'] ?? '',
            cookTime: a['cookTime'] ?? '',
            totalTime: a['totalTime'] ?? '',
            servings: a['servings'] ?? 1,
            difficulty: a['difficulty'] ?? 'Easy',
            nutrition: NutritionInfo(
              calories: n['calories'] ?? 0,
              protein: n['protein'] ?? '0g',
              carbs: n['carbs'] ?? '0g',
              fats: n['fats'] ?? '0g',
            ),
            ingredients: List<String>.from(ingredients[title] ?? [])
                .map(IngredientEntry.fromLegacy)
                .toList(),
            steps: List<String>.from(steps[title] ?? []),
            tags: List<String>.from(a['tags'] ?? []),
          ),
        );
      }
    } catch (_) {}

    // Local JSON recipes take precedence — seeded DB copies of the same title
    // are excluded so they don't appear as user-created recipes.
    final merged = <RecipeModel>[...localRecipes];
    for (final apiRecipe in apiRecipes) {
      if (!merged.any((recipe) => recipe.title == apiRecipe.title)) {
        merged.add(apiRecipe);
      }
    }

    return merged;
  }
}
