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

  testWidgets('Integration: Launch app, navigate to Home, show SnackBar',
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

    // Verify HomePage content
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Hello! This is the dashboard.'), findsOneWidget);

    // Find and tap the button that shows nutrition info
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
}
