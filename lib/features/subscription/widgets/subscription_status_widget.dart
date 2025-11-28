import 'package:flutter/material.dart';

class SubscriptionStatusWidget extends StatelessWidget {
  final String? status;
  final String? expiredReason;
  const SubscriptionStatusWidget({super.key, this.status, this.expiredReason});

  @override
  Widget build(BuildContext context) {
    if (status == null) return SizedBox.shrink();
    Color bgColor;
    Color iconColor;
    IconData icon;
    String text;
    switch (status) {
      case 'active':
        bgColor = Colors.green.shade50;
        iconColor = Colors.green;
        icon = Icons.check_circle;
        text = 'Đăng ký đang hoạt động';
        break;
      case 'trialing':
        bgColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        icon = Icons.hourglass_top;
        text = 'Đang dùng thử';
        break;
      case 'expired':
        bgColor = Colors.red.shade50;
        iconColor = Colors.red;
        icon = Icons.warning;
        text =
            'Đăng ký đã hết hạn${expiredReason != null ? ': $expiredReason' : ''}';
        break;
      case 'canceled':
        bgColor = Colors.red.shade50;
        iconColor = Colors.red;
        icon = Icons.warning;
        text =
            'Đăng ký đã bị hủy${expiredReason != null ? ': $expiredReason' : ''}';
        break;
      case 'paused':
        bgColor = Colors.red.shade50;
        iconColor = Colors.red;
        icon = Icons.warning;
        text = 'Đăng ký đang tạm dừng';
        break;
      default:
        bgColor = Colors.red.shade50;
        iconColor = Colors.red;
        icon = Icons.warning;
        text = 'Trạng thái: $status';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
