// ============================================================
// views/meal_calendar.dart
// ============================================================
// Two-tab meal calendar wrapped in NavBarScaffold:
//
//   Tab 0 — Planning: month-grid calendar for scheduling future meals.
//     • GridView.builder with crossAxisCount=7 (one column per weekday).
//     • Past dates are greyed and non-tappable.
//     • Today gets a brand-green border.
//     • Tapping a future date opens _openDaySheet() — a modal bottom
//       sheet where recipes can be searched and serving counts adjusted.
//     • A "Add to List" button in the sheet header sends planned meals
//       to ShoppingListService with a plannedDate stamp.
//
//   Tab 1 — Log: records which meals were eaten on a chosen date.
//     • Uses showDatePicker (themed brand-green) to select the log date.
//     • _mealLogService.totalsForDay() provides total servings for the header.
//
// Reactive updates: both MealLogService and MealPlanService extend
// ChangeNotifier. The view registers via addListener(_onCalendarDataChanged)
// in initState and removes both listeners in dispose() to prevent leaks.
//
// Shared recipe list widget (_buildRecipeListForDay) is reused for both
// the planning sheet and the log tab. It sorts recipes: selected first
// (by serving count desc), then alphabetically.
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/services/meal_plan_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/services/shopping_list_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

/// Main meal calendar view — planning + logging in one screen.
class MealCalendarView extends StatefulWidget {
  const MealCalendarView({super.key});

  @override
  State<MealCalendarView> createState() => _MealCalendarViewState();
}

class _MealCalendarViewState extends State<MealCalendarView> {
  /// The month currently shown in the Planning tab grid.
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final MealLogService _mealLogService = MealLogService();
  final MealPlanService _mealPlanService = MealPlanService();
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();

  /// Search query used in the Log tab's recipe list.
  String _todaySearchQuery = '';

  /// Currently selected date in the Log tab.
  DateTime _logDate = DateTime.now();

  bool _isLoading = true;
  List<RecipeModel> _availableRecipes = [];

  @override
  void initState() {
    super.initState();
    // Register ChangeNotifier listeners so UI rebuilds when service state changes.
    // Both listeners call the same handler because both affect the calendar grid.
    _mealLogService.addListener(_onCalendarDataChanged);
    _mealPlanService.addListener(_onCalendarDataChanged);
    _fetchRecipes();
  }

  @override
  void dispose() {
    // Always remove ChangeNotifier listeners to avoid memory leaks and
    // setState calls on a disposed widget.
    _mealLogService.removeListener(_onCalendarDataChanged);
    _mealPlanService.removeListener(_onCalendarDataChanged);
    super.dispose();
  }

  /// ChangeNotifier callback: triggers a rebuild when meal plan or log changes.
  /// The mounted guard prevents setState after the widget is disposed.
  void _onCalendarDataChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// Fetches the full recipe catalog once on mount.
  /// Results are stored in _availableRecipes for use in the recipe list widget.
  Future<void> _fetchRecipes() async {
    final recipes = await _recipeCatalogService.getAllRecipes();
    if (mounted) {
      setState(() {
        _availableRecipes = recipes;
        _isLoading = false;
      });
    }
  }

  /// Client-side recipe search: matches title or summary against [query].
  /// Returns all recipes when the query is blank.
  List<RecipeModel> _filterRecipes(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _availableRecipes;
    }

