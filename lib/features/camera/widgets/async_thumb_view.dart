import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AsyncThumbView extends StatelessWidget {
  final String src;
  final double borderRadius;
  const AsyncThumbView({super.key, required this.src, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    Widget fallback = Container(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.camera_alt_outlined, color: Colors.grey[300]),
    );
    if (src.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: src,
          fit: BoxFit.cover,
          placeholder: (_, __) => Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => fallback,
        ),
      );
    }
    if (src.startsWith('data:image')) {
      final comma = src.indexOf(',');
      final b64 = comma >= 0 ? src.substring(comma + 1) : src;
      try {
        final bytes = base64Decode(b64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }
    // Assume file path
    String path = src;
    final q = path.indexOf('?');
    final hash = path.indexOf('#');
    final cut = [q, hash].where((i) => i >= 0).fold<int>(-1, (a, b) {
      if (a < 0) return b;
      if (b < 0) return a;
      return a < b ? a : b;
    });
    if (cut >= 0) path = path.substring(0, cut);
    final file = path.startsWith('file:')
        ? File(Uri.parse(path).toFilePath())
        : File(path);
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return fallback;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      },
    );
  }
}
