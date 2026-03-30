import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/widgets/navbar.dart';

void main() {
  group('NavBarScaffold Tests', () {
    testWidgets('NavBarScaffold renders with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarScaffold(
            title: 'Test Title',
            body: Center(child: Text('Test Body')),
          ),
        ),
      );

      // Should render title
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('NavBarScaffold renders body', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarScaffold(
            title: 'Test',
            body: Center(child: Text('Test Body')),
          ),
        ),
      );

      // Should render body
      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('NavBarScaffold has Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarScaffold(
            title: 'Test',
            body: Center(child: Text('Content')),
          ),
        ),
      );

      // Should have Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('NavBarScaffold renders properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarScaffold(
            title: 'Test',
            body: Center(child: Text('Content')),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(NavBarScaffold), findsOneWidget);
    });
  });
}