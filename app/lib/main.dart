import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/views/dashboard.dart';
import 'package:simplyserve/views/recipes.dart';
import 'package:simplyserve/views/settings.dart';
import 'package:simplyserve/views/profile.dart';
import 'package:simplyserve/views/shopping_list.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simply Serve',
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? '/' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/': (context) => const DashboardView(),
        '/recipes': (context) => const RecipesView(),
        '/recipe': (context) {
          final recipe =
              ModalRoute.of(context)?.settings.arguments as RecipeModel?;
          return RecipePage(recipe: recipe);
        },
        '/settings': (context) => const SettingsView(),
        '/profile': (context) => const ProfileView(),
        '/shopping-list': (context) => const ShoppingListView(),
      },
    );
  }
}
