// ============================================================
// recipe_page.dart
// ============================================================
// Full-screen detail view for a single recipe. Contains three
// data-model classes (IngredientEntry, RecipeModel, NutritionInfo)
// shared across the app, the main RecipePage StatefulWidget, and
// a suite of private sub-widgets that build each section of the
// scrollable body.
//
// Layout pattern: CustomScrollView with a pinned SliverAppBar
// (expandedHeight: 360) acting as the hero image, and a single
// SliverToBoxAdapter containing the text body. A persistent
// bottom bar provides one-tap addition of all ingredients to the
// shopping list.
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/services/favourites_service.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/services/private_notes_service.dart';
import 'package:simplyserve/views/recipe_form.dart';

// ────────────────────────────────────────────────────────────
// Data model: IngredientEntry
// Represents one line in a recipe's ingredient list.
// Structured ingredients carry explicit quantity + unit;
// legacy plain-text ingredients are wrapped via fromLegacy()
// with sentinel values (quantity=1, unit='pcs') so the
// displayLabel getter returns the raw name unchanged.
// ────────────────────────────────────────────────────────────
class IngredientEntry {
  final String name;
  final double quantity;
  final String unit;

  /// Nutritional values per 100g/ml of this ingredient (only set for custom
  /// ingredients the backend cannot look up).
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  /// True when the user added this ingredient manually and supplied macros.
  /// Custom-ingredient macros are accumulated by _submit() in RecipeFormView
  /// and patched on top of the backend's auto-calculated nutrition total.
  final bool isCustom;

  const IngredientEntry({
    required this.name,
    required this.quantity,
    required this.unit,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.isCustom = false,
  });

  /// Smart display label:
  /// • Legacy entries (quantity==1, unit=='pcs') → just the name, because
  ///   the name already encodes its own quantity (e.g. "2 salmon fillets").
  /// • Structured entries → "400 g pasta" or "0.5 tsp salt".
  ///   Integer quantities are formatted without a decimal point.
  String get displayLabel {
    // For legacy ingredients with default sentinel values, just show the name
    // since it already contains quantity/unit (e.g., "2 salmon fillets")
    if (quantity == 1 && unit == 'pcs') {
      return name;
    }

    // For properly structured ingredients, format with quantity and unit
    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toString();
    return '$quantityLabel $unit $name';
  }

  /// Serialise to the JSON shape expected by the backend API.
  /// Custom-ingredient nutrition fields are only included when isCustom==true
  /// (spread operator pattern: `if (condition) ...{map}`).
  Map<String, dynamic> toJson() => {
        'ingredient_name': name,
        'quantity': quantity,
        'unit': unit,
        if (isCustom) ...{
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fats': fats,
          'is_custom': true,
        },
      };

