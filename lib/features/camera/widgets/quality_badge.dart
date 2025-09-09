import 'package:flutter/material.dart';

class QualityBadge extends StatelessWidget {
  final bool isHd;
  final VoidCallback onTap;
  const QualityBadge({super.key, required this.isHd, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            isHd ? '1080P' : 'SD',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
