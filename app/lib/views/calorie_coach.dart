import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // added
import 'package:simplyserve/services/profile_service.dart';
import 'package:simplyserve/widgets/navbar.dart';

class CalorieCoachView extends StatefulWidget {
  const CalorieCoachView({super.key});

  @override
  State<CalorieCoachView> createState() => _CalorieCoachViewState();
}

class _CalorieCoachViewState extends State<CalorieCoachView> {
  final ProfileService _profileService = ProfileService();
  final _inputCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  // Steps: 0=age, 1=height unit, 2=height, 3=weight unit, 4=weight,
  //        5=gender, 6=activity, 7=goal, 8=target weight, 9=done
  int _step = 0;

  final ScrollController _scrollCtrl = ScrollController();

  int? _age;
  double? _height; // always stored in cm
  double? _weight; // always stored in kg
  String? _gender;
  String? _activity;
  String _heightUnit = 'cm'; // 'cm' or 'ft'
  String _weightUnit = 'kg'; // 'kg' or 'lb'
  String? _goal; // 'gain', 'maintain', 'lose'
  double? _targetWeight; // stored in kg

  double? _bmr;
  double? _tdee;

  // Avatar assets
  final String _botAvatarAsset = 'assets/images/image.png';
  final String? _userAvatarAsset = null;
  String? _userAvatarUrl;
  double? _calorieTarget;
  double? _proteinTarget;

  bool _isWeightUpdateMode = false;
  bool _showIntro = true;

