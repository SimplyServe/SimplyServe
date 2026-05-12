// ============================================================
// homepage.dart — Legacy Home/Welcome Page
//
// A simple StatelessWidget used as an early landing screen.
// The main app now navigates directly to DashboardView ('/'),
// but this page remains accessible and demonstrates the
// brand green gradient header + action-card pattern reused
// throughout the app.
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/widgets.dart';

/// A standalone welcome page that renders a hero gradient card
/// and a "get started" call-to-action card.
///
/// StatelessWidget is appropriate here because the page holds
/// no mutable state — all content is hardcoded.
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── App bar ─────────────────────────────────────────────────────
      // PreferredSize lets us supply a custom-height app bar widget.
      // AppNavigation (widgets/widgets.dart) renders the SimplyServe logo
      // and responsive nav links.
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppNavigation(bannerText: 'SimplyServe'),
      ),

      // ── Page body ───────────────────────────────────────────────────
      body: ColoredBox(
        color: const Color(0xFFF4FAF1), // light green surface
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Hero header card ──────────────────────────────────
                // A full-width container with a diagonal green gradient,
                // rounded corners, and a drop shadow — used as a brand
                // banner at the top of the page.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF74BC42), Color(0xFF4E8A2B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF74BC42).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon badge with frosted-glass tint
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hello! This is the dashboard.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Action card ───────────────────────────────────────
                // A white card with a bordered, shadowed container that
                // prompts the user to view nutrition / meal plan info.
                // The button triggers a SnackBar as a placeholder action.
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7EEE2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF74BC42).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                color: Color(0xFF74BC42),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF24421A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'View your nutrition information and meal plans to stay on track with your goals.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5F7559),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            // Placeholder: shows a SnackBar; in production this
                            // would navigate to the nutrition or meal-plan view.
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Here you can view nutrition information and meal plans!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF74BC42),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'View Nutrition Information and Meal Plans',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
