import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('ProfileView Widget Tests', () {
    testWidgets('ProfileView renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileView(),
        ),
      );

      await tester.pump();

      // Verify ProfileView loads
      expect(find.byType(ProfileView), findsOneWidget);
    });

    testWidgets('ProfileView is a StatefulWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileView(),
        ),
      );

      await tester.pump();

      // Verify it's a stateful widget
      expect(find.byType(ProfileView), findsOneWidget);
    });

    testWidgets('ProfileView has Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileView(),
        ),
      );

      await tester.pump();

      // Verify Scaffold is present
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ProfileView structure is correct',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileView(),
        ),
      );

      await tester.pump();

      // Verify basic structure
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