  // ── Brand colours ────────────────────────────────────────────────────
  static const Color _brandGreen = Color(0xFF74BC42);
  static const Color _darkGreen = Color(0xFF4E8A2B);
  static const Color _surfaceGreen = Color(0xFFF4FAF1);
  static const Color _textDark = Color(0xFF24421A);
  static const Color _textMuted = Color(0xFF5F7559);

  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly active': 1.375,
    'Moderately active': 1.55,
    'Very active': 1.725,
  };

  static const Map<String, String> _activityDescriptions = {
    'Sedentary': 'Little or no exercise, desk job',
    'Lightly active': 'Light exercise 1–3 days/week',
    'Moderately active': 'Moderate exercise 3–5 days/week',
    'Very active': 'Hard exercise 6–7 days/week',
    'Extra active': 'Very hard exercise or physical job',
  };

  // SharedPreferences keys
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
  static const _kCompleted = 'cc_completed';
  static const _kGoalReached = 'cc_goal_reached';

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    // attempt to load saved results; if none, start normal conversation
    _loadSavedResults();
  }

  Future<void> _loadUserAvatar() async {
    final userData = await _profileService.getCurrentUser();
    final rawUrl = (userData?['profile_image_url'] ?? '').toString().trim();
    if (!mounted) return;

    if (rawUrl.isEmpty) {
      setState(() => _userAvatarUrl = null);
      return;
    }

    final base = _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final normalized = rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
    setState(() => _userAvatarUrl = normalized);
  }

  Future<void> _loadSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTdee = prefs.getDouble(_kTdee);
    if (storedTdee == null) {
      // no saved results — show intro screen
      setState(() => _showIntro = true);
      return;
    }

    // restore fields — skip intro for returning users
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
      _step = 9;
    });

    _messages.clear();

    // Check if goal was reached
    await _checkGoalReached();

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
  }

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
    prefs.setBool(_kCompleted, true);
  }

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
      _kCompleted,
      _kGoalReached,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── Goal tracking ────────────────────────────────────────────────────

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
      return;
    }

    bool reached = false;
    if (goal == 'lose' && currentWeight <= targetWeight) reached = true;
    if (goal == 'gain' && currentWeight >= targetWeight) reached = true;

    if (reached) {
      await prefs.setBool(_kGoalReached, true);
      await prefs.setString(_kGoal, 'maintain');

      // Recalculate for maintenance
      final tdee = _tdee ?? prefs.getDouble(_kTdee);
      if (tdee != null) {
        final proteinTarget = currentWeight * 1.8;
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
    setState(() {});

    _pushBot('This will only take a moment. How old are you? (years)');
  }

  Future<void> _letsGo() async {
    setState(() => _showIntro = false);
    await _startConversation();
  }

  void _pushUser(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
    });
    _scrollToBottom();
  }

  void _pushBot(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

  Future<void> _sendBot(String text, {int delayMs = 800}) async {
    setState(() {
      _messages.add(_ChatMessage(text: '…', fromUser: false, isTyping: true));
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: delayMs));

    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.isTyping == true);
      if (idx != -1) _messages.removeAt(idx);
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

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

  bool get _showTextInput =>
      _step == 0 ||
      _step == 2 ||
      _step == 4 ||
      _step == 8 ||
      _isWeightUpdateMode;

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
        _step = 1;
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
        _height = cm;
        _step = 3;
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
        _weight = kg;
        _step = 5;
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
        _step = 9;
        await _calculateAndShowResults();
        break;

      default:
        break;
    }
  }

  // ── Selection handlers ───────────────────────────────────────────────

  Future<void> _selectHeightUnit(String unit) async {
    _pushUser(unit == 'cm' ? 'Centimeters' : 'Feet & Inches');
    _heightUnit = unit;
    _step = 2;
    if (unit == 'ft') {
      await _sendBot(
          'Enter your height as feet and inches separated by a space (e.g. 5 10).');
    } else {
      await _sendBot('What is your height in cm?');
    }
    setState(() {});
  }

  Future<void> _selectWeightUnit(String unit) async {
    _pushUser(unit == 'kg' ? 'Kilograms' : 'Pounds');
    _weightUnit = unit;
    _step = 4;
    if (unit == 'lb') {
      await _sendBot('What is your weight in pounds?');
    } else {
      await _sendBot('What is your weight in kg?');
    }
    setState(() {});
  }

  Future<void> _selectGender(String g) async {
    _pushUser(g);
    _gender = g;
    _step = 6;
    await _sendBot('Thanks. Now choose your typical activity level:');
    setState(() {});
  }

  Future<void> _selectActivity(String a) async {
    _pushUser(a);
    _activity = a;
    _step = 7;
    await _sendBot(
        'What is your fitness goal? All plans include high protein to support muscle.');
    setState(() {});
  }

  Future<void> _selectGoal(String goal) async {
    final labels = {
      'gain': 'Gain Weight',
      'maintain': 'Maintain Weight',
      'lose': 'Lose Weight'
    };
    _pushUser(labels[goal]!);
    _goal = goal;

    if (goal == 'maintain') {
      _step = 9;
      await _calculateAndShowResults();
    } else {
      _step = 8;
      final action = goal == 'gain' ? 'gain' : 'lose';
      final unitLabel = _weightUnit == 'lb' ? 'pounds' : 'kg';
      await _sendBot(
          'What is your target weight to $action to? (in $unitLabel)');
      setState(() {});
    }
  }

  // ── Weight update sub-flow ───────────────────────────────────────────

  void _startWeightUpdate() {
    setState(() {
      _isWeightUpdateMode = true;
    });
    _pushBot(
        'Enter your current weight (${_weightUnit == 'lb' ? 'in pounds' : 'in kg'}):');
  }

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

    // Recalculate with new weight
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

      prefs.setDouble(_kBmr, bmr);
      prefs.setDouble(_kTdee, tdee);
      prefs.setDouble(_kCalorieTarget, _calorieTarget!);
      prefs.setDouble(_kProteinTarget, _proteinTarget!);

      await _sendBot(
          'Recalculated — daily calorie target: ${_calorieTarget!.round()} kcal/day, '
          'protein: ${_proteinTarget!.round()}g/day.',
          delayMs: 600);
    }

    // Check goal
    await _checkGoalReached();
    setState(() {});
  }

  // ── Calculation logic ────────────────────────────────────────────────

  double _computeCalorieTarget(double tdee) {
    double target;
    switch (_goal) {
      case 'gain':
        target = tdee + 400;
        break;
      case 'lose':
        target = tdee - 500;
        break;
      case 'maintain':
      default:
        target = tdee;
        break;
    }
    if (target < 1200) target = 1200;
    return target;
  }

  // Protein from body weight (g/kg), fat fixed at 25% of calories,
  // carbs fill whatever is left.
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
    // Cap so protein never exceeds 35% of calories
    final maxProteinG = (calories * 0.35) / 4;
    return proteinG < maxProteinG ? proteinG : maxProteinG;
  }

  double _computeFatTarget(double calories) {
    return (calories * 0.25) / 9; // 25% of calories, 9 kcal per gram
  }

  double _computeCarbTarget(double calories) {
    final proteinCals = _computeProteinTarget(calories) * 4;
    final fatCals = _computeFatTarget(calories) * 9;
    final remaining = calories - proteinCals - fatCals;
    return remaining > 0 ? remaining / 4 : 0;
  }

  Future<void> _calculateAndShowResults() async {
    if (_age == null || _height == null || _weight == null) {
      await _sendBot('Missing information. Please restart.');
      return;
    }

    // Mifflin-St Jeor
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
    });
    await _saveResults();

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
        'Tap "Restart" to run again, "Done" for a summary, or "Update Weight" to log progress.',
        delayMs: 500);
    setState(() {});
  }

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

    // Macro breakdown (40/30/30 split)
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
            if (_goal != 'maintain' && _targetWeight != null)
              _summaryRow(Icons.my_location,
                  'Target weight', _formatWeightForDisplay(_targetWeight!)),
            const Divider(height: 20),
            _summaryRow(Icons.local_fire_department_outlined, 'BMR', bmr),
            _summaryRow(Icons.bolt_outlined, 'Daily calories', calories),
            const SizedBox(height: 8),
            Text('Daily Macros',
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
              _startConversation();
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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helper methods ──────────────────────────────────────────────────

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

  String _formatWeightForDisplay(double kg) {
    if (_weightUnit == 'lb') {
      final lb = kg * 2.20462;
      return '${lb.toStringAsFixed(1)} lb';
    } else {
      return '${kg.toStringAsFixed(1)} kg';
    }
  }

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

  double _convertWeightToKg(double weight) {
    if (_weightUnit == 'lb') {
      return weight / 2.20462;
    }
    return weight;
  }

  // ── Message bubble builder ───────────────────────────────────────────

  Widget _buildMessage(_ChatMessage m) {
    const double avatarSize = 36;

    Widget fallbackUserAvatar() {
      return CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: _brandGreen,
        child: const Icon(Icons.person,
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

    final bubble = ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFE4F2DE) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
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
        child: m.isTyping
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _brandGreen),
                  ),
                  const SizedBox(width: 8),
                  const Text('…'),
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

  Widget _buildIntroScreen() {
    return ColoredBox(
      color: _surfaceGreen,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Gradient header — matches meal_spinner_page.dart
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
                    // Avatar card
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

                    // Info card — matches shopping_list.dart card style
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
                        'I will ask a few quick questions (age, height, weight, gender, activity level, and fitness goal) '
                        'to calculate your daily calorie and macro needs.\n\n'
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

  // ── Selection panel helper ───────────────────────────────────────────

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
              // Gradient header — matches meal_spinner_page.dart / shopping_list.dart
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
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _buildMessage(_messages[i]),
                ),
              ),

              // ── Step 1: Height unit selection ──
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

              // ── Step 3: Weight unit selection ──
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

              // ── Step 5: Gender selection ──
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

              // ── Step 6: Activity selection ──
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

              // ── Step 7: Goal selection ──
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

              // ── Text input for numeric steps ──
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
                              decimal: _step != 0,
                            ),
                            inputFormatters: [
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

              // ── Step 9: Done buttons ──
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

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isTyping;
  _ChatMessage(
      {required this.text, required this.fromUser, this.isTyping = false});
}

