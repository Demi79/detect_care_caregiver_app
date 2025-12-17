import 'package:flutter/material.dart';

import 'camera_timeline_components.dart';

class CameraTimelineEmptyPreview extends StatelessWidget {
  final List<CameraTimelineClip> clips;
  final bool isLoading;

  const CameraTimelineEmptyPreview({
    super.key,
    required this.clips,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final hasClip = clips.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacitySafe(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // subtle background panel
              Positioned.fill(
                child: Container(
                  color: hasClip ? Colors.white : Colors.grey.shade50,
                ),
              ),
              // inner preview card area
              Positioned(
                left: 6,
                right: 6,
                top: 12,
                bottom: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: hasClip ? Colors.white : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasClip ? Icons.videocam_outlined : Icons.block,
                          size: 36,
                          color: hasClip
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hasClip
                              ? 'Chọn bản ghi ở dưới để xem lại'
                              : isLoading
                              ? 'Đang tải dữ liệu bản ghi...'
                              : 'Không có bản ghi',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!hasClip && !isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Chưa phát hiện bản ghi trong ngày này',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
