// ignore_for_file: prefer_const_constructors

// ============================================================
// views/nutritional_dashboard.dart — Nutritional Dashboard View
//
// The main landing screen after login. Shows:
//   1. A branded welcome header with the user's name + avatar.
//   2. A "Calories Today" macro card — protein/carbs/fat totals
//      for today, pulled live from MealLogService.
//   3. Calorie Coach progress bars (only when targets have been
//      set via CalorieCoachView) using LinearProgressIndicator.
//      Bars turn red when the user exceeds their target.
//   4. A "Your Profile" card with body stats from Calorie Coach.
//   5. Today's logged meals as deletable tiles.
//   6. A Calorie Coach CTA card (hidden once the Coach is done).
//   7. "Browse Recipes" and "Meal Spinner" link buttons.
//
// State management pattern:
//   AnimatedBuilder listens to MealLogService (a ChangeNotifier)
//   so only the body rebuilds on meal changes — the scaffold chrome
//   (AppBar, Drawer) is unaffected. This is more efficient than
//   wrapping the whole tree in a Consumer.
//
// Calorie Coach data is read from SharedPreferences using the same
// 'cc_*' keys written by CalorieCoachView. The keys are defined as
// static const strings to ensure consistency.
//
// Route: '/'  (the root route — registered in main.dart)
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/services/meal_log_service.dart';
import 'package:simplyserve/services/profile_service.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/widgets/navbar.dart';

