// ignore_for_file: prefer_const_constructors

// ============================================================
// views/shopping_list.dart — Shopping List View
//
// Displays the user's current shopping list, grouped into
// meaningful sections for easy scanning at the supermarket:
//
//   • "Common ingredients" — items that appear in ≥ 2 recipes.
//     Shown first with a starred gradient header.
//   • Per-recipe sections — items tied to exactly one recipe,
//     ordered by the recipe's planned date (soonest first).
//   • "Other ingredients" — items added manually or without a
//     recipe link (e.g., via the custom ingredient input).
//
// State management pattern:
//   ShoppingListService extends ChangeNotifier. This view
//   registers as a listener via _service.addListener(_onChanged)
//   and calls setState inside _onChanged so the widget tree
//   rebuilds whenever the service mutates the list — no need for
//   Provider, Riverpod, or BLoC.
//
// Route: '/shopping-list'  (named route in main.dart)
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

/// The shopping list screen. Rebuilds whenever [ShoppingListService]
/// notifies its listeners of a change.
class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  /// Singleton service that holds and persists the shopping list in memory.
  final _service = ShoppingListService();

  /// Controller for the "Add custom ingredient" text field at the top.
  final _customIngredientController = TextEditingController();

  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);

  @override
  void initState() {
    super.initState();
    // Register as a ChangeNotifier listener. Every time the service calls
    // notifyListeners(), _onChanged is invoked, which triggers a rebuild.
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    // Unregister to prevent calling setState after the widget is disposed.
    _service.removeListener(_onChanged);
    _customIngredientController.dispose();
    super.dispose();
  }

  /// Callback invoked by ShoppingListService when the list changes.
  /// Calls setState() to schedule a rebuild with the latest data.
  void _onChanged() => setState(() {});

  // ── Custom ingredient input ───────────────────────────────────────────

  /// Reads the text field, validates it is non-empty, then calls
  /// [ShoppingListService.addIngredients] with a single-item list.
  /// Clears the field and shows a confirmation SnackBar on success.
  void _addCustomIngredient() {
    final name = _customIngredientController.text.trim();
    if (name.isEmpty) return;
    // addIngredients accepts a List<String> so it can also be called
    // with a recipe's full ingredient list in one call.
    _service.addIngredients([name]);
    _customIngredientController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$name" added to shopping list'),
        backgroundColor: _brandGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Date formatting ───────────────────────────────────────────────────

  /// Returns a human-readable date label for a planned meal date.
  /// "Today" and "Tomorrow" are used for the nearest two days;
  /// older dates fall back to "DD Mon" format.
  String _formatPlannedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == tomorrow) return 'Tomorrow';
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month]}';
  }

  // ── Section grouping logic ────────────────────────────────────────────

  /// Partitions [items] into three groups and returns a list of
  /// [_ShoppingSection] objects ready to render.
  ///
  /// Algorithm:
  /// 1. Sort the recipe metadata by plannedDate (earliest first, null last).
  /// 2. Build a deterministic ordered set of recipe titles from the sorted
  ///    recipes and then from any remaining item.recipeTitles.
  /// 3. For each item count how many distinct recipes reference it:
  ///    - > 1  → commonItems
  ///    - == 1 → per-recipe bucket in recipeItemMap
  ///    - == 0 → otherItems (manually added / recipe no longer in list)
  List<_ShoppingSection> _buildSections(List<ShoppingItem> items) {
    // Sort recipe metadata by planned date; undated recipes go last.
    final sortedRecipes = List.of(_service.recipes)
      ..sort((a, b) {
        if (a.plannedDate == null && b.plannedDate == null) return 0;
        if (a.plannedDate == null) return 1;
        if (b.plannedDate == null) return -1;
        return a.plannedDate!.compareTo(b.plannedDate!);
      });

    // Build an ordered, deduplicated list of recipe titles. The order
    // determines section order in the final list.
    final recipeOrder = <String>[];
    final seenRecipeTitles = <String>{};

    for (final recipe in sortedRecipes) {
      if (seenRecipeTitles.add(recipe.recipeTitle)) {
        recipeOrder.add(recipe.recipeTitle);
      }
    }

    // Also include titles mentioned in item.recipeTitles that aren't
    // in the recipe metadata (edge case: recipe removed from plan but
    // its ingredients still on the list).
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
        // Shared across multiple recipes → Common section.
        commonItems.add(item);
      } else if (matchedRecipes.length == 1) {
        // Belongs to exactly one recipe → that recipe's section.
        recipeItemMap
            .putIfAbsent(matchedRecipes.first, () => [])
            .add(item);
      } else {
        // No matched recipe → Other section.
        otherItems.add(item);
      }
    }

    final sections = <_ShoppingSection>[];

    // ── Common ingredients section ────────────────────────────────
    if (commonItems.isNotEmpty) {
      commonItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      sections.add(_ShoppingSection(
        title: 'Common ingredients',
        subtitle: 'Used in more than one recipe',
        items: commonItems,
        accent: _brandGreen,
        filled: true, // triggers the starred gradient header
      ));
    }

    // ── Per-recipe sections ────────────────────────────────────────
    for (final recipe in sortedRecipes) {
      final recipeItems = recipeItemMap[recipe.recipeTitle];
      if (recipeItems == null || recipeItems.isEmpty) continue;
      recipeItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final dateLabel = recipe.plannedDate != null
          ? _formatPlannedDate(recipe.plannedDate!)
          : null;
      final countLabel =
          '${recipeItems.length} ingredient${recipeItems.length == 1 ? '' : 's'}';
      sections.add(_ShoppingSection(
        title: recipe.recipeTitle,
        subtitle:
            dateLabel != null ? '$dateLabel · $countLabel' : countLabel,
        items: recipeItems,
        accent: _brandGreen,
      ));
    }

    // ── Other ingredients section ─────────────────────────────────
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

  // ── Clear list dialog ─────────────────────────────────────────────────

  /// Shows a confirmation dialog before clearing the entire list.
  /// Uses a standard AlertDialog; the destructive action is colour-coded red.
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _service.items;
    final hasRecipes = _service.recipes.isNotEmpty;
    final sections = _buildSections(items);
    final hasItems = items.isNotEmpty || hasRecipes;

    return NavBarScaffold(
      title: 'Shopping List',
      // "Clear List" action button appears in the AppBar only when the
      // list is non-empty, so there is always something to clear.
      actions: [
        if (hasItems)
          TextButton.icon(
            onPressed: _confirmClearList,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.redAccent),
            label: const Text('Clear List',
                style:
                    TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
      ],
      body: ColoredBox(
        color: _surfaceGreen,
        child: Column(
          children: [
            // ── Custom ingredient input row ────────────────────────
            // Always visible at the top so users can quickly add
            // items without navigating to a recipe first.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customIngredientController,
                      textInputAction: TextInputAction.done,
                      // Trigger add on keyboard Done button.
                      onSubmitted: (_) => _addCustomIngredient(),
                      decoration: InputDecoration(
                        hintText: 'Add custom ingredient...',
                        prefixIcon: const Icon(
                            Icons.add_circle_outline,
                            color: _brandGreen,
                            size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _brandGreen),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _addCustomIngredient,
                    child: const Text('Add',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // ── Main list area ────────────────────────────────────
            Expanded(
              child: items.isEmpty && !hasRecipes
                  // Empty state: shown when no items and no recipe metadata.
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Your shopping list is empty',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add ingredients from a recipe or use the input above.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  // List of grouped section cards, one per _ShoppingSection.
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: sections.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ShoppingSectionCard(
                          section: sections[i],
                          brandGreen: _brandGreen,
                          // Callbacks forward to ShoppingListService;
                          // the service calls notifyListeners() which
                          // triggers _onChanged → setState.
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

// ── Data model for a rendered section ─────────────────────────────────────────

/// Plain data class representing one rendered section of the shopping list.
/// Passed to [_ShoppingSectionCard] for rendering.
class _ShoppingSection {
  final String title;
  final String subtitle;
  final List<ShoppingItem> items;
  final Color accent;

  /// When true the section header uses the filled (starred) gradient style
  /// used for "Common ingredients".
  final bool filled;

  const _ShoppingSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.accent,
    this.filled = false,
  });
}

// ── Section card widget ────────────────────────────────────────────────────────

/// Renders a single shopping section as a rounded card with:
///   • A gradient header showing the section title, subtitle, and item count.
///   • A per-item row with [_QtyButton] steppers and a delete button.
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

  /// Builds a single ingredient row with quantity controls.
  ///
  /// Layout: [Name label] [–] [count] [+] [🗑]
  /// The minus and plus buttons delegate to [onDecreaseQuantity] /
  /// [onIncreaseQuantity], which call ShoppingListService.updateQuantity().
  /// If quantity reaches 0 the service removes the item automatically.
  Widget _buildItemRow(ShoppingItem item) {
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // Ingredient name — takes available space.
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

              // ── Quantity stepper ─────────────────────────────────
              // [–] count [+]  pattern used for item quantity control.
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
                // Green tint on the + button to signal the positive action.
                backgroundColor: const Color(0xFFE4F2DE),
                iconColor: const Color(0xFF3C7E2A),
              ),

              // Delete button removes the item entirely (regardless of qty).
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
        // Filled sections (Common) get a tinted border.
        border: Border.all(
          color: section.filled
              // ignore: deprecated_member_use
              ? section.accent.withOpacity(0.18)
              : const Color(0xFFE7EEE2),
        ),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────────
          // LinearGradient differentiates Common (bold green-to-white)
          // from normal sections (subtle light green-to-white).
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
                // Icon badge: star for Common, fork-and-knife for recipes.
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
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
                // Title + subtitle column.
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
                // Item count pill badge.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
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

          // ── Item rows ────────────────────────────────────────────────
          // Spread operator maps each ShoppingItem to a _buildItemRow call.
          ...section.items.map(_buildItemRow),
        ],
      ),
    );
  }
}

// ── Quantity button ────────────────────────────────────────────────────────────

/// A small square tap target used for the [–] and [+] quantity controls.
/// Uses [GestureDetector] rather than [IconButton] so we can precisely
/// control the 28×28 hit area and rounded corner style without the default
/// IconButton padding.
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
