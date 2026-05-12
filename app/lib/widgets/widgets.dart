// ============================================================
// widgets/widgets.dart — AppNavigation Top Bar
//
// A responsive web-style navigation bar rendered as the AppBar
// on the legacy HomePage. It adapts its layout based on the
// available width:
//   • Wide (> 900 px): full horizontal nav links centred between
//     the logo and the icon row
//   • Narrow (≤ 900 px): hamburger PopupMenuButton replaces the
//     inline text links
//
// Note: this widget is only used by homepage.dart; all other
// views use NavBarScaffold (widgets/navbar.dart) which provides
// a Material Drawer-based navigation instead.
// ============================================================

import 'package:flutter/material.dart';

/// A fixed-height top navigation bar with a responsive layout.
///
/// [bannerText] is accepted as a parameter but not currently
/// rendered — it is kept for future use or theming.
class AppNavigation extends StatelessWidget {
  final String bannerText;
  const AppNavigation({super.key, required this.bannerText});

  /// Placeholder callback for icon buttons that have not yet been
  /// wired to real actions (search, cart, etc.).
  void _placeholderCallbackForButtons() {}

  /// Builds a styled TextButton used in the full-width nav row.
  /// The text gains an underline decoration on hover via
  /// WidgetStateProperty for web/desktop compatibility.
  Widget _navTextButton(BuildContext context, String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        foregroundColor: WidgetStateProperty.all(Colors.grey[800]),
        // WidgetStateProperty.resolveWith lets us change text decoration
        // dynamically based on pointer/focus state.
        textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) {
            final hovered = states.contains(WidgetState.hovered);
            return TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: hovered ? TextDecoration.underline : TextDecoration.none,
              decorationThickness: hovered ? 1.4 : 0,
            );
          },
        ),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder exposes the parent's constraints so we can choose
    // between the full nav row and the compact hamburger menu.
    return LayoutBuilder(
      builder: (context, constraints) {
        final showFullNav = constraints.maxWidth > 900;

        return Container(
          height: 60,
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // ── Logo ───────────────────────────────────────
                      // Tapping the logo navigates to '/' and clears
                      // the entire navigation stack (pushNamedAndRemoveUntil).
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/', (route) => false);
                        },
                        child: Image.asset(
                          'assets/images/image.png',
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Graceful fallback if the asset is missing.
                            return Container(
                              color: Colors.grey[300],
                              width: 40,
                              height: 40,
                              child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),

                      // ── Adaptive navigation area ───────────────────
                      if (showFullNav)
                        // Full horizontal nav links (wide screens)
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _navTextButton(context, 'Home',
                                    () => Navigator.pushNamedAndRemoveUntil(
                                        context, '/', (route) => false)),
                                const SizedBox(width: 12),
                                _navTextButton(context, 'holder',
                                    () => Navigator.pushNamed(
                                        context, '/holder')),
                                const SizedBox(width: 12),
                                _navTextButton(context, 'About',
                                    () => Navigator.pushNamed(
                                        context, '/holder')),
                              ],
                            ),
                          ),
                        )
                      else
                        // Compact hamburger menu (narrow screens)
                        // PopupMenuButton shows a dropdown with the same
                        // destination items.
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.menu, color: Colors.grey),
                          onSelected: (value) {
                            if (value == 0) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/', (r) => false);
                            }
                            if (value == 1) {
                              Navigator.pushNamed(context, '/holder');
                            }
                            if (value == 2) {
                              Navigator.pushNamed(context, '/holder');
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 0, child: Text('Home')),
                            PopupMenuItem(value: 1, child: Text('Holder')),
                            PopupMenuItem(value: 2, child: Text('About')),
                          ],
                        ),

                      // ── Icon button row ────────────────────────────
                      // Search, profile, and cart icons are always visible.
                      // ConstrainedBox caps the row width on very wide screens.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search,
                                  size: 18, color: Colors.grey),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: _placeholderCallbackForButtons,
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_outline,
                                  size: 18, color: Colors.grey),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              // Navigates to the login page so users can
                              // manage their account from the top bar.
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/login'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.shopping_bag_outlined,
                                  size: 18, color: Colors.grey),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/cart'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
