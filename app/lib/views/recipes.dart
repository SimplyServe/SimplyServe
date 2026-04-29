import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/custom_tag_service.dart';
import 'package:simplyserve/services/favourites_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
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
    case 'Breakfast':
      return const Color(0xFFFFA726);
    case 'Lunch':
      return const Color(0xFF66BB6A);
    case 'Dinner':
      return const Color(0xFF5C6BC0);
    case 'Snack':
      return const Color(0xFFEC407A);
    default:
      return const Color(0xFF757575);
  }
}

Color _cuisineColour(String cuisine) {
  switch (cuisine) {
    case 'European':
      return const Color(0xFF1565C0);
    case 'Asian':
      return const Color(0xFFAD1457);
    case 'African':
      return const Color(0xFFE65100);
    case 'Middle Eastern':
      return const Color(0xFF6A1B9A);
    case 'American':
      return const Color(0xFF2E7D32);
    case 'Latin American':
      return const Color(0xFFC62828);
    case 'Caribbean':
      return const Color(0xFF00838F);
    case 'Mediterranean':
      return const Color(0xFF0277BD);
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
  'Breakfast',
  'Lunch',
  'Dinner',
  'Snack',
];

const _kAllDifficulties = ['Easy', 'Medium', 'Hard'];

const _kAllCuisines = [
  'European',
  'Asian',
  'African',
  'Middle Eastern',
  'American',
  'Latin American',
  'Caribbean',
  'Mediterranean',
];

// Parse "30 min" → 30.  Returns 0 if unparseable.
int _parseMins(String t) =>
    int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

class _RecipesViewState extends State<RecipesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final AllergyService _allergyService = AllergyService();
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();
  final FavouritesService _favouritesService = FavouritesService();
  final CustomTagService _customTagService = CustomTagService();
  String _query = '';
  bool _isLoading = true;
  final List<RecipeModel> _localRecipes = [];
  final List<RecipeModel> _userRecipes = [];
  List<String> _allergies = const [];
  Set<String> _favourites = {};
  List<String> _customTags = [];

  final Set<String> _selectedTags = {};
  final Set<String> _selectedDifficulties = {};
  final Set<String> _selectedCuisines = {};
  double _maxDuration = 120;
  bool _showAdvanced = false;

  int get _activeFilterCount =>
      _selectedTags.length +
      _selectedDifficulties.length +
      _selectedCuisines.length +
      (_maxDuration < 120 ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _selectedDifficulties.clear();
      _selectedCuisines.clear();
      _maxDuration = 120;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRecipes();
    _loadCustomTags();
  }

  Future<void> _loadCustomTags() async {
    final tags = await _customTagService.loadTags();
    if (mounted) setState(() => _customTags = tags);
  }

  Future<void> _fetchRecipes() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _recipeCatalogService.getAllRecipes(),
      _allergyService.loadAllergies(),
      _favouritesService.loadFavourites(),
    ]);

    if (mounted) {
      final recipes = results[0] as List<RecipeModel>;
      final allergies = results[1] as List<String>;
      final favourites = results[2] as Set<String>;

      final local = recipes.where((r) => r.id == null).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

      final user = recipes.where((r) => r.id != null).toList();

      // Favourited local recipes also appear in My Recipes
      for (final r in local) {
        if (favourites.contains(r.title) &&
            !user.any((u) => u.title == r.title)) {
          user.add(r);
        }
      }

      // Favourites first (alphabetical), then rest (alphabetical)
      user.sort((a, b) {
        final aFav = favourites.contains(a.title);
        final bFav = favourites.contains(b.title);
        if (aFav != bFav) return aFav ? -1 : 1;
        return a.title.compareTo(b.title);
      });

      setState(() {
        _allergies = allergies;
        _favourites = favourites;
        _localRecipes
          ..clear()
          ..addAll(local);
        _userRecipes
          ..clear()
          ..addAll(user);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<RecipeModel> _filteredFrom(List<RecipeModel> source) {
    final q = _query.trim().toLowerCase();
    return source.where((r) {
      if (AllergenFilterService.recipeContainsAnyAllergen(r, _allergies)) {
        return false;
      }

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

      // Tag filter - recipe must have ANY of the selected tags
      if (_selectedTags.isNotEmpty &&
          !_selectedTags.any((t) => r.tags.contains(t))) {
        return false;
      }

      // Cuisine filter - recipe must match ANY of the selected cuisines
      if (_selectedCuisines.isNotEmpty &&
          !_selectedCuisines.any((c) => r.tags.contains(c))) {
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

  Widget _buildRecipeList(List<RecipeModel> source) {
    final results = _filteredFrom(source);
    return _isLoading
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchRecipes,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final recipe = results[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RecipeCard(
                        recipe: recipe,
                        isFavourited: _favourites.contains(recipe.title),
                        onReturn: _fetchRecipes,
                      ),
                    );
                  },
                ),
              );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _activeFilterCount > 0;

    return NavBarScaffold(
      title: 'Recipes',
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF74BC42),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const RecipeFormView()),
          );
          if (result is RecipeModel) {
            await _fetchRecipes();
            await _loadCustomTags();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recipe created successfully.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
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
                prefixIcon: const Icon(Icons.search, color: Color(0xFF74BC42)),
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
                  borderSide: const BorderSide(color: Color(0xFFB8DFA0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB8DFA0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF74BC42), width: 2),
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
                    selectedCuisines: _selectedCuisines,
                    customTags: _customTags,
                    maxDuration: _maxDuration,
                    onTagToggled: (tag) => setState(() =>
                        _selectedTags.contains(tag)
                            ? _selectedTags.remove(tag)
                            : _selectedTags.add(tag)),
                    onDifficultyToggled: (d) => setState(() =>
                        _selectedDifficulties.contains(d)
                            ? _selectedDifficulties.remove(d)
                            : _selectedDifficulties.add(d)),
                    onCuisineToggled: (c) => setState(() =>
                        _selectedCuisines.contains(c)
                            ? _selectedCuisines.remove(c)
                            : _selectedCuisines.add(c)),
                    onDurationChanged: (v) => setState(() => _maxDuration = v),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Tabs ────────────────────────────────────
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF74BC42),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF74BC42),
            tabs: const [
              Tab(text: 'SimplyServe Originals'),
              Tab(text: 'My Recipes'),
            ],
          ),

          // ── Tab content ─────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecipeList(_localRecipes),
                _buildRecipeList(_userRecipes),
              ],
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
  final Set<String> selectedCuisines;
  final List<String> customTags;
  final double maxDuration;
  final ValueChanged<String> onTagToggled;
  final ValueChanged<String> onDifficultyToggled;
  final ValueChanged<String> onCuisineToggled;
  final ValueChanged<double> onDurationChanged;

  const _AdvancedFilterPanel({
    required this.selectedTags,
    required this.selectedDifficulties,
    required this.selectedCuisines,
    required this.customTags,
    required this.maxDuration,
    required this.onTagToggled,
    required this.onDifficultyToggled,
    required this.onCuisineToggled,
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
                color: Color(0xFF5FA832),
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

          // ── Custom Tags ────────────────────────────
          if (customTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Custom Tags',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5FA832),
                  letterSpacing: 0.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: customTags.map((tag) {
                final selected = selectedTags.contains(tag);
                const colour = Color(0xFF9C27B0);
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
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),

          // ── Cuisine ───────────────────────────────
          const Text(
            'Cuisine',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5FA832),
                letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kAllCuisines.map((cuisine) {
              final selected = selectedCuisines.contains(cuisine);
              final colour = _cuisineColour(cuisine);
              return GestureDetector(
                onTap: () => onCuisineToggled(cuisine),
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
                    cuisine,
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
                color: Color(0xFF5FA832),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
  final bool isFavourited;
  final VoidCallback? onReturn;

  const _RecipeCard({
    required this.recipe,
    this.isFavourited = false,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recipe', arguments: recipe)
          .then((_) => onReturn?.call()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
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
            // Green accent stripe
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF74BC42), Color(0xFF5FA832)],
                ),
              ),
            ),
            Stack(
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
                if (isFavourited)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    ),
                  ),
              ],
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAE8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD0EDBA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_outlined,
                            size: 15, color: Color(0xFF74BC42)),
                        const SizedBox(width: 4),
                        Text(
                          recipe.totalTime,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF555555)),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.bar_chart_rounded,
                            size: 15, color: Color(0xFF74BC42)),
                        const SizedBox(width: 4),
                        Text(
                          recipe.difficulty,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF555555)),
                        ),
                        const SizedBox(width: 14),
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
        // ignore: deprecated_member_use
        color: colour.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // ignore: deprecated_member_use
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
