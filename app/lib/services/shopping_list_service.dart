import 'package:flutter/foundation.dart';

class ShoppingItem {
  static int _counter = 0;
  final String id;
  String name;
  int quantity;

  ShoppingItem({required this.name, this.quantity = 1}) : id = '${_counter++}';
}

class ShoppingListService extends ChangeNotifier {
  static final ShoppingListService _instance = ShoppingListService._internal();
  factory ShoppingListService() => _instance;
  ShoppingListService._internal();

  final List<ShoppingItem> _items = [];
  List<ShoppingItem> get items => List.unmodifiable(_items);

  String _normalizeName(String rawName) {
    final trimmed = rawName.trim();
    // Remove leading quantity/unit prefixes such as "1 pcs onion".
    final withoutPrefix = trimmed.replaceFirst(
      RegExp(r'^\d+(?:\.\d+)?\s+[A-Za-z]+\s+'),
      '',
    );
    return withoutPrefix.trim();
  }

  void addIngredients(List<String> ingredients) {
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
      } else {
        _items.add(ShoppingItem(name: name));
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
}
