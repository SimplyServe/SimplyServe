import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user-created custom tags stored locally via SharedPreferences.
class CustomTagService {
  static const String _storageKey = 'custom_tags';

  /// Load the list of custom tags.
  Future<List<String>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    return List<String>.from(json.decode(raw));
  }

  /// Save the full list of custom tags (overwrites).
  Future<void> saveTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(tags));
  }

  /// Add a new custom tag. Returns false if it already exists.
  Future<bool> addTag(String tag) async {
    final tags = await loadTags();
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return false;
    if (tags.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    tags.add(trimmed);
    await saveTags(tags);
    return true;
  }

  /// Rename a custom tag.
  Future<void> renameTag(String oldName, String newName) async {
    final tags = await loadTags();
    final index = tags.indexWhere((t) => t == oldName);
    if (index != -1) {
      tags[index] = newName.trim();
      await saveTags(tags);
    }
  }

  /// Delete a custom tag.
  Future<void> deleteTag(String tag) async {
    final tags = await loadTags();
    tags.removeWhere((t) => t == tag);
    await saveTags(tags);
  }
}
