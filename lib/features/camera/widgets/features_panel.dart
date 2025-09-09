import 'package:flutter/material.dart';

class CameraFeaturesPanel extends StatelessWidget {
  final int fps;
  final ValueChanged<int> onFpsChanged;

  // Bổ sung: thời gian lưu (ngày) và kênh nhận thông báo
  final int retentionDays; // số ngày lưu trữ
  final ValueChanged<int> onRetentionChanged;
  final Set<String> channels; // tập kênh đang chọn
  final ValueChanged<Set<String>> onChannelsChanged;

  const CameraFeaturesPanel({
    super.key,
    required this.fps,
    required this.onFpsChanged,
    required this.retentionDays,
    required this.onRetentionChanged,
    required this.channels,
    required this.onChannelsChanged,
  });

  @override
  Widget build(BuildContext context) {
    const availableChannels = <String>['App', 'SMS', 'Email'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tốc độ khung hình (FPS)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider.adaptive(
                min: 5,
                max: 60,
                divisions: 11, // 5,10,...,60
                label: '$fps',
                value: fps.toDouble().clamp(5, 60),
                onChanged: (v) => onFpsChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${fps}fps',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Kéo để điều chỉnh fps. Lưu ý: không phải camera nào cũng hỗ trợ tham số fps trong URL.',
          style: TextStyle(color: Colors.black54),
        ),

        const SizedBox(height: 24),
        const Text(
          'Thời gian lưu (ngày)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider.adaptive(
                min: 1,
                max: 30,
                divisions: 29,
                label: '$retentionDays',
                value: retentionDays.toDouble().clamp(1, 30),
                onChanged: (v) => onRetentionChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$retentionDays d',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chọn số ngày muốn lưu dữ liệu. Áp dụng ở phía server nếu có chính sách lưu trữ.',
          style: TextStyle(color: Colors.black54),
        ),

        const SizedBox(height: 24),
        const Text(
          'Kênh nhận thông báo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ch in availableChannels)
              FilterChip(
                label: Text(ch),
                selected: channels.contains(ch),
                onSelected: (sel) {
                  final next = Set<String>.from(channels);
                  if (sel) {
                    next.add(ch);
                  } else {
                    next.remove(ch);
                  }
                  onChannelsChanged(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Bạn có thể bật nhiều kênh một lúc: nhận trong ứng dụng (App), qua SMS hoặc Email.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
