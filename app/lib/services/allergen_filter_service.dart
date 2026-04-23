import 'package:simplyserve/recipe_page.dart';

class AllergenFilterService {
  // Maps a user-facing allergen label to the ingredient keywords it covers.
  static const Map<String, List<String>> _synonyms = {
    'gluten': [
      'gluten', 'wheat', 'flour', 'bread', 'pasta', 'noodle', 'spaghetti',
      'penne', 'fettuccine', 'tagliatelle', 'lasagna', 'lasagne', 'couscous',
      'semolina', 'barley', 'rye', 'oat', 'crouton', 'breadcrumb', 'crumb',
      'bulgur', 'farro', 'spelt', 'malt', 'baguette', 'croissant', 'tortilla',
      'wrap', 'pita', 'chapati', 'naan', 'dumpling', 'gyoza', 'wonton',
      'seitan', 'panko',
    ],
    'dairy': [
      'dairy', 'milk', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt',
      'whey', 'casein', 'lactose', 'ghee', 'ricotta', 'mozzarella',
      'parmesan', 'cheddar', 'brie', 'feta', 'gouda', 'gruyere', 'halloumi',
      'custard', 'crème', 'creme', 'fraiche', 'sour cream', 'kefir',
    ],
    'eggs': [
      'egg', 'eggs', 'mayonnaise', 'mayo', 'meringue', 'albumin', 'omelette',
      'frittata', 'quiche', 'hollandaise', 'aioli',
    ],
    'peanuts': [
      'peanut', 'groundnut', 'peanut butter', 'peanut oil', 'satay',
    ],
    'tree nuts': [
      'almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'hazelnut',
      'macadamia', 'brazil nut', 'pine nut', 'chestnut', 'praline',
      'marzipan', 'nougat', 'nut',
    ],
    'fish': [
      'fish', 'salmon', 'tuna', 'cod', 'halibut', 'tilapia', 'bass',
      'anchovy', 'anchovies', 'sardine', 'mackerel', 'trout', 'catfish',
      'snapper', 'swordfish', 'flounder', 'haddock', 'pollock', 'herring',
      'worcestershire',
    ],
    'shellfish': [
      'shellfish', 'shrimp', 'prawn', 'crab', 'lobster', 'crayfish',
      'scallop', 'clam', 'oyster', 'mussel', 'squid', 'octopus', 'calamari',
    ],
    'soy': [
      'soy', 'soya', 'tofu', 'edamame', 'miso', 'tempeh', 'tamari',
      'soy sauce', 'soymilk',
    ],
    'sesame': [
      'sesame', 'tahini', 'sesame oil', 'sesame seed', 'hummus',
    ],
    'mustard': ['mustard'],
    'celery': ['celery', 'celeriac'],
    'sulphites': [
      'sulphite', 'sulfite', 'wine', 'vinegar', 'dried fruit',
    ],
    'lupin': ['lupin', 'lupine'],
  };

  // Returns every keyword to match for the given allergen label.
  static List<String> _expandAllergen(String allergen) {
    final key = allergen.trim().toLowerCase();
    // Check if the input matches any known synonym key.
    for (final entry in _synonyms.entries) {
      if (entry.key == key || entry.value.contains(key)) {
        return entry.value;
      }
    }
    // Unknown allergen — just match it literally.
    return [key];
  }

  static bool recipeContainsAnyAllergen(
    RecipeModel recipe,
    List<String> allergies,
  ) {
    if (allergies.isEmpty) return false;

    final ingredientText = recipe.ingredients
        .map((i) => i.name.toLowerCase())
        .join(' ');

    for (final allergy in allergies) {
      if (allergy.trim().isEmpty) continue;
      final keywords = _expandAllergen(allergy);
      if (keywords.any((kw) => ingredientText.contains(kw))) return true;
    }

    return false;
  }

  static List<RecipeModel> hiddenRecipes(
    List<RecipeModel> recipes,
    List<String> allergies,
  ) {
    return recipes
        .where((r) => recipeContainsAnyAllergen(r, allergies))
        .toList();
  }

  // Returns the canonical display label for a known allergen, or null.
  static String? canonicalLabel(String input) {
    final key = input.trim().toLowerCase();
    for (final entry in _synonyms.entries) {
      if (entry.key == key || entry.value.contains(key)) return entry.key;
    }
    return null;
  }

  static List<String> get knownAllergens => _synonyms.keys.toList();
}
