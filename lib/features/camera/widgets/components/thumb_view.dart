import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class ThumbView extends StatelessWidget {
  final String src;
  final double borderRadius;
  final bool isOnline;
  final double? width;
  final double? height;

  const ThumbView({
    super.key,
    required this.src,
    this.borderRadius = 12,
    this.isOnline = true,
    this.width,
    this.height,
  });

  Widget _buildFallback() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, color: Color(0xFFBDBDBD), size: 32),
            SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    return Positioned(
      top: 8,
      right: 8,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green : Colors.red,
          shape: BoxShape.circle,
          border: const Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: (isOnline ? Colors.green : Colors.red).withValues(
                alpha: 0.3,
              ),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: isOnline
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.8),
                      Colors.green.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return _buildFallback();

    try {
      if (src.startsWith('http')) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                src,
                fit: BoxFit.cover,
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                gaplessPlayback: true,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: width ?? double.infinity,
                    height: height ?? double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => _buildFallback(),
              ),
            ),
            // Only show status dot, remove connection indicator to avoid overlap
            _buildStatusDot(),
          ],
        );
      }

      if (src.startsWith('data:image')) {
        final comma = src.indexOf(',');
        final b64 = comma >= 0 ? src.substring(comma + 1) : src;
        final bytes = base64Decode(b64);
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                errorBuilder: (_, __, ___) => _buildFallback(),
              ),
            ),
            _buildStatusDot(),
          ],
        );
      }

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
            return Container(
              width: width ?? double.infinity,
              height: height ?? double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            );
          }
          if (snapshot.hasError || !(snapshot.data ?? false)) {
            return _buildFallback();
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: width ?? double.infinity,
                  height: height ?? double.infinity,
                  errorBuilder: (_, __, ___) => _buildFallback(),
                ),
              ),
              _buildStatusDot(),
            ],
          );
        },
      );
    } catch (_) {
      return _buildFallback();
    }
  }
}
