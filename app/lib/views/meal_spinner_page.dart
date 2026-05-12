// ============================================================
// views/meal_spinner_page.dart — Meal Spinner View
//
// A thin wrapper view that hosts the SpinningWheelWidget inside
// a NavBarScaffold. It adds a branded gradient header above the
// wheel and delegates all spin logic to the widget itself
// (see widgets/spinning_wheel.dart).
//
// Route: '/spin'  (registered in main.dart)
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:simplyserve/widgets/spinning_wheel.dart';

/// The full-screen page for the Meal Spinner feature.
///
/// StatelessWidget is sufficient here because this view owns no
/// state — it simply composes the branded header and the
/// [SpinningWheelWidget] which manages its own internal state.
class SpinWheelView extends StatelessWidget {
  const SpinWheelView({super.key});

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Meal Spinner',
      body: ColoredBox(
        color: const Color(0xFFF4FAF1), // light green page background
        child: SingleChildScrollView(
          // SingleChildScrollView ensures the layout works correctly on
          // devices with smaller screens where the wheel would otherwise
          // overflow vertically.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branded gradient header ──────────────────────────
              // Full-width container with the app's diagonal green
              // gradient. The icon badge + headline/subtitle pattern is
              // shared with CalorieCoachView and ShoppingListView headers.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF74BC42), Color(0xFF4E8A2B)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon badge with semi-transparent white background
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.casino_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Feeling indecisive?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Let the wheel decide your next meal.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Spinning wheel widget ────────────────────────────
              // Padding provides breathing room around the card.
              // SpinningWheelWidget is a StatefulWidget that loads
              // recipes, handles the slot-machine animation, tracks
              // which meals have been rolled today, and shows the
              // result + "Go to Recipe" button.
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: SpinningWheelWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
