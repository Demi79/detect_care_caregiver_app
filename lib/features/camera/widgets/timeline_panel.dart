import 'package:flutter/material.dart';

class CameraTimelinePanel extends StatelessWidget {
  const CameraTimelinePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (ctx, i) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 84,
                height: 56,
                color: Colors.black12,
                child: const Icon(Icons.videocam, size: 36, color: Colors.grey),
              ),
            ),
            title: Text(
              'Clip ${i + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Demo - không có dữ liệu ghi hình'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('1080P', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () {},
                      tooltip: 'Phát',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () {},
                      tooltip: 'Tải về',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: 6,
    );
  }
}
