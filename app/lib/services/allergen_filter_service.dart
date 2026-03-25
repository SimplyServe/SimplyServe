import 'package:simplyserve/recipe_page.dart';

class AllergenFilterService {
  static bool recipeContainsAnyAllergen(
    RecipeModel recipe,
    List<String> allergies,
  ) {
    if (allergies.isEmpty) {
      return false;
    }

    final ingredientText = recipe.ingredients
        .map((ingredient) => ingredient.name.toLowerCase())
        .join(' ');

    for (final allergy in allergies) {
      final needle = allergy.trim().toLowerCase();
      if (needle.isEmpty) {
        continue;
      }

      if (ingredientText.contains(needle)) {
        return true;
      }
    }

    return false;
  }

  static List<RecipeModel> hiddenRecipes(
    List<RecipeModel> recipes,
    List<String> allergies,
  ) {
    return recipes
        .where((recipe) => recipeContainsAnyAllergen(recipe, allergies))
        .toList();
  }
}
