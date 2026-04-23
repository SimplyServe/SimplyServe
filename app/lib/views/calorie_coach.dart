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

  // 40/30/30 split (carbs/protein/fat) based on calorie target
  double _computeProteinTarget(double calories) {
    return (calories * 0.30) / 4; // 30% of calories, 4 kcal per gram
  }

  double _computeCarbTarget(double calories) {
    return (calories * 0.40) / 4; // 40% of calories, 4 kcal per gram
  }

  double _computeFatTarget(double calories) {
    return (calories * 0.30) / 9; // 30% of calories, 9 kcal per gram
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
    final gender = _gender;
    final activity = _activity;
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
        title: const Text('Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Age: $age'),
            Text('Height: $height'),
            Text('Weight: $weight'),
            Text('Gender: ${_gender ?? 'N/A'}'),
            Text('Activity: ${_activity ?? 'N/A'}'),
            Text('Goal: $_goalDisplayName'),
            if (_goal != 'maintain' && _targetWeight != null)
              Text('Target weight: ${_formatWeightForDisplay(_targetWeight!)}'),
            const SizedBox(height: 8),
            Text('BMR: $bmr'),
            Text('Daily calorie target: $calories'),
            const SizedBox(height: 8),
            const Text('Daily Macros :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text(' Protein : $protein'),
            Text(' Carbs : $carbStr'),
            Text(' Fat : $fatStr'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startConversation();
            },
            child: const Text('Restart'),
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
    // avatar widget builder: uses asset if provided, otherwise fallback to Icon
    // larger avatar for better visibility
    const double avatarSize = 56;

    Widget fallbackUserAvatar() {
      return CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: Colors.green[300],
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              asset,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) {
                if (isUser) {
                  return fallbackUserAvatar();
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      if (isUser) {
        return fallbackUserAvatar();
      }

      return const CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: Colors.transparent,
      );
    }

    final bubble = ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: Container(
        decoration: BoxDecoration(
          color: m.fromUser ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: m.isTyping
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('…'),
                ],
              )
            : Text(m.text, style: const TextStyle(color: Colors.black)),
      ),
    );

    if (m.fromUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/Coach.png',
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.smart_toy, size: 100, color: Colors.green),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Welcome to Calorie Coach — your assistant for personalized calorie and protein targets.\n\n'
              'I will ask a few quick questions (age, height, weight, gender, activity level, and fitness goal) '
              'to calculate your daily calorie and macro needs.\n\n'
              'Your answers are stored locally on this device only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, height: 1.6, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _letsGo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74BC42),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text("Let's Go"),
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
      body: SafeArea(
        child: Column(
          children: [
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Choose your height unit:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Centimeters (cm)'),
                          avatar: const Icon(Icons.straighten, size: 18),
                          selected: false,
                          onSelected: (_) => _selectHeightUnit('cm'),
                        ),
                        ChoiceChip(
                          label: const Text('Feet & Inches'),
                          avatar: const Icon(Icons.height, size: 18),
                          selected: false,
                          onSelected: (_) => _selectHeightUnit('ft'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Step 3: Weight unit selection ──
            if (_step == 3)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Choose your weight unit:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Kilograms (kg)'),
                          avatar: const Icon(Icons.monitor_weight, size: 18),
                          selected: false,
                          onSelected: (_) => _selectWeightUnit('kg'),
                        ),
                        ChoiceChip(
                          label: const Text('Pounds (lb)'),
                          avatar: const Icon(Icons.fitness_center, size: 18),
                          selected: false,
                          onSelected: (_) => _selectWeightUnit('lb'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Step 5: Gender selection ──
            if (_step == 5)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Which gender should I use?',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Male'),
                          avatar: const Icon(Icons.male, size: 18),
                          selected: _gender == 'Male',
                          onSelected: (_) => _selectGender('Male'),
                        ),
                        ChoiceChip(
                          label: const Text('Female'),
                          avatar: const Icon(Icons.female, size: 18),
                          selected: _gender == 'Female',
                          onSelected: (_) => _selectGender('Female'),
                        ),
                        ChoiceChip(
                          label: const Text('Prefer not to say'),
                          selected: _gender == 'Prefer not to say',
                          onSelected: (_) => _selectGender('Prefer not to say'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                        'You can change this later by restarting the coach.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

            // ── Step 6: Activity selection ──
            if (_step == 6)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Choose your typical activity level',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._activityMultipliers.keys.map((k) {
                      final selected = _activity == k;
                      return Card(
                        color: selected ? Colors.green[50] : null,
                        child: InkWell(
                          onTap: () => _selectActivity(k),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color:
                                      selected ? Colors.green : Colors.black54,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(k,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? Colors.green[800]
                                                  : Colors.black)),
                                      const SizedBox(height: 2),
                                      Text(_activityDescriptions[k] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // ── Step 7: Goal selection ──
            if (_step == 7)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('What is your fitness goal?',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...{
                      'gain': {
                        'label': 'Gain Weight',
                        'desc':
                            'Calorie surplus for muscle growth and mass gain',
                        'icon': Icons.trending_up,
                      },
                      'maintain': {
                        'label': 'Maintain Weight',
                        'desc':
                            'Stay at current weight, optimize body composition',
                        'icon': Icons.balance,
                      },
                      'lose': {
                        'label': 'Lose Weight',
                        'desc':
                            'Calorie deficit to lose fat while preserving muscle',
                        'icon': Icons.trending_down,
                      },
                    }.entries.map((e) {
                      final selected = _goal == e.key;
                      return Card(
                        color: selected ? Colors.green[50] : null,
                        child: InkWell(
                          onTap: () => _selectGoal(e.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  e.value['icon'] as IconData,
                                  color:
                                      selected ? Colors.green : Colors.black54,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.value['label'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.green[800]
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.value['desc'] as String,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 6),
                    const Text(
                        'Tap an option to select. If you are unsure, choose the closest match.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

            // ── Text input for numeric steps ──
            if (_showTextInput)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: _step != 0,
                          ),
                          inputFormatters: [
                            // Allow spaces for feet+inches input
                            if (_step == 2 && _heightUnit == 'ft')
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9. ]'))
                            else
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                          ],
                          decoration: InputDecoration(
                            hintText: _inputHintText,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onSubmitted: (_) => _handleSubmitText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleSubmitText,
                        child: const Icon(Icons.send),
                      )
                    ],
                  ),
                ),
              ),

            // ── Step 9: Done buttons ──
            if (_step == 9 && !_isWeightUpdateMode)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _startConversation,
                            child: const Text('Restart'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _showSummaryDialog,
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
                        icon: const Icon(Icons.monitor_weight),
                        label: const Text('Update Current Weight'),
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

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isTyping;
  _ChatMessage(
      {required this.text, required this.fromUser, this.isTyping = false});
}
