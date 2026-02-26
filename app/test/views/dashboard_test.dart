import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/dashboard.dart';
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
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Hello! This is the dashboard.'), findsOneWidget);
    });

    testWidgets('DashboardView displays nutrition info button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Find the nutrition info button
      expect(find.text('View Nutrition Information and Meal Plans'),
          findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Nutrition info button shows SnackBar when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Tap the nutrition info button
      await tester.tap(find.text('View Nutrition Information and Meal Plans'));
      await tester.pump(); // Start SnackBar animation

      // Verify SnackBar message
      expect(
        find.text('Here you can view nutrition information and meal plans!'),
        findsOneWidget,
      );
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
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify icons in drawer
      expect(find.byIcon(Icons.dashboard), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
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

    testWidgets('DashboardView uses correct theme color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Find the ElevatedButton
      final buttonFinder = find.widgetWithText(
          ElevatedButton, 'View Nutrition Information and Meal Plans');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);

      // Verify button uses the theme color (#74BC42)
      final buttonColor = button.style?.backgroundColor?.resolve({});
      expect(buttonColor, const Color(0xFF74BC42));
    });
  });
}
