import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final double splashRadius;

  const ActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 16,
    this.splashRadius = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: IconButton(
        icon: Icon(icon, color: color, size: iconSize),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: splashRadius,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          shadowColor: Colors.black26,
        ),
      ),
    );
  }
}