/// The main dashboard showing nutrition totals, coach targets, and today's meals.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  /// Formats a double for display: uses an integer representation when the
  /// value is whole (e.g. 200 instead of 200.0), otherwise one decimal place.
  static String _formatNumber(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    if (isWhole) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  /// ChangeNotifier service that holds today's logged meals. Passed to
  /// AnimatedBuilder in build() so the dashboard reacts to meal changes.
  final MealLogService _mealLogService = MealLogService();

  /// Service for fetching the user's display name and avatar URL.
  final ProfileService _profileService = ProfileService();

  String? _displayName;
  String? _profileImageUrl;

  /// Whether to show the Calorie Coach CTA card. Hidden once the user
  /// has completed the Coach questionnaire (cc_completed == true).
  bool _showCoachButton = false;

  // ── Coach target fields ───────────────────────────────────────────────
  // Populated from SharedPreferences in _loadCoachData().
  double? _calorieTarget;
  double? _proteinTarget;
  double? _carbTarget;
  double? _fatTarget;

  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);

  // ── SharedPreferences keys (must match CalorieCoachView) ─────────────
  static const _kCalorieTarget = 'cc_calorie_target';
  static const _kProteinTarget = 'cc_protein_target';
  static const _kCarbTarget = 'cc_carb_target';
  static const _kFatTarget = 'cc_fat_target';
  static const _kCompleted = 'cc_completed';

  // Profile fields written by Calorie Coach
  static const _kHeight = 'cc_height';
  static const _kWeight = 'cc_weight';
  static const _kGender = 'cc_gender';
  static const _kActivity = 'cc_activity';
  static const _kHeightUnit = 'cc_height_unit';
  static const _kWeightUnit = 'cc_weight_unit';
  static const _kGoal = 'cc_goal';
  static const _kTargetWeight = 'cc_target_weight';

  // ── Profile stat fields ───────────────────────────────────────────────
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

  // ── Data loading ──────────────────────────────────────────────────────

  /// Fetches the user's display name and avatar from the backend API.
  /// Relative image URLs returned by the server are converted to full URLs
  /// by prepending [ProfileService.baseUrl].
  Future<void> _loadProfile() async {
    final userData = await _profileService.getCurrentUser();
    final name = (userData?['name'] ?? '').toString().trim();
    final rawUrl =
        (userData?['profile_image_url'] ?? '').toString().trim();
    final base =
        _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final fullImageUrl = rawUrl.isEmpty
        ? null
        : (rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl');

    if (!mounted) return;
    setState(() {
      _displayName = name.isEmpty ? null : name;
      _profileImageUrl = fullImageUrl;
    });
  }

  /// Reads all Calorie Coach values from SharedPreferences.
  /// _kCompleted controls whether the CTA card is shown.
  Future<void> _loadCoachData() async {
    final prefs = await SharedPreferences.getInstance();
    // cc_completed is written by CalorieCoachView when the user finishes
    // the questionnaire. Until then, show the CTA card.
    final completed = prefs.getBool(_kCompleted) ?? false;
    final calorieTarget = prefs.getDouble(_kCalorieTarget);
    final proteinTarget = prefs.getDouble(_kProteinTarget);
    final carbTarget = prefs.getDouble(_kCarbTarget);
    final fatTarget = prefs.getDouble(_kFatTarget);

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

  // ── Unit formatters ───────────────────────────────────────────────────

  /// Converts stored-cm height to a display string respecting [_heightUnit].
  String _formatHeight(double cm) {
    if (_heightUnit == 'ft') {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return '${feet}ft ${inches}in';
    }
    return '${cm.round()} cm';
  }

  /// Converts stored-kg weight to a display string respecting [_weightUnit].
  String _formatWeight(double kg) {
    if (_weightUnit == 'lb') return '${(kg * 2.20462).round()} lb';
    return '${kg.toStringAsFixed(1)} kg';
  }

  /// Human-readable label for the user's selected fitness goal.
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

  /// Personalised welcome message — includes the display name if available.
  String get _welcomeMessage {
    if (_displayName == null) return 'Welcome Back!';
    return 'Welcome Back $_displayName!';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Dashboard',
      body: ColoredBox(
        color: _surfaceGreen,
        // ── AnimatedBuilder — ChangeNotifier pattern ─────────────────
        // AnimatedBuilder registers as a listener on _mealLogService.
        // Whenever the service calls notifyListeners() (e.g. after a
        // meal is added/removed), Flutter calls builder() again with
        // the latest data. Only the body rebuilds, not the AppBar/Drawer.
        child: AnimatedBuilder(
          animation: _mealLogService,
          builder: (context, _) {
            // Recompute today's totals and meal list on every rebuild.
            final totals =
                _mealLogService.totalsForDay(DateTime.now());
            final meals =
                _mealLogService.mealsForDay(DateTime.now());

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome header ────────────────────────────────
                  // Gradient card with the personalised welcome message
                  // and the user's profile avatar thumbnail.
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF74BC42),
                          Color(0xFF4E8A2B)
                        ],
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                        // Avatar thumbnail — shows network image or person icon.
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.3),
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 26)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Macro counter card ────────────────────────────
                  // Shows kcal consumed today (vs target if set) and a
                  // macro row for protein/carbs/fat. When coach targets
                  // exist, progress bars are appended below the macro row.
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: const Color(0xFFE7EEE2)),
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
                        // Card header with kcal pill
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFF1FAEC),
                                Colors.white
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _brandGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(12),
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
                              // Pill: "consumed / target kcal" or just "consumed kcal"
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _brandGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(999),
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

                        // Macro legend row: protein / carbs / fat
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
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

                        // ── Coach progress bars ──────────────────────
                        // Only shown when the user has completed the
                        // Calorie Coach questionnaire. Each bar uses
                        // LinearProgressIndicator clamped to [0, 1].
                        // The bar and remaining-label turn red when over target.
                        if (_calorieTarget != null ||
                            _proteinTarget != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Divider(
                                    height: 1,
                                    color: Color(0xFFE7EEE2)),
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

                  // ── Your Profile card ─────────────────────────────
                  // Displays height, weight, gender, activity level, and
                  // goal from Calorie Coach. Shown only when data exists.
                  // "Edit" link navigates to CalorieCoachView and reloads
                  // data on return via .then(_loadCoachData).
                  if (_height != null ||
                      _weight != null ||
                      _gender != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFE7EEE2)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header with "Edit" button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                                16, 14, 16, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFF1FAEC),
                                  Colors.white
                                ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _brandGreen
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(12),
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
                                // "Edit" navigates to Calorie Coach and
                                // refreshes the profile data on return.
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
                                      color: _brandGreen
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(999),
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
                          // Profile stat grid (height / weight / gender / activity / goal)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    if (_height != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons.height_rounded,
                                          label: 'Height',
                                          value: _formatHeight(
                                              _height!),
                                          iconColor:
                                              const Color(0xFF42A5F5),
                                        ),
                                      ),
                                    if (_weight != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons
                                              .monitor_weight_outlined,
                                          label: 'Weight',
                                          value: _formatWeight(
                                              _weight!),
                                          iconColor:
                                              const Color(0xFFAB47BC),
                                        ),
                                      ),
                                    if (_gender != null)
                                      Expanded(
                                        child: _ProfileStatTile(
                                          icon: Icons.wc_rounded,
                                          label: 'Gender',
                                          value: _gender!,
                                          iconColor:
                                              const Color(0xFFFF8F00),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_activity != null ||
                                    _goal != null) ...[
                                  const SizedBox(height: 10),
                                  const Divider(
                                      height: 1,
                                      color: Color(0xFFE7EEE2)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (_activity != null)
                                        Expanded(
                                          child: _ProfileStatTile(
                                            icon: Icons
                                                .directions_run_rounded,
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
                                                    ? Icons
                                                        .trending_down
                                                    : Icons
                                                        .balance_rounded,
                                            label: 'Goal',
                                            value: _goalLabel,
                                            iconColor: _goal == 'gain'
                                                ? const Color(
                                                    0xFF66BB6A)
                                                : _goal == 'lose'
                                                    ? const Color(
                                                        0xFFEF5350)
                                                    : const Color(
                                                        0xFF42A5F5),
                                          ),
                                        ),
                                      if (_goal != 'maintain' &&
                                          _targetWeight != null)
                                        Expanded(
                                          child: _ProfileStatTile(
                                            icon: Icons.flag_rounded,
                                            label: 'Target',
                                            value: _formatWeight(
                                                _targetWeight!),
                                            iconColor:
                                                const Color(0xFFFF8F00),
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

                  // ── Today's meals ─────────────────────────────────
                  const Text(
                    "Today's Meals",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24421A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Empty state: prompt user to log meals via the calendar.
                  if (!_mealLogService.hasAnyMeals) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFE7EEE2)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.05),
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
                                  color: Colors.grey
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.no_meals_rounded,
                                    color: Colors.grey,
                                    size: 20),
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
                                color: Color(0xFF5F7559),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          // CTA button navigates to MealCalendarView via
                          // MaterialPageRoute (not a named route).
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MealCalendarView(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calendar_month),
                              label:
                                  const Text('Log meals in calendar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandGreen,
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

                  // Logged meal tiles for today; each shows calories and servings.
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
                    // Service has meals for other days but none today.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No meals logged for today.',
                        style: TextStyle(
                            color: const Color(0xFF5F7559),
                            fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Calorie Coach CTA ─────────────────────────────
                  // Only shown before the user completes the Coach
                  // questionnaire (_showCoachButton is set to false once
                  // cc_completed == true in SharedPreferences).
                  if (_showCoachButton) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFE082)
                              .withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                                16, 14, 16, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFFDE7),
                                  Colors.white
                                ],
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
                                    borderRadius:
                                        BorderRadius.circular(12),
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
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                                        // Reload data when the user returns
                                        // from the Coach questionnaire.
                                        _loadCoachData();
                                      });
                                    },
                                    icon: const Icon(
                                        Icons.arrow_forward),
                                    label: const Text(
                                        'Start Calorie Coach'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFFF8F00),
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
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

                  // ── Meal-idea link buttons ─────────────────────────
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

