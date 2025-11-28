import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final bool isOnline;
  const StatusChip({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [
                  Colors.greenAccent.shade400.withAlpha(200),
                  Colors.greenAccent.shade700.withAlpha(200),
                ]
              : [
                  Colors.redAccent.shade400.withAlpha(200),
                  Colors.redAccent.shade700.withAlpha(200),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60), width: 1),
        boxShadow: [
          BoxShadow(
            color: isOnline
                ? Colors.greenAccent.shade400.withAlpha(100)
                : Colors.redAccent.shade400.withAlpha(100),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class CameraStatusChip extends StatelessWidget {
  final String text;
  const CameraStatusChip({super.key, required this.text});

  Color _getStatusColor() {
    final t = text.toLowerCase();
    if (t.contains('playing') || t.contains('đang phát')) {
      return Colors.green;
    } else if (t.contains('connecting') || t.contains('đang kết nối')) {
      return Colors.orange;
    } else if (t.contains('error') || t.contains('lỗi')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  IconData _getStatusIcon() {
    final t = text.toLowerCase();
    if (t.contains('playing') || t.contains('đang phát')) {
      return Icons.play_circle_filled;
    } else if (t.contains('connecting') || t.contains('đang kết nối')) {
      return Icons.sync;
    } else if (t.contains('error') || t.contains('lỗi')) {
      return Icons.error;
    }
    return Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();

    // Static status chip (animation disabled)
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(220), color.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(120),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
