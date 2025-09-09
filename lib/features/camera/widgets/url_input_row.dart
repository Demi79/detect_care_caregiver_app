import 'package:flutter/material.dart';

class UrlInputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool starting;
  final VoidCallback onStart;
  const UrlInputRow({
    super.key,
    required this.controller,
    required this.starting,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'RTSP/HTTP URL',
                hintText:
                    'rtsp://user:pass@ip:554/cam/realmonitor?channel=1&subtype=1',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              onSubmitted: (_) => onStart(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: starting ? null : onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(starting ? 'Đang phát...' : 'Phát'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
