import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/services/meal_plan_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

class MealCalendarView extends StatefulWidget {
  const MealCalendarView({super.key});

  @override
  State<MealCalendarView> createState() => _MealCalendarViewState();
}

class _MealCalendarViewState extends State<MealCalendarView> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final MealLogService _mealLogService = MealLogService();
  final MealPlanService _mealPlanService = MealPlanService();
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();
  String _todaySearchQuery = '';

  bool _isLoading = true;
  List<RecipeModel> _availableRecipes = [];

  @override
  void initState() {
    super.initState();
    _mealLogService.addListener(_onCalendarDataChanged);
    _mealPlanService.addListener(_onCalendarDataChanged);
    _fetchRecipes();
  }

  @override
  void dispose() {
    _mealLogService.removeListener(_onCalendarDataChanged);
    _mealPlanService.removeListener(_onCalendarDataChanged);
    super.dispose();
  }

  void _onCalendarDataChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _fetchRecipes() async {
    final recipes = await _recipeCatalogService.getAllRecipes();
    if (mounted) {
      setState(() {
        _availableRecipes = recipes;
        _isLoading = false;
      });
    }
  }

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

    int servingsForTitle(String title) {
      if (localServingsByTitle != null) {
        return localServingsByTitle[title] ?? 0;
      }
      return servingsByTitle[title] ?? 0;
    }

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

  void _openDaySheet(DateTime day) {
    final sheetServingsByTitle = _servingsByTitle(day, forLog: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String sheetQuery = '';

        return StatefulBuilder(builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '${day.day} ${_monthName(day.month)} ${day.year}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _mealPlanService.clearDay(day);
                              setModalState(() {
                                sheetServingsByTitle.clear();
                              });
                              setState(() {});
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildRecipeListForDay(
                        day: day,
                        forLog: false,
                        query: sheetQuery,
                        searchHint: 'Search recipes to plan',
                        localServingsByTitle: sheetServingsByTitle,
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

  Widget _buildPlanningTab() {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startWeekday = first.weekday % 7; // Make Sunday=0
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    const horizontalPadding = 16.0 * 2;
    const spacing = 6.0;
    const crossAxisCount = 7;
    final bool isNarrow = screenWidth < 420;
    final desiredCellHeight = isNarrow ? 92.0 : 72.0;
    final cellWidth =
        (screenWidth - horizontalPadding - (crossAxisCount - 1) * spacing) /
            crossAxisCount;
    final childAspectRatio = cellWidth / desiredCellHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  });
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_monthName(month)} $year',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: Center(child: Text('Sun'))),
              Expanded(child: Center(child: Text('Mon'))),
              Expanded(child: Center(child: Text('Tue'))),
              Expanded(child: Center(child: Text('Wed'))),
              Expanded(child: Center(child: Text('Thu'))),
              Expanded(child: Center(child: Text('Fri'))),
              Expanded(child: Center(child: Text('Sat'))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              final dayIndex = index - startWeekday + 1;
              final inMonth = dayIndex >= 1 && dayIndex <= daysInMonth;
              if (!inMonth) {
                return Container();
              }

              final day = DateTime(year, month, dayIndex);
              final meals = _mealPlanService.mealsForDay(day);
              final servings =
                  meals.fold<int>(0, (sum, meal) => sum + meal.servings);
              final today = DateTime.now();
              final isToday = day.day == today.day &&
                  day.month == today.month &&
                  day.year == today.year;

              return GestureDetector(
                onTap: () => _openDaySheet(day),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayIndex',
                        style: TextStyle(
                          fontSize: isNarrow ? 13 : 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isToday ? const Color(0xFF74BC42) : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      if (servings > 0)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF74BC42),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '$servings',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
            'Tap any date box to plan future meals or backfill past meals.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    final today = DateTime.now();
    final totals = _mealLogService.totalsForDay(today);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.today, color: Color(0xFF74BC42)),
              const SizedBox(width: 8),
              Text(
                'Today: ${today.day} ${_monthName(today.month)} ${today.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _mealLogService.clearDay(today);
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
              '${totals.totalServings} serving(s) logged today',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          child: _buildRecipeListForDay(
            day: today,
            forLog: true,
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