  /// Deserialise from the API response. Handles both 'ingredient_name' and
  /// the legacy 'name' key for backwards compatibility.
  factory IngredientEntry.fromJson(Map<String, dynamic> json) {
    return IngredientEntry(
      name: (json['ingredient_name'] ?? json['name'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: (json['unit'] ?? 'pcs').toString(),
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0,
      isCustom: (json['is_custom'] as bool?) ?? false,
    );
  }

  /// Wrap a legacy plain-text ingredient string so it can be stored
  /// as an IngredientEntry without any parsing. The sentinel values
  /// (quantity=1, unit='pcs') cause displayLabel to return name unchanged.
  factory IngredientEntry.fromLegacy(String ingredient) {
    return IngredientEntry(name: ingredient, quantity: 1, unit: 'pcs');
  }
}

// ────────────────────────────────────────────────────────────
// Data model: RecipeModel
// Immutable value object passed via named route arguments
// ('/recipe') and shared across the recipes list, spinning
// wheel, shopping list, and meal calendar.
//
// Key design decision: `id` is nullable.
// • id == null  → built-in SimplyServe catalog recipe (no server record).
// • id != null  → user-created recipe stored in the backend database.
// This distinction drives which action buttons are shown on the
// detail page (edit/delete vs. favourite toggle).
// ────────────────────────────────────────────────────────────
class RecipeModel {
  final String title;
  final String summary;
  final String imageUrl;
  final String prepTime;
  final String cookTime;
  final String totalTime;
  final int servings;
  final String difficulty;
  final NutritionInfo nutrition;
  final List<IngredientEntry> ingredients;
  final List<String> steps;
  final List<String> tags;

  /// Null for built-in catalog recipes; non-null for user-created recipes.
  final int? id;

  const RecipeModel({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.prepTime,
    required this.cookTime,
    required this.totalTime,
    required this.servings,
    required this.difficulty,
    required this.nutrition,
    required this.ingredients,
    required this.steps,
    this.tags = const [],
    this.id,
  });

  /// Produces a shallow copy with an updated NutritionInfo, used by
  /// RecipeFormView._submit() to patch custom-ingredient macros on top
  /// of the server-returned nutrition totals without mutating the original.
  RecipeModel copyWith({NutritionInfo? nutrition}) {
    return RecipeModel(
      title: title,
      summary: summary,
      imageUrl: imageUrl,
      prepTime: prepTime,
      cookTime: cookTime,
      totalTime: totalTime,
      servings: servings,
      difficulty: difficulty,
      nutrition: nutrition ?? this.nutrition,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
      id: id,
    );
  }
}

// ────────────────────────────────────────────────────────────
// Data model: NutritionInfo
// Simple value object for per-serving macro values.
// protein/carbs/fats are stored as strings (e.g. "25g") because
// the API returns them that way; calories is an int (kcal).
// ────────────────────────────────────────────────────────────
class NutritionInfo {
  final int calories;
  final String protein;
  final String carbs;
  final String fats;

  const NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

// ────────────────────────────────────────────────────────────
// RecipePage — StatefulWidget
// Accepts an optional RecipeModel via the constructor.
// When no recipe is supplied it falls back to the hardcoded
// Spaghetti Bolognese demo, ensuring the page is never blank.
// ────────────────────────────────────────────────────────────
class RecipePage extends StatefulWidget {
  final RecipeModel? recipe;

  const RecipePage({super.key, this.recipe});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  bool _isFavourited = false;

  /// _currentRecipe can be updated in-place after a successful edit,
  /// allowing the detail page to reflect changes without a full navigation.
  RecipeModel? _currentRecipe;

  /// Private note fetched from PrivateNotesService (SharedPreferences).
  /// Hidden when empty; shown as an amber lock-icon card when non-empty.
  String _privateNote = '';

  final FavouritesService _favouritesService = FavouritesService();
  final PrivateNotesService _notesService = PrivateNotesService();

  static const Color _brand = Color(0xFF74BC42);

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _loadFavouriteState();
    _loadPrivateNote();
  }

  /// Reads the private note from SharedPreferences.
  /// Keyed by recipe id (user recipes) or title (built-in recipes).
  Future<void> _loadPrivateNote() async {
    final recipe = _currentRecipe ?? widget.recipe;
    if (recipe == null) return;
    final note = await _notesService.getNote(
      id: recipe.id,
      title: recipe.title,
    );
    if (mounted) setState(() => _privateNote = note);
  }

  /// Only built-in catalog recipes (id == null) can be favourited.
  /// User-created recipes are already in "My Recipes" by virtue of existing
  /// in the database, so favouriting them would be redundant.
  Future<void> _loadFavouriteState() async {
    if (widget.recipe?.id != null) return;
    final title = widget.recipe?.title;
    if (title == null) return;
    final isFav = await _favouritesService.isFavourite(title);
    if (mounted) setState(() => _isFavourited = isFav);
  }

  /// Getter that returns _currentRecipe if available, otherwise falls back
  /// to the hardcoded demo recipe. This guarantees _recipe is never null
  /// anywhere in the build tree.
  RecipeModel get _recipe =>
      _currentRecipe ??
      const RecipeModel(
        title: 'Spaghetti Bolognese',
        summary:
            'A classic Italian pasta dish with rich, meaty sauce. Perfect for a hearty family meal.',
        imageUrl:
            'https://images.unsplash.com/photo-1604908177520-9c8b1e5f1a2c?auto=format&fit=crop&w=800&q=80',
        prepTime: '15 mins',
        cookTime: '45 mins',
        totalTime: '1 hr',
        servings: 4,
        difficulty: 'Medium',
        nutrition: NutritionInfo(
          calories: 550,
          protein: '25g',
          carbs: '60g',
          fats: '20g',
        ),
        ingredients: [
          IngredientEntry(name: 'spaghetti', quantity: 400, unit: 'g'),
          IngredientEntry(name: 'olive oil', quantity: 2, unit: 'tbsp'),
          IngredientEntry(
              name: 'onion, finely chopped', quantity: 1, unit: 'pcs'),
          IngredientEntry(
              name: 'garlic cloves, minced', quantity: 2, unit: 'pcs'),
          IngredientEntry(name: 'ground beef', quantity: 500, unit: 'g'),
          IngredientEntry(name: 'canned tomatoes', quantity: 400, unit: 'g'),
          IngredientEntry(name: 'tomato paste', quantity: 2, unit: 'tbsp'),
          IngredientEntry(name: 'dried oregano', quantity: 1, unit: 'tsp'),
          IngredientEntry(
              name: 'salt and pepper to taste', quantity: 1, unit: 'pcs'),
          IngredientEntry(
              name: 'grated Parmesan cheese, to serve',
              quantity: 1,
              unit: 'pcs'),
        ],
        steps: [
          'Cook spaghetti according to package instructions. Drain and set aside.',
          'Heat olive oil in a large pan over medium heat. Add onion and garlic, sauté until softened.',
          'Add ground beef to the pan and cook until browned.',
          'Stir in canned tomatoes, tomato paste, oregano, salt, and pepper. Simmer for 20-25 minutes.',
          'Serve sauce over spaghetti and top with grated Parmesan cheese.',
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      // ── Persistent bottom bar ──────────────────────────────────────
      // Always visible regardless of scroll position. Tapping it:
      // 1. Calls ShoppingListService.addIngredients() with displayLabel
      //    strings (resolved via IngredientEntry.displayLabel getter).
      // 2. Calls ShoppingListService.addRecipe() with per-serving macros
      //    stripped of their 'g' suffix via replaceAll(RegExp(r'[^0-9.]'), '').
      // 3. Shows a floating SnackBar confirmation.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: ElevatedButton.icon(
            onPressed: () {
              final service = ShoppingListService();
              // Add each ingredient's display label to the shared list
              service.addIngredients(
                _recipe.ingredients
                    .map((ingredient) => ingredient.displayLabel)
                    .toList(),
                recipeTitle: _recipe.title,
              );
              // Register the recipe entry for nutrition summary in the list view
              service.addRecipe(ShoppingRecipeEntry(
                recipeTitle: _recipe.title,
                caloriesPerServing: _recipe.nutrition.calories,
                proteinPerServing: double.tryParse(
                      _recipe.nutrition.protein
                          .replaceAll(RegExp(r'[^0-9.]'), ''),
                    ) ??
                    0,
                carbsPerServing: double.tryParse(
                      _recipe.nutrition.carbs
                          .replaceAll(RegExp(r'[^0-9.]'), ''),
                    ) ??
                    0,
                fatsPerServing: double.tryParse(
                      _recipe.nutrition.fats.replaceAll(RegExp(r'[^0-9.]'), ''),
                    ) ??
                    0,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Items added to shopping list successfully!'),
                  backgroundColor: Color(0xFF74BC42),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Add Ingredients to Shopping List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),

      // ── Scrollable body ────────────────────────────────────────────
      // CustomScrollView enables the SliverAppBar (hero image) to
      // collapse and pin the toolbar as the user scrolls down.
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                // Cap content width for readability on large screens
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleSection(recipe: _recipe),
                      const SizedBox(height: 28),
                      _MetadataRow(recipe: _recipe),
                      const SizedBox(height: 28),
                      const _SectionHeader(title: 'Nutrition per Serving'),
                      const SizedBox(height: 16),
                      _NutritionGrid(nutrition: _recipe.nutrition),
                      const SizedBox(height: 28),
                      const _SectionHeader(title: 'Ingredients'),
                      const SizedBox(height: 16),
                      _IngredientsList(ingredients: _recipe.ingredients),
                      const SizedBox(height: 28),
                      const _SectionHeader(title: 'Instructions'),
                      const SizedBox(height: 16),
                      _InstructionsList(steps: _recipe.steps),

                      // ── Private notes card ─────────────────────────
                      // Only rendered when the user has saved a private note.
                      // Uses the collection-if spread pattern to conditionally
                      // inject two children (header + card) into the Column.
                      if (_privateNote.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionHeader(title: 'Private Notes'),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            // Amber tint to visually distinguish private content
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE082),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lock icon signals this note is private
                              const Icon(Icons.lock_outline,
                                  size: 18, color: Color(0xFFFF8F00)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _privateNote,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5D4037),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the collapsible hero image AppBar.
  ///
  /// Key decisions:
  /// • expandedHeight: 360 — gives the image plenty of real estate.
  /// • pinned: true — the toolbar stays visible when collapsed.
  /// • Action buttons are conditional:
  ///   - Edit + Delete shown only when recipe.id != null (user-created).
  ///   - Favourite toggle shown only when recipe.id == null (built-in).
  /// • Image source branching: 'assets/' prefix → Image.asset,
  ///   otherwise Image.network with a loadingBuilder that shows a
  ///   determinate CircularProgressIndicator while bytes arrive.
  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 1,
      // Back button — uses maybePop so it's safe from nested routes
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
      ),
      actions: [
        // ── Edit button (user-created recipes only) ──────────────────
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _CircleIconButton(
            icon: Icons.edit_outlined,
            iconColor: Colors.black87,
            onTap: () async {
              if (_recipe.id == null) {
                return; // built-in recipes cannot be edited
              }
              // Push RecipeFormView in edit mode; await the returned RecipeModel
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => RecipeFormView(existingRecipe: _recipe),
                ),
              );

              // If a RecipeModel was returned, update the page in-place
              if (updated is RecipeModel && mounted) {
                setState(() {
                  _currentRecipe = updated;
                });
                _loadPrivateNote(); // re-fetch note in case it was changed
              }
            },
            tooltip: 'Edit Recipe',
          ),
        ),

        // ── Delete button (user-created recipes only) ────────────────
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _CircleIconButton(
            icon: Icons.delete_outline,
            iconColor: Colors.black87,
            onTap: () async {
              if (_recipe.id == null) return;
              // showDialog<bool> awaited for confirmation before API call
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Recipe'),
                  content: Text('Move "${_recipe.title}" to Deleted Recipes?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              // Soft-delete: marks the recipe as deleted on the server.
              // It will appear in DeletedRecipesView and can be restored.
              if (confirmed == true && context.mounted) {
                final success = await RecipeService().deleteRecipe(_recipe.id!);
                if (success && context.mounted) {
                  Navigator.of(context).pop(); // return to recipes list
                }
              }
            },
            tooltip: 'Delete Recipe',
          ),
        ),

        // ── Favourite toggle (built-in catalog recipes only) ─────────
        // User-created recipes are already in "My Recipes" by definition,
        // so the favourite button is hidden when id != null.
        if (_recipe.id == null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _CircleIconButton(
              icon: _isFavourited
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: _isFavourited ? Colors.redAccent : Colors.black87,
              onTap: () async {
                if (_isFavourited) {
                  await _favouritesService.removeFavourite(_recipe.title);
                  if (!mounted) return;
                  setState(() => _isFavourited = false);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Removed from My Recipes'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  await _favouritesService.addFavourite(_recipe.title);
                  if (!mounted) return;
                  setState(() => _isFavourited = true);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to My Recipes'),
                      backgroundColor: Color(0xFF74BC42),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              tooltip: _isFavourited
                  ? 'Remove from My Recipes'
                  : 'Add to My Recipes',
            ),
          ),
      ],

      // ── Hero image in the flexible space ────────────────────────────
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          // Branch between local asset and remote URL image loading
          child: _recipe.imageUrl.startsWith('assets/')
              ? Image.asset(
                  _recipe.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE8F5E9),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.grey),
                    ),
                  ),
                )
              : Image.network(
                  _recipe.imageUrl,
                  fit: BoxFit.cover,
                  // loadingBuilder: shows a determinate progress indicator
                  // while the image bytes are downloading from the network.
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFE8F5E9),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: _brand,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE8F5E9),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.grey),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _CircleIconButton
// Reusable circular action button with a white card shadow.
// Used in the SliverAppBar for back, edit, delete, and favourite
// actions. Wraps InkWell for ripple feedback; border-radius
// matches BoxShape.circle so the ripple clips correctly.
// ────────────────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _TitleSection
// Displays the recipe title (bold, 30px) and summary paragraph.
// ────────────────────────────────────────────────────────────
class _TitleSection extends StatelessWidget {
  final RecipeModel recipe;

