import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/nutritional_dashboard.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  setUp(() {
    // Provide an empty SharedPreferences store so cc_completed is unset
    SharedPreferences.setMockInitialValues({});
  });

  group('DashboardView Widget Tests', () {
    testWidgets('DashboardView renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Verify DashboardView loads
      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Dashboard'), findsOneWidget);

      // Verify main content - message will be "Welcome Back!" or "Welcome Back {name}!"
      expect(find.textContaining('Welcome Back'), findsWidgets);
    });

    testWidgets(
        'DashboardView displays macro counter and no meals message by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Default state shows macro counter with zeros
      expect(find.text('Calories Today'), findsOneWidget);
      expect(find.text('0 kcal'), findsOneWidget);

      // Shows "Today's Meals" section — title and no-meals message (two separate Text widgets)
      expect(find.text("Today's Meals"), findsOneWidget);
      expect(find.text('No meals logged yet'), findsOneWidget);
      expect(
          find.text('Log meals from the Meal Calendar or Shopping List.'),
          findsOneWidget);
    });

    testWidgets('Dashboard shows Log meals button when no data',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Verify the Log meals button exists
      expect(find.text('Log meals in calendar'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    });

    testWidgets('Dashboard always shows Browse Recipes button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Always shown at the bottom
      expect(find.text('Looking for meal ideas?'), findsOneWidget);
      expect(find.text('Browse Recipes'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    });

    testWidgets('DashboardView displays drawer navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Open the drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify drawer header
      expect(find.text('Simply Serve'), findsWidgets);
      expect(find.text('Smart Meal Planner'), findsOneWidget);

      // Verify navigation menu items
      expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
      expect(find.text('Recipes'), findsAtLeastNWidgets(1));
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('Dashboard drawer has navigation icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Open the drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify icons in drawer (some icons may appear multiple times)
      expect(find.byIcon(Icons.dashboard), findsWidgets);
      expect(find.byIcon(Icons.restaurant_menu), findsWidgets);
      expect(find.byIcon(Icons.settings), findsWidgets);
    });

    testWidgets('Dashboard shows Meal Spinner button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      expect(find.text('Meal Spinner'), findsOneWidget);
      expect(find.byIcon(Icons.casino), findsOneWidget);
    });

    testWidgets('Dashboard welcome header shows daily summary subtitle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      expect(find.text('Here is your daily nutritional summary.'), findsOneWidget);
    });

    testWidgets('Dashboard macro counter shows Protein, Carbs and Fat labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('Dashboard welcome header shows profile avatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // No profile image loaded in test env — fallback person icon shown
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('Dashboard shows Calorie Coach setup card for new users',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );
      // Wait for SharedPreferences to resolve (no network call, safe to settle)
      await tester.pumpAndSettle();

      // cc_completed is unset → _showCoachButton is true
      expect(find.text('Set Up Your Calorie Coach'), findsOneWidget);
      expect(find.text('Start Calorie Coach'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('DashboardView has SingleChildScrollView',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Verify scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('DashboardView renders with proper styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF74BC42),
            ),
          ),
          home: const DashboardView(),
        ),
      );
      await tester.pump();

      // Verify dashboard renders with themed content and key structural widgets
      expect(find.textContaining('Welcome Back'), findsWidgets);
      expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
