// ============================================================
// views/recipes.dart
// ============================================================
// The main recipe discovery screen, wrapped in NavBarScaffold.
// Presents two tabs via TabController:
//   Tab 0 — "SimplyServe Originals": built-in catalog (id==null)
//   Tab 1 — "My Recipes": user-created (id!=null) + favourited built-ins
//
// Filter pipeline (applied client-side on every rebuild):
//   1. AllergenFilterService — hides allergen-matching recipes
//   2. Full-text search — title, summary, tags
//   3. Tag filter    — recipe must carry ANY selected tag (OR logic)
//   4. Cuisine filter — recipe must match ANY selected cuisine (OR logic)
//   5. Difficulty filter
//   6. Duration filter — max total minutes via Slider
//
// Key sub-widgets:
//   _AdvancedFilterPanel — AnimatedSize collapsible filter drawer
//   _RecipeCard          — image + metadata + tag chips + shopping list button
//   _TagChip             — coloured tag pill using _tagColour()
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/custom_tag_service.dart';
import 'package:simplyserve/services/favourites_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/views/recipe_form.dart';
import 'package:simplyserve/widgets/navbar.dart';

// ── Tag colour mapping ────────────────────────────────────────────────────
// Maps a tag string to the brand colour used for that category.
// Called by _TagChip (list view) and _AdvancedFilterPanel (filter chips).
// Falls back to a neutral grey for unknown/custom tags.
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

// ── Cuisine colour mapping ────────────────────────────────────────────────
// Separate mapping for cuisine tags, which appear in _AdvancedFilterPanel.
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

/// Main recipes screen — two-tab layout with search and advanced filters.
class RecipesView extends StatefulWidget {
  const RecipesView({super.key});

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

// ── Filter constants ──────────────────────────────────────────────────────
// Static lists of tags, difficulties, and cuisines used to populate the
// filter panel. These match the values stored in recipe.tags by the API.

/// All distinct dietary/meal-type tags used across the recipe catalog.
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

/// Parse "30 min" → 30.  Strips non-digits with a regex then parses.
/// Returns 0 if the string is unparseable (treated as "unknown duration",
/// which passes the duration filter even when a max is set).
int _parseMins(String t) =>
    int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

// ─────────────────────────────────────────────────────────────────────────
// _RecipesViewState
// SingleTickerProviderStateMixin — provides the vsync token for TabController.
// ─────────────────────────────────────────────────────────────────────────
class _RecipesViewState extends State<RecipesView>
    with SingleTickerProviderStateMixin {
  /// TabController drives both the TabBar indicator and TabBarView pages.
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final AllergyService _allergyService = AllergyService();
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();
  final FavouritesService _favouritesService = FavouritesService();
  final CustomTagService _customTagService = CustomTagService();

  String _query = '';
  bool _isLoading = true;

  // _localRecipes: built-in catalog (id == null), alphabetically sorted
  final List<RecipeModel> _localRecipes = [];
  // _userRecipes: user-created (id != null) + favourited built-ins
  final List<RecipeModel> _userRecipes = [];

  List<String> _allergies = const [];
  Set<String> _favourites = {};
  List<String> _customTags = [];

  // ── Active filter state ────────────────────────────────────────────────
  final Set<String> _selectedTags = {};
  final Set<String> _selectedDifficulties = {};
  final Set<String> _selectedCuisines = {};
  double _maxDuration = 120; // 120 = "Any" (no cap applied)
  bool _showAdvanced = false;

  /// Count of currently active filter dimensions (used for the badge pill).
  int get _activeFilterCount =>
      _selectedTags.length +
      _selectedDifficulties.length +
      _selectedCuisines.length +
      (_maxDuration < 120 ? 1 : 0);

  /// Reset all filter dimensions and duration to their defaults.
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
    // TabController(length: 2) — Originals + My Recipes
    _tabController = TabController(length: 2, vsync: this);
    _fetchRecipes();
    _loadCustomTags();
  }

  /// Loads user-defined tags from CustomTagService (SharedPreferences).
  /// These appear as a separate chip group in _AdvancedFilterPanel.
  Future<void> _loadCustomTags() async {
    final tags = await _customTagService.loadTags();
    if (mounted) setState(() => _customTags = tags);
  }