  const _TitleSection({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recipe.summary,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// _SectionHeader
// Consistent section heading pattern: a 4px brand-green left
// accent bar followed by bold text. Used before Ingredients,
// Instructions, Nutrition, and Private Notes sections.
// ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Brand-green vertical accent bar
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF74BC42),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// _MetadataRow + _MetaItem + _MetaChip
// A horizontally scrollable row of metadata chips (prep time,
// cook time, total time, servings, difficulty). Uses
// SingleChildScrollView + Row to handle overflow on narrow
// screens without wrapping.
// ────────────────────────────────────────────────────────────

/// Plain data class for a metadata chip. Not a Widget.
class _MetaItem {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem(
      {required this.icon, required this.label, required this.value});
}

/// Builds the horizontally scrollable strip of _MetaChip widgets.
class _MetadataRow extends StatelessWidget {
  final RecipeModel recipe;

  const _MetadataRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetaItem(
          icon: Icons.timer_outlined, label: 'Prep', value: recipe.prepTime),
      _MetaItem(
          icon: Icons.local_fire_department_outlined,
          label: 'Cook',
          value: recipe.cookTime),
      _MetaItem(
          icon: Icons.schedule_outlined,
          label: 'Total',
          value: recipe.totalTime),
      _MetaItem(
          icon: Icons.people_outline_rounded,
          label: 'Serves',
          value: '${recipe.servings}'),
      _MetaItem(
          icon: Icons.bar_chart_rounded,
          label: 'Difficulty',
          value: recipe.difficulty),
    ];

    // Horizontal scroll prevents overflow on narrow screens
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MetaChip(item: item),
                ))
            .toList(),
      ),
    );
  }
}

