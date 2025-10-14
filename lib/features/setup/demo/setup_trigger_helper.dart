import 'package:flutter/material.dart';
import '../utils/setup_flow_test_utils.dart';

class SetupTriggerHelper {
  /// Trigger setup flow bằng cách reset về first-time user và navigate
  static Future<void> triggerSetupFlow(BuildContext context) async {
    try {
      // Reset to first-time user
      await SetupFlowTestUtils.resetToFirstTimeUser();

      // Navigate to setup flow
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/setup');
      }
    } catch (e) {
      debugPrint('Error triggering setup flow: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi kích hoạt thiết lập: $e')));
      }
    }
  }

  /// Navigate trực tiếp đến setup flow (không reset state)
  static void navigateToSetup(BuildContext context) {
    Navigator.of(context).pushNamed('/setup');
  }

  /// Reset setup state về first-time user
  static Future<void> resetToFirstTime() async {
    await SetupFlowTestUtils.resetToFirstTimeUser();
  }

  /// Complete tất cả steps (for testing)
  static Future<void> completeAllSteps() async {
    await SetupFlowTestUtils.completeAllSteps();
  }

  /// Show debug dialog
  static Future<void> showDebugInfo(BuildContext context) async {
    await SetupFlowTestUtils.showSetupDebugDialog(context);
  }

  /// Floating action button để quick trigger setup flow
  static Widget buildTriggerFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => triggerSetupFlow(context),
      icon: const Icon(Icons.settings),
      label: const Text('Thiết lập'),
      backgroundColor: Colors.blue[600],
    );
  }

  /// Quick trigger button widget
  static Widget buildTriggerButton(BuildContext context, {String? label}) {
    return ElevatedButton.icon(
      onPressed: () => triggerSetupFlow(context),
      icon: const Icon(Icons.settings),
      label: Text(label ?? 'Kích hoạt luồng thiết lập'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Debug menu với tất cả options
  static void showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Menu gỡ lỗi luồng thiết lập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Kích hoạt luồng thiết lập'),
              subtitle: const Text('Đặt lại và bắt đầu thiết lập'),
              onTap: () {
                Navigator.pop(context);
                triggerSetupFlow(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Đặt lại về lần đầu sử dụng'),
              subtitle: const Text('Chỉ đặt lại trạng thái thiết lập'),
              onTap: () async {
                Navigator.pop(context);
                await resetToFirstTime();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đã đặt lại về trạng thái lần đầu sử dụng!',
                      ),
                    ),
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Hoàn tất tất cả bước'),
              subtitle: const Text('Đánh dấu tất cả bước là đã hoàn thành'),
              onTap: () async {
                Navigator.pop(context);
                await completeAllSteps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã hoàn tất tất cả các bước!'),
                    ),
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Hiển thị thông tin gỡ lỗi'),
              subtitle: const Text('Xem trạng thái thiết lập hiện tại'),
              onTap: () {
                Navigator.pop(context);
                showDebugInfo(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.launch),
              title: const Text('Đi tới thiết lập'),
              subtitle: const Text(
                'Đi tới màn thiết lập (không đặt lại trạng thái)',
              ),
              onTap: () {
                Navigator.pop(context);
                navigateToSetup(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
