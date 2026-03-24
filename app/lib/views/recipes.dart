import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/views/recipe_form.dart';
import 'package:simplyserve/widgets/navbar.dart';

Color _tagColour(String tag) {
  switch (tag) {
    case 'Vegan':
      return const Color(0xFF43A047);
    case 'High Protein':
      return const Color(0xFF1E88E5);
    case 'High Fibre':
      return const Color(0xFF8D6E63);
    case 'Gluten Free':
      return const Color(0xFFFF8F00);
    case 'Dairy Free':
      return const Color(0xFF00ACC1);
    case 'Comfort Food':
      return const Color(0xFFE53935);
    default:
      return const Color(0xFF757575);
  }
}

class RecipesView extends StatefulWidget {
  const RecipesView({super.key});

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

// All distinct tags and difficulties used across recipes.
const _kAllTags = [
  'Vegan',
  'High Protein',
  'High Fibre',
  'Gluten Free',
  'Dairy Free',
  'Comfort Food',
];

const _kAllDifficulties = ['Easy', 'Medium', 'Hard'];

// Parse "30 min" → 30.  Returns 0 if unparseable.
int _parseMins(String t) =>
    int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

class _RecipesViewState extends State<RecipesView> {
  final TextEditingController _searchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();
  String _query = '';
  bool _isLoading = true;
  final List<RecipeModel> _allRecipes = [];

  final Set<String> _selectedTags = {};
  final Set<String> _selectedDifficulties = {};
  double _maxDuration = 120;
  bool _showAdvanced = false;

  int get _activeFilterCount =>
      _selectedTags.length +
      _selectedDifficulties.length +
      (_maxDuration < 120 ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _selectedDifficulties.clear();
      _maxDuration = 120;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  // Fallback ingredients sourced from assets/data/recipe_ingredients.json
  static const _wrapIngredientsFallback = [
    '2 chicken breasts, grilled and sliced',
    '4 large flour tortillas',
    '1 cup romaine lettuce, shredded',
    '1 tomato, diced',
    '1/2 red onion, thinly sliced',
    '1/2 cup cheddar cheese, shredded',
    '1/4 cup ranch dressing',
    '1 tbsp olive oil',
    '1 tsp garlic powder',
    'Salt and pepper to taste',
  ];

  Future<List<String>> _loadWrapIngredients() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/data/recipe_ingredients.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      final raw = data['American Grilled Chicken Wrap'];
      if (raw != null) return List<String>.from(raw as List);
    } catch (_) {}
    return _wrapIngredientsFallback;
  }

