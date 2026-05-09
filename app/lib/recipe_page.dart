import 'package:flutter/material.dart';
import 'package:simplyserve/services/favourites_service.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/services/private_notes_service.dart';
import 'package:simplyserve/views/recipe_form.dart';

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

  String get displayLabel {
    // For legacy ingredients with default values, just show the name
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

  factory IngredientEntry.fromLegacy(String ingredient) {
    return IngredientEntry(name: ingredient, quantity: 1, unit: 'pcs');
  }
}

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

class RecipePage extends StatefulWidget {
  final RecipeModel? recipe;

  const RecipePage({super.key, this.recipe});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  bool _isFavourited = false;
  RecipeModel? _currentRecipe;
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

  Future<void> _loadPrivateNote() async {
    final recipe = _currentRecipe ?? widget.recipe;
    if (recipe == null) return;
    final note = await _notesService.getNote(
      id: recipe.id,
      title: recipe.title,
    );
    if (mounted) setState(() => _privateNote = note);
  }

  Future<void> _loadFavouriteState() async {
    if (widget.recipe?.id != null) return;
    final title = widget.recipe?.title;
    if (title == null) return;
    final isFav = await _favouritesService.isFavourite(title);
    if (mounted) setState(() => _isFavourited = isFav);
  }

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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: ElevatedButton.icon(
            onPressed: () {
              final service = ShoppingListService();
              service.addIngredients(
                _recipe.ingredients
                    .map((ingredient) => ingredient.displayLabel)
                    .toList(),
                recipeTitle: _recipe.title,
              );
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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
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
                      if (_privateNote.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionHeader(title: 'Private Notes'),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE082),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 1,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _CircleIconButton(
            icon: Icons.edit_outlined,
            iconColor: Colors.black87,
            onTap: () async {
              if (_recipe.id == null) {
                return;
              }
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => RecipeFormView(existingRecipe: _recipe),
                ),
              );

              if (updated is RecipeModel && mounted) {
                setState(() {
                  _currentRecipe = updated;
                });
                _loadPrivateNote();
              }
            },
            tooltip: 'Edit Recipe',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _CircleIconButton(
            icon: Icons.delete_outline,
            iconColor: Colors.black87,
            onTap: () async {
              if (_recipe.id == null) return;
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
              if (confirmed == true && context.mounted) {
                final success = await RecipeService().deleteRecipe(_recipe.id!);
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            tooltip: 'Delete Recipe',
          ),
        ),
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
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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

class _MetaItem {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem(
      {required this.icon, required this.label, required this.value});
}

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

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        children: cards,
      );
    });
  }
}

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
          indent: 56,
          color: Colors.grey[100],
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
