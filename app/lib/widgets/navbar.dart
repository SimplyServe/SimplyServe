// ============================================================
// widgets/navbar.dart — NavBarScaffold
//
// A reusable Scaffold wrapper used by every main-screen view.
// It provides:
//   • A consistent white AppBar with a page title
//   • A full-height brand-green side Drawer with nav links
//   • Optional FAB and AppBar action buttons passed through as
//     parameters, keeping each view in control of its own actions
//
// Usage:
//   return NavBarScaffold(
//     title: 'Recipes',
//     body: ...,
//     floatingActionButton: FloatingActionButton(...),
//   );
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/views/meal_calendar.dart';
import 'package:simplyserve/views/calorie_coach.dart';

/// A Scaffold with a pre-built AppBar + Drawer so every view
/// shares the same chrome without code duplication.
///
/// [body]   — the main content of the page
/// [title]  — shown in the AppBar
/// [floatingActionButton] — optional FAB forwarded to Scaffold
/// [actions] — optional AppBar trailing widgets (e.g. "Clear List")
class NavBarScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const NavBarScaffold({
    super.key,
    required this.body,
    required this.title,
    this.floatingActionButton,
    this.actions,
  });

  // ── Navigation helper ──────────────────────────────────────────────
  // Pops the Drawer (which pushes itself onto the navigator stack) and
  // then replaces the current route with [routeName].
  // The currentRoute guard avoids pushing the same route onto itself.
  void _navigate(BuildContext context, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // Close the drawer (it was opened via Navigator.push internally
    // by Flutter's Drawer widget).
    Navigator.of(context).maybePop();

    if (currentRoute != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  /// Returns true if the current route matches [routeName].
  /// Used to highlight the active drawer tile.
  bool _isActiveRoute(BuildContext context, String routeName) {
    return ModalRoute.of(context)?.settings.name == routeName;
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF74BC42);

    return Scaffold(
      // ── AppBar ────────────────────────────────────────────────────
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
        actions: actions, // forwarded from the calling view
      ),

      // ── Side Drawer ───────────────────────────────────────────────
      // The Drawer opens from the left when the user taps the hamburger
      // icon that Flutter automatically adds when a Drawer is present.
      drawer: Drawer(
        backgroundColor: themeColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── DrawerHeader — branded image banner ────────────────
            // Uses a BoxDecoration image so the header fills with the
            // app logo, overlaid by a bottom-to-top gradient scrim so
            // the white text remains legible.
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
                // Gradient scrim for text legibility over the image
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

            // ── Navigation tiles ───────────────────────────────────
            // Each ListTile navigates to its route via _navigate().
            // The selected property highlights the tile for the active route.

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

            // Meal Calendar is not in the named route table (it's pushed
            // as a MaterialPageRoute), so we handle navigation manually.
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.white),
              title: const Text('Meal Calendar', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/calendar'),
              selectedTileColor: Colors.white24,
              onTap: () {
                final currentRoute = ModalRoute.of(context)?.settings.name;
                Navigator.of(context).maybePop(); // close drawer
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

            // Calorie Coach also uses a MaterialPageRoute because it
            // was added after the named route table was populated.
            ListTile(
              leading: const Icon(Icons.local_fire_department, color: Colors.white),
              title: const Text('Calorie Coach', style: TextStyle(color: Colors.white)),
              selected: _isActiveRoute(context, '/calorie-coach'),
              selectedTileColor: Colors.white24,
              onTap: () {
                final currentRoute = ModalRoute.of(context)?.settings.name;
                Navigator.pop(context); // close drawer
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

      // ── Page body & optional FAB ───────────────────────────────────
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