/// Displays one macro nutrient (protein/carbs/fat) with an emoji icon,
/// a label, and the consumed/target value. Used in the macro legend row.
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
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF5F7559))),
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

/// A dismissable tile for one logged meal showing its title, serving count,
/// and total calorie contribution. The delete icon removes it from MealLogService.
class _LoggedMealTile extends StatelessWidget {
  final LoggedMeal meal;
  final VoidCallback onRemove;

  const _LoggedMealTile({required this.meal, required this.onRemove});

  static String _formatNumber(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    if (isWhole) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    // Total calories = calories-per-serving × number of servings.
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
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
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
                    // Unicode bullet (•) separates servings from kcal.
                    '${meal.servings} serving(s) • ${_formatNumber(totalCalories.toDouble())} kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F7559),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              onPressed: onRemove,
              tooltip: 'Remove meal',
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width button that navigates to the Recipes view.
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

/// A labeled progress bar for one macro nutrient.
///
/// Uses [LinearProgressIndicator] with [clamp(0.0, 1.0)] so the bar
/// never overflows visually. When consumed > target the label and bar
/// both switch to [Colors.redAccent] as a warning.
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
    // Clamp progress to [0, 1] — the bar itself must never exceed full.
    final progress =
        (target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0);
    final remaining =
        (target - consumed).clamp(0.0, double.infinity);
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
            // Show "X over" in red when the user exceeds their target.
            Text(
              isOver
                  ? '${DashboardView._formatNumber(consumed - target)}$unit over'
                  : '${DashboardView._formatNumber(remaining)}$unit remaining',
              style: TextStyle(
                fontSize: 12,
                color: isOver
                    ? Colors.redAccent
                    : const Color(0xFF5F7559),
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
            // Switch to red when over target.
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? Colors.redAccent : color,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${DashboardView._formatNumber(consumed)} / ${DashboardView._formatNumber(target)} $unit',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF8A9A85)),
        ),
      ],
    );
  }
}

/// A small icon + label + value tile used in the profile stats grid.
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

/// Full-width outlined button that navigates to the Meal Spinner view.
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
