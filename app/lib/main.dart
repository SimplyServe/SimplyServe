// ============================================================
// main.dart — Application Entry Point
//
// This is the first file Flutter executes. It:
//   1. Initialises Flutter bindings so async calls can happen before runApp()
//   2. Loads environment variables from a .env file (API base URL, etc.)
//   3. Reads the persisted login flag from SharedPreferences to decide
//      whether to land on the login screen or the dashboard
//   4. Registers every named route so Navigator.pushNamed() works
//      anywhere in the app without needing a context reference
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/views/meal_spinner_page.dart';
import 'package:simplyserve/views/nutritional_dashboard.dart';
import 'package:simplyserve/views/recipes.dart';
import 'package:simplyserve/views/settings.dart';
import 'package:simplyserve/views/profile.dart';
import 'package:simplyserve/views/shopping_list.dart';
import 'package:simplyserve/views/deleted_recipes.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:simplyserve/views/calorie_coach.dart';

/// Entry point — must be async because we need to await SharedPreferences
/// and dotenv before the widget tree is built.
void main() async {
  // Required when calling async code before runApp(); ensures the Flutter
  // engine is ready to handle method-channel calls (e.g. SharedPreferences).
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file so API base URL and other secrets are available via
  // dotenv.env['KEY'] throughout the app.
  await dotenv.load(fileName: ".env");

  // Read the login flag that was persisted after the user last logged in.
  // Defaults to false if the key has never been written (first-ever launch).
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Build the root widget, passing the login flag so the initial route
  // can be chosen before the first frame is painted — avoids a flash of
  // the login screen for already-authenticated users.
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

/// Root widget. StatelessWidget is sufficient because the app-level
/// configuration (theme, routes) never changes at runtime.
class MyApp extends StatelessWidget {
  /// Whether the user was already logged in when the app launched.
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simply Serve',
      debugShowCheckedModeBanner: false,

      // If the user was logged in, skip the login screen and go straight
      // to the dashboard; otherwise show the login/register page.
      initialRoute: isLoggedIn ? '/' : '/login',

      // ── Named route table ──────────────────────────────────────────────
      // All screens in the app are registered here. Navigator.pushNamed()
      // looks up this map at runtime. The '/recipe' route is the only one
      // that receives an argument (a RecipeModel) via ModalRoute.settings.
      routes: {
        '/login':           (context) => const LoginPage(),
        '/':                (context) => const DashboardView(),          // nutritional_dashboard.dart
        '/spin':            (context) => const SpinWheelView(),          // meal_spinner_page.dart
        '/recipes':         (context) => const RecipesView(),            // recipes.dart
        '/recipe': (context) {
          // Extract the RecipeModel passed by the caller via
          // Navigator.pushNamed(context, '/recipe', arguments: recipe).
          // The cast is nullable so a broken call shows an empty page
          // rather than crashing.
          final recipe =
              ModalRoute.of(context)?.settings.arguments as RecipeModel?;
          return RecipePage(recipe: recipe);
        },
        '/settings':        (context) => const SettingsView(),
        '/profile':         (context) => const ProfileView(),
        '/shopping-list':   (context) => const ShoppingListView(),
        '/deleted-recipes': (context) => const DeletedRecipesView(),
        '/calorie-coach':   (context) => const CalorieCoachView(),
      },
    );
  }
}
