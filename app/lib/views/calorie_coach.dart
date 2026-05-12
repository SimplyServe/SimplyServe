// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// ============================================================
// views/calorie_coach.dart
// ============================================================
// Conversational step-machine that collects biometric data, calculates
// personalised calorie and macro targets, and suggests matching recipes.
//
// ── Step machine ─────────────────────────────────────────────
// _step drives all UI branching:
//   0  — age (text input)
//   1  — height unit selection (cm / ft·in)
//   2  — height value (text input)
//   3  — weight unit selection (kg / lb)
//   4  — weight value (text input)
//   5  — gender selection
//   6  — activity level selection
//   7  — fitness goal selection
//   75 — dietary options (multi-select chip panel)
//   8  — target weight (text input, skipped for 'maintain')
//   9  — results / done
//
// ── BMR / TDEE calculation (Mifflin-St Jeor equation) ────────
//   Male:   BMR = 10W + 6.25H − 5A + 5
//   Female: BMR = 10W + 6.25H − 5A − 161
//   TDEE = BMR × activityMultiplier
//   where W=weight(kg), H=height(cm), A=age(years)
//
// ── Calorie target ───────────────────────────────────────────
//   gain:     TDEE + 400  (lean bulk surplus)
//   lose:     TDEE − 500  (fat-loss deficit)
//   maintain: TDEE
//   Floor: 1200 kcal (safe minimum)
//
// ── Macro split ──────────────────────────────────────────────
//   Protein:  2.0–2.2 g/kg bodyweight (capped at 35% of calories)
//   Fat:      25% of calories  (9 kcal/g)
//   Carbs:    remainder        (4 kcal/g)
//
// ── Persistence (SharedPreferences) ──────────────────────────
// All results are stored under 'cc_*' keys. On next open,
// _loadSavedResults() detects a stored TDEE and jumps directly
// to the results screen, bypassing the intro and conversation.
//
// ── Chat bubble pattern ───────────────────────────────────────
// _pushBot() / _pushUser() add _ChatMessage objects to _messages.
// _sendBot() shows a typing indicator (isTyping=true) for [delayMs]
// ms before replacing it with the actual message — simulating a
// realistic bot response delay.
//
// ── Goal reached detection ───────────────────────────────────
// _checkGoalReached() compares current weight to target weight.
// If reached, it sets goal→'maintain', recalculates targets, and
// persists 'cc_goal_reached' so the celebration message appears only once.
//
// ── Sub-widget: _RecipeSuggestionSheet ───────────────────────
// DraggableScrollableSheet presenting recipes filtered by the
// user's dietary tags. Tag chips allow further in-sheet filtering.
// _recipeField() / _recipeTags() / _recipeInt() handle both typed
// RecipeModel objects and raw Map responses from the API.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // added
import 'package:simplyserve/services/profile_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

/// Main Calorie Coach screen. Shows an intro page on first visit
/// or the results / chat history on subsequent visits.
class CalorieCoachView extends StatefulWidget {
  const CalorieCoachView({super.key});

  @override
  State<CalorieCoachView> createState() => _CalorieCoachViewState();
}

class _CalorieCoachViewState extends State<CalorieCoachView> {
  final ProfileService _profileService = ProfileService();

  /// Text input controller for numeric steps (age, height, weight, target weight).
  final _inputCtrl = TextEditingController();

  /// Ordered list of chat messages rendered in the scrollable area.
  final List<_ChatMessage> _messages = [];

  // Steps: 0=age, 1=height unit, 2=height, 3=weight unit, 4=weight,
  //        5=gender, 6=activity, 7=goal, 8=target weight, 9=done
  // Step 75 is an intermediate step for dietary options (between 7 and 8).
  int _step = 0;

  final ScrollController _scrollCtrl = ScrollController();

  // ── Collected biometric data ──────────────────────────────────────────
  int? _age;
  double? _height; // always stored in cm regardless of display unit
  double? _weight; // always stored in kg regardless of display unit
  String? _gender;
  String? _activity;
  String _heightUnit = 'cm'; // 'cm' or 'ft' — controls parsing + display
  String _weightUnit = 'kg'; // 'kg' or 'lb' — controls parsing + display
  String? _goal; // 'gain', 'maintain', 'lose'
  double? _targetWeight; // stored in kg

  // ── Calculated values ─────────────────────────────────────────────────
  double? _bmr;
  double? _tdee;

  // ── Avatar assets ─────────────────────────────────────────────────────
  /// Bot avatar: brand mascot image shown next to every bot message.
  final String _botAvatarAsset = 'assets/images/image.png';
  final String? _userAvatarAsset = null;

  /// User avatar: fetched from the profile API; falls back to a green circle.
  String? _userAvatarUrl;

  // ── Targets (written to SharedPreferences and used by NutritionalDashboard)
  double? _calorieTarget;
  double? _proteinTarget;
  double? _carbTarget;
  double? _fatTarget;

  /// True when the weight-update sub-flow is active (re-uses the text input).
  bool _isWeightUpdateMode = false;

  /// True until the user taps "Let's Go" or saved results are detected.
  bool _showIntro = true;

  // ── Dietary options (step 75) ──────────────────────────────────────────
  // Steps: ..., 7=goal, 75=dietary (handled as _step==75), 8=target weight, 9=done
  final List<String> _dietaryOptions = [];

  // These must exactly match the tag strings used in the recipe catalog
  // (see _kAllTags in recipes.dart). Only include tags that recipes actually
  // carry so the filter always returns results.
  static const List<String> _allDietaryOptions = [
    'Vegan',
    'High Protein',
    'High Fibre',
    'Gluten Free',
    'Dairy Free',
    'No restrictions',
  ];

