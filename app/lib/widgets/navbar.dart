import 'package:flutter/material.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/views/calorie_coach.dart'; // added import



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
        backgroundColor: themeColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/image.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                alignment: Alignment.bottomLeft,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Simply Serve',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Smart Meal Planner',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.white),
              title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/'),
              selectedTileColor: Colors.white24,
              onTap: () => _navigate(context, '/'),
            ),
            ListTile(
              leading: const Icon(Icons.casino_outlined, color: Colors.white),
              title: const Text('Meal Spinner', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/spin'),
              selectedTileColor: Colors.white24,
              onTap: () => _navigate(context, '/spin'),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Colors.white),
              title: const Text('Recipes', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/recipes'),
              selectedTileColor: Colors.white24,
              onTap: () => _navigate(context, '/recipes'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.white),
              title: const Text('Meal Calendar', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/calendar'),
              selectedTileColor: Colors.white24,
              onTap: () {
                final currentRoute = ModalRoute.of(context)?.settings.name;
                Navigator.of(context).maybePop();
                if (currentRoute != '/calendar') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MealCalendarView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              title: const Text('Shopping List', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/shopping-list'),
              selectedTileColor: Colors.white24,
              onTap: () => _navigate(context, '/shopping-list'),
            ),
            ListTile(
              leading: const Icon(Icons.local_fire_department, color: Colors.white),
              title: const Text('Calorie Coach', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/calorie-coach'),
              selectedTileColor: Colors.white24,
              onTap: () {
                final currentRoute = ModalRoute.of(context)?.settings.name;
                Navigator.pop(context);
                if (currentRoute != '/calorie-coach') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CalorieCoachView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/settings'),
              selectedTileColor: Colors.white24,
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
