import 'dart:math';

import 'package:flutter/material.dart';

/// Lightweight shimmer row used in invoice lists.
class ShimmerItem extends StatefulWidget {
  const ShimmerItem({super.key});

  @override
  State<ShimmerItem> createState() => _ShimmerItemState();
}

class _ShimmerItemState extends State<ShimmerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final base = Colors.grey.shade200;
        final hi = Colors.grey.shade100;
        final t = (sin((_c.value * 2 * pi)) + 1) / 2;
        final color = Color.lerp(base, hi, t)!;
        return Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }
}
