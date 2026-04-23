import 'package:flutter/material.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final _service = ShoppingListService();

  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);

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

  List<_ShoppingSection> _buildSections(List<ShoppingItem> items) {
    final recipeOrder = <String>[];
    final seenRecipeTitles = <String>{};

    for (final recipe in _service.recipes) {
      if (seenRecipeTitles.add(recipe.recipeTitle)) {
        recipeOrder.add(recipe.recipeTitle);
      }
    }

    for (final item in items) {
      for (final recipeTitle in item.recipeTitles) {
        if (seenRecipeTitles.add(recipeTitle)) {
          recipeOrder.add(recipeTitle);
        }
      }
    }

    final recipeItemMap = <String, List<ShoppingItem>>{};
    final commonItems = <ShoppingItem>[];
    final otherItems = <ShoppingItem>[];

    for (final item in items) {
      final matchedRecipes = recipeOrder
          .where((t) => item.recipeTitles.contains(t))
          .toList();

      if (matchedRecipes.length > 1) {
        commonItems.add(item);
      } else if (matchedRecipes.length == 1) {
        recipeItemMap.putIfAbsent(matchedRecipes.first, () => []).add(item);
      } else {
        otherItems.add(item);
      }
    }

    final sections = <_ShoppingSection>[];

    if (commonItems.isNotEmpty) {
      commonItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      sections.add(_ShoppingSection(
        title: 'Common ingredients',
        subtitle: 'Used in more than one recipe',
        items: commonItems,
        accent: _brandGreen,
        filled: true,
      ));
    }

    for (final recipe in _service.recipes) {
      final recipeItems = recipeItemMap[recipe.recipeTitle];
      if (recipeItems == null || recipeItems.isEmpty) continue;
      recipeItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      sections.add(_ShoppingSection(
        title: recipe.recipeTitle,
        subtitle:
            '${recipeItems.length} ingredient${recipeItems.length == 1 ? '' : 's'}',
        items: recipeItems,
        accent: _brandGreen,
      ));
    }

    if (otherItems.isNotEmpty) {
      otherItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      sections.add(_ShoppingSection(
        title: 'Other ingredients',
        subtitle: 'Added without a recipe reference',
        items: otherItems,
        accent: const Color(0xFF4E8A2B),
      ));
    }

    return sections;
  }

  void _confirmClearList() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Shopping List'),
        content: const Text(
            'This will remove all ingredients and recipes from your list. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _service.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shopping list cleared.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _service.items;
    final hasRecipes = _service.recipes.isNotEmpty;
    final sections = _buildSections(items);

    final hasItems = items.isNotEmpty || hasRecipes;

    return NavBarScaffold(
      title: 'Shopping List',
      actions: [
        if (hasItems)
          TextButton.icon(
            onPressed: _confirmClearList,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            label: const Text('Clear List',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
      ],
      body: ColoredBox(
        color: _surfaceGreen,
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty && !hasRecipes
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Your shopping list is empty',
                            style:
                                TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add ingredients from a recipe to get started.',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: sections.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ShoppingSectionCard(
                          section: sections[i],
                          brandGreen: _brandGreen,
                          onRemoveItem: (item) =>
                              _service.removeItem(item.id),
                          onDecreaseQuantity: (item) => _service
                              .updateQuantity(item.id, item.quantity - 1),
                          onIncreaseQuantity: (item) => _service
                              .updateQuantity(item.id, item.quantity + 1),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingSection {
  final String title;
  final String subtitle;
  final List<ShoppingItem> items;
  final Color accent;
  final bool filled;

  const _ShoppingSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.accent,
    this.filled = false,
  });
}

class _ShoppingSectionCard extends StatelessWidget {
  final _ShoppingSection section;
  final Color brandGreen;
  final ValueChanged<ShoppingItem> onRemoveItem;
  final ValueChanged<ShoppingItem> onDecreaseQuantity;
  final ValueChanged<ShoppingItem> onIncreaseQuantity;

  const _ShoppingSectionCard({
    required this.section,
    required this.brandGreen,
    required this.onRemoveItem,
    required this.onDecreaseQuantity,
    required this.onIncreaseQuantity,
  });

  Widget _buildItemRow(ShoppingItem item) {
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF333333)),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.remove,
                onTap: () => onDecreaseQuantity(item),
              ),
              SizedBox(
                width: 34,
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
                onTap: () => onIncreaseQuantity(item),
                backgroundColor: const Color(0xFFE4F2DE),
                iconColor: const Color(0xFF3C7E2A),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFF7D7D7D)),
                onPressed: () => onRemoveItem(item),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: section.filled
              ? section.accent.withOpacity(0.18)
              : const Color(0xFFE7EEE2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: section.filled
                    ? [const Color(0xFF7FCB57), const Color(0xFFEAF7E5)]
                    : [const Color(0xFFF1FAEC), Colors.white],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    section.filled
                        ? Icons.star_rounded
                        : Icons.restaurant_rounded,
                    color: brandGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24421A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        section.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F7559),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${section.items.length}',
                    style: TextStyle(
                      color: brandGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...section.items.map(_buildItemRow),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor = const Color(0xFFF0F0F0),
    this.iconColor = const Color(0xFF555555),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}
