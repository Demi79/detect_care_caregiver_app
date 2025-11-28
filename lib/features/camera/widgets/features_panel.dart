import 'package:flutter/material.dart';

/// Panel hiển thị các tuỳ chỉnh camera (FPS, retention, mở timeline).
class CameraFeaturesPanel extends StatelessWidget {
  final int fps;
  final ValueChanged<int> onFpsChanged;
  final int retentionDays;
  final ValueChanged<int> onRetentionChanged;
  final bool showRetention;
  final Set<String> channels;
  final ValueChanged<Set<String>> onChannelsChanged;
  final Widget? timelineContent;
  final VoidCallback? onOpenTimeline;

  const CameraFeaturesPanel({
    super.key,
    required this.fps,
    required this.onFpsChanged,
    required this.retentionDays,
    required this.onRetentionChanged,
    this.showRetention = false,
    required this.channels,
    required this.onChannelsChanged,
    this.timelineContent,
    this.onOpenTimeline,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final padding = EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset);
        final minHeight = hasBoundedHeight
            ? (constraints.maxHeight - bottomInset).clamp(0.0, double.infinity)
            : 0.0;
        final constrainedBox = hasBoundedHeight
            ? BoxConstraints(minHeight: minHeight)
            : const BoxConstraints();

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: constrainedBox,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // _buildFpsCard(context),
                    if (showRetention) ...[
                      const SizedBox(height: 20),
                      _buildRetentionCard(context),
                    ],
                    if (timelineContent != null) ...[
                      const SizedBox(height: 20),
                      _buildTimelineCard(context, timelineContent!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Thẻ điều chỉnh tốc độ khung hình.
  // ignore: unused_element
  Widget _buildFpsCard(BuildContext context) {
    return _buildSettingCard(
      icon: Icons.speed_rounded,
      title: 'Tốc độ khung hình',
      subtitle: 'Điều chỉnh FPS của camera',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blueAccent,
                    inactiveTrackColor: Colors.blueAccent.withAlpha(60),
                    thumbColor: Colors.blueAccent,
                    overlayColor: Colors.blueAccent.withAlpha(30),
                    valueIndicatorColor: Colors.blueAccent,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider.adaptive(
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '$fps',
                    value: fps.toDouble().clamp(5, 60),
                    onChanged: (v) => onFpsChanged(v.round()),
                  ),
                ),
              ),
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${fps}fps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blueAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kéo để điều chỉnh fps. Lưu ý: không phải camera nào cũng hỗ trợ tham số fps trong URL.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ điều chỉnh thời gian lưu trữ (nếu bật).
  Widget _buildRetentionCard(BuildContext context) {
    return _buildSettingCard(
      icon: Icons.storage_rounded,
      title: 'Thời gian lưu trữ',
      subtitle: 'Số ngày lưu dữ liệu',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.greenAccent.shade400,
                    inactiveTrackColor: Colors.greenAccent.shade400.withAlpha(
                      60,
                    ),
                    thumbColor: Colors.greenAccent.shade400,
                    overlayColor: Colors.greenAccent.shade400.withAlpha(30),
                    valueIndicatorColor: Colors.greenAccent.shade400,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider.adaptive(
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$retentionDays',
                    value: retentionDays.toDouble().clamp(1, 30),
                    onChanged: (v) => onRetentionChanged(v.round()),
                  ),
                ),
              ),
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$retentionDays d',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn số ngày muốn lưu dữ liệu. Áp dụng ở phía server nếu có chính sách lưu trữ.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ giới thiệu nút mở timeline.
  Widget _buildTimelineCard(BuildContext context, Widget timeline) {
    return _buildSettingCard(
      icon: Icons.view_timeline_outlined,
      title: 'Lịch thời gian ghi hình (Timeline)',
      subtitle: 'Xem lại bản ghi và sự kiện theo khung giờ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Truy cập nhanh tới giao diện timeline để xem lại bản ghi và trạng thái camera theo từng ngày.',
          //   style: TextStyle(
          //     color: Colors.grey.shade700,
          //     fontSize: 13,
          //     height: 1.4,
          //   ),
          // ),
          // const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFF6F6F6)),
              child: timeline,
            ),
          ),
          if (onOpenTimeline != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onOpenTimeline,
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Xem toàn màn hình'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Card chung chứa icon + tiêu đề + phần nội dung truyền vào.
  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
