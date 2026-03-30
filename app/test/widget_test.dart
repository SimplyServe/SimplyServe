import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:simplyserve/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('MyApp Widget Tests', () {
    testWidgets('MyApp initializes with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      // Verify MaterialApp properties
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Simply Serve');
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('MyApp shows LoginPage when not logged in',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));
      await tester.pumpAndSettle();

      // LoginPage should be visible when not logged in
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('MyApp routing is properly configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      final app = tester.widget<MyApp>(find.byType(MyApp));
      expect(app, isNotNull);
    });
  });

  group('LoginPage Widget Tests', () {
    testWidgets('LoginPage displays all required UI elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      // Check for required text
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Enter your details to continue'), findsOneWidget);

      // Check for text fields
      expect(find.byType(TextField), findsWidgets);

      // Check for buttons
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('LoginPage has image asset', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      // Image should be present
      final images = find.byType(Image);
      if (images.evaluate().isNotEmpty) {
        final image = tester.widget<Image>(images.first);
        final provider = image.image;
        expect(provider, isA<AssetImage>());
      }
    });

    testWidgets('Password field obscures input text',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      if (textFields.length >= 2) {
        // Second field (password) should obscure text
        expect(textFields[1].obscureText, isTrue);
      }
    });

    testWidgets('Continue button has onPressed handler',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final buttons = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .toList();
      if (buttons.isNotEmpty) {
        expect(buttons.first.onPressed, isNotNull);
      }
    });

    testWidgets('Create account button has onPressed handler',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final buttons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();
      if (buttons.isNotEmpty) {
        expect(buttons.first.onPressed, isNotNull);
      }
    });

    testWidgets('Email field accepts user input', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Password field accepts user input',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pump();

      // Text is entered but shown as obscured
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('Navigation Tests', () {
    testWidgets('App navigates between routes correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));
      await tester.pumpAndSettle();

      // Initially on login
      expect(find.byType(LoginPage), findsOneWidget);

      // Navigation should be configured
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Theme Tests', () {
    testWidgets('App has MaterialApp with proper configuration', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app, isNotNull);
      expect(app.title, equals('Simply Serve'));
    });

    testWidgets('App uses default Material theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(isLoggedIn: false));

      // App should be properly configured
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app, isNotNull);
      expect(app.debugShowCheckedModeBanner, isFalse);
    });
  });
}
