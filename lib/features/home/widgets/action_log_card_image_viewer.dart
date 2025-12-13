import 'package:flutter/material.dart';

/// Accept either a list of strings or objects exposing `.path` (e.g. ImageSource)
void showActionLogCardImageViewer(
  BuildContext context,
  List<dynamic> urls,
  int initialIndex,
) {
  if (urls.isEmpty) return;

  final stringUrls = urls.map<String>((u) {
    if (u is String) return u;
    try {
      final p = (u as dynamic).path;
      if (p is String) return p;
    } catch (_) {}
    return u.toString();
  }).toList();

  var currentIndex = initialIndex.clamp(0, stringUrls.length - 1).toInt();
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final imageUrl = urls[currentIndex];
        final canPrevious = currentIndex > 0;
        final canNext = currentIndex < urls.length - 1;
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, w, p) =>
                        p == null ? w : const CircularProgressIndicator(),
                    errorBuilder: (c, e, s) => Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.black),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ảnh ${currentIndex + 1}/${urls.length}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (urls.length > 1)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.white.withOpacity(0.7),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: canPrevious
                            ? () => setState(() => currentIndex -= 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                    ),
                  ),
                ),
              if (urls.length > 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.white.withOpacity(0.7),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: canNext
                            ? () => setState(() => currentIndex += 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      try {
                        Navigator.of(context, rootNavigator: true).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng dùng nút "Xem camera" trong cửa sổ ảnh để mở camera.',
                            ),
                          ),
                        );
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.videocam, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
