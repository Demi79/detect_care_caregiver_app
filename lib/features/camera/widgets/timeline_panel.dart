import 'package:flutter/material.dart';

class CameraTimelinePanel extends StatelessWidget {
  const CameraTimelinePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.videocam_outlined),
        title: Text('Clip ${i + 1}'),
        subtitle: const Text('Không có dữ liệu ghi hình (demo)'),
        trailing: const Text('1080P'),
      ),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: 6,
    );
  }
}
