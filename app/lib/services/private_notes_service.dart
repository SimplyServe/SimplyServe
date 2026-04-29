import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores private per-recipe notes locally.
/// Notes are keyed by recipe title (for local recipes) or recipe id (for API recipes).
class PrivateNotesService {
  static const String _storageKey = 'private_recipe_notes';

  Future<Map<String, String>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    return Map<String, String>.from(json.decode(raw));
  }

  Future<void> _saveAll(Map<String, String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(notes));
  }

  /// Build a storage key for the recipe.
  String _recipeKey({int? id, required String title}) {
    if (id != null) return 'id_$id';
    return 'title_$title';
  }

  /// Load the private note for a recipe. Returns empty string if none.
  Future<String> getNote({int? id, required String title}) async {
    final all = await _loadAll();
    return all[_recipeKey(id: id, title: title)] ?? '';
  }

  /// Save a private note for a recipe.
  Future<void> saveNote({int? id, required String title, required String note}) async {
    final all = await _loadAll();
    final key = _recipeKey(id: id, title: title);
    if (note.trim().isEmpty) {
      all.remove(key);
    } else {
      all[key] = note;
    }
    await _saveAll(all);
  }
}