  /// Fetches recipes, allergies, and favourites in parallel using Future.wait.
  /// Partition:
  ///   • id == null → built-in catalog, sorted alphabetically.
  ///   • id != null → user-created recipes.
  ///   • Favourited built-ins are duplicated into the user list so they also
  ///     appear on the "My Recipes" tab without altering the originals list.
  /// The user list is then sorted: favourites first (alpha), then rest (alpha).
  Future<void> _fetchRecipes() async {
    setState(() => _isLoading = true);

    // Parallel fetch: recipes + allergies + favourites
    final results = await Future.wait([
      _recipeCatalogService.getAllRecipes(),
      _allergyService.loadAllergies(),
      _favouritesService.loadFavourites(),
    ]);

    if (mounted) {
      final recipes = results[0] as List<RecipeModel>;
      final allergies = results[1] as List<String>;
      final favourites = results[2] as Set<String>;

      // Recipes without an id are SimplyServe built-ins;
      // those with an id are user-created (stored in the backend DB).
      final local = recipes.where((r) => r.id == null).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

      final user = recipes.where((r) => r.id != null).toList();

      // Favourited local recipes also appear in My Recipes tab
      for (final r in local) {
        if (favourites.contains(r.title) &&
            !user.any((u) => u.title == r.title)) {
          user.add(r);
        }
      }

      // Favourites first (alphabetical), then the rest (alphabetical)
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

  // ─────────────────────────────────────────────────────────────────────
  // _filteredFrom — client-side filter pipeline
  // Applies all active filter dimensions sequentially (short-circuit via
  // return false). Each dimension is only evaluated when it has selections.
  // ─────────────────────────────────────────────────────────────────────
  List<RecipeModel> _filteredFrom(List<RecipeModel> source) {
    final q = _query.trim().toLowerCase();
    return source.where((r) {
      // Step 1: allergen check — AllergenFilterService scans ingredient names
      //         against the user's saved allergen list (client-side, no API call).
      if (AllergenFilterService.recipeContainsAnyAllergen(r, _allergies)) {
        return false;
      }

      // Step 2: full-text search across title, summary, and tags
      if (q.isNotEmpty) {
        final title = r.title.toLowerCase();
        final summary = r.summary.toLowerCase();
        final tags = r.tags.map((t) => t.toLowerCase());
        final textMatch = title.contains(q) ||
            summary.contains(q) ||
            tags.any((t) => t.contains(q));
        if (!textMatch) return false;
      }

      // Step 3: tag filter — OR logic: recipe must have ANY of the selected tags
      if (_selectedTags.isNotEmpty &&
          !_selectedTags.any((t) => r.tags.contains(t))) {
        return false;
      }

      // Step 4: cuisine filter — OR logic: recipe must match ANY selected cuisine
      if (_selectedCuisines.isNotEmpty &&
          !_selectedCuisines.any((c) => r.tags.contains(c))) {
        return false;
      }

      // Step 5: difficulty filter (exact match, OR across selected values)
      if (_selectedDifficulties.isNotEmpty &&
          !_selectedDifficulties.contains(r.difficulty)) {
        return false;
      }

      // Step 6: duration filter — only applied when < 120 (the "Any" sentinel)
      if (_maxDuration < 120) {
        final mins = _parseMins(r.totalTime);
        if (mins > _maxDuration) return false;
      }

      return true;
    }).toList();
  }

  /// Builds the list of filtered recipe cards for a given source list.
  /// Shows loading spinner, empty-state illustration, or a RefreshIndicator
  /// wrapping the ListView depending on current state.
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
                // Pull-to-refresh re-fetches from the API
                onRefresh: _fetchRecipes,
                child: ListView.builder(
                  // AlwaysScrollableScrollPhysics ensures pull-to-refresh works
                  // even when the list is shorter than the viewport.
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
                        // onReturn re-fetches so favourite changes are reflected
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
      // FAB opens RecipeFormView (create mode). On return, refreshes both
      // the recipe list and custom tags, then shows a success SnackBar.
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
          // ── Search bar ────────────────────────────────────────────────
          // Live-filters on every keystroke via onChanged → setState.
          // Suffix clear button appears only when _query is non-empty.
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

          // ── Advanced-search toggle ────────────────────────────────────
          // Tap to expand/collapse the _AdvancedFilterPanel.
          // When filters are active:
          //   • Border turns brand-green.
          //   • A green badge shows _activeFilterCount.
          //   • A "Clear" link resets all filters.
          // AnimatedRotation spins the chevron 180° when expanded.
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
                    // Active filter count badge
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
                    // Chevron rotates 180° when the panel is open
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

          // ── Advanced filter panel (animated dropdown) ──────────────
          // AnimatedSize smoothly expands/collapses the panel over 250ms
          // using the easeInOut curve. When collapsed, SizedBox.shrink()
          // takes up zero height, causing AnimatedSize to animate to 0.
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
                    // Toggle callbacks update the parent state and re-filter
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

          // ── Tab bar ──────────────────────────────────────────────────
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

          // ── Tab content ──────────────────────────────────────────────
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
// _AdvancedFilterPanel
// ─────────────────────────────────────────────
// StatelessWidget that renders the collapsible filter drawer.
// All mutable state lives in the parent (_RecipesViewState);
// the panel only calls callbacks.
//
// Sections:
//   Tags       — AnimatedContainer chips (150ms colour transition)
//   Custom Tags — same pattern, shown only when _customTags is non-empty
//   Cuisine    — AnimatedContainer chips
//   Difficulty — AnimatedContainer chips (uses brand-green when selected)
//   Duration   — Slider with a custom SliderTheme; 120 = "Any"

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
          // ── Tags section ────────────────────────────────────────────
          // AnimatedContainer (150ms) transitions background colour and border
          // colour when a tag is toggled. Uses _tagColour() tinted at 18%
          // opacity for the selected background.
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

          // ── Custom Tags section (conditional) ───────────────────────
          // Only shown when the user has created at least one custom tag.
          // Custom tags use a fixed purple colour (0xFF9C27B0) rather than
          // the per-tag colour mapping.
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

          // ── Cuisine section ─────────────────────────────────────────
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

          // ── Difficulty section ──────────────────────────────────────
          // Horizontal row of three chips. Selected chip fills with brand
          // green; unselected remains light grey.
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

          // ── Duration slider ─────────────────────────────────────────
          // Range 10–120 minutes with 22 divisions (~5-min steps).
          // When maxDuration == 120 the label shows "Any" and the filter
          // is not applied (see _filteredFrom step 6).
          // SliderTheme overrides colours to match the brand palette.
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
          // Custom SliderTheme for brand-consistent colours
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

// ─────────────────────────────────────────────
// _RecipeCard
// ─────────────────────────────────────────────
// Tap-to-navigate card. On tap: pushes the '/recipe' named route
// with the RecipeModel as arguments; on return calls onReturn()
// so the parent can refresh favourite state.
//
// Structure (top to bottom):
//   • 4px green accent stripe
//   • 180px image (asset or network with loadingBuilder)
//   • Favourited heart badge (Stack overlay, conditional)
//   • Title + summary
//   • Metadata bar (time / difficulty / servings)
//   • Tag chip row (Wrap)
//   • "Add to Shopping List" outlined button
//
// Shopping list sheet: _showAddToShoppingListSheet uses
// showModalBottomSheet + StatefulBuilder so the checkbox state
// (Set<int> selected) is local to the sheet without needing a
// separate widget class.

class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool isFavourited;
  final VoidCallback? onReturn;

  const _RecipeCard({
    required this.recipe,
    this.isFavourited = false,
    this.onReturn,
  });

  /// Opens a bottom sheet allowing the user to select individual ingredients
  /// before adding them to the shopping list.
  ///
  /// Uses StatefulBuilder to maintain per-ingredient checkbox state
  /// (Set<int> selected — indices into recipe.ingredients) inside the
  /// modal sheet without promoting it to a full StatefulWidget.
  ///
  /// "Select/Deselect all" toggle: if all are selected → clear; else → fill.
  Future<void> _showAddToShoppingListSheet(BuildContext context) async {
    final service = ShoppingListService();
    final ingredients = recipe.ingredients;
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This recipe has no ingredients to add.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Pre-select all ingredients by default
    final selected = <int>{...List.generate(ingredients.length, (i) => i)};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // StatefulBuilder: local setState for checkbox toggles without
        // rebuilding the entire parent screen.
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: Color(0xFF74BC42), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add to Shopping List',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              recipe.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF74BC42),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Select / deselect all toggle
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            if (selected.length == ingredients.length) {
                              selected.clear(); // deselect all
                            } else {
                              selected.addAll(
                                  List.generate(ingredients.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          selected.length == ingredients.length
                              ? 'Deselect all'
                              : 'Select all',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF74BC42),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  // Constrain list height to 45% of screen to keep the
                  // confirm button above the keyboard on short displays.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: ingredients.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF5F5F5)),
                      itemBuilder: (_, i) {
                        final ing = ingredients[i];
                        final isChecked = selected.contains(i);
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              if (isChecked) {
                                selected.remove(i);
                              } else {
                                selected.add(i);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                // AnimatedContainer transitions the checkbox
                                // fill colour when toggled (150ms)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? const Color(0xFF74BC42)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isChecked
                                          ? const Color(0xFF74BC42)
                                          : const Color(0xFFCCCCCC),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    ing.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isChecked
                                          ? const Color(0xFF1A1A1A)
                                          : const Color(0xFF888888),
                                      fontWeight: isChecked
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${ing.quantity} ${ing.unit}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF74BC42),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Confirm button — disabled (grey) when nothing is selected
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected.isEmpty
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF74BC42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              // Resolve display labels for selected indices
                              final chosenLabels = selected
                                  .map((i) => ingredients[i].displayLabel)
                                  .toList();
                              // Add ingredients and recipe metadata to the list
                              service.addIngredients(
                                chosenLabels,
                                recipeTitle: recipe.title,
                              );
                              service.addRecipe(ShoppingRecipeEntry(
                                recipeTitle: recipe.title,
                                caloriesPerServing: recipe.nutrition.calories,
                                proteinPerServing: double.tryParse(
                                      recipe.nutrition.protein
                                          .replaceAll(RegExp(r'[^0-9.]'), ''),
                                    ) ??
                                    0,
                                carbsPerServing: double.tryParse(
                                      recipe.nutrition.carbs
                                          .replaceAll(RegExp(r'[^0-9.]'), ''),
                                    ) ??
                                    0,
                                fatsPerServing: double.tryParse(
                                      recipe.nutrition.fats
                                          .replaceAll(RegExp(r'[^0-9.]'), ''),
                                    ) ??
                                    0,
                              ));
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${selected.length} ingredient${selected.length == 1 ? '' : 's'} added to your shopping list.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF74BC42),
                                ),
                              );
                            },
                      child: Text(
                        selected.isEmpty
                            ? 'Select ingredients'
                            : 'Add ${selected.length} ingredient${selected.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector wraps the entire card for full-surface tap target.
    // After navigation returns, onReturn() re-fetches to sync favourite changes.
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
            // 4px brand-green accent stripe at the very top of every card
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF74BC42), Color(0xFF5FA832)],
                ),
              ),
            ),
            // Image area with optional favourited heart badge
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
                          // loadingBuilder shows a spinner while the image loads
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
                // Favourited heart badge — positioned top-right over image
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
                  // Recipe title
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
                  // Summary (max 2 lines)
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
                  // Metadata bar: time / difficulty / servings
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
                  // Tag chip row (Wrap, only when tags exist)
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
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F5EC)),
                  const SizedBox(height: 8),
                  // "Add to Shopping List" outlined button — opens the sheet
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddToShoppingListSheet(context),
                      icon: const Icon(Icons.add_shopping_cart_rounded,
                          size: 16, color: Color(0xFF74BC42)),
                      label: const Text(
                        'Add to Shopping List',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF74BC42),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB8DFA0)),
                        backgroundColor: const Color(0xFFF4FAF1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _TagChip
// A small pill chip that displays a tag label using its mapped
// brand colour. Background is the colour at 12% opacity;
// border is the same colour at 40% opacity.
// ────────────────────────────────────────────────────────────
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
