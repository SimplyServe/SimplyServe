// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/services/profile_service.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/widgets/navbar.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  static String _formatNumber(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    if (isWhole) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final MealLogService _mealLogService = MealLogService();
  final ProfileService _profileService = ProfileService();
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final userData = await _profileService.getCurrentUser();
    final name = (userData?['name'] ?? '').toString().trim();
    if (!mounted) return;
    setState(() {
      _displayName = name.isEmpty ? null : name;
    });
  }

  String get _welcomeMessage {
    if (_displayName == null) {
      return 'Welcome Back!';
    }
    return 'Welcome Back $_displayName!';
  }

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Dashboard',
      body: AnimatedBuilder(
        animation: _mealLogService,
        builder: (context, _) {
          final totals = _mealLogService.totalsForDay(DateTime.now());
          final meals = _mealLogService.mealsForDay(DateTime.now());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _welcomeMessage,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Here is your daily nutritional summary.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Macro Counter (always visible) ──────────────────────
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Text('🔥', style: TextStyle(fontSize: 20)),
                                SizedBox(width: 6),
                                Text(
                                  'Calories Today',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${DashboardView._formatNumber(totals.calories)} kcal',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _MacroLegendItem(
                              icon: '🍗',
                              label: 'Protein',
                              value:
                                  '${DashboardView._formatNumber(totals.protein)}g',
                            ),
                            _MacroLegendItem(
                              icon: '🍞',
                              label: 'Carbs',
                              value:
                                  '${DashboardView._formatNumber(totals.carbs)}g',
                            ),
                            _MacroLegendItem(
                              icon: '🥑',
                              label: 'Fat',
                              value:
                                  '${DashboardView._formatNumber(totals.fats)}g',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Today's Meals ───────────────────────────────────────
                const Text(
                  "Today's Meals",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (!totals.hasData) ...[
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No meals logged yet. Log meals from the Meal Calendar or Shopping List.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MealCalendarView(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Log meals in calendar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ...meals.map(
                    (meal) => _LoggedMealTile(
                      meal: meal,
                      onRemove: () {
                        _mealLogService.removeMeal(
                            DateTime.now(), meal.recipeTitle);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Action Buttons ──────────────────────────────────────
                const Text(
                  'Looking for meal ideas?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const _RecipeLinkButton(),
                const SizedBox(height: 8),
                const _SpinnerLinkButton(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _MacroLegendItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _MacroLegendItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _LoggedMealTile extends StatelessWidget {
  final LoggedMeal meal;
  final VoidCallback onRemove;

  const _LoggedMealTile({required this.meal, required this.onRemove});

  static String _formatNumber(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    if (isWhole) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final totalCalories = meal.caloriesPerServing * meal.servings;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.recipeTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.servings} serving(s) \u2022 ${_formatNumber(totalCalories.toDouble())} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onRemove,
              tooltip: 'Remove meal',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeLinkButton extends StatelessWidget {
  const _RecipeLinkButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/recipes'),
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Browse Recipes'),
      ),
    );
  }
}

class _SpinnerLinkButton extends StatelessWidget {
  const _SpinnerLinkButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/spin'),
        icon: const Icon(Icons.casino),
        label: const Text('Meal Spinner'),
      ),
    );
  }
}