/// A single white card chip showing an icon, value, and label.
class _MetaChip extends StatelessWidget {
  final _MetaItem item;

  const _MetaChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(item.icon, color: const Color(0xFF74BC42), size: 22),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _NutritionGrid
// Responsive grid of macro cards. Uses LayoutBuilder to switch
// between 2-column (narrow) and 4-column (wide) layouts at the
// 500px breakpoint. shrinkWrap + NeverScrollableScrollPhysics
// is required because GridView is nested inside CustomScrollView.
// ────────────────────────────────────────────────────────────
class _NutritionGrid extends StatelessWidget {
  final NutritionInfo nutrition;

  const _NutritionGrid({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _NutritionCard(
        label: 'Calories',
        value: '${nutrition.calories}',
        unit: 'kcal',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF7043),
      ),
      _NutritionCard(
        label: 'Protein',
        value: nutrition.protein,
        unit: '',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF42A5F5),
      ),
      _NutritionCard(
        label: 'Carbs',
        value: nutrition.carbs,
        unit: '',
        icon: Icons.grain_rounded,
        color: const Color(0xFFFFCA28),
      ),
      _NutritionCard(
        label: 'Fats',
        value: nutrition.fats,
        unit: '',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF74BC42),
      ),
    ];

    // LayoutBuilder: switch grid column count based on available width.
    // crossAxisCount 4 for wide screens (>500px), 2 for narrow.
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // shrinkWrap: prevents the GridView from expanding to fill the
        // parent's height when nested in a scrollable Column.
        shrinkWrap: true,
        // NeverScrollableScrollPhysics: delegates all scroll gestures
        // to the outer CustomScrollView.
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        children: cards,
      );
    });
  }
}

