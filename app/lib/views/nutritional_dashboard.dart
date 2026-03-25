import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  // Swap these for your real data source when ready
  static const double _calories = 1840;
  static const double _protein  = 120;
  static const double _carbs    = 210;
  static const double _fat      = 55;

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [

            // ── Greeting ─────────────────────────────────────────────
            Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Here is your daily nutritional summary.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),

            // ── Calorie summary card ──────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Calories Today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$_calories kcal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // ── Macros heading ────────────────────────────────────────
            Text(
              'Macronutrients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),

            // ── Macro legend ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MacroLegendItem(color: Colors.blue,   label: 'Protein', value: '${_protein}g'),
                _MacroLegendItem(color: Colors.orange, label: 'Carbs',   value: '${_carbs}g'),
                _MacroLegendItem(color: Colors.red,    label: 'Fat',     value: '${_fat}g'),
              ],
            ),
            SizedBox(height: 24),

            // ── Macro breakdown cards ─────────────────────────────────
            Text(
              'Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _MacroCard(label: 'Protein', value: _protein, unit: 'g', color: Colors.blue),
            SizedBox(height: 8),
            _MacroCard(label: 'Carbohydrates', value: _carbs, unit: 'g', color: Colors.orange),
            SizedBox(height: 8),
            _MacroCard(label: 'Fat', value: _fat, unit: 'g', color: Colors.red),
            SizedBox(height: 24),

            // ── Quick link to recipes ─────────────────────────────────
            Text(
              'Looking for meal ideas?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            _RecipeLinkButton(),
            SizedBox(height: 24),

          ],
        ),
      ),
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _MacroLegendItem extends StatelessWidget {
  final Color  color;
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
        Text(value,  style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color  color;

  const _MacroCard({
    required this.label,
    required this.value,
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
              '$value$unit',
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