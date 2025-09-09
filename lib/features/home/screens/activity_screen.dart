import 'package:flutter/material.dart';

import '../../../features/health_overview/screens/health_overview_screen.dart';
import '../widgets/tab_selector.dart';
import 'warning_log_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Center(child: const Text('Nội dung màn Activity…')),
      bottomNavigationBar: TabSelector(
        selectedTab: 'Activity',
        onTabChanged: (label) {
          switch (label) {
            case 'Warning':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WarningLogScreen.defaultScreen(),
                ),
              );
              break;
            case 'Report':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HealthOverviewScreen()),
              );
              break;
          }
        },
      ),
    );
  }
}