// ────────────────────────────────────────────────────────────
// _NutritionCard
// Individual macro card with a coloured icon badge, bold value,
// and a small unit label. The icon background uses
// color.withOpacity(0.12) to create a tinted circle without
// hardcoding a separate colour per macro.
// ────────────────────────────────────────────────────────────
class _NutritionCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _NutritionCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tinted icon badge
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Value + unit on the same baseline
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _IngredientsList
// Renders all ingredients inside a single white card using a
// ListView.separated with NeverScrollableScrollPhysics (nested
// inside CustomScrollView). Each item shows a brand-green bullet
// dot followed by the ingredient's displayLabel.
// ────────────────────────────────────────────────────────────
class _IngredientsList extends StatelessWidget {
  final List<IngredientEntry> ingredients;

  const _IngredientsList({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ingredients.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 56, // align divider with text, not bullet
          color: Colors.grey[100],
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand-green bullet dot
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF74BC42),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    // displayLabel resolves legacy vs structured format
                    ingredients[index].displayLabel,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _InstructionsList + _StepCard
// Renders each cooking step as a numbered card. List.generate
// is used instead of ListView.builder because the list is always
// short and is nested in a non-scrolling Column.
// ────────────────────────────────────────────────────────────

/// Generates one _StepCard per step (1-indexed).
class _InstructionsList extends StatelessWidget {
  final List<String> steps;

  const _InstructionsList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _StepCard(stepNumber: index + 1, instruction: steps[index]),
        );
      }),
    );
  }
}

/// A single white card with a green numbered badge on the left
/// and the step instruction text on the right.
class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String instruction;

  const _StepCard({required this.stepNumber, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand-green rounded step number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF74BC42),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                instruction,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF333333),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
