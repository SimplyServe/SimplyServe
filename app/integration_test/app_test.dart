import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:simplyserve/main.dart' as app;

void main() {
  // Initialize the integration test binding
  // Initialize the integration test binding. Some environments may not provide
  // the integration binding symbol at runtime; fall back to the regular
  // WidgetsBinding if that happens so tests can still run on the device.
  try {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } catch (_) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  testWidgets('Integration: Launch app, navigate to Dashboard, show SnackBar',
      (tester) async {
    // Start the real app
    app.main();

    // Give the app more time to initialize and render
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Wait for the login page to be fully rendered
    await tester.pump();

    // Verify we're on the Login screen
    expect(find.text('Sign in'), findsOneWidget);

    // Find the Continue button (as an ElevatedButton widget)
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
    expect(continueButton, findsOneWidget);

    // Scroll to make sure the button is visible and tap it
    await tester.scrollUntilVisible(
      continueButton,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify Dashboard content
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Hello! This is the dashboard.'), findsOneWidget);

    // Find and tap the nutrition info button
    final nutritionButton =
        find.text('View Nutrition Information and Meal Plans');
    expect(nutritionButton, findsOneWidget);

    await tester.tap(nutritionButton);
    // Wait for SnackBar animation
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the SnackBar message appears
    expect(find.text('Here you can view nutrition information and meal plans!'),
        findsOneWidget);
  });

  testWidgets('Integration: Navigate to Recipes via drawer', (tester) async {
    // Start the real app
    app.main();

    // Give the app time to initialize
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Login
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.scrollUntilVisible(
      continueButton,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Open drawer
    final ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify drawer is open with navigation items
    expect(find.text('Simply Serve'), findsWidgets);
    expect(find.text('Smart Meal Planner'), findsOneWidget);

    // Tap Recipes in drawer
    final recipesTile = find.ancestor(
      of: find.text('Recipes'),
      matching: find.byType(ListTile),
    );
    await tester.tap(recipesTile.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify we're on Recipes page
    expect(
        find.text(
            'Browse and discover delicious meal recipes tailored to your dietary needs.'),
        findsOneWidget);
    expect(find.text('Search Recipes'), findsOneWidget);

    // Test search button
    await tester.tap(find.text('Search Recipes'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify SnackBar
    expect(find.text('Recipe search coming soon!'), findsOneWidget);
  });

  testWidgets('Integration: Navigate to Settings via drawer', (tester) async {
    // Start the real app
    app.main();

    // Give the app time to initialize
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Login
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.scrollUntilVisible(
      continueButton,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Open drawer
    final ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Tap Settings in drawer
    final settingsTile = find.ancestor(
      of: find.text('Settings'),
      matching: find.byType(ListTile),
    );
    await tester.tap(settingsTile.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify we're on Settings page
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Verify all settings items are present
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
  });

  testWidgets('Integration: Navigate between all pages via drawer',
      (tester) async {
    // Start the real app
    app.main();

    // Give the app time to initialize
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Login
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.scrollUntilVisible(
      continueButton,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Start on Dashboard
    expect(find.text('Welcome'), findsOneWidget);

    // Navigate to Recipes
    ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find
        .ancestor(
          of: find.text('Recipes'),
          matching: find.byType(ListTile),
        )
        .first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Search Recipes'), findsOneWidget);

    // Navigate to Settings
    state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find
        .ancestor(
          of: find.text('Settings'),
          matching: find.byType(ListTile),
        )
        .first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Account'), findsOneWidget);

    // Navigate back to Dashboard
    state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find
        .ancestor(
          of: find.text('Dashboard'),
          matching: find.byType(ListTile),
        )
        .first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Welcome'), findsOneWidget);
  });
}
