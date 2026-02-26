import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:simplyserve/main.dart';
import 'package:simplyserve/views/dashboard.dart';

void main() {
  group('Widget tests for LoginPage and DashboardView', () {
    testWidgets('LoginPage shows key elements and navigates to DashboardView',
        (WidgetTester tester) async {
      // Use MyApp to get proper routing
      await tester.pumpWidget(const MyApp());

      // Basic text checks
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Enter your details to continue'), findsOneWidget);

      // There are two TextField widgets (email & password)
      expect(find.byType(TextField), findsNWidgets(2));

      // Buttons: Continue and Create an account
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      // Tap Continue and expect DashboardView to appear
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('DashboardView shows welcome text and SnackBar on button',
        (WidgetTester tester) async {
      // Test DashboardView directly
      await tester.pumpWidget(const MaterialApp(home: DashboardView()));

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Hello! This is the dashboard.'), findsOneWidget);
      expect(find.text('View Nutrition Information and Meal Plans'),
          findsOneWidget);

      // Tap the nutrition info button
      await tester.tap(find.text('View Nutrition Information and Meal Plans'));
      await tester.pump(); // start animation for SnackBar

      // SnackBar should show the message
      expect(
          find.text('Here you can view nutrition information and meal plans!'),
          findsOneWidget);
    });

    testWidgets('MyApp and LoginPage widget properties',
        (WidgetTester tester) async {
      // Pump the full app
      await tester.pumpWidget(const MyApp());

      // MaterialApp properties from MyApp
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Simply Serve');
      expect(materialApp.debugShowCheckedModeBanner, isFalse);

      // LoginPage should be the initial route
      expect(find.byType(LoginPage), findsOneWidget);

      // Image asset is present and uses the expected asset name
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, 'assets/image.png');

      // There are two TextFields and the second (password) hides input
      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, greaterThanOrEqualTo(2));
      expect(textFields[1].obscureText, isTrue);

      // Buttons exist and have onPressed handlers
      final elevated =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevated.onPressed, isNotNull);

      final outlined =
          tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(outlined.onPressed, isNotNull);
    });
  });
}
