import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:simplyserve/widgets/spinning_wheel.dart';


class SpinWheelView extends StatelessWidget {
  const SpinWheelView({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavBarScaffold(
      title: 'Meal Spinner',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feeling indecisive?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Let the wheel decide your next meal.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),
            SpinningWheelWidget(),
            SizedBox(height: 24),

            // Meal Calendar navigation moved into the app drawer.
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
