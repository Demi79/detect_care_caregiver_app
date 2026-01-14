import 'package:flutter/material.dart';

Future<void> showActionLogCardImageViewer(
  BuildContext context,
  List<dynamic> urls,
  int initialIndex,
) {
  if (urls.isEmpty) return Future.value();

  final stringUrls = urls.map<String>((u) {
    if (u is String) return u;
    try {
      final p = (u as dynamic).path;
      if (p is String) return p;
    } catch (_) {}
    return u.toString();
  }).toList();

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: _ImageGallery(urls: stringUrls, initialIndex: initialIndex),
        ),
      ),
      fullscreenDialog: true,
    ),
  );
}

class _ImageGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _ImageGallery({required this.urls, required this.initialIndex});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.urls.length,
      itemBuilder: (context, index) {
        final url = widget.urls[index];
        return InteractiveViewer(
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (c, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (c, e, st) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 64,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
