import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/widgets.dart';

/// A very basic home page used for the app's starting screen.
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // use AppNavigation as the app bar
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppNavigation(bannerText: 'Simply Serve'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Hello! This is the dashboard.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Here you can view nutrition information and meal plans!')),
                );
              },
              child: const Text('View Nutrition Information and Meal Plans'),
            ),
          ],
        ),
      ),
    );
  }
}
