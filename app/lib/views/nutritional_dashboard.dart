import 'package:flutter/material.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/widgets/navbar.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  static String _formatNumber(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    if (isWhole) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final mealLogService = MealLogService();

    return NavBarScaffold(
      title: 'Dashboard',
      body: AnimatedBuilder(
        animation: mealLogService,
        builder: (context, _) {
          final totals = mealLogService.totalsForDay(DateTime.now());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(
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
                if (!totals.hasData) ...[
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.insights_outlined,
                                  color: Color(0xFF74BC42)),
                              SizedBox(width: 8),
                              Text(
                                'No data to show yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Log what you ate in Meal Calendar, including servings, and your totals for today will appear here.',
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
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Calories Today',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_formatNumber(totals.calories)} kcal',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${totals.totalServings} serving(s) across ${totals.totalRecipes} recipe(s) logged for today',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Macronutrients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MacroLegendItem(
                        color: const Color(0xFF74BC42),
                        label: 'Protein',
                        value: '${_formatNumber(totals.protein)}g',
                      ),
                      _MacroLegendItem(
                        color: Colors.orange,
                        label: 'Carbs',
                        value: '${_formatNumber(totals.carbs)}g',
                      ),
                      _MacroLegendItem(
                        color: Colors.red,
                        label: 'Fat',
                        value: '${_formatNumber(totals.fats)}g',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MacroCard(
                    label: 'Protein',
                    valueLabel: _formatNumber(totals.protein),
                    unit: 'g',
                    color: const Color(0xFF74BC42),
                  ),
                  const SizedBox(height: 8),
                  _MacroCard(
                    label: 'Carbohydrates',
                    valueLabel: _formatNumber(totals.carbs),
                    unit: 'g',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _MacroCard(
                    label: 'Fat',
                    valueLabel: _formatNumber(totals.fats),
                    unit: 'g',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                ],
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
  final Color color;
  final String label;
  final String value;

  const _MacroLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(backgroundColor: color, radius: 7),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String valueLabel;
  final String unit;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.valueLabel,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            Text(
              '$valueLabel$unit',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
