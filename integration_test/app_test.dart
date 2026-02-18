import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simplyserve/main.dart' as app;

void main() {
  // Initialize the integration test binding
  // ignore: unused_local_variable
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Integration: Launch app, navigate to Home, show SnackBar',
      (tester) async {
    // Start the real app
    app.main();
    await tester.pumpAndSettle();

    // Verify we're on the Login screen
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Ensure Continue button is visible and tap it to navigate to HomePage
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify HomePage content
    expect(find.text('Welcome'), findsOneWidget);
    expect(
        find.text('View Nutrition Information and Meal Plans'), findsOneWidget);

    // Tap the Say Hello button and assert SnackBar message
    await tester.ensureVisible(find.text('Say Hello'));
    await tester.tap(find.text('Say Hello'));
    // Wait for SnackBar animation
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Hello from HomePage!'), findsOneWidget);

    // Optionally capture a screenshot on supported bindings
    // binding.takeScreenshot('after_say_hello');
  });
}
