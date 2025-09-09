import 'package:flutter/material.dart';

class CameraEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const CameraEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_outlined,
              size: 64,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có camera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhấn nút + để thêm camera mới',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Thêm camera'),
            ),
          ],
        ),
      ),
    );
  }
}