    return _availableRecipes.where((recipe) {
      return recipe.title.toLowerCase().contains(q) ||
          recipe.summary.toLowerCase().contains(q);
    }).toList();
  }

  /// Returns a title→servings map for the given day from either the
  /// meal log (forLog: true) or the meal plan (forLog: false).
  /// This abstraction lets _buildRecipeListForDay work for both tabs
  /// without duplicating the query logic.
  Map<String, int> _servingsByTitle(DateTime day, {required bool forLog}) {
    if (forLog) {
      final meals = _mealLogService.mealsForDay(day);
      return {
        for (final meal in meals) meal.recipeTitle: meal.servings,
      };
    }

    final meals = _mealPlanService.mealsForDay(day);
    return {
      for (final meal in meals) meal.recipeTitle: meal.servings,
    };
  }

  /// Updates serving count for a recipe on a given day, routing to either
  /// the log service or the plan service based on [forLog].
  /// Negative servings are clamped to 0 (treated as removal).
  void _setServings(
    DateTime day,
    RecipeModel recipe,
    int servings, {
    required bool forLog,
  }) {
    final nextServings = servings < 0 ? 0 : servings;

    if (forLog) {
      _mealLogService.setServings(
        date: day,
        recipe: recipe,
        servings: nextServings,
      );
      return;
    }

    _mealPlanService.setServings(
      date: day,
      recipe: recipe,
      servings: nextServings,
    );
  }

  /// Renders the recipe image, branching between asset and network sources.
  Widget _buildRecipeImage(RecipeModel recipe) {
    if (recipe.imageUrl.startsWith('assets/')) {
      return Image.asset(
        recipe.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
      );
    }

    return Image.network(
      recipe.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
    );
  }

  /// Builds a single recipe list tile with a –/count/+ serving stepper.
  ///
  /// Visual states:
  ///   • selected (servings > 0): serving count shown in subtitle; stepper
  ///     buttons and count are brand-green.
  ///   • unselected: subtitle shows only totalTime; count is grey.
  ///
  /// Tap on the tile toggles between 0 and 1 serving (quick add/remove).
  Widget _buildRecipeListTile({
    required RecipeModel recipe,
    required int servings,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required VoidCallback onTap,
  }) {
    final selected = servings > 0;

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 30,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildRecipeImage(recipe),
        ),
      ),
      title: Text(recipe.title),
      subtitle: Text(
        selected
            ? '${recipe.totalTime}  -  $servings serving(s)'
            : recipe.totalTime,
      ),
      trailing: SizedBox(
        width: 132,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Decrement button — disabled (grey) when servings == 0
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: servings > 0 ? const Color(0xFF74BC42) : Colors.grey,
              onPressed: servings > 0 ? onDecrement : null,
            ),
            Text(
              '$servings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF74BC42) : Colors.black54,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: const Color(0xFF74BC42),
              onPressed: onIncrement,
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }

  /// Shared recipe list widget used in both the planning modal sheet and
  /// the log tab.
  ///
  /// Sort order: recipes with servings > 0 float to the top (sorted by
  /// serving count desc), then unselected recipes sorted alphabetically.
  ///
  /// [localServingsByTitle]: when provided (planning sheet), serving changes
  /// are applied to this local map so the sheet shows up-to-date counts
  /// without waiting for the ChangeNotifier to propagate.
  Widget _buildRecipeListForDay({
    required DateTime day,
    required bool forLog,
    required String query,
    required String searchHint,
    required ValueChanged<String> onQueryChanged,
    VoidCallback? onServingsChanged,
    Map<String, int>? localServingsByTitle,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  }) {
    final servingsByTitle = _servingsByTitle(day, forLog: forLog);

    // Read from localServingsByTitle (sheet state) if provided, otherwise
    // fall back to the live service state.
    int servingsForTitle(String title) {
      if (localServingsByTitle != null) {
        return localServingsByTitle[title] ?? 0;
      }
      return servingsByTitle[title] ?? 0;
    }

    // Update the local map (planning sheet only) to keep sheet state in sync
    // with stepper interactions before ChangeNotifier fires.
    void updateLocalServings(String title, int servings) {
      if (localServingsByTitle == null) {
        return;
      }
      if (servings <= 0) {
        localServingsByTitle.remove(title);
      } else {
        localServingsByTitle[title] = servings;
      }
    }

    final recipes = _filterRecipes(query);

    // Sort: selected recipes first (by serving count desc), then alphabetical.
    final sortedRecipes = List<RecipeModel>.from(recipes)
      ..sort((a, b) {
        final servingsA = servingsForTitle(a.title);
        final servingsB = servingsForTitle(b.title);

        final hasServingsA = servingsA > 0;
        final hasServingsB = servingsB > 0;

        if (hasServingsA != hasServingsB) {
          return hasServingsA ? -1 : 1;
        }

        if (servingsA != servingsB) {
          return servingsB.compareTo(servingsA);
        }

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74BC42)),
      );
    }

    if (recipes.isEmpty) {
      return const Center(
        child: Text(
          'No recipes match your search.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Search field for filtering the recipe list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: padding,
            itemCount: sortedRecipes.length,
            itemBuilder: (context, index) {
              final recipe = sortedRecipes[index];
              final servings = servingsForTitle(recipe.title);

              return _buildRecipeListTile(
                recipe: recipe,
                servings: servings,
                // Increment: add one serving and notify parent
                onIncrement: () {
                  final nextServings = servings + 1;
                  _setServings(
                    day,
                    recipe,
                    nextServings,
                    forLog: forLog,
                  );
                  updateLocalServings(recipe.title, nextServings);
                  if (onServingsChanged != null) {
                    onServingsChanged();
                  } else {
                    setState(() {});
                  }
                },
                // Decrement: remove one serving (clamped to 0 in _setServings)
                onDecrement: () {
                  final nextServings = servings - 1;
                  _setServings(
                    day,
                    recipe,
                    nextServings,
                    forLog: forLog,
                  );
                  updateLocalServings(recipe.title, nextServings);
                  if (onServingsChanged != null) {
                    onServingsChanged();
                  } else {
                    setState(() {});
                  }
                },
                // Tile tap: toggle 0→1 or 1→0 (quick add / remove)
                onTap: () {
                  final nextServings = servings > 0 ? 0 : 1;
                  _setServings(
                    day,
                    recipe,
                    nextServings,
                    forLog: forLog,
                  );
                  updateLocalServings(recipe.title, nextServings);
                  if (onServingsChanged != null) {
                    onServingsChanged();
                  } else {
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Converts all planned meals for [day] into shopping list entries.
  ///
  /// Uses firstWhere + orElse guard pattern to safely skip meals whose
  /// recipe titles don't match any loaded recipe (e.g. stale plan data).
  /// Passes plannedDate to ShoppingListService so the shopping list can
  /// group by date in its "Add to List" workflow.
  void _addPlanToShoppingList(DateTime day) {
    final meals = _mealPlanService.mealsForDay(day);
    final shoppingService = ShoppingListService();
    for (final meal in meals) {
      // orElse returns a dummy; the guard below skips it if title doesn't match
      final recipe = _availableRecipes.firstWhere(
        (r) => r.title == meal.recipeTitle,
        orElse: () => _availableRecipes.first,
      );
      if (recipe.title != meal.recipeTitle) continue;
      shoppingService.addIngredients(
        recipe.ingredients.map((i) => i.displayLabel).toList(),
        recipeTitle: recipe.title,
      );
      shoppingService.addRecipe(ShoppingRecipeEntry(
        recipeTitle: recipe.title,
        caloriesPerServing: recipe.nutrition.calories,
        proteinPerServing:
            double.tryParse(recipe.nutrition.protein.replaceAll('g', '')) ?? 0,
        carbsPerServing:
            double.tryParse(recipe.nutrition.carbs.replaceAll('g', '')) ?? 0,
        fatsPerServing:
            double.tryParse(recipe.nutrition.fats.replaceAll('g', '')) ?? 0,
        // plannedDate links shopping items to this planned day
        plannedDate: DateTime(day.year, day.month, day.day),
      ));
    }
  }

  /// Opens the day planning modal bottom sheet for [day].
  ///
  /// Uses showModalBottomSheet + StatefulBuilder so that:
  ///   • sheetQuery (search field) and sheetServingsByTitle (local serving
  ///     counts) are local to the sheet without needing a separate widget.
  ///   • setModalState rebuilds only the sheet; setState rebuilds the calendar
  ///     grid behind it.
  ///
  /// Header buttons (conditional):
  ///   • "Add to List" — only shown for future dates (including today)
  ///     with at least one planned meal. Opens a confirmation AlertDialog.
  ///   • "Clear" — removes all planned meals for the day.
  void _openDaySheet(DateTime day) {
    final sheetServingsByTitle = _servingsByTitle(day, forLog: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final isFuture = !normalizedDay.isBefore(today); // includes today

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String sheetQuery = '';

        // StatefulBuilder: local state management for the sheet without
        // promoting to a full StatefulWidget class.
        return StatefulBuilder(builder: (ctx, setModalState) {
          final hasMeals = _mealPlanService.mealsForDay(day).isNotEmpty;

          return SafeArea(
            child: Padding(
              // Shift content up when keyboard appears
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: Column(
                  children: [
                    // ── Green gradient header ──────────────────────────
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF74BC42), Color(0xFF5FA832)],
                        ),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Column(
                        children: [
                          // Drag handle (visual affordance for the bottom sheet)
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${day.day} ${_monthName(day.month)} ${day.year}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                // "Add to List" — future dates only, when meals are planned
                                if (isFuture && hasMeals)
                                  TextButton.icon(
                                    icon: const Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 16,
                                        color: Colors.white),
                                    label: const Text('Add to List',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    onPressed: () {
                                      final meals =
                                          _mealPlanService.mealsForDay(day);
                                      // Confirmation dialog before bulk-adding to list
                                      showDialog<void>(
                                        context: ctx,
                                        builder: (_) => AlertDialog(
                                          title: const Text(
                                              'Add to Shopping List'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                  'Add ingredients for these planned meals?'),
                                              const SizedBox(height: 12),
                                              // List each planned meal with a restaurant icon
                                              ...meals.map((m) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.restaurant,
                                                            size: 16,
                                                            color: Color(
                                                                0xFF74BC42)),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                            child: Text(
                                                                m.recipeTitle)),
                                                      ],
                                                    ),
                                                  )),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF74BC42),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                // Call _addPlanToShoppingList after confirmation
                                                _addPlanToShoppingList(day);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                  content: Text(
                                                      'Ingredients added to shopping list!'),
                                                  backgroundColor:
                                                      Color(0xFF74BC42),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ));
                                              },
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                // "Clear" removes all planned meals for the day
                                TextButton(
                                  onPressed: () {
                                    _mealPlanService.clearDay(day);
                                    setModalState(() {
                                      sheetServingsByTitle.clear();
                                    });
                                    setState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.white),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Recipe list fills remaining sheet space
                    Expanded(
                      child: _buildRecipeListForDay(
                        day: day,
                        forLog: false, // planning mode
                        query: sheetQuery,
                        searchHint: 'Search recipes to plan',
                        localServingsByTitle: sheetServingsByTitle,
                        // onServingsChanged: rebuilds both the sheet and the grid
                        onServingsChanged: () {
                          setModalState(() {});
                          setState(() {});
                        },
                        onQueryChanged: (value) {
                          setModalState(() {
                            sheetQuery = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  /// Converts a month number (1–12) to a short three-letter abbreviation.
  String _monthName(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m];
  }

  // ──────────────────────────────────────────────────────────────────────
  // Planning tab: month-grid calendar
  // ──────────────────────────────────────────────────────────────────────
  //
  // Layout: month header (prev/next chevrons) + day-of-week row + GridView.
  //
  // GridView mechanics:
  //   • crossAxisCount: 7 (one column per weekday)
  //   • startWeekday = first.weekday % 7  (converts Mon=1…Sun=7 → Sun=0)
  //   • Empty leading cells (before the 1st) return SizedBox.shrink()
  //   • childAspectRatio: calculated from actual cell width so height fits
  //     exactly on screen without requiring a fixed pixel value.
  //
  // Cell visual states:
  //   • past date    → grey bg, grey text, non-tappable
  //   • today        → light-green bg, brand-green 2px border
  //   • future+meals → very light green bg, subtle green border
  //   • future empty → white bg, grey border
  //   • hasMeals     → green pill badge showing total serving count
  Widget _buildPlanningTab() {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // startWeekday: offset from Sunday (0) so the first day of month lands
    // in the correct column. Dart DateTime.weekday is Mon=1…Sun=7;
    // % 7 remaps Sun=7 to 0, keeping Mon–Sat as 1–6.
    final startWeekday = first.weekday % 7;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    const horizontalPadding = 16.0 * 2;
    const spacing = 4.0;
    const crossAxisCount = 7;
    final bool isNarrow = screenWidth < 420;
    final desiredCellHeight = isNarrow ? 92.0 : 72.0;
    // Compute exact cell width to derive aspect ratio programmatically
    final cellWidth =
        (screenWidth - horizontalPadding - (crossAxisCount - 1) * spacing) /
            crossAxisCount;
    final childAspectRatio = cellWidth / desiredCellHeight;

    const brandGreen = Color(0xFF74BC42);
    const darkGreen = Color(0xFF4E8A2B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Month navigation header with chevron buttons
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [brandGreen, Color(0xFF5FA832)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthName(month)} $year',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Day-of-week header row (Sun–Sat)
          Container(
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              children: [
                Expanded(child: Center(child: Text('Sun', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Mon', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Tue', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Wed', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Thu', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Fri', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Sat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Calendar grid: rows * 7 cells, empty cells for month alignment
          GridView.builder(
            shrinkWrap: true,
            // NeverScrollableScrollPhysics: scrolling delegated to the outer
            // SingleChildScrollView.
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              // Convert grid index to day-of-month number
              final dayIndex = index - startWeekday + 1;
              final inMonth = dayIndex >= 1 && dayIndex <= daysInMonth;
              // Cells before the 1st or after the last are invisible
              if (!inMonth) return const SizedBox.shrink();

              final day = DateTime(year, month, dayIndex);
              final meals = _mealPlanService.mealsForDay(day);
              // Total servings across all meals on this day (for badge pill)
              final servings =
                  meals.fold<int>(0, (sum, meal) => sum + meal.servings);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              final isPast = day.isBefore(today);
              final hasMeals = servings > 0;

              return GestureDetector(
                // Past dates are not tappable — cannot plan into the past
                onTap: isPast ? null : () => _openDaySheet(day),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFFF5F5F5)
                        : isToday
                            ? const Color(0xFFE8F5DC)
                            : hasMeals
                                ? const Color(0xFFF0FAE8)
                                : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPast
                          ? const Color(0xFFE0E0E0)
                          : isToday
                              ? brandGreen       // thick green border for today
                              : hasMeals
                                  ? const Color(0xFFB4DCA0)
                                  : const Color(0xFFE8E8E8),
                      width: isToday ? 2 : 1,   // today gets 2px border
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day number
                      Text(
                        '$dayIndex',
                        style: TextStyle(
                          fontSize: isNarrow ? 13 : 12,
                          fontWeight: FontWeight.bold,
                          color: isPast
                              ? Colors.grey[400]
                              : isToday
                                  ? darkGreen
                                  : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Green serving-count badge when meals are planned
                      if (hasMeals)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: brandGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$servings',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap today or a future date to plan meals. Future dates show an option to add ingredients to your shopping list.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Log tab: record meals eaten on a chosen date
  // ──────────────────────────────────────────────────────────────────────
  //
  // showDatePicker is themed with brand-green via ColorScheme.light(primary).
  // The picker is limited to dates up to today (lastDate: DateTime.now())
  // because logging future meals doesn't make sense.
  //
  // totalsForDay() returns a MealTotals object with totalServings used
  // to show the "X serving(s) logged" header line.
  Widget _buildLogTab() {
    final totals = _mealLogService.totalsForDay(_logDate);
    final now = DateTime.now();
    final isToday = _logDate.year == now.year &&
        _logDate.month == now.month &&
        _logDate.day == now.day;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.today, color: Color(0xFF74BC42)),
              const SizedBox(width: 8),
              // Show "Today" for the current date, otherwise the formatted date
              Text(
                isToday
                    ? 'Today'
                    : '${_logDate.day} ${_monthName(_logDate.month)} ${_logDate.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              // Date picker button: opens a calendar constrained to past+today
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _logDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(), // cannot log future meals
                    // Theme override to use brand-green for the picker header
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF74BC42),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _logDate = picked;
                      _todaySearchQuery = ''; // reset search on date change
                    });
                  }
                },
                icon: const Icon(Icons.edit_calendar, size: 14),
                label: const Text('Change Date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF74BC42),
                  side: const BorderSide(color: Color(0xFF74BC42)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              // Clear all logged meals for the selected date
              TextButton(
                onPressed: () {
                  _mealLogService.clearDay(_logDate);
                  setState(() {});
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${totals.totalServings} serving(s) logged',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        // Reuse the shared recipe list widget for log mode
        Expanded(
          child: _buildRecipeListForDay(
            day: _logDate,
            forLog: true, // log mode — writes to MealLogService
            query: _todaySearchQuery,
            searchHint: 'Search recipes to log',
            onQueryChanged: (value) {
              setState(() {
                _todaySearchQuery = value;
              });
            },
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController creates a TabController without needing
    // SingleTickerProviderStateMixin (since the tab bar is simple here).
    return NavBarScaffold(
      title: 'Meal Calendar',
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF74BC42),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF74BC42),
              tabs: [
                Tab(text: 'Planning'),
                Tab(text: 'Log'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlanningTab(),
                  _buildLogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
