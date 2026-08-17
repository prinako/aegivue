import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/theme/app_theme.dart';
import 'package:aegivue/features/dashboard/dashboard_controller.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(ApiClient())..load(),
      child: MaterialApp(
        title: 'Aegivue',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const DashboardPage(),
      ),
    );
  }
}
