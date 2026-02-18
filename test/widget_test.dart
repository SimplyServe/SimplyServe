import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/widgets/widgets.dart'; 
void main() {

  testWidgets('shows popup menu on narrow screens and menu items are present', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400, 
          child: Scaffold(
            body: AppNavigation(bannerText: 'test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('holder'), findsNothing);
    expect(find.text('About'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets); 
    expect(find.text('Holder'), findsOneWidget); 
    expect(find.text('About'), findsOneWidget);
  });
}