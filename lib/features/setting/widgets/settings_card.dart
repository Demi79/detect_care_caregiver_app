// lib/widgets/settings_card.dart
import 'package:flutter/material.dart';

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      // nếu muốn cách đều giữa các card, bạn có thể thêm margin
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        // nền trắng
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // đổ bóng nhẹ
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          // đường viền mờ nhạt
          color: Colors.grey.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}
