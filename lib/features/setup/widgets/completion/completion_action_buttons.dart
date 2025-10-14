import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/setup_flow_manager.dart';

class CompletionActionButtons extends StatelessWidget {
  const CompletionActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupFlowManager>(
      builder: (context, setupManager, child) {
        return Column(
          children: [
            // Primary action button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF10B981,
                    ).withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _handleCompleteSetup(context, setupManager),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.celebration_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bắt đầu sử dụng',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary action button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _handleReviewSettings(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Xem lại cài đặt',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleCompleteSetup(
    BuildContext context,
    SetupFlowManager setupManager,
  ) {
    // Mark setup as completed
    setupManager.completeSetup(context);

    // Navigate to main app
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _handleReviewSettings(BuildContext context) {
    // Navigate back to settings review
    Navigator.of(context).pushNamed('/settings-review');
  }
}
