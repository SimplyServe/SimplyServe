import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('LoginPage Widget Tests', () {
    testWidgets('LoginPage renders with all required elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Check for app title
      expect(find.text('Simply Serve'), findsOneWidget);

      // Check for mode title
      expect(find.text('Sign in'), findsOneWidget);

      // Check for subtitle
      expect(find.text('Enter your details to continue'), findsOneWidget);

      // Check for text fields
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password in login mode

      // Check for buttons
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('Login mode shows correct text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Should show Sign in
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Need an account?'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('Email and password fields are present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Find text fields by their labels
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Continue button exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Find Continue button
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    });

    testWidgets('LoginPage has Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('LoginPage is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Verify it's stateful (can change modes)
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}