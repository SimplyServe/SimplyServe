import 'package:shared_preferences/shared_preferences.dart';

class FavouritesService {
  static const _key = 'favourited_recipes';

  Future<Set<String>> loadFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> addFavourite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (!list.contains(title)) {
      list.add(title);
      await prefs.setStringList(_key, list);
    }
  }

  Future<void> removeFavourite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(title);
    await prefs.setStringList(_key, list);
  }

  Future<bool> isFavourite(String title) async {
    final favourites = await loadFavourites();
    return favourites.contains(title);
  }
}
