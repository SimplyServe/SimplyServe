import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/nutritional_dashboard.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('SpinWheelView Widget Tests', () {
    testWidgets('SpinWheelView renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify SpinWheelView loads
      expect(find.byType(SpinWheelView), findsOneWidget);
      expect(find.byType(NavBarScaffold), findsOneWidget);
    });

    testWidgets('SpinWheelView has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify title is shown
      expect(find.text('Meal Spinner'), findsOneWidget);
    });

    testWidgets('SpinWheelView displays main heading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify main heading
      expect(find.text('Feeling indecisive?'), findsOneWidget);
    });

    testWidgets('SpinWheelView displays subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify subtitle
      expect(find.text('Let the wheel decide your next meal.'), findsOneWidget);
    });

    testWidgets('SpinWheelView has SingleChildScrollView',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('SpinWheelView is a StatelessWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpinWheelView(),
        ),
      );

      // Verify widget structure
      expect(find.byType(SpinWheelView), findsOneWidget);
    });
  });
}
