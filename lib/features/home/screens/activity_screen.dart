import 'package:flutter/material.dart';

import '../../../features/health_overview/screens/health_overview_screen.dart';
import '../widgets/tab_selector.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hoạt động')),
      body: Center(child: const Text('Nội dung màn Hoạt động…')),
      bottomNavigationBar: TabSelector(
        selectedTab: 'activity',
        onTabChanged: (label) {
          switch (label) {
            case 'warning':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WarningLogScreen()),
              );
              break;
            case 'report':
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

// Simple placeholder for the missing WarningLogScreen. Replace or extend
// with the real implementation if available in the project.
class WarningLogScreen extends StatelessWidget {
  const WarningLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo')),
      body: const Center(child: Text('Màn cảnh báo - chưa triển khai')),
    );
  }
}
