import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:simplyserve/widgets/spinning_wheel.dart';
import 'package:simplyserve/views/meal_calendar.dart'; // Added import to navigate to calendar


class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Here is your daily meal suggestion.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const SpinningWheelWidget(),
            const SizedBox(height: 24),

            // New button to open Meal Calendar
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MealCalendarView()),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Open Meal Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74BC42),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