  // ── Brand colours ────────────────────────────────────────────────────
  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _darkGreen = Color(0xFF4E8A2B);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);
  static const Color _textDark = Color(0xFF24421A);
  static const Color _textMuted = Color(0xFF5F7559);

  // ── Activity level multipliers for TDEE calculation ───────────────────
  // Keys match the display labels shown to the user.
  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly active': 1.375,
    'Moderately active': 1.55,
    'Very active': 1.725,
  };

  /// Subtitle descriptions shown in the activity selection card.
  static const Map<String, String> _activityDescriptions = {
    'Sedentary': 'Little or no exercise, desk job',
    'Lightly active': 'Light exercise 1–3 days/week',
    'Moderately active': 'Moderate exercise 3–5 days/week',
    'Very active': 'Hard exercise 6–7 days/week',
    'Extra active': 'Very hard exercise or physical job',
  };

  // ── SharedPreferences keys (all prefixed 'cc_') ───────────────────────
  // These keys are also read by NutritionalDashboard and ProfileView.
  static const _kAge = 'cc_age';
  static const _kHeight = 'cc_height';
  static const _kWeight = 'cc_weight';
  static const _kGender = 'cc_gender';
  static const _kActivity = 'cc_activity';
  static const _kBmr = 'cc_bmr';
  static const _kTdee = 'cc_tdee';
  static const _kHeightUnit = 'cc_height_unit';
  static const _kWeightUnit = 'cc_weight_unit';
  static const _kGoal = 'cc_goal';
  static const _kTargetWeight = 'cc_target_weight';
  static const _kCalorieTarget = 'cc_calorie_target';
  static const _kProteinTarget = 'cc_protein_target';
  static const _kCarbTarget = 'cc_carb_target';
  static const _kFatTarget = 'cc_fat_target';
  static const _kCompleted = 'cc_completed';
  static const _kGoalReached = 'cc_goal_reached';
  static const _kDietaryOptions = 'cc_dietary_options';

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    // Try to restore a previous session; if none found, stay on the intro screen.
    _loadSavedResults();
  }

  /// Fetches the user's profile image URL from the API and normalises it.
  /// Relative paths from the backend are prefixed with the base URL.
  Future<void> _loadUserAvatar() async {
    final userData = await _profileService.getCurrentUser();
    final rawUrl = (userData?['profile_image_url'] ?? '').toString().trim();
    if (!mounted) return;

    if (rawUrl.isEmpty) {
      setState(() => _userAvatarUrl = null);
      return;
    }

    // Ensure relative paths like '/media/avatars/x.png' become absolute URLs
    final base = _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final normalized = rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
    setState(() => _userAvatarUrl = normalized);
  }

  /// Restores saved Calorie Coach results from SharedPreferences.
  ///
  /// If cc_tdee exists, the user has completed the coach before.
  /// We skip the intro, jump to step 9, and replay their results as
  /// chat messages (so the context is visible without re-answering).
  Future<void> _loadSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTdee = prefs.getDouble(_kTdee);
    if (storedTdee == null) {
      // No saved results — show intro screen for first-time users
      setState(() => _showIntro = true);
      return;
    }

    // Returning user: skip intro and go straight to results (step 9)
    setState(() {
      _showIntro = false;
      _age = prefs.getInt(_kAge);
      _height = prefs.getDouble(_kHeight);
      _weight = prefs.getDouble(_kWeight);
      _gender = prefs.getString(_kGender);
      _activity = prefs.getString(_kActivity);
      _bmr = prefs.getDouble(_kBmr);
      _tdee = prefs.getDouble(_kTdee);
      _heightUnit = prefs.getString(_kHeightUnit) ?? 'cm';
      _weightUnit = prefs.getString(_kWeightUnit) ?? 'kg';
      _goal = prefs.getString(_kGoal) ?? 'maintain';
      _targetWeight = prefs.getDouble(_kTargetWeight);
      _calorieTarget = prefs.getDouble(_kCalorieTarget) ?? _tdee;
      _proteinTarget = prefs.getDouble(_kProteinTarget);
      _carbTarget = prefs.getDouble(_kCarbTarget);
      _fatTarget = prefs.getDouble(_kFatTarget);
      final savedDietary = prefs.getStringList(_kDietaryOptions);
      if (savedDietary != null) {
        _dietaryOptions
          ..clear()
          ..addAll(savedDietary);
      }
      _step = 9;
    });

    _messages.clear();

    // Check whether the user has reached their target weight since last session
    await _checkGoalReached();

    // Replay summary as bot messages (no typing delay — immediate on return)
    _pushBot('Welcome back — here are your Calorie Coach results.');
    _pushBot('Age: ${_age ?? 'N/A'}');
    _pushBot(
        'Height: ${_height != null ? _formatHeightForDisplay(_height!) : 'N/A'}');
    _pushBot(
        'Weight: ${_weight != null ? _formatWeightForDisplay(_weight!) : 'N/A'}');
    _pushBot('Gender: ${_gender ?? 'N/A'}');
    _pushBot('Activity: ${_activity ?? 'N/A'}');
    _pushBot('Goal: $_goalDisplayName');
    if (_goal != 'maintain' && _targetWeight != null) {
      _pushBot('Target weight: ${_formatWeightForDisplay(_targetWeight!)}');
    }
    if (_bmr != null) {
      _pushBot('BMR: ${_bmr!.round()} kcal/day');
    }
    if (_calorieTarget != null) {
      _pushBot('Daily calorie target: ${_calorieTarget!.round()} kcal/day');
    }
    if (_proteinTarget != null) {
      _pushBot('Protein target: ${_proteinTarget!.round()}g/day');
    }
    if (_dietaryOptions.isNotEmpty) {
      _pushBot('Dietary preferences: $_dietaryDisplayName');
    }
    _pushBot('Tap "Suggest Recipes" to see meals matched to your goals and diet.');
  }

  /// Persists all Calorie Coach results to SharedPreferences.
  /// Called at the end of _calculateAndShowResults(). Also sets
  /// 'cc_completed' = true, which NutritionalDashboard reads to hide the CTA.
  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    if (_age != null) prefs.setInt(_kAge, _age!);
    if (_height != null) prefs.setDouble(_kHeight, _height!);
    if (_weight != null) prefs.setDouble(_kWeight, _weight!);
    if (_gender != null) prefs.setString(_kGender, _gender!);
    if (_activity != null) prefs.setString(_kActivity, _activity!);
    if (_bmr != null) prefs.setDouble(_kBmr, _bmr!);
    if (_tdee != null) prefs.setDouble(_kTdee, _tdee!);
    prefs.setString(_kHeightUnit, _heightUnit);
    prefs.setString(_kWeightUnit, _weightUnit);
    if (_goal != null) prefs.setString(_kGoal, _goal!);
    if (_targetWeight != null) prefs.setDouble(_kTargetWeight, _targetWeight!);
    if (_calorieTarget != null) {
      prefs.setDouble(_kCalorieTarget, _calorieTarget!);
    }
    if (_proteinTarget != null) {
      prefs.setDouble(_kProteinTarget, _proteinTarget!);
    }
    if (_carbTarget != null) {
      prefs.setDouble(_kCarbTarget, _carbTarget!);
    }
    if (_fatTarget != null) {
      prefs.setDouble(_kFatTarget, _fatTarget!);
    }
    prefs.setStringList(_kDietaryOptions, _dietaryOptions);
    prefs.setBool(_kCompleted, true); // signals NutritionalDashboard to hide CTA
  }

  /// Removes all cc_* keys from SharedPreferences, resetting the coach.
  /// Called at the start of _startConversation() before clearing in-memory state.
  Future<void> _clearSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kAge,
      _kHeight,
      _kWeight,
      _kGender,
      _kActivity,
      _kBmr,
      _kTdee,
      _kHeightUnit,
      _kWeightUnit,
      _kGoal,
      _kTargetWeight,
      _kCalorieTarget,
      _kProteinTarget,
      _kCarbTarget,
      _kFatTarget,
      _kCompleted,
      _kGoalReached,
      _kDietaryOptions,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── Goal tracking ────────────────────────────────────────────────────

  /// Checks whether the user has hit their target weight.
  ///
  /// If they have:
  ///   • Sets cc_goal_reached = true (so the message doesn't repeat).
  ///   • Switches goal → 'maintain'.
  ///   • Recalculates calorie + protein targets for maintenance.
  ///   • Pushes a congratulations chat message.
  Future<void> _checkGoalReached() async {
    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getString(_kGoal);
    final targetWeight = prefs.getDouble(_kTargetWeight);
    final currentWeight = prefs.getDouble(_kWeight);
    final goalReached = prefs.getBool(_kGoalReached) ?? false;

    if (goalReached ||
        goal == null ||
        goal == 'maintain' ||
        targetWeight == null ||
        currentWeight == null) {
      return; // nothing to check
    }

    bool reached = false;
    if (goal == 'lose' && currentWeight <= targetWeight) reached = true;
    if (goal == 'gain' && currentWeight >= targetWeight) reached = true;

    if (reached) {
      await prefs.setBool(_kGoalReached, true);
      await prefs.setString(_kGoal, 'maintain');

      // Recalculate targets for maintenance mode
      final tdee = _tdee ?? prefs.getDouble(_kTdee);
      if (tdee != null) {
        final proteinTarget = currentWeight * 1.8; // 1.8 g/kg for maintenance
        await prefs.setDouble(_kCalorieTarget, tdee);
        await prefs.setDouble(_kProteinTarget, proteinTarget);
        setState(() {
          _goal = 'maintain';
          _calorieTarget = tdee;
          _proteinTarget = proteinTarget;
        });
      }

      _pushBot('Congratulations! You\'ve reached your target weight of '
          '${_formatWeightForDisplay(targetWeight)}! '
          'Your plan has been switched to maintenance mode.');
    }
  }

  // ── Conversation flow ────────────────────────────────────────────────

  /// Resets all in-memory state and SharedPreferences, then starts the
  /// conversation from step 0 (age question).
  Future<void> _startConversation() async {
    await _clearSavedResults();

    _messages.clear();
    _step = 0;
    _age = null;
    _height = null;
    _weight = null;
    _gender = null;
    _activity = null;
    _heightUnit = 'cm';
    _weightUnit = 'kg';
    _goal = null;
    _targetWeight = null;
    _bmr = null;
    _tdee = null;
    _calorieTarget = null;
    _proteinTarget = null;
    _isWeightUpdateMode = false;
    _dietaryOptions.clear();
    setState(() {});

    _pushBot('This will only take a moment. How old are you? (years)');
  }

  /// Called when the user taps "Let's Go" on the intro screen.
  Future<void> _letsGo() async {
    setState(() => _showIntro = false);
    await _startConversation();
  }

  /// Appends a user message immediately (no delay).
  void _pushUser(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
    });
    _scrollToBottom();
  }

  /// Appends a bot message immediately (no delay, used for loading saved results).
  void _pushBot(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

  /// Appends a bot message with a typing indicator that lasts [delayMs] ms.
  ///
  /// Pattern:
  ///   1. Add a _ChatMessage with isTyping=true (shows "…" + spinner).
  ///   2. Wait for delayMs.
  ///   3. Remove the typing message and replace it with the real text.
  /// This simulates a realistic conversational bot response delay.
  Future<void> _sendBot(String text, {int delayMs = 800}) async {
    setState(() {
      _messages.add(_ChatMessage(text: '…', fromUser: false, isTyping: true));
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: delayMs));

    setState(() {
      // Find and replace the last typing indicator
      final idx = _messages.lastIndexWhere((m) => m.isTyping == true);
      if (idx != -1) _messages.removeAt(idx);
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

  /// Scrolls the chat list to the bottom after the current frame renders.
  /// Uses addPostFrameCallback so the scroll happens after ListView rebuilds.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      try {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
  }

  // ── Input handling ───────────────────────────────────────────────────

  /// Hint text for the text input field, changing per step.
  String get _inputHintText {
    if (_isWeightUpdateMode) {
      return _weightUnit == 'lb'
          ? 'Enter current weight (lb)'
          : 'Enter current weight (kg)';
    }
    switch (_step) {
      case 0:
        return 'Enter age';
      case 2:
        return _heightUnit == 'ft'
            ? 'Enter feet inches (e.g. 5 10)'
            : 'Enter height (cm)';
      case 4:
        return _weightUnit == 'lb' ? 'Enter weight (lb)' : 'Enter weight (kg)';
      case 8:
        return _weightUnit == 'lb'
            ? 'Enter target weight (lb)'
            : 'Enter target weight (kg)';
      default:
        return 'Enter value';
    }
  }

  /// True when the text input field should be visible.
  /// Shown only for numeric steps (0, 2, 4, 8) and weight update mode.
  /// Hidden during selection steps (1, 3, 5, 6, 7, 75, 9).
  bool get _showTextInput =>
      (_step == 0 ||
      _step == 2 ||
      _step == 4 ||
      _step == 8 ||
      _isWeightUpdateMode) && _step != 75;

  /// Handles text input submission for all numeric steps.
  ///
  /// Each case validates the input (range checks, unit conversion),
  /// stores the canonical value (always cm/kg internally), advances _step,
  /// and fires the next bot message via _sendBot.
  Future<void> _handleSubmitText() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _pushUser(text);
    _inputCtrl.clear();

    if (_isWeightUpdateMode) {
      await _handleWeightUpdate(text);
      return;
    }

    switch (_step) {
      case 0: // age
        final n = int.tryParse(text);
        if (n == null || n < 10 || n > 120) {
          await _sendBot('Please enter a valid age (10–120).');
          return;
        }
        _age = n;
        _step = 1; // → height unit selection panel
        await _sendBot(
            'Would you like to enter your height in centimeters or feet and inches?');
        setState(() {});
        break;

      case 2: // height value
        final cm = _parseHeightToCm(text);
        if (cm < 50 || cm > 300) {
          if (_heightUnit == 'ft') {
            await _sendBot(
                'Please enter a valid height (e.g. 5 10 for 5 feet 10 inches).');
          } else {
            await _sendBot('Please enter a realistic height in cm (e.g. 170).');
          }
          return;
        }
        _height = cm; // store as cm regardless of input unit
        _step = 3; // → weight unit selection panel
        await _sendBot(
            'Would you like to enter your weight in kilograms or pounds?');
        setState(() {});
        break;

      case 4: // weight value
        final n = double.tryParse(text);
        if (n == null || n <= 0) {
          await _sendBot('Please enter a valid number.');
          return;
        }
        final kg = _convertWeightToKg(n);
        if (kg < 20 || kg > 700) {
          await _sendBot(_weightUnit == 'lb'
              ? 'Please enter a realistic weight in pounds (e.g. 154).'
              : 'Please enter a realistic weight in kg (e.g. 70).');
          return;
        }
        _weight = kg; // store as kg regardless of input unit
        _step = 5; // → gender selection panel
        await _sendBot('Which gender should I use for the calculation?');
        setState(() {});
        break;

      case 8: // target weight
        final n = double.tryParse(text);
        if (n == null || n <= 0) {
          await _sendBot('Please enter a valid number.');
          return;
        }
        final targetKg = _convertWeightToKg(n);
        if (targetKg < 20 || targetKg > 700) {
          await _sendBot('Please enter a realistic target weight.');
          return;
        }
        // Validate target direction relative to current weight
        if (_goal == 'gain' && targetKg <= _weight!) {
          await _sendBot(
              'Your target weight should be higher than your current weight for a weight gain goal.');
          return;
        }
        if (_goal == 'lose' && targetKg >= _weight!) {
          await _sendBot(
              'Your target weight should be lower than your current weight for a weight loss goal.');
          return;
        }
        _targetWeight = targetKg;
        _step = 9; // → results
        await _calculateAndShowResults();
        break;

      default:
        break;
    }
  }

  // ── Selection handlers ───────────────────────────────────────────────

  /// User selects a height unit. Advances to step 2 (height value input).
  Future<void> _selectHeightUnit(String unit) async {
    _pushUser(unit == 'cm' ? 'Centimeters' : 'Feet & Inches');
    _heightUnit = unit;
    _step = 2; // → height value text input
    if (unit == 'ft') {
      await _sendBot(
          'Enter your height as feet and inches separated by a space (e.g. 5 10).');
    } else {
      await _sendBot('What is your height in cm?');
    }
    setState(() {});
  }

  /// User selects a weight unit. Advances to step 4 (weight value input).
  Future<void> _selectWeightUnit(String unit) async {
    _pushUser(unit == 'kg' ? 'Kilograms' : 'Pounds');
    _weightUnit = unit;
    _step = 4; // → weight value text input
    if (unit == 'lb') {
      await _sendBot('What is your weight in pounds?');
    } else {
      await _sendBot('What is your weight in kg?');
    }
    setState(() {});
  }

  /// User selects gender. Advances to step 6 (activity level selection).
  Future<void> _selectGender(String g) async {
    _pushUser(g);
    _gender = g;
    _step = 6; // → activity selection panel
    await _sendBot('Thanks. Now choose your typical activity level:');
    setState(() {});
  }

  /// User selects an activity level. Advances to step 7 (goal selection).
  Future<void> _selectActivity(String a) async {
    _pushUser(a);
    _activity = a;
    _step = 7; // → goal selection panel
    await _sendBot(
        'What is your fitness goal? All plans include high protein to support muscle.');
    setState(() {});
  }

  /// User selects a fitness goal. Advances to step 75 (dietary options).
  /// Dietary options are always collected before the target weight step.
  Future<void> _selectGoal(String goal) async {
    final labels = {
      'gain': 'Gain Weight',
      'maintain': 'Maintain Weight',
      'lose': 'Lose Weight'
    };
    _pushUser(labels[goal]!);
    _goal = goal;

    // Always go to dietary options step first, regardless of goal
    _step = 75; // dietary multi-select panel
    await _sendBot(
        'Great! Do you have any dietary requirements or preferences? Select all that apply, then tap "Continue".');
    setState(() {});
  }

  /// User confirms dietary options. Routes to:
  ///   • step 9 (results) if goal is 'maintain' (no target weight needed).
  ///   • step 8 (target weight input) for gain/lose goals.
  Future<void> _confirmDietaryOptions() async {
    final display = _dietaryOptions.isEmpty || _dietaryOptions.contains('No restrictions')
        ? 'No restrictions'
        : _dietaryOptions.join(', ');
    _pushUser(display);

    if (_goal == 'maintain') {
      _step = 9;
      await _calculateAndShowResults(); // no target weight needed
    } else {
      _step = 8; // → target weight text input
      final action = _goal == 'gain' ? 'gain' : 'lose';
      final unitLabel = _weightUnit == 'lb' ? 'pounds' : 'kg';
      await _sendBot(
          'What is your target weight to $action to? (in $unitLabel)');
      setState(() {});
    }
  }

  // ── Weight update sub-flow ───────────────────────────────────────────
  // Allows the user to log a new weight after the initial setup, triggering
  // a recalculation of BMR/TDEE and checking for goal completion.

  /// Activates the weight update sub-flow. Reuses the standard text input.
  void _startWeightUpdate() {
    setState(() {
      _isWeightUpdateMode = true;
    });
    _pushBot(
        'Enter your current weight (${_weightUnit == 'lb' ? 'in pounds' : 'in kg'}):');
  }

  /// Validates the new weight, updates state + SharedPreferences,
  /// recalculates BMR/TDEE using Mifflin-St Jeor, and checks goal status.
  Future<void> _handleWeightUpdate(String text) async {
    final n = double.tryParse(text);
    if (n == null || n <= 0) {
      await _sendBot('Please enter a valid number.');
      return;
    }
    final kg = _convertWeightToKg(n);
    if (kg < 20 || kg > 400) {
      await _sendBot('Please enter a realistic weight.');
      return;
    }

    _weight = kg;
    _isWeightUpdateMode = false;

    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_kWeight, kg);

    await _sendBot('Weight updated to ${_formatWeightForDisplay(kg)}.');

    // Recalculate BMR and TDEE with the updated weight
    if (_age != null && _height != null) {
      double bmr;
      if (_gender == 'Male') {
        bmr = 10 * _weight! + 6.25 * _height! - 5 * _age! + 5;
      } else {
        bmr = 10 * _weight! + 6.25 * _height! - 5 * _age! - 161;
      }
      final multiplier = _activityMultipliers[_activity] ?? 1.2;
      final tdee = bmr * multiplier;

      _bmr = bmr;
      _tdee = tdee;
      _calorieTarget = _computeCalorieTarget(tdee);
      _proteinTarget = _computeProteinTarget(_calorieTarget!);
      _carbTarget = _computeCarbTarget(_calorieTarget!);
      _fatTarget = _computeFatTarget(_calorieTarget!);

      prefs.setDouble(_kBmr, bmr);
      prefs.setDouble(_kTdee, tdee);
      prefs.setDouble(_kCalorieTarget, _calorieTarget!);
      prefs.setDouble(_kProteinTarget, _proteinTarget!);
      prefs.setDouble(_kCarbTarget, _carbTarget!);
      prefs.setDouble(_kFatTarget, _fatTarget!);

      await _sendBot(
          'Recalculated — daily calorie target: ${_calorieTarget!.round()} kcal/day, '
          'protein: ${_proteinTarget!.round()}g/day.',
          delayMs: 600);
    }

    // Check if the new weight means the user has reached their goal
    await _checkGoalReached();
    setState(() {});
  }

  // ── Calculation logic ────────────────────────────────────────────────

  /// Applies the goal adjustment to TDEE to produce the daily calorie target.
  /// Floor of 1200 kcal prevents dangerously low targets.
  double _computeCalorieTarget(double tdee) {
    double target;
    switch (_goal) {
      case 'gain':
        target = tdee + 400; // lean-bulk surplus
        break;
      case 'lose':
        target = tdee - 500; // fat-loss deficit
        break;
      case 'maintain':
      default:
        target = tdee;
        break;
    }
    if (target < 1200) target = 1200; // 1200 kcal is a widely-used safe minimum to prevent nutritional deficiency
    return target;
  }

  /// Calculates the daily protein target in grams.
  ///
  /// Method: body-weight scaling (g/kg), with different rates per goal:
  ///   lose: 2.0 g/kg, gain: 2.2 g/kg, maintain: 1.8 g/kg
  /// Cap: protein never exceeds 35% of total daily calories to stay
  /// within evidence-based recommendations.
  double _computeProteinTarget(double calories) {
    if (_weight == null) return (calories * 0.30) / 4;
    final double gPerKg;
    switch (_goal) {
      case 'lose':
        gPerKg = 2.0;
        break;
      case 'gain':
        gPerKg = 2.2;
        break;
      default:
        gPerKg = 1.8;
    }
    final proteinG = _weight! * gPerKg;
    // Cap protein at 35% of calories (4 kcal/g)
    final maxProteinG = (calories * 0.35) / 4;
    return proteinG < maxProteinG ? proteinG : maxProteinG;
  }

  /// Fat = 25% of total daily calories (9 kcal/g).
  double _computeFatTarget(double calories) {
    return (calories * 0.25) / 9;
  }

  /// Carbs = remaining calories after protein and fat are accounted for.
  /// If protein + fat exceed total calories (edge case with very low calorie
  /// targets), carbs default to 0 rather than going negative.
  double _computeCarbTarget(double calories) {
    final proteinCals = _computeProteinTarget(calories) * 4;
    final fatCals = _computeFatTarget(calories) * 9;
    final remaining = calories - proteinCals - fatCals;
    return remaining > 0 ? remaining / 4 : 0;
  }

  /// Runs the full BMR → TDEE → macro calculation and streams results
  /// as sequential bot messages with staggered delays for a natural feel.
  ///
  /// Mifflin-St Jeor equations:
  ///   Male:   BMR = 10W + 6.25H − 5A + 5
  ///   Female: BMR = 10W + 6.25H − 5A − 161
  ///   TDEE  = BMR × activityMultiplier
  Future<void> _calculateAndShowResults() async {
    if (_age == null || _height == null || _weight == null) {
      await _sendBot('Missing information. Please restart.');
      return;
    }

    // Mifflin-St Jeor equation
    double bmr;
    if (_gender == 'Male') {
      bmr = 10 * _weight! + 6.25 * _height! - 5 * _age! + 5;
    } else {
      bmr = 10 * _weight! + 6.25 * _height! - 5 * _age! - 161;
    }
    final multiplier = _activityMultipliers[_activity] ?? 1.2;
    final tdee = bmr * multiplier;
    final calorieTarget = _computeCalorieTarget(tdee);
    final proteinTarget = _computeProteinTarget(calorieTarget);
    final carbTarget = _computeCarbTarget(calorieTarget);
    final fatTarget = _computeFatTarget(calorieTarget);

    setState(() {
      _bmr = bmr;
      _tdee = tdee;
      _calorieTarget = calorieTarget;
      _proteinTarget = proteinTarget;
      _carbTarget = carbTarget;
      _fatTarget = fatTarget;
    });
    // Save to SharedPreferences so other screens can read the targets
    await _saveResults();

    // Stream results with staggered delays to simulate natural conversation
    await _sendBot('Here are your results:');
    await _sendBot('BMR (basal metabolic rate): ${bmr.round()} kcal/day',
        delayMs: 600);
    await _sendBot(
        'TDEE (total daily energy expenditure): ${tdee.round()} kcal/day',
        delayMs: 600);

    String goalNote = '';
    if (_goal == 'gain') goalNote = ' (+400 surplus for lean bulk)';
    if (_goal == 'lose') goalNote = ' (-500 deficit for fat loss)';
    await _sendBot('Goal: $_goalDisplayName$goalNote', delayMs: 500);

    if (_goal != 'maintain' && _targetWeight != null) {
      await _sendBot(
          'Target weight: ${_formatWeightForDisplay(_targetWeight!)}',
          delayMs: 400);
    }

    await _sendBot('Daily calorie target: ${calorieTarget.round()} kcal/day',
        delayMs: 500);
    await _sendBot('Recommended daily macros:', delayMs: 500);
    await _sendBot(' Protein : ${proteinTarget.round()}g', delayMs: 400);
    await _sendBot(' Carbs : ${carbTarget.round()}g', delayMs: 400);
    await _sendBot(' Fat : ${fatTarget.round()}g', delayMs: 400);
    await _sendBot(
        'Tap "Suggest Recipes" to see meals matched to your goals, or "Restart" to run again.',
        delayMs: 500);
    setState(() {});
  }

  /// Shows a summary AlertDialog with all biometric data and calculated targets.
  /// The dialog includes a "Restart" button that triggers _startConversation().
  void _showSummaryDialog() {
    final age = _age?.toString() ?? 'N/A';
    final height =
        _height != null ? '${_height!.toStringAsFixed(1)} cm' : 'N/A';
    final weight =
        _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : 'N/A';
    final bmr = _bmr != null ? '${_bmr!.round()} kcal/day' : 'N/A';
    final calories =
        _calorieTarget != null ? '${_calorieTarget!.round()} kcal/day' : 'N/A';
    final protein =
        _proteinTarget != null ? '${_proteinTarget!.round()}g/day' : 'N/A';

    // Macro breakdown (40/30/30 split approximation)
    String fatStr = 'N/A';
    String carbStr = 'N/A';
    if (_calorieTarget != null) {
      final carbTarget = _computeCarbTarget(_calorieTarget!);
      final fatTarget = _computeFatTarget(_calorieTarget!);
      fatStr = '${fatTarget.round()}g/day';
      carbStr = '${carbTarget.round()}g/day';
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        // Gradient header matching the screen's green theme
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandGreen, _darkGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const Text(
            'Your Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow(Icons.cake_outlined, 'Age', age),
            _summaryRow(Icons.straighten, 'Height', height),
            _summaryRow(Icons.monitor_weight_outlined, 'Weight', weight),
            _summaryRow(Icons.person_outline, 'Gender', _gender ?? 'N/A'),
            _summaryRow(Icons.directions_run, 'Activity', _activity ?? 'N/A'),
            _summaryRow(Icons.flag_outlined, 'Goal', _goalDisplayName),
            _summaryRow(Icons.restaurant_outlined, 'Diet', _dietaryDisplayName),
            if (_goal != 'maintain' && _targetWeight != null)
              _summaryRow(Icons.my_location,
                  'Target weight', _formatWeightForDisplay(_targetWeight!)),
            const Divider(height: 20),
            _summaryRow(Icons.local_fire_department_outlined, 'BMR', bmr),
            _summaryRow(Icons.bolt_outlined, 'Daily calories', calories),
            const SizedBox(height: 8),
            const Text('Daily Macros',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _textDark)),
            const SizedBox(height: 6),
            _summaryRow(Icons.egg_outlined, 'Protein', protein),
            _summaryRow(Icons.grain, 'Carbs', carbStr),
            _summaryRow(Icons.water_drop_outlined, 'Fat', fatStr),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: _textMuted),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startConversation(); // restart the conversation from scratch
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  /// Builds a single icon + label: value row for the summary dialog.
  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _brandGreen),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A)),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  /// Human-readable dietary preference string for display in the summary.
  String get _dietaryDisplayName {
    if (_dietaryOptions.isEmpty || _dietaryOptions.contains('No restrictions')) {
      return 'No restrictions';
    }
    return _dietaryOptions.join(', ');
  }

  /// Opens the _RecipeSuggestionSheet as a DraggableScrollableSheet.
  ///
  /// Passes dietary tags to the sheet for initial filtering.
  /// 'No restrictions' or empty → no tag filter (show all recipes).
  void _showRecipeSuggestions() {
    // "No restrictions" or nothing selected → no filter (show all recipes).
    // Otherwise pass the selected labels directly — they match the catalog
    // tag strings exactly (sourced from _kAllTags in recipes.dart).
    final noFilter = _dietaryOptions.isEmpty ||
        _dietaryOptions.contains('No restrictions');

    final activeTags = noFilter
        ? <String>[]
        : List<String>.from(_dietaryOptions);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipeSuggestionSheet(
        calorieTarget: _calorieTarget,
        proteinTarget: _proteinTarget,
        dietaryTags: activeTags,
        dietaryLabel: _dietaryDisplayName,
        goal: _goal ?? 'maintain',
        brandGreen: _brandGreen,
        darkGreen: _darkGreen,
        surfaceGreen: _surfaceGreen,
        textDark: _textDark,
        textMuted: _textMuted,
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helper methods ──────────────────────────────────────────────────

  /// Human-readable goal label for display in chat and the summary dialog.
  String get _goalDisplayName {
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

  /// Converts a height stored in cm to the user's preferred display format.
  /// ft mode: converts cm → total inches → feet + inches.
  String _formatHeightForDisplay(double cm) {
    if (_heightUnit == 'ft') {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = totalInches % 12;
      return '$feet\'${inches.toStringAsFixed(0)}"';
    } else {
      return '${cm.toStringAsFixed(0)} cm';
    }
  }

  /// Converts a weight stored in kg to the user's preferred display format.
  String _formatWeightForDisplay(double kg) {
    if (_weightUnit == 'lb') {
      final lb = kg * 2.20462;
      return '${lb.toStringAsFixed(1)} lb';
    } else {
      return '${kg.toStringAsFixed(1)} kg';
    }
  }

  /// Parses a height string to centimetres.
  /// ft mode: splits on space or apostrophe, converts feet + inches to cm.
  /// cm mode: direct double.tryParse.
  double _parseHeightToCm(String input) {
    if (_heightUnit == 'ft') {
      final parts = input.trim().split(RegExp(r"[\s']"));
      if (parts.length >= 2) {
        final feet = double.tryParse(parts[0]) ?? 0;
        final inches = double.tryParse(parts[1]) ?? 0;
        return (feet * 12 + inches) * 2.54;
      }
      return 0;
    } else {
      return double.tryParse(input) ?? 0;
    }
  }

  /// Converts a weight value from the user's display unit to kg.
  double _convertWeightToKg(double weight) {
    if (_weightUnit == 'lb') {
      return weight / 2.20462;
    }
    return weight;
  }

  // ── Message bubble builder ───────────────────────────────────────────

  /// Renders a single chat message as a styled bubble with avatar.
  ///
  /// User bubbles: light-green background, right-aligned, user avatar on right.
  /// Bot bubbles: white background, left-aligned, bot avatar on left.
  /// Typing bubble: shows a miniature CircularProgressIndicator + "…" text.
  ///
  /// Avatar priority for the user:
  ///   1. Network image from _userAvatarUrl (profile photo)
  ///   2. Asset image from _userAvatarAsset (currently null)
  ///   3. Fallback: green circle with person icon
  Widget _buildMessage(_ChatMessage m) {
    const double avatarSize = 36;

    Widget fallbackUserAvatar() {
      return const CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: _brandGreen,
        child: Icon(Icons.person,
            color: Colors.white, size: avatarSize * 0.45),
      );
    }

    Widget avatar(bool isUser) {
      if (isUser && _userAvatarUrl != null) {
        return ClipOval(
          child: Image.network(
            _userAvatarUrl!,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackUserAvatar(),
          ),
        );
      }

      final asset = isUser ? _userAvatarAsset : _botAvatarAsset;
      if (asset != null) {
        return Container(
          width: avatarSize,
          height: avatarSize,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(
              asset,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) {
                if (isUser) return fallbackUserAvatar();
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      if (isUser) return fallbackUserAvatar();

      return const CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: Colors.transparent,
      );
    }

    final isUser = m.fromUser;

    // ConstrainedBox caps bubble width at 72% of screen width so long
    // messages don't stretch edge-to-edge.
    final bubble = ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFE4F2DE) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            // Tail corner: user = bottom-right square, bot = bottom-left square
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFFBCDFA0)
                : const Color(0xFFE7EEE2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // Typing indicator: spinner + "…" text while the bot "thinks"
        child: m.isTyping
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _brandGreen),
                  ),
                  SizedBox(width: 8),
                  Text('…'),
                ],
              )
            : Text(
                m.text,
                style: TextStyle(
                  color: isUser ? _textDark : const Color(0xFF2D4A24),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
      ),
    );

    // User messages: right-aligned with avatar on the right
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: bubble),
            const SizedBox(width: 8),
            avatar(true),
          ],
        ),
      );
    } else {
      // Bot messages: left-aligned with avatar on the left
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar(false),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
      );
    }
  }

  // ── Intro screen ──────────────────────────────────────────────────────
  // Shown to first-time users before any results are saved.
  // Contains: gradient header + bot avatar + info card + "Let's Go" button.

  Widget _buildIntroScreen() {
    return ColoredBox(
      color: _surfaceGreen,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Gradient header — consistent with meal_spinner_page.dart style
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brandGreen, _darkGreen],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calorie Coach',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Personalised calorie & macro targets.',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Bot avatar card with green glow shadow
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _brandGreen.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(70),
                        child: Image.asset(
                          'assets/images/Coach.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _surfaceGreen,
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: const Icon(Icons.smart_toy,
                                size: 60, color: _brandGreen),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info card explaining what the coach does and data privacy
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
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        'Welcome to Calorie Coach — your assistant for personalised calorie and protein targets.\n\n'
                        'I will ask a few quick questions (age, height, weight, gender, activity level, fitness goal, and dietary requirements) '
                        'to calculate your daily calorie and macro needs, then suggest matching recipes.\n\n'
                        'Your answers are stored locally on this device only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // CTA button: enters the conversation flow
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _letsGo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          elevation: 0,
                        ),
                        child: const Text("Let's Go"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selection panel helpers ───────────────────────────────────────────
  // Reusable container and chip widgets used across selection steps.

  /// White card container with border and shadow — wraps all selection panels.
  Widget _panelContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  /// Bold label text shown at the top of each selection panel.
  Widget _panelLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: _textDark,
      ),
    );
  }

  /// A small pill-shaped choice chip with an icon, used for binary choices
  /// (e.g. cm vs ft, kg vs lb, Male vs Female).
  Widget _styledChoiceChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _surfaceGreen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCE8B5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _brandGreen),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
          ],
        ),
      ),
    );
  }

  /// A tappable card option with an icon, title, subtitle, and a green
  /// checkmark when selected. Used for activity level and goal selection.
  Widget _styledOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF7E5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _brandGreen : const Color(0xFFE7EEE2),
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: selected
                    ? _brandGreen.withValues(alpha: 0.15)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 18, color: selected ? _brandGreen : Colors.black45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selected ? _textDark : Colors.black87,
                      )),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF777777))),
                  ],
                ],
              ),
            ),
            // Checkmark badge appears when option is selected
            if (selected)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _brandGreen,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show the intro screen until the user taps "Let's Go"
    if (_showIntro) {
      return NavBarScaffold(
        title: 'Calorie Coach',
        body: _buildIntroScreen(),
      );
    }

    return NavBarScaffold(
      title: 'Calorie Coach',
      body: ColoredBox(
        color: _surfaceGreen,
        child: SafeArea(
          child: Column(
            children: [
              // ── Gradient header ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brandGreen, _darkGreen],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calorie Coach',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Personalised calorie & macro targets.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Chat message list ──────────────────────────────────────
              // Grows as messages are added; scrolled by _scrollCtrl.
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _buildMessage(_messages[i]),
                ),
              ),

              // ── Step 1: Height unit selection ──────────────────────────
              if (_step == 1)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('Choose your height unit:'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _styledChoiceChip(
                            label: 'Centimeters (cm)',
                            icon: Icons.straighten,
                            onTap: () => _selectHeightUnit('cm'),
                          ),
                          _styledChoiceChip(
                            label: 'Feet & Inches',
                            icon: Icons.height,
                            onTap: () => _selectHeightUnit('ft'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ── Step 3: Weight unit selection ──────────────────────────
              if (_step == 3)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('Choose your weight unit:'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _styledChoiceChip(
                            label: 'Kilograms (kg)',
                            icon: Icons.monitor_weight,
                            onTap: () => _selectWeightUnit('kg'),
                          ),
                          _styledChoiceChip(
                            label: 'Pounds (lb)',
                            icon: Icons.fitness_center,
                            onTap: () => _selectWeightUnit('lb'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ── Step 5: Gender selection ───────────────────────────────
              if (_step == 5)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('Which gender should I use?'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _styledChoiceChip(
                            label: 'Male',
                            icon: Icons.male,
                            onTap: () => _selectGender('Male'),
                          ),
                          _styledChoiceChip(
                            label: 'Female',
                            icon: Icons.female,
                            onTap: () => _selectGender('Female'),
                          ),
                          _styledChoiceChip(
                            label: 'Prefer not to say',
                            icon: Icons.person_outline,
                            onTap: () => _selectGender('Prefer not to say'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          'You can change this later by restarting the coach.',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF8A9A85))),
                    ],
                  ),
                ),

              // ── Step 6: Activity level selection ───────────────────────
              // Iterates _activityMultipliers.keys to build one card per level.
              if (_step == 6)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('Choose your typical activity level'),
                      const SizedBox(height: 10),
                      ..._activityMultipliers.keys.map((k) {
                        return _styledOptionCard(
                          title: k,
                          subtitle: _activityDescriptions[k] ?? '',
                          icon: Icons.directions_run,
                          selected: _activity == k,
                          onTap: () => _selectActivity(k),
                        );
                      }),
                    ],
                  ),
                ),

              // ── Step 7: Goal selection ─────────────────────────────────
              // Three options: gain / maintain / lose. Described with icons
              // and subtitle text so the user can make an informed choice.
              if (_step == 7)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('What is your fitness goal?'),
                      const SizedBox(height: 10),
                      ...[
                        {
                          'key': 'gain',
                          'label': 'Gain Weight',
                          'desc':
                              'Calorie surplus for muscle growth and mass gain',
                          'icon': Icons.trending_up,
                        },
                        {
                          'key': 'maintain',
                          'label': 'Maintain Weight',
                          'desc':
                              'Stay at current weight, optimise body composition',
                          'icon': Icons.balance,
                        },
                        {
                          'key': 'lose',
                          'label': 'Lose Weight',
                          'desc':
                              'Calorie deficit to lose fat while preserving muscle',
                          'icon': Icons.trending_down,
                        },
                      ].map((e) {
                        return _styledOptionCard(
                            title: e['label'] as String,
                          subtitle: e['desc'] as String,
                          icon: e['icon'] as IconData,
                          selected: _goal == e['key'],
                          onTap: () => _selectGoal(e['key'] as String),
                        );
                      }),
                      const SizedBox(height: 2),
                      const Text(
                          'Tap an option to select. If you are unsure, choose the closest match.',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF8A9A85))),
                    ],
                  ),
                ),

              // ── Step 75: Dietary options (multi-select) ────────────────
              // Multi-select chip panel. "No restrictions" clears all others;
              // selecting any specific option removes "No restrictions".
              // "Continue" button calls _confirmDietaryOptions().
              if (_step == 75)
                _panelContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelLabel('Any dietary requirements?'),
                      const SizedBox(height: 4),
                      const Text(
                        'Select all that apply — we\'ll use this to suggest matching recipes.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8A9A85)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allDietaryOptions.map((option) {
                          final selected = _dietaryOptions.contains(option);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (option == 'No restrictions') {
                                  // "No restrictions" is mutually exclusive with all others
                                  _dietaryOptions.clear();
                                  _dietaryOptions.add('No restrictions');
                                } else {
                                  _dietaryOptions.remove('No restrictions');
                                  if (selected) {
                                    _dietaryOptions.remove(option);
                                  } else {
                                    _dietaryOptions.add(option);
                                  }
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFEAF7E5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? _brandGreen
                                      : const Color(0xFFE7EEE2),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 5),
                                      child: Icon(Icons.check_circle,
                                          size: 14, color: _brandGreen),
                                    ),
                                  Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? _textDark : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // "Continue" advances to step 8 (target weight) or step 9 (maintain)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmDietaryOptions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Text input (numeric steps 0, 2, 4, 8 + weight update) ──
              // FilteringTextInputFormatter restricts input:
              //   ft height: digits, dot, space (for "5 10" format)
              //   all others: digits and dot only
              if (_showTextInput)
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7EEE2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: _step != 0, // age is integer only
                            ),
                            inputFormatters: [
                              // ft height allows a space between feet and inches
                              if (_step == 2 && _heightUnit == 'ft')
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9. ]'))
                              else
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                            ],
                            decoration: InputDecoration(
                              hintText: _inputHintText,
                              hintStyle:
                                  const TextStyle(color: Color(0xFFAAAAAA)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDDDDDD)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: _brandGreen, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            onSubmitted: (_) => _handleSubmitText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Send button (green circle with arrow icon)
                        GestureDetector(
                          onTap: _handleSubmitText,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _brandGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.send,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Step 9: Done action buttons ────────────────────────────
              // Four buttons arranged vertically:
              //   Row: Restart (outlined) + Done/Summary (filled)
              //   "Update Current Weight" — triggers weight-update sub-flow
              //   "Suggest Recipes" — opens _RecipeSuggestionSheet
              if (_step == 9 && !_isWeightUpdateMode)
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE7EEE2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Restart: clears all data and returns to step 0
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _startConversation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textMuted,
                                  side: const BorderSide(
                                      color: Color(0xFFCCCCCC)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Restart'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Done: shows the full summary AlertDialog
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _showSummaryDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Done'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Update weight: triggers the weight-update sub-flow
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _startWeightUpdate,
                            icon: const Icon(Icons.monitor_weight,
                                color: _brandGreen, size: 18),
                            label: const Text('Update Current Weight',
                                style: TextStyle(color: _textDark)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _brandGreen),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Suggest Recipes: opens DraggableScrollableSheet with
                        // filtered catalog based on dietary preferences
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showRecipeSuggestions,
                            icon: const Icon(Icons.restaurant_menu,
                                color: Colors.white, size: 18),
                            label: const Text('Suggest Recipes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recipe Suggestion Bottom Sheet ──────────────────────────────────────────
// ────────────────────────────────────────────────────────────────────────────
// _RecipeSuggestionSheet
// ────────────────────────────────────────────────────────────────────────────
// DraggableScrollableSheet (initialSize: 0.85, min: 0.5, max: 0.95) that
// fetches the full recipe catalog and filters it by the user's dietary tags.
//
// Tag chips at the top of the sheet allow further ad-hoc filtering.
// When all filters are cleared, all recipes are shown.
//
// Recipe field access pattern:
//   _recipeField(recipe, key) first tries typed RecipeModel access (fast),
//   then falls back to Map['key'] for raw API shapes. This handles both
//   strongly-typed RecipeModel objects and dynamically-typed JSON maps
//   from the API without needing reflection or toJson overhead.
//
// Calorie badge colour (_kcalColor):
//   < 25% of daily target → blue (very light meal)
//   25–45%                → green (well-portioned)
//   > 45%                 → orange (heavy meal)

class _RecipeSuggestionSheet extends StatefulWidget {
  final double? calorieTarget;
  final double? proteinTarget;
  final List<String> dietaryTags;
  final String dietaryLabel;
  final String goal;
  final Color brandGreen;
  final Color darkGreen;
  final Color surfaceGreen;
  final Color textDark;
  final Color textMuted;

  const _RecipeSuggestionSheet({
    required this.calorieTarget,
    required this.proteinTarget,
    required this.dietaryTags,
    required this.dietaryLabel,
    required this.goal,
    required this.brandGreen,
    required this.darkGreen,
    required this.surfaceGreen,
    required this.textDark,
    required this.textMuted,
  });

  @override
  State<_RecipeSuggestionSheet> createState() => _RecipeSuggestionSheetState();
}

class _RecipeSuggestionSheetState extends State<_RecipeSuggestionSheet> {
  final RecipeCatalogService _catalogService = RecipeCatalogService();
  List<dynamic> _allRecipes = [];
  bool _isLoading = true;

  /// All distinct tags found across loaded recipes — derived at runtime.
  List<String> _availableTags = [];

  /// Currently active tag filters — seeded from the coach's dietary selection.
  late Set<String> _activeFilters;

  @override
  void initState() {
    super.initState();
    // Pre-seed filters with the coach's dietary selection
    _activeFilters = Set<String>.from(widget.dietaryTags);
    _loadRecipes();
  }

  /// Fetches all recipes and collects every distinct tag for the filter row.
  Future<void> _loadRecipes() async {
    try {
      final recipes = await _catalogService.getAllRecipes();
      // Collect every distinct tag that appears on at least one recipe
      final tagSet = <String>{};
      for (final r in recipes) {
        tagSet.addAll(_recipeTags(r));
      }
      setState(() {
        _allRecipes = recipes;
        _availableTags = tagSet.toList()..sort();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// Returns recipes that carry every currently active filter tag (AND logic).
  /// When no filters are active, all recipes are returned.
  List<dynamic> get _filteredRecipes {
    if (_activeFilters.isEmpty) return List<dynamic>.from(_allRecipes);
    // Keep only recipes that carry every selected tag (strict AND filtering)
    return _allRecipes.where((r) {
      final tags = _recipeTags(r);
      return _activeFilters.every((dt) => tags.contains(dt));
    }).toList();
  }

  /// Polymorphic field accessor for both RecipeModel and Map<String, dynamic>.
  ///
  /// Prefers typed access (switch on key → recipe.nutrition.calories etc.)
  /// which avoids serialisation overhead. Falls back to Map['key'] for
  /// raw JSON shapes returned directly by some API endpoints.
  dynamic _recipeField(dynamic recipe, String key) {
    try {
      switch (key) {
        case 'calories':
          return recipe.nutrition.calories; // int from RecipeModel
        case 'protein':
          return recipe.nutrition.protein;  // String e.g. "25g"
        case 'tags':
          return recipe.tags;               // List<String>
        case 'title':
          return recipe.title;
        case 'description':
          return recipe.summary;            // RecipeModel uses 'summary'
      }
    } catch (_) {}
    // Fallback for Map-shaped recipes (user-created via API)
    if (recipe is Map) return recipe[key];
    return null;
  }

  /// Extracts the tags list from either a RecipeModel or a raw Map.
  List<String> _recipeTags(dynamic recipe) {
    try {
      final t = recipe.tags;
      if (t is List) return List<String>.from(t);
    } catch (_) {}
    final tags = _recipeField(recipe, 'tags');
    if (tags is List) return List<String>.from(tags);
    return [];
  }

  /// Extracts an integer field, handling int/num/String inputs.
  /// Strips non-numeric characters (e.g. "25g" → 25).
  int _recipeInt(dynamic recipe, String key) {
    final value = _recipeField(recipe, key);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  /// Extracts a string field, returning empty string when absent.
  String _recipeString(dynamic recipe, String key) {
    final value = _recipeField(recipe, key);
    return value?.toString() ?? '';
  }

  /// Returns a colour coding the meal's calorie density relative to the
  /// daily target:
  ///   < 25%  → blue  (light snack)
  ///   25–45% → green (suitable main meal portion)
  ///   > 45%  → orange (large meal)
  Color _kcalColor(int kcal) {
    final target = widget.calorieTarget;
    if (target == null) return Colors.blueGrey;
    final ratio = kcal / target;
    if (ratio < 0.25) return Colors.blue;
    if (ratio < 0.45) return Colors.green;
    return Colors.orange;
  }

  /// Navigates to the recipe detail page using the named '/recipe' route.
  /// The recipe object is passed as arguments and extracted in main.dart's
  /// route builder via ModalRoute.of(context)!.settings.arguments.
  Future<void> _navigateToRecipe(
      BuildContext context, dynamic recipe) async {
    try {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/recipe', arguments: recipe);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to load recipe details.'),
          backgroundColor: widget.brandGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;
    String goalLabel;
    if (widget.goal == 'gain') {
      goalLabel = 'Gain Weight';
    } else if (widget.goal == 'lose') {
      goalLabel = 'Lose Weight';
    } else {
      goalLabel = 'Maintain Weight';
    }

    // DraggableScrollableSheet: user can drag the sheet between 50% and 95%
    // of screen height. initialChildSize 0.85 provides immediate visibility.
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle visual indicator
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Gradient header: goal + dietary label + daily kcal badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.brandGreen, widget.darkGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suggested Recipes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$goalLabel · ${widget.dietaryLabel}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  // Daily calorie target badge
                  if (widget.calorieTarget != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.calorieTarget!.round()} kcal/day',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            // ── Tag filter chips ──────────────────────────────────────────
            // Derived from all tags across loaded recipes (not hardcoded).
            // Toggling a chip updates _activeFilters and rebuilds _filteredRecipes.
            if (!_isLoading && _availableTags.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list,
                            size: 14, color: widget.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Filter by tag',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.textMuted),
                        ),
                        const Spacer(),
                        // "Clear all" resets filters to show every recipe
                        if (_activeFilters.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _activeFilters.clear()),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.brandGreen,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _availableTags.map((tag) {
                        final selected = _activeFilters.contains(tag);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _activeFilters.remove(tag);
                              } else {
                                _activeFilters.add(tag);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.brandGreen
                                  : widget.surfaceGreen,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? widget.brandGreen
                                    : const Color(0xFFCCE8B5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selected) ...[
                                  const Icon(Icons.check,
                                      size: 11, color: Colors.white),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : widget.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    const Divider(
                        height: 1,
                        color: Color(0xFFE7EEE2)),
                  ],
                ),
              ),

            // ── Recipe list ───────────────────────────────────────────────
            // Rebuilds reactively when _activeFilters changes (setState inside
            // chip tap handlers). Each card shows name, description, calorie
            // badge (colour-coded by _kcalColor), protein, and up to 3 tags.
            Expanded(
                child: _isLoading
                  ? Center(
                    child: CircularProgressIndicator(
                      color: widget.brandGreen),
                  )
                  : recipes.isEmpty
                    ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Icon(Icons.search_off,
                          size: 56,
                          color: widget.brandGreen.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No recipes match the selected filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15, color: widget.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try removing a filter above to see more results.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.textMuted
                              .withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 16),
                        // Quick "Clear all" button in the empty state
                        GestureDetector(
                          onTap: () => setState(() => _activeFilters.clear()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: widget.brandGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Clear all filters',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                        ],
                      ),
                      ),
                    )
                    : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: recipes.length,
                      itemBuilder: (_, i) {
                      final r = recipes[i];
                      final kcal = _recipeInt(r, 'calories');
                      final protein = _recipeInt(r, 'protein');
                      final tags = _recipeTags(r);
                      final name = _recipeString(r, 'title').isNotEmpty
                          ? _recipeString(r, 'title')
                          : 'Unknown Recipe';
                      final description = _recipeString(r, 'description');
                      return GestureDetector(
                        onTap: () => _navigateToRecipe(context, r),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: widget.surfaceGreen,
                          borderRadius: BorderRadius.circular(14),
                          border:
                            Border.all(color: const Color(0xFFDEEDD4)),
                          boxShadow: [
                          BoxShadow(
                            color:
                              Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                            children: [
                              Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: widget.textDark,
                                ),
                              ),
                              ),
                              // Calorie badge: colour reflects portion relative to daily target
                              Container(
                              padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kcalColor(kcal)
                                  .withValues(alpha: 0.12),
                                borderRadius:
                                  BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$kcal kcal',
                                style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kcalColor(kcal),
                                ),
                              ),
                              ),
                            ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF555555),
                              height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Row(
                            children: [
                              Icon(Icons.egg_outlined,
                                size: 13,
                                color: widget.brandGreen),
                              const SizedBox(width: 4),
                              Text(
                              '${protein}g protein',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.textDark),
                              ),
                              const Spacer(),
                              // Show at most 3 tags to keep cards compact
                              Wrap(
                              spacing: 4,
                              children: tags.take(3).map((tag) {
                                return Container(
                                padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.brandGreen
                                    .withValues(alpha: 0.12),
                                  borderRadius:
                                    BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag.toString(),
                                  style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: widget.darkGreen,
                                  ),
                                ),
                                );
                              }).toList(),
                              ),
                            ],
                            ),
                          ],
                          ),
                        ),
                        ),
                      );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// _ChatMessage
// Immutable data class for a single entry in the chat history.
// fromUser=true → right-aligned user bubble.
// fromUser=false, isTyping=false → left-aligned bot message.
// fromUser=false, isTyping=true → typing indicator bubble (temporary).
// ────────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isTyping;
  _ChatMessage(
      {required this.text, required this.fromUser, this.isTyping = false});
}
