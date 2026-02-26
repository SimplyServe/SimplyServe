import 'package:flutter/material.dart';
import 'package:simplyserve/authorisation.dart';
import 'package:simplyserve/views/dashboard.dart';
import 'package:simplyserve/views/recipes.dart';
import 'package:simplyserve/views/settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simply Serve',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/': (context) => const DashboardView(),
        '/recipes': (context) => const RecipesView(),
        '/settings': (context) => const SettingsView(),
      },
    );
  }
}