  Future<void> _fetchRecipes() async {
    setState(() => _isLoading = true);

    List<RecipeModel> apiRecipes = [];
    try {
      apiRecipes = await _recipeService.getRecipes();
    } catch (_) {}

    List<String> wrapIngredients = [];
    try {
      wrapIngredients = await _loadWrapIngredients();
    } catch (_) {}

    final wrapRecipe = RecipeModel(
      title: 'American Grilled Chicken Wrap',
      summary:
          'A classic American-style wrap packed with juicy grilled chicken, crisp romaine, cheddar, and creamy ranch dressing — ready in under 30 minutes.',
      imageUrl: 'assets/images/American Grilled Chicken Wrap.png',
      prepTime: '10 mins',
      cookTime: '15 mins',
      totalTime: '25 mins',
      servings: 4,
      difficulty: 'Easy',
      nutrition: const NutritionInfo(
        calories: 480,
        protein: '38g',
        carbs: '34g',
        fats: '18g',
      ),
      ingredients: wrapIngredients,
      steps: [
        'Season chicken breasts with garlic powder, salt, and pepper. Brush with olive oil.',
        'Grill chicken over medium-high heat for 6–7 minutes per side until cooked through. Rest for 5 minutes, then slice.',
        'Warm the flour tortillas in a dry pan or microwave for 20 seconds each.',
        'Lay out each tortilla and drizzle with ranch dressing.',
        'Top with shredded romaine, diced tomato, red onion, cheddar cheese, and sliced chicken.',
        'Fold in the sides, then roll up tightly. Slice in half and serve immediately.',
      ],
      tags: ['High Protein'],
    );

    if (mounted) {
      setState(() {
        _allRecipes.clear();
        _allRecipes.addAll(apiRecipes);
        if (!_allRecipes.any((r) => r.title == wrapRecipe.title)) {
          _allRecipes.insert(0, wrapRecipe);
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecipeModel> get _filteredRecipes {
    final q = _query.trim().toLowerCase();
    return _allRecipes.where((r) {
      // Text search
      if (q.isNotEmpty) {
        final title = r.title.toLowerCase();
        final summary = r.summary.toLowerCase();
        final tags = r.tags.map((t) => t.toLowerCase());
        final textMatch = title.contains(q) ||
            summary.contains(q) ||
            tags.any((t) => t.contains(q));
        if (!textMatch) return false;
      }

      // Tag filter – recipe must have ALL selected tags
      if (_selectedTags.isNotEmpty &&
          !_selectedTags.every((t) => r.tags.contains(t))) {
        return false;
      }

      // Difficulty filter
      if (_selectedDifficulties.isNotEmpty &&
          !_selectedDifficulties.contains(r.difficulty)) {
        return false;
      }

      // Duration filter
      if (_maxDuration < 120) {
        final mins = _parseMins(r.totalTime);
        if (mins > _maxDuration) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredRecipes;
    final hasFilters = _activeFilterCount > 0;

    return NavBarScaffold(
      title: 'Recipes',
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF74BC42),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const RecipeFormView()),
          );
          if (added == true) {
            _fetchRecipes();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Advanced-search toggle ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: InkWell(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _showAdvanced ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFilters
                        ? const Color(0xFF74BC42)
                        : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        size: 18, color: Color(0xFF74BC42)),
                    const SizedBox(width: 6),
                    const Text(
                      'Advanced Search',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF74BC42),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (hasFilters)
                      GestureDetector(
                        onTap: _clearFilters,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF74BC42),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _showAdvanced ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Advanced filter panel (dropdown) ────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showAdvanced
                ? _AdvancedFilterPanel(
                    selectedTags: _selectedTags,
                    selectedDifficulties: _selectedDifficulties,
                    maxDuration: _maxDuration,
                    onTagToggled: (tag) => setState(() =>
                        _selectedTags.contains(tag)
                            ? _selectedTags.remove(tag)
                            : _selectedTags.add(tag)),
                    onDifficultyToggled: (d) => setState(() =>
                        _selectedDifficulties.contains(d)
                            ? _selectedDifficulties.remove(d)
                            : _selectedDifficulties.add(d)),
                    onDurationChanged: (v) => setState(() => _maxDuration = v),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),

          // ── Results list ────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF74BC42)))
                : results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _query.isNotEmpty
                                    ? 'No recipes found for "$_query".'
                                    : 'No recipes match the selected filters.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRecipes,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _RecipeCard(recipe: results[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Advanced filter panel
// ─────────────────────────────────────────────

class _AdvancedFilterPanel extends StatelessWidget {
  final Set<String> selectedTags;
  final Set<String> selectedDifficulties;
  final double maxDuration;
  final ValueChanged<String> onTagToggled;
  final ValueChanged<String> onDifficultyToggled;
  final ValueChanged<double> onDurationChanged;

  const _AdvancedFilterPanel({
    required this.selectedTags,
    required this.selectedDifficulties,
    required this.maxDuration,
    required this.onTagToggled,
    required this.onDifficultyToggled,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tags ──────────────────────────────────
          const Text(
            'Tags',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
                letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kAllTags.map((tag) {
              final selected = selectedTags.contains(tag);
              final colour = _tagColour(tag);
              return GestureDetector(
                onTap: () => onTagToggled(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        // ignore: deprecated_member_use
                        ? colour.withOpacity(0.18)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          // ignore: deprecated_member_use
                          ? colour.withOpacity(0.6)
                          : const Color(0xFFDDDDDD),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? colour : const Color(0xFF666666),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),

          // ── Difficulty ────────────────────────────
          const Text(
            'Difficulty',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
                letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: _kAllDifficulties.map((d) {
              final selected = selectedDifficulties.contains(d);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onDifficultyToggled(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF74BC42)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF74BC42)
                            : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),

          // ── Duration slider ───────────────────────
          Row(
            children: [
              const Text(
                'Max Duration',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                    letterSpacing: 0.4),
              ),
              const Spacer(),
              Text(
                maxDuration >= 120 ? 'Any' : '≤ ${maxDuration.round()} min',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF74BC42)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF74BC42),
              inactiveTrackColor: const Color(0xFFDDDDDD),
              thumbColor: const Color(0xFF74BC42),
              overlayColor: const Color(0x2274BC42),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              min: 10,
              max: 120,
              divisions: 22,
              value: maxDuration,
              onChanged: onDurationChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('10 min',
                    style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                Text('Any',
                    style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recipe', arguments: recipe),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: recipe.imageUrl.startsWith('assets/')
                  ? Image.asset(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.grey),
                        ),
                      ),
                    )
                  : Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF74BC42),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 15, color: Color(0xFF74BC42)),
                      const SizedBox(width: 4),
                      Text(
                        recipe.totalTime,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.bar_chart_rounded,
                          size: 15, color: Color(0xFF74BC42)),
                      const SizedBox(width: 4),
                      Text(
                        recipe.difficulty,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_outline_rounded,
                          size: 15, color: Color(0xFF74BC42)),
                      const SizedBox(width: 4),
                      Text(
                        'Serves ${recipe.servings}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                    ],
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipe.tags
                          .map((tag) => _TagChip(label: tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colour = _tagColour(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colour.withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}
