import 'package:flutter/material.dart';
import 'package:simplyserve/widgets/navbar.dart';

/// Recipes view - displays meal recipes
class RecipesView extends StatelessWidget {
  const RecipesView({super.key});

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Recipes',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: const Color(0xFF74BC42).withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              const Text(
                'Recipes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Browse and discover delicious meal recipes tailored to your dietary needs.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recipe search coming soon!'),
                    ),
                  );
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Search Recipes',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF74BC42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
