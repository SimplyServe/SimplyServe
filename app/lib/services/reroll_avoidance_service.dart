import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks recipes that have already been rolled today so the spinning wheel
/// never repeats a recipe within the same calendar day.
class RerollAvoidanceService {
  static const String _storageKey = 'reroll_avoidance';

  /// Returns the set of recipe titles already rolled today.
  Future<Set<String>> getRolledToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};

    final Map<String, dynamic> data = json.decode(raw);
    final storedDate = data['date'] as String?;
    final today = _todayKey();

    if (storedDate != today) {
      // Day has changed — clear stale data.
      await prefs.remove(_storageKey);
      return {};
    }

    return Set<String>.from(data['titles'] as List<dynamic>? ?? []);
  }

  /// Record a recipe title as "already rolled" for today.
  Future<void> markRolled(String recipeTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRolledToday();
    existing.add(recipeTitle);

    final payload = json.encode({
      'date': _todayKey(),
      'titles': existing.toList(),
    });
    await prefs.setString(_storageKey, payload);
  }

  /// Clear all rolled entries (e.g. if user wants a fresh start).
  Future<void> clearRolledToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
