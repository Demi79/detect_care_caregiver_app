import 'package:flutter/material.dart';

class Grid2MoreButton extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRefresh;

  const Grid2MoreButton({
    super.key,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz, color: Colors.black54),
      tooltip: 'Tác vụ',
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Phát'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          enabled: onEdit != null,
          child: const Row(
            children: [
              Icon(Icons.edit, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('Sửa'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Xóa'),
            ],
          ),
        ),
        if (onRefresh != null)
          const PopupMenuItem(
            value: 4,
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('Làm mới'),
              ],
            ),
          ),
      ],
      onSelected: (v) {
        if (v == 1) onPlay();
        if (v == 2 && onEdit != null) onEdit!();
        if (v == 3) onDelete();
        if (v == 4 && onRefresh != null) onRefresh!();
      },
    );
  }
}
