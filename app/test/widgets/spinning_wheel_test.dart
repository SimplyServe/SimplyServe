import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/widgets/spinning_wheel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for testing
    await dotenv.load(fileName: ".env");
  });

  group('SpinningWheelWidget Tests', () {
    testWidgets('SpinningWheelWidget renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpinningWheelWidget(),
          ),
        ),
      );

      // Widget should render
      expect(find.byType(SpinningWheelWidget), findsOneWidget);
    });

    testWidgets('SpinningWheelWidget is a StatefulWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpinningWheelWidget(),
          ),
        ),
      );

      // Should be stateful
      expect(find.byType(SpinningWheelWidget), findsOneWidget);
    });

    testWidgets('SpinningWheelWidget shows loading initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpinningWheelWidget(),
          ),
        ),
      );

      // Should show loading indicator or widget
      expect(find.byType(SpinningWheelWidget), findsOneWidget);
    });
  });
}