import 'package:flutter/material.dart';

import 'camera_timeline_components.dart';
import 'camera_timeline_zoom_control.dart';

class CameraTimelineDateSelector extends StatelessWidget {
  final String formattedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onMenu;
  final bool compact;
  final bool showZoom;
  final double zoomLevel;
  final ValueChanged<double> onAdjustZoom;

  const CameraTimelineDateSelector({
    super.key,
    required this.formattedDay,
    required this.onPrev,
    required this.onNext,
    this.onMenu,
    this.compact = false,
    this.showZoom = true,
    this.zoomLevel = 0.5,
    required this.onAdjustZoom,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12)
        : const EdgeInsets.symmetric(horizontal: 20);
    final showMenuBtn = !compact;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          CameraTimelineCircleButton(icon: Icons.chevron_left, onTap: onPrev),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    formattedDay,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chọn ngày cần xem',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          CameraTimelineCircleButton(icon: Icons.chevron_right, onTap: onNext),
          if (showZoom) ...[
            const SizedBox(width: 8),
            CameraTimelineZoomControl(
              zoomLevel: zoomLevel,
              onAdjust: onAdjustZoom,
            ),
          ],
          if (showMenuBtn) ...[
            const SizedBox(width: 8),
            CameraTimelineCircleButton(
              icon: Icons.more_horiz,
              onTap: () => onMenu?.call(),
            ),
          ],
        ],
      ),
    );
  }
}
