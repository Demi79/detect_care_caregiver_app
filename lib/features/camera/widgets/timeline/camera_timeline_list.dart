import 'package:flutter/material.dart';
import 'camera_timeline_components.dart';
import 'camera_timeline_state_message.dart';
import 'camera_timeline_zoom_control.dart';

class CameraTimelineList extends StatelessWidget {
  final List<CameraTimelineEntry> entries;
  final String? selectedClipId;
  final bool isLoading;
  final String? errorMessage;
  final bool compact;
  final double zoomLevel;
  final ValueChanged<double> onAdjustZoom;
  final ValueChanged<String> onSelectClip;
  final VoidCallback onRetry;

  const CameraTimelineList({
    super.key,
    required this.entries,
    required this.selectedClipId,
    required this.isLoading,
    required this.errorMessage,
    required this.compact,
    required this.zoomLevel,
    required this.onAdjustZoom,
    required this.onSelectClip,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return CameraTimelineStateMessage(
        icon: Icons.error_outline,
        title: 'Không thể tải dữ liệu',
        message: errorMessage!,
        actionLabel: 'Thử lại',
        onAction: onRetry,
      );
    }
    if (entries.isEmpty) {
      return CameraTimelineStateMessage(
        icon: Icons.videocam_off,
        title: 'Chưa có dữ liệu',
        message: 'Không tìm thấy bản ghi/snapshot cho ngày đã chọn.',
        actionLabel: 'Chọn ngày khác',
        onAction: onRetry,
      );
    }

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8)
        : const EdgeInsets.symmetric(horizontal: 12);
    final showZoom = !compact;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 20 : 28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacitySafe(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isSelected = entry.clip?.id == selectedClipId;
                  return CameraTimelineRow(
                    entry: entry,
                    isSelected: isSelected,
                    onClipTap: entry.clip != null
                        ? () => onSelectClip(entry.clip!.id)
                        : null,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: entries.length,
              ),
            ),
          ),
          if (showZoom) ...[
            const SizedBox(width: 12),
            CameraTimelineZoomControl(
              zoomLevel: zoomLevel,
              onAdjust: onAdjustZoom,
            ),
          ],
        ],
      ),
    );
  }
}
