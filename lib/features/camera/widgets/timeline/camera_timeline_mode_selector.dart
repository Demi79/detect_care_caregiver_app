import 'package:flutter/material.dart';
import 'camera_timeline_components.dart';

class CameraTimelineModeSelector extends StatelessWidget {
  final List<CameraTimelineModeOption> options;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool compact;

  const CameraTimelineModeSelector({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12)
        : const EdgeInsets.symmetric(horizontal: 20);
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < options.length; i++)
            CameraTimelineModeChip(
              icon: options[i].icon,
              label: options[i].label,
              selected: i == selectedIndex,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}
