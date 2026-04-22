import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int? _age;
  double? _height; // cm
  double? _weight; // kg
  String _gender = 'Male';
  String _activity = 'Sedentary';

  // store results for summary
  double? _bmr;
  double? _tdee;

  // Optional: replace these with your asset paths if you add avatar images to assets.
  // e.g. put files under assets/images/user.png and assets/images/bot.png and add them to pubspec.yaml.
  final String? _botAvatarAsset = null; // 'assets/images/bot.png';
  final String? _userAvatarAsset = null; // 'assets/images/user.png';

  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly active': 1.375,
    'Moderately active': 1.55,
    'Very active': 1.725,
    'Extra active': 1.9,
  };

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  // startConversation is async so bot messages can be sent with typing delay
  Future<void> _startConversation() async {
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
    await _sendBot('Hi — I\'m your Calorie Coach. Let\'s figure out your daily needs. How old are you? (years)');
  }

  // Adds a user message immediately
  void _pushUser(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
    });
  }

  // Sends bot message with typing indicator ("…") and optional delay
  Future<void> _sendBot(String text, {int delayMs = 800}) async {
    // add typing indicator
    setState(() {
      _messages.add(_ChatMessage(text: '…', fromUser: false, isTyping: true));
    });

    await Future.delayed(Duration(milliseconds: delayMs));

    // remove the typing indicator (last typing message) and add real message
    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.isTyping == true);
      if (idx != -1) _messages.removeAt(idx);
      _messages.add(_ChatMessage(text: text, fromUser: false));
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

    // store results for summary dialog
    setState(() {
      _bmr = bmr;
      _tdee = tdee;
    });

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
    super.dispose();
  }

  // Modified: show profile avatar on left for bot and right for user
  Widget _buildMessage(_ChatMessage m) {
    // avatar widget builder: uses asset if provided, otherwise fallback to Icon
    Widget _avatar(bool isUser) {
      final asset = isUser ? _userAvatarAsset : _botAvatarAsset;
      if (asset != null) {
        return CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage(asset),
          backgroundColor: Colors.transparent,
        );
      }
      // default icons
      return CircleAvatar(
        radius: 18,
        backgroundColor: isUser ? Colors.green[300] : Colors.grey[400],
        child: Icon(
          isUser ? Icons.person : Icons.smart_toy,
          color: Colors.white,
          size: 18,
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessage(_messages[i]),
              ),
            ),

            // Choice row for gender
            if (_step == 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _selectGender('Male'),
                        child: const Text('Male'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _selectGender('Female'),
                        child: const Text('Female'),
                      ),
                    ),
                  ],
                ),
              ),

            // Choice row for activity
            if (_step == 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _activityMultipliers.keys.map((k) {
                    return ElevatedButton(
                      onPressed: () => _selectActivity(k),
                      child: Text(k),
                    );
                  }).toList(),
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