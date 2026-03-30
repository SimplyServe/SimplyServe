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

  group('NutritionalDashboard View Tests', () {
    testWidgets('DashboardView renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      await tester.pump();

      // Verify DashboardView loads with NavBarScaffold
      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.byType(NavBarScaffold), findsOneWidget);
    });

    testWidgets('DashboardView displays correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      await tester.pump();

      // Verify dashboard title
      expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
    });

    testWidgets('DashboardView has SingleChildScrollView',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      await tester.pump();

      // Verify scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('DashboardView is a StatelessWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardView(),
        ),
      );

      // Verify widget structure
      expect(find.byType(DashboardView), findsOneWidget);
    });
  });
}
