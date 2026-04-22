import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simplyserve/widgets/navbar.dart'; // added import

class CalorieCoachView extends StatefulWidget {
  const CalorieCoachView({super.key});

  @override
  State<CalorieCoachView> createState() => _CalorieCoachViewState();
}

class _CalorieCoachViewState extends State<CalorieCoachView> {
  final _formKey = GlobalKey<FormState>();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(); // cm
  final _weightCtrl = TextEditingController(); // kg

  String _gender = 'Male';
  String _activity = 'Sedentary';

  double? _bmr;
  double? _tdee;

  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly active': 1.375,
    'Moderately active': 1.55,
    'Very active': 1.725,
    'Extra active': 1.9,
  };

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;

    // Mifflin-St Jeor equation
    double bmr;
    if (_gender == 'Male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    final multiplier = _activityMultipliers[_activity] ?? 1.2;
    final tdee = bmr * multiplier;

    setState(() {
      _bmr = bmr;
      _tdee = tdee;
    });
  }

  String? _validatePositive(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v.trim());
    if (n == null || n <= 0) return 'Enter a valid positive number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Use NavBarScaffold so the app drawer/navigation is present
    return NavBarScaffold(
      title: 'Calorie Coach',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Age
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Age (years)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final msg = _validatePositive(v);
                  if (msg != null) return msg;
                  final age = int.tryParse(v!.trim()) ?? 0;
                  if (age < 10 || age > 120) return 'Enter a realistic age';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Height
              TextFormField(
                controller: _heightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final msg = _validatePositive(v);
                  if (msg != null) return msg;
                  final h = double.tryParse(v!.trim()) ?? 0;
                  if (h < 50 || h > 300) return 'Enter a realistic height';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Weight
              TextFormField(
                controller: _weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final msg = _validatePositive(v);
                  if (msg != null) return msg;
                  final w = double.tryParse(v!.trim()) ?? 0;
                  if (w < 20 || w > 700) return 'Enter a realistic weight';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Gender & Activity row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v!),
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _activity,
                      items: _activityMultipliers.keys
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) => setState(() => _activity = v!),
                      decoration: const InputDecoration(
                        labelText: 'Activity level',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _calculate,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Calculate'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_bmr != null && _tdee != null)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('BMR (calories/day):'),
                            Text('${_bmr!.round()} kcal'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated needs (TDEE):'),
                            Text('${_tdee!.round()} kcal'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on Mifflin–St Jeor equation and selected activity level.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
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