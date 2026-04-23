import 'package:flutter/material.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final _service = ShoppingListService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _logMealsToDashboard() {
    final mealLogService = MealLogService();
    final today = DateTime.now();

    for (final recipe in _service.recipes) {
      mealLogService.addMeal(
        date: today,
        meal: LoggedMeal(
          recipeTitle: recipe.recipeTitle,
          servings: 1,
          caloriesPerServing: recipe.caloriesPerServing,
          proteinPerServing: recipe.proteinPerServing,
          carbsPerServing: recipe.carbsPerServing,
          fatsPerServing: recipe.fatsPerServing,
        ),
      );
    }

    _service.clearRecipes();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meals logged to dashboard!'),
        backgroundColor: Color(0xFF74BC42),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isCommon = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF74BC42),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          if (isCommon) ...[
            const Icon(Icons.layers, size: 16, color: Color(0xFF74BC42)),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCommon
                  ? const Color(0xFF74BC42)
                  : const Color(0xFF555555),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShoppingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            left: BorderSide(color: Color(0xFF74BC42), width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () =>
                      _service.updateQuantity(item.id, item.quantity - 1),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () =>
                      _service.updateQuantity(item.id, item.quantity + 1),
                ),
              ],
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _service.removeItem(item.id),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _service.items;
    final hasRecipes = _service.recipes.isNotEmpty;

    // Partition items into sections
    final commonItems = <ShoppingItem>[];
    final Map<String, List<ShoppingItem>> perRecipe = {};
    final otherItems = <ShoppingItem>[];

    for (final item in items) {
      if (item.recipeTitles.length > 1) {
        commonItems.add(item);
      } else if (item.recipeTitles.length == 1) {
        perRecipe
            .putIfAbsent(item.recipeTitles.first, () => [])
            .add(item);
      } else {
        otherItems.add(item);
      }
    }

    final hasSections = commonItems.isNotEmpty ||
        perRecipe.isNotEmpty ||
        otherItems.isNotEmpty;

    // Build flat list of widgets
    final listWidgets = <Widget>[];

    if (commonItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Common Ingredients', isCommon: true));
      listWidgets.addAll(commonItems.map(_buildItemCard));
    }

    for (final entry in perRecipe.entries) {
      listWidgets.add(_buildSectionHeader(entry.key));
      listWidgets.addAll(entry.value.map(_buildItemCard));
    }

    if (otherItems.isNotEmpty) {
      if (commonItems.isNotEmpty || perRecipe.isNotEmpty) {
        listWidgets.add(_buildSectionHeader('Other'));
      }
      listWidgets.addAll(otherItems.map(_buildItemCard));
    }

    return NavBarScaffold(
      title: 'Shopping List',
      body: Column(
        children: [
          if (hasRecipes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                color: const Color(0xFFE8F5E9),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant, color: Color(0xFF74BC42)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_service.recipes.length} recipe(s) ready to log',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _logMealsToDashboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74BC42),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Log Meals'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: !hasSections && !hasRecipes
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Your shopping list is empty',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add ingredients from a recipe to get started.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: listWidgets,
                  ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF555555)),
      ),
    );
  }
}
