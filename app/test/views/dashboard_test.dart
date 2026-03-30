import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/nutritional_dashboard.dart';
import 'package:simplyserve/widgets/navbar.dart';

void main() {
  group('DashboardView Widget Tests', () {
    testWidgets('DashboardView renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Verify NavBarScaffold is present
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Dashboard'), findsOneWidget);

      // Verify main content
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Here is your daily nutritional summary.'), findsOneWidget);
    });

    testWidgets('DashboardView displays no data message by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Default state shows no data message
      expect(find.text('No data to show yet'), findsOneWidget);
      expect(find.text('Log what you ate in Meal Calendar, including servings, and your totals for today will appear here.'), findsOneWidget);
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

    testWidgets('DashboardView has drawer with navigation items',
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

    testWidgets('Dashboard is highlighted as active route in drawer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const DashboardView(),
          },
          initialRoute: '/',
        ),
      );

      // Open the drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Find the Dashboard ListTile
      final dashboardTiles = tester.widgetList<ListTile>(
        find.ancestor(
          of: find.text('Dashboard'),
          matching: find.byType(ListTile),
        ),
      );

      // At least one Dashboard tile should be selected (active route)
      expect(dashboardTiles.any((tile) => tile.selected == true), isTrue);
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

      // Verify dashboard renders with cards and proper content
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.byType(Card), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    });
  });
}
