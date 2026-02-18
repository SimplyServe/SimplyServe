import 'package:flutter/material.dart';
import 'widgets/widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // place navigation at top and keep the rest of the page content below
      body: Column(
        children: [
          const AppNavigation(bannerText: 'Free delivery on orders over £30'),
          Expanded(
            child: Center(
              child: Text(
                'Homepage content',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
