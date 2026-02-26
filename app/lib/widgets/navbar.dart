import 'package:flutter/material.dart';

/// A scaffold wrapper that includes a drawer-based navigation system
/// This makes it easy to use consistent navigation across multiple pages
class NavBarScaffold extends StatelessWidget {
  final Widget body;
  final String title;

  const NavBarScaffold({
    super.key,
    required this.body,
    required this.title,
  });

  /// Helper method to handle navigation
  void _navigate(BuildContext context, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // Close the drawer safely
    Navigator.of(context).maybePop();

    // Only navigate if not already on that route
    if (currentRoute != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  /// Check if a route is currently active
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
                children: [
                  Text(
                    'Simply Serve',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Smart Meal Planner',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
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
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recipes'),
              selected: _isActiveRoute(context, '/recipes'),
              selectedTileColor: selectedTileColor,
              selectedColor: themeColor,
              onTap: () => _navigate(context, '/recipes'),
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
    );
  }
}
