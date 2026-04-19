import 'package:flutter/material.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/views/shopping_list.dart';



class NavBarScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? floatingActionButton;

  const NavBarScaffold({
    super.key,
    required this.body,
    required this.title,
    this.floatingActionButton,
  });

  void _navigate(BuildContext context, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    Navigator.of(context).maybePop();

    if (currentRoute != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  bool _isActiveRoute(BuildContext context, String routeName) {
    return ModalRoute.of(context)?.settings.name == routeName;
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF74BC42);
    // ignore: deprecated_member_use
    final selectedTileColor = themeColor.withOpacity(0.1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: themeColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Simply Serve',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      'Smart Meal Planner',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _isActiveRoute(context, '/'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/'),
            ),
            ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: const Text('Meal Spinner'),
              selected: _isActiveRoute(context, '/spin'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/spin'),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recipes'),
              selected: _isActiveRoute(context, '/recipes'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/recipes'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Meal Calendar'),
              // Highlight as active only if route name matches; fall back to false
              selected: _isActiveRoute(context, '/calendar'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () {
                final currentRoute = ModalRoute.of(context)?.settings.name;
                Navigator.of(context).maybePop();
                if (currentRoute != '/calendar') {
                  // Push the calendar page directly (named route may not be registered).
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MealCalendarView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('Shopping List'),
              selected: _isActiveRoute(context, '/shopping-list'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/shopping-list'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _isActiveRoute(context, '/settings'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/settings'),
            ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
