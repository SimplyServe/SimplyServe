import 'package:flutter/foundation.dart';

class ShoppingItem {
  static int _counter = 0;
  final String id;
  String name;
  int quantity;
  final Set<String> recipeTitles;

  ShoppingItem({
    required this.name,
    this.quantity = 1,
    Set<String>? recipeTitles,
  })  : recipeTitles = recipeTitles ?? <String>{},
        id = '${_counter++}';
}

class ShoppingRecipeEntry {
  final String recipeTitle;
  final int caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatsPerServing;

  const ShoppingRecipeEntry({
    required this.recipeTitle,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatsPerServing,
  });
}

class ShoppingListService extends ChangeNotifier {
  static final ShoppingListService _instance = ShoppingListService._internal();
  factory ShoppingListService() => _instance;
  ShoppingListService._internal();

  final List<ShoppingItem> _items = [];
  List<ShoppingItem> get items => List.unmodifiable(_items);

  final List<ShoppingRecipeEntry> _recipes = [];
  List<ShoppingRecipeEntry> get recipes => List.unmodifiable(_recipes);

  String _normalizeName(String rawName) {
    final trimmed = rawName.trim();
    // Remove leading quantity/unit prefixes such as "1 pcs onion".
    final withoutPrefix = trimmed.replaceFirst(
      RegExp(r'^\d+(?:\.\d+)?\s+[A-Za-z]+\s+'),
      '',
    );
    return withoutPrefix.trim();
  }

  void addIngredients(List<String> ingredients, {String? recipeTitle}) {
    final normalizedRecipeTitle = recipeTitle?.trim();
    for (final rawName in ingredients) {
      final name = _normalizeName(rawName);
      if (name.isEmpty) {
        continue;
      }

      final index = _items.indexWhere(
        (i) => i.name.toLowerCase() == name.toLowerCase(),
      );
      if (index != -1) {
        _items[index].quantity++;
        if (normalizedRecipeTitle != null && normalizedRecipeTitle.isNotEmpty) {
          _items[index].recipeTitles.add(normalizedRecipeTitle);
        }
      } else {
        _items.add(
          ShoppingItem(
            name: name,
            recipeTitles:
                normalizedRecipeTitle == null || normalizedRecipeTitle.isEmpty
                    ? <String>{}
                    : {normalizedRecipeTitle},
          ),
        );
      }
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeItem(id);
      return;
    }
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void addRecipe(ShoppingRecipeEntry entry) {
    final exists = _recipes.any(
      (r) => r.recipeTitle.toLowerCase() == entry.recipeTitle.toLowerCase(),
    );
    if (!exists) {
      _recipes.add(entry);
      notifyListeners();
    }
  }

  void clearRecipes() {
    if (_recipes.isNotEmpty) {
      _recipes.clear();
      notifyListeners();
    }
  }
}
