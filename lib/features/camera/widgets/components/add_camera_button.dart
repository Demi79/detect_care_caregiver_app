import 'package:flutter/material.dart';

class AddCameraButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;

  const AddCameraButton({super.key, required this.onPressed, this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: Colors.blueAccent.withValues(alpha: 0.3 * 255),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 24),
      label: Text(
        label ?? 'Thêm camera',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
