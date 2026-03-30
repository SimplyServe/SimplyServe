import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('MealCalendarView Widget Tests', () {
    testWidgets('MealCalendarView renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MealCalendarView(),
        ),
      );

      await tester.pump();

      // Verify NavBarScaffold is present
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Meal Calendar'), findsAtLeastNWidgets(1));
    });

    testWidgets('MealCalendarView has Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MealCalendarView(),
        ),
      );

      await tester.pump();

      // Verify Scaffold exists
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('MealCalendarView renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MealCalendarView(),
        ),
      );

      // Verify it renders
      expect(find.byType(MealCalendarView), findsOneWidget);
    });
  });
}