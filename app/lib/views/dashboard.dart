import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:simplyserve/widgets/spinning_wheel.dart';


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
          children: const [
            Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Here is your daily meal suggestion.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),
            SpinningWheelWidget(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
