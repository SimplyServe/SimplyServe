import 'package:shared_preferences/shared_preferences.dart';

class AllergyService {
  static const String _allergiesKey = 'user_allergies';

  Future<List<String>> loadAllergies() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_allergiesKey) ?? const <String>[];
    return _normalize(stored);
  }

  Future<void> saveAllergies(List<String> allergies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allergiesKey, _normalize(allergies));
  }

  List<String> _normalize(List<String> values) {
    final normalized = <String>[];
    final seenLower = <String>{};

    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final lowered = trimmed.toLowerCase();
      if (seenLower.add(lowered)) {
        normalized.add(trimmed);
      }
    }

    return normalized;
  }
}
