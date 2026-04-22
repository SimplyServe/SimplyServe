import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // added
import 'package:simplyserve/widgets/navbar.dart';

class CalorieCoachView extends StatefulWidget {
  const CalorieCoachView({super.key});

  @override
  State<CalorieCoachView> createState() => _CalorieCoachViewState();
}

class _CalorieCoachViewState extends State<CalorieCoachView> {
  final _inputCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  int _step = 0; // 0: age, 1: height, 2: weight, 3: gender, 4: activity, 5: done

  // auto-scroll controller so new bot messages (intro) are visible
  final ScrollController _scrollCtrl = ScrollController();

  int? _age;
  double? _height; // cm
  double? _weight; // kg
  String _gender = 'Male';
  String _activity = 'Sedentary';

  // store results for summary
  double? _bmr;
  double? _tdee;

  // Optional: replace these with your asset paths if you add avatar images to assets.
  // Put the attached image file.png under assets/images/image.png
  final String? _botAvatarAsset = 'assets/images/image.png'; // use attached image
  final String? _userAvatarAsset = null; // 'assets/images/user.png';

  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly active': 1.375,
    'Moderately active': 1.55,
    'Very active': 1.725,
    'Extra active': 1.9,
  };

  // Friendly descriptions used in the activity selection UI
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

  @override
  void initState() {
    super.initState();
    // attempt to load saved results; if none, start normal conversation
    _loadSavedResults();
  }

  Future<void> _loadSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTdee = prefs.getDouble(_kTdee);
    if (storedTdee == null) {
      // no saved results
      await _startConversation();
      return;
    }

    // restore fields
    setState(() {
      _age = prefs.getInt(_kAge);
      _height = prefs.getDouble(_kHeight);
      _weight = prefs.getDouble(_kWeight);
      _gender = prefs.getString(_kGender) ?? 'Male';
      _activity = prefs.getString(_kActivity) ?? 'Sedentary';
      _bmr = prefs.getDouble(_kBmr);
      _tdee = prefs.getDouble(_kTdee);
      _step = 5; // mark as done so UI shows Restart/Done
    });

    // show restored conversation/messages immediately (no typing delay)
    _messages.clear();
    _pushBot('Welcome back — I loaded your previous Calorie Coach results.');
    _pushBot('Age: ${_age ?? 'N/A'}');
    _pushBot('Height: ${_height != null ? _height!.toStringAsFixed(1) + " cm" : 'N/A'}');
    _pushBot('Weight: ${_weight != null ? _weight!.toStringAsFixed(1) + " kg" : 'N/A'}');
    _pushBot('Gender: $_gender');
    _pushBot('Activity: $_activity');
    if (_bmr != null && _tdee != null) {
      _pushBot('BMR: ${_bmr!.round()} kcal/day');
      _pushBot('Estimated needs (TDEE): ${_tdee!.round()} kcal/day');
    } else {
      _pushBot('No calculated results found. You can restart to run again.');
    }
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    if (_age != null) prefs.setInt(_kAge, _age!);
    if (_height != null) prefs.setDouble(_kHeight, _height!);
    if (_weight != null) prefs.setDouble(_kWeight, _weight!);
    prefs.setString(_kGender, _gender);
    prefs.setString(_kActivity, _activity);
    if (_bmr != null) prefs.setDouble(_kBmr, _bmr!);
    if (_tdee != null) prefs.setDouble(_kTdee, _tdee!);
  }

  Future<void> _clearSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAge);
    await prefs.remove(_kHeight);
    await prefs.remove(_kWeight);
    await prefs.remove(_kGender);
    await prefs.remove(_kActivity);
    await prefs.remove(_kBmr);
    await prefs.remove(_kTdee);
  }

  // startConversation is async so bot messages can be sent with typing delay
  Future<void> _startConversation() async {
    // clear saved results in storage when explicitly starting fresh
    await _clearSavedResults();

    _messages.clear();
    _step = 0;
    _age = null;
    _height = null;
    _weight = null;
    _gender = 'Male';
    _activity = 'Sedentary';
    _bmr = null;
    _tdee = null;
    setState(() {});

    // Full intro text shown immediately (no typing indicator / delay)
    _pushBot('Welcome to Calorie Coach — your simple assistant for estimating daily calorie needs.');
    _pushBot('I will ask a few quick questions (age, height, weight, gender, activity level) and use the Mifflin–St Jeor equation to estimate your Basal Metabolic Rate (BMR) and Total Daily Energy Expenditure (TDEE).');
    _pushBot('Your answers are stored locally on this device so you can return later and see your results again. Data stays on your device only.');
    _pushBot('This will only take a moment. First question — how old are you? (years)');
  }

  // Adds a user message immediately
  void _pushUser(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
    });
    _scrollToBottom();
  }

  // Adds a bot message immediately (no typing indicator / delay)
  void _pushBot(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

  // Sends bot message with typing indicator ("…") and optional delay
  Future<void> _sendBot(String text, {int delayMs = 800}) async {
    // add typing indicator
    setState(() {
      _messages.add(_ChatMessage(text: '…', fromUser: false, isTyping: true));
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: delayMs));

    // remove the typing indicator (last typing message) and add real message
    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.isTyping == true);
      if (idx != -1) _messages.removeAt(idx);
      _messages.add(_ChatMessage(text: text, fromUser: false));
    });
    _scrollToBottom();
  }

  // ensure list scrolls to bottom when new messages arrive
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

  Future<void> _handleSubmitText() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _pushUser(text);
    _inputCtrl.clear();

    switch (_step) {
      case 0:
        final n = int.tryParse(text);
        if (n == null || n < 10 || n > 120) {
          await _sendBot('Please enter a valid age (10–120).');
          return;
        }
        _age = n;
        _step = 1;
        await _sendBot('Great. What is your height in cm?');
        break;
      case 1:
        final n = double.tryParse(text);
        if (n == null || n < 50 || n > 300) {
          await _sendBot('Please enter a realistic height in cm (e.g. 170).');
          return;
        }
        _height = n;
        _step = 2;
        await _sendBot('Nice. What is your weight in kg?');
        break;
      case 2:
        final n = double.tryParse(text);
        if (n == null || n < 20 || n > 700) {
          await _sendBot('Please enter a realistic weight in kg (e.g. 70).');
          return;
        }
        _weight = n;
        _step = 3;
        await _sendBot('Which gender should I use? Tap a button:');
        break;
      default:
        break;
    }
  }

  Future<void> _selectGender(String g) async {
    _pushUser(g);
    _gender = g;
    _step = 4;
    await _sendBot('Thanks. Now choose your typical activity level:');
    setState(() {});
  }

  Future<void> _selectActivity(String a) async {
    _pushUser(a);
    _activity = a;
    _step = 5;
    await _calculateAndShowResults();
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

    // store results for summary dialog and persist them
    setState(() {
      _bmr = bmr;
      _tdee = tdee;
    });
    await _saveResults();

    await _sendBot('Here are your results:');
    await _sendBot('BMR (basal metabolic rate): ${bmr.round()} kcal/day', delayMs: 600);
    await _sendBot('Estimated daily needs (TDEE): ${tdee.round()} kcal/day (activity: $_activity)', delayMs: 600);
    await _sendBot('Tap "Restart" to run again or press "Done" to see a summary.', delayMs: 500);
    setState(() {});
  }

  // show summary dialog when Done is pressed
  void _showSummaryDialog() {
    final age = _age?.toString() ?? 'N/A';
    final height = _height != null ? '${_height!.toStringAsFixed(1)} cm' : 'N/A';
    final weight = _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : 'N/A';
    final gender = _gender;
    final activity = _activity;
    final bmr = _bmr != null ? '${_bmr!.round()} kcal/day' : 'N/A';
    final tdee = _tdee != null ? '${_tdee!.round()} kcal/day' : 'N/A';

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
            Text('Gender: $gender'),
            Text('Activity: $activity'),
            const SizedBox(height: 8),
            Text('BMR: $bmr'),
            Text('Estimated daily needs (TDEE): $tdee'),
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

  // Modified: show profile avatar on left for bot and right for user
  Widget _buildMessage(_ChatMessage m) {
    // avatar widget builder: uses asset if provided, otherwise fallback to Icon
    // larger avatar for better visibility
    final double _avatarSize = 56;

    Widget _avatar(bool isUser) {
      final asset = isUser ? _userAvatarAsset : _botAvatarAsset;
      if (asset != null) {
        return Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.cover, // center-crop
              alignment: Alignment.center,
            ),
          ),
          // keep Image.asset underneath to provide errorBuilder fallback
          child: ClipOval(
            child: Image.asset(
              asset,
              width: _avatarSize,
              height: _avatarSize,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) {
                if (isUser) {
                  return Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green[300],
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: _avatarSize * 0.45),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      // fallback avatars
      if (isUser) {
        return CircleAvatar(
          radius: _avatarSize / 2,
          backgroundColor: Colors.green[300],
          child: Icon(Icons.person, color: Colors.white, size: _avatarSize * 0.45),
        );
      }

      return CircleAvatar(
        radius: _avatarSize / 2,
        backgroundColor: Colors.transparent,
      );
    }

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: Container(
        decoration: BoxDecoration(
          color: m.fromUser ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: m.isTyping
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
      // user: bubble on left of avatar, align to right
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: bubble),
            const SizedBox(width: 8),
            _avatar(true),
          ],
        ),
      );
    } else {
      // bot: avatar on left of bubble, align to left
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(false),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Calorie Coach',
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl, // ensure auto-scroll works
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessage(_messages[i]),
              ),
            ),

            // Improved gender choice: ChoiceChips with icons and clear labels
            if (_step == 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Which gender should I use?', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Male'),
                          avatar: const Icon(Icons.male, size: 18),
                          selected: _gender == 'Male',
                          // always call handler so user can confirm / proceed even if already selected
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
                    const Text('You can change this later in your profile.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

            // Improved activity selection: selectable list with short descriptions
            if (_step == 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Choose your typical activity level', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._activityMultipliers.keys.map((k) {
                      final selected = _activity == k;
                      return Card(
                        color: selected ? Colors.green[50] : null,
                        child: InkWell(
                          onTap: () => _selectActivity(k),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: selected ? Colors.green : Colors.black54,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.green[800] : Colors.black)),
                                      const SizedBox(height: 2),
                                      Text(_activityDescriptions[k] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                if (selected) const Icon(Icons.check, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 6),
                    const Text('Tap an option to select. If you are unsure, choose the closest match.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

            // Text input for numeric steps (age/height/weight)
            if (_step == 0 || _step == 1 || _step == 2)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          keyboardType: TextInputType.numberWithOptions(decimal: _step != 0),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: InputDecoration(
                            hintText: _step == 0
                                ? 'Enter age'
                                : _step == 1
                                    ? 'Enter height (cm)'
                                    : 'Enter weight (kg)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

            // Restart button when done
            if (_step == 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _startConversation();
                        },
                        child: const Text('Restart'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // show summary dialog instead of just popping
                          _showSummaryDialog();
                        },
                        child: const Text('Done'),
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
  _ChatMessage({required this.text, required this.fromUser, this.isTyping = false});
}