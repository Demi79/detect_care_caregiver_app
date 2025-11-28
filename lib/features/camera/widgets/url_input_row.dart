import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'RTSP/HTTP URL',
                  hintText:
                      'rtsp://user:pass@ip:554/cam/realmonitor?channel=1&subtype=1',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => onStart(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data != null && data.text != null) {
                            controller.text = data.text!;
                          }
                        },
                        icon: const Icon(Icons.paste),
                        tooltip: 'Dán',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => controller.clear(),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Xóa',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: starting ? null : onStart,
                    icon: Icon(starting ? Icons.stop : Icons.play_arrow),
                    label: Text(starting ? 'Đang phát...' : 'Phát'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      backgroundColor: starting
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
