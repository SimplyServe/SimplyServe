import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/views/settings.dart';
import 'package:simplyserve/widgets/navbar.dart';

void main() {
  group('SettingsView Widget Tests', () {
    testWidgets('SettingsView renders correctly with NavBarScaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify NavBarScaffold is present
      expect(find.byType(NavBarScaffold), findsOneWidget);

      // Verify AppBar title
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('SettingsView displays all three sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify all three section headers
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('Account section displays correct items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify Account items
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Manage your profile information'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Control your privacy settings'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('Preferences section displays correct items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify Preferences items
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Manage notification preferences'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Customize app appearance'), findsOneWidget);
      expect(find.byIcon(Icons.palette), findsOneWidget);
    });

    testWidgets('About section displays correct items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify About items
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Get help with the app'), findsOneWidget);
      expect(find.byIcon(Icons.help), findsOneWidget);
    });

    testWidgets('All settings items have chevron trailing icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify there are 6 chevron icons (one for each settings item)
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(6));
    });

    testWidgets('Settings items are tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Find and tap Profile item
      final profileTile = find.ancestor(
        of: find.text('Profile'),
        matching: find.byType(ListTile),
      );

      expect(profileTile, findsOneWidget);

      // Tap should not throw an error
      await tester.tap(profileTile);
      await tester.pump();

      // Still on Settings page (no navigation implemented yet)
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('Settings items use correct theme color for icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Find icons with the theme color
      final personIcon = tester.widget<Icon>(find.byIcon(Icons.person));
      expect(personIcon.color, const Color(0xFF74BC42));

      final lockIcon = tester.widget<Icon>(find.byIcon(Icons.lock));
      expect(lockIcon.color, const Color(0xFF74BC42));

      final notificationsIcon =
          tester.widget<Icon>(find.byIcon(Icons.notifications));
      expect(notificationsIcon.color, const Color(0xFF74BC42));
    });

    testWidgets('Section titles use correct styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Find all Text widgets that might be section titles
      final textWidgets = tester.widgetList<Text>(find.byType(Text));

      // Find one with "Account" text and check its styling
      final accountText = textWidgets.firstWhere(
        (text) => text.data == 'Account',
        orElse: () => throw Exception('Account text not found'),
      );

      // Verify styling
      expect(accountText.style?.fontSize, 14);
      expect(accountText.style?.fontWeight, FontWeight.w600);
      expect(accountText.style?.color, const Color(0xFF74BC42));
    });

    testWidgets('SettingsView uses ListView for scrolling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Verify ListView is used
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('SettingsView uses Card widgets for sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Should have 3 cards (one for each section)
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('SettingsView has drawer with navigation items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
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
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('Settings is highlighted as active route in drawer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/settings': (context) => const SettingsView(),
          },
          initialRoute: '/settings',
        ),
      );

      // Open the drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Find the Settings ListTile in the drawer
      final settingsTiles = tester.widgetList<ListTile>(
        find.ancestor(
          of: find.text('Settings'),
          matching: find.byType(ListTile),
        ),
      );

      // At least one Settings tile should be selected (active route)
      expect(settingsTiles.any((tile) => tile.selected == true), isTrue);
    });

    testWidgets('Each ListTile has proper structure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );

      // Find Profile ListTile
      final profileTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Profile'),
          matching: find.byType(ListTile),
        ),
      );

      // Verify ListTile structure
      expect(profileTile.leading, isNotNull); // Has icon
      expect(profileTile.title, isNotNull); // Has title
      expect(profileTile.subtitle, isNotNull); // Has subtitle
      expect(profileTile.trailing, isNotNull); // Has chevron
      expect(profileTile.onTap, isNotNull); // Is tappable
    });
  });
}
