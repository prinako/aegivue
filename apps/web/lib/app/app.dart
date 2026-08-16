import 'package:aegivue/core/theme/app_theme.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegivue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const DashboardPage(),
    );
  }
}
