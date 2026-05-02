// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _profileImageUrl;
  bool _showCoachButton = false;

  // Calorie Coach targets
  double? _calorieTarget;
  double? _proteinTarget;
  double? _carbTarget;
  double? _fatTarget;

  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);

  // SharedPreferences keys (must match CalorieCoachView)
  static const _kCalorieTarget = 'cc_calorie_target';
  static const _kProteinTarget = 'cc_protein_target';
  static const _kCarbTarget = 'cc_carb_target';
  static const _kFatTarget = 'cc_fat_target';
  static const _kCompleted = 'cc_completed';

  // Profile keys from Calorie Coach
  static const _kHeight = 'cc_height';
  static const _kWeight = 'cc_weight';
  static const _kGender = 'cc_gender';
  static const _kActivity = 'cc_activity';
  static const _kHeightUnit = 'cc_height_unit';
  static const _kWeightUnit = 'cc_weight_unit';
  static const _kGoal = 'cc_goal';
  static const _kTargetWeight = 'cc_target_weight';

  // Profile state
  double? _height;
  double? _weight;
  String? _gender;
  String? _activity;
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  String? _goal;
  double? _targetWeight;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCoachData();
  }

  Future<void> _loadProfile() async {
    final userData = await _profileService.getCurrentUser();
    final name = (userData?['name'] ?? '').toString().trim();
    final rawUrl = (userData?['profile_image_url'] ?? '').toString().trim();
    final base = _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final fullImageUrl = rawUrl.isEmpty
        ? null
        : (rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl');

    if (!mounted) return;
    setState(() {
      _displayName = name.isEmpty ? null : name;
      _profileImageUrl = fullImageUrl;
    });
  }

  Future<void> _loadCoachData() async {
    final prefs = await SharedPreferences.getInstance();
    // _kCompleted is written by CalorieCoachView after finishing the questionnaire
    final completed = prefs.getBool(_kCompleted) ?? false;
    final calorieTarget = prefs.getDouble(_kCalorieTarget);
    final proteinTarget = prefs.getDouble(_kProteinTarget);
    final carbTarget = prefs.getDouble(_kCarbTarget);
    final fatTarget = prefs.getDouble(_kFatTarget);

    // Load profile fields saved by Calorie Coach
    final height = prefs.getDouble(_kHeight);
    final weight = prefs.getDouble(_kWeight);
    final gender = prefs.getString(_kGender);
    final activity = prefs.getString(_kActivity);
    final heightUnit = prefs.getString(_kHeightUnit) ?? 'cm';
    final weightUnit = prefs.getString(_kWeightUnit) ?? 'kg';
    final goal = prefs.getString(_kGoal);
    final targetWeight = prefs.getDouble(_kTargetWeight);

    if (!mounted) return;
    setState(() {
      _showCoachButton = !completed;
      _calorieTarget = calorieTarget;
      _proteinTarget = proteinTarget;
      _carbTarget = carbTarget;
      _fatTarget = fatTarget;
      _height = height;
      _weight = weight;
      _gender = gender;
      _activity = activity;
      _heightUnit = heightUnit;
      _weightUnit = weightUnit;
      _goal = goal;
      _targetWeight = targetWeight;
    });
  }

  /// Converts stored-cm height to a display string respecting the chosen unit.
  String _formatHeight(double cm) {
    if (_heightUnit == 'ft') {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return '${feet}ft ${inches}in';
    }
    return '${cm.round()} cm';
  }

  /// Converts stored-kg weight to a display string respecting the chosen unit.
  String _formatWeight(double kg) {
    if (_weightUnit == 'lb') {
      return '${(kg * 2.20462).round()} lb';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  /// Human-readable goal label.
  String get _goalLabel {
    switch (_goal) {
      case 'gain':
        return 'Gain Weight';
      case 'lose':
        return 'Lose Weight';
      case 'maintain':
      default:
        return 'Maintain Weight';
    }
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
      body: ColoredBox(
        color: _surfaceGreen,
        child: AnimatedBuilder(
          animation: _mealLogService,
          builder: (context, _) {
            final totals = _mealLogService.totalsForDay(DateTime.now());
            final meals = _mealLogService.mealsForDay(DateTime.now());

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome Header ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF74BC42), Color(0xFF4E8A2B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _brandGreen.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _welcomeMessage,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Here is your daily nutritional summary.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 26)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Macro Counter ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE7EEE2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Card header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF1FAEC), Colors.white],
                            ),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _brandGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('🔥',
                                    style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Calories Today',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF24421A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _brandGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _calorieTarget != null
                                      ? '${DashboardView._formatNumber(totals.calories)} / ${_calorieTarget!.round()} kcal'
                                      : '${DashboardView._formatNumber(totals.calories)} kcal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _brandGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Macro row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _MacroLegendItem(
                                icon: '🍗',
                                label: 'Protein',
                                value: _proteinTarget != null
                                    ? '${DashboardView._formatNumber(totals.protein)}/${_proteinTarget!.round()}g'
                                    : '${DashboardView._formatNumber(totals.protein)}g',
                              ),
                              _MacroLegendItem(
                                icon: '🍞',
                                label: 'Carbs',
                                value: _carbTarget != null
                                    ? '${DashboardView._formatNumber(totals.carbs)}/${_carbTarget!.round()}g'
                                    : '${DashboardView._formatNumber(totals.carbs)}g',
                              ),
                              _MacroLegendItem(
                                icon: '🥑',
                                label: 'Fat',
                                value: _fatTarget != null
                                    ? '${DashboardView._formatNumber(totals.fats)}/${_fatTarget!.round()}g'
                                    : '${DashboardView._formatNumber(totals.fats)}g',
                              ),
                            ],
                          ),
                        ),

                        // ── Coach progress bars (shown when targets exist) ──
                        if (_calorieTarget != null || _proteinTarget != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 1, color: Color(0xFFE7EEE2)),
                                const SizedBox(height: 14),
                                if (_calorieTarget != null) ...[
                                  _CoachProgressBar(
                                    label: 'Calories',
                                    consumed: totals.calories,
                                    target: _calorieTarget!,
                                    unit: 'kcal',
                                    color: const Color(0xFFFF8F00),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_proteinTarget != null) ...[
                                  _CoachProgressBar(
                                    label: 'Protein',
                                    consumed: totals.protein,
                                    target: _proteinTarget!,
                                    unit: 'g',
                                    color: const Color(0xFF74BC42),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_carbTarget != null) ...[
                                  _CoachProgressBar(
                                    label: 'Carbs',
                                    consumed: totals.carbs,
                                    target: _carbTarget!,
                                    unit: 'g',
                                    color: const Color(0xFF42A5F5),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_fatTarget != null)
                                  _CoachProgressBar(
                                    label: 'Fat',
                                    consumed: totals.fats,
                                    target: _fatTarget!,
                                    unit: 'g',
                                    color: const Color(0xFFAB47BC),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Your Profile Card ──────────────────────────────────
                  if (_height != null || _weight != null || _gender != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7EEE2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF1FAEC), Colors.white],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _brandGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: _brandGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Your Profile',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF24421A),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                            context, '/calorie-coach')
                                        .then((_) => _loadCoachData());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _brandGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _brandGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Profile stat grid
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    if (_height != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons.height_rounded,
                                          label: 'Height',
                                          value: _formatHeight(_height!),
                                          iconColor: const Color(0xFF42A5F5),
                                        ),
                                      ),
                                    if (_weight != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons.monitor_weight_outlined,
                                          label: 'Weight',
                                          value: _formatWeight(_weight!),
                                          iconColor: const Color(0xFFAB47BC),
                                        ),
                                      ),
                                    if (_gender != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons.wc_rounded,
                                          label: 'Gender',
                                          value: _gender!,
                                          iconColor: const Color(0xFFFF8F00),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_activity != null || _goal != null) ...[
                                  const SizedBox(height: 10),
                                  const Divider(
                                      height: 1, color: Color(0xFFE7EEE2)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (_activity != null)
                                        Expanded(
                                          child: _ProfileStatTile(
                                            icon: Icons.directions_run_rounded,
                                            label: 'Activity',
                                            value: _activity!,
                                            iconColor: _brandGreen,
                                          ),
                                        ),
                                      if (_goal != null)
                                        Expanded(
                                          child: _ProfileStatTile(
                                            icon: _goal == 'gain'
                                                ? Icons.trending_up
                                                : _goal == 'lose'
                                                    ? Icons.trending_down
                                                    : Icons.balance_rounded,
                                            label: 'Goal',
                                            value: _goalLabel,
                                            iconColor: _goal == 'gain'
                                                ? const Color(0xFF66BB6A)
                                                : _goal == 'lose'
                                                    ? const Color(0xFFEF5350)
                                                    : const Color(0xFF42A5F5),
                                          ),
                                        ),
                                      if (_goal != 'maintain' &&
                                          _targetWeight != null)
                                        Expanded(
                                          child: _ProfileStatTile(
                                            icon: Icons.flag_rounded,
                                            label: 'Target',
                                            value: _formatWeight(_targetWeight!),
                                            iconColor: const Color(0xFFFF8F00),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Today's Meals ──────────────────────────────────────
                  const Text(
                    "Today's Meals",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24421A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_mealLogService.hasAnyMeals) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7EEE2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.no_meals_rounded,
                                    color: Colors.grey, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'No meals logged yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF24421A),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Log meals from the Meal Calendar or Shopping List.',
                            style: TextStyle(
                                color: Color(0xFF5F7559), fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (totals.hasData) ...[
                    ...meals.map(
                      (meal) => _LoggedMealTile(
                        meal: meal,
                        onRemove: () {
                          _mealLogService.removeMeal(
                              DateTime.now(), meal.recipeTitle);
                        },
                      ),
                    ),
                  ] else if (_mealLogService.hasAnyMeals) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No meals logged for today.',
                        style: TextStyle(
                            color: const Color(0xFF5F7559), fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Coach Button (first-time users only) ───────────────
                  if (_showCoachButton) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFFFE082).withValues(alpha: 0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFFDE7), Colors.white],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6F00)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.local_fire_department,
                                      color: Color(0xFFFF6F00),
                                      size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Set Up Your Calorie Coach',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF24421A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Get personalized calorie and protein targets based on your body and goals.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.5),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                              context, '/calorie-coach')
                                          .then((_) {
                                        _loadCoachData();
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text('Start Calorie Coach'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF8F00),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Action Buttons ─────────────────────────────────────
                  const Text(
                    'Looking for meal ideas?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24421A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _RecipeLinkButton(),
                  const SizedBox(height: 10),
                  const _SpinnerLinkButton(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────────

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
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF5F7559))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF24421A))),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EEE2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF74BC42).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded,
                  color: Color(0xFF74BC42), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.recipeTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF24421A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${meal.servings} serving(s) \u2022 ${_formatNumber(totalCalories.toDouble())} kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F7559),
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
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF74BC42),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _CoachProgressBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final String unit;
  final Color color;

  const _CoachProgressBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0);
    final remaining = (target - consumed).clamp(0.0, double.infinity);
    final isOver = consumed > target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF24421A),
              ),
            ),
            Text(
              isOver
                  ? '${DashboardView._formatNumber(consumed - target)}$unit over'
                  : '${DashboardView._formatNumber(remaining)}$unit remaining',
              style: TextStyle(
                fontSize: 12,
                color: isOver ? Colors.redAccent : const Color(0xFF5F7559),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? Colors.redAccent : color,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${DashboardView._formatNumber(consumed)} / ${DashboardView._formatNumber(target)} $unit',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A9A85)),
        ),
      ],
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _ProfileStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5F7559),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24421A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF74BC42),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF74BC42)),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
