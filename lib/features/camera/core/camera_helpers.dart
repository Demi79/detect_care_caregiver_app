import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Utility functions for camera operations
class CameraHelpers {
  /// Parse subtype from URL query parameters
  static int readSubtype(String url) {
    try {
      final uri = Uri.parse(url);
      final subtypeStr = uri.queryParameters['subtype'];
      return int.tryParse(subtypeStr ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Add or update subtype in URL
  static String withSubtype(String url, int subtype) {
    try {
      final uri = Uri.parse(url);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['subtype'] = subtype.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return url;
    }
  }

  /// Parse FPS from URL query parameters
  static int? tryReadFps(String url) {
    try {
      final uri = Uri.parse(url);
      final fpsStr = uri.queryParameters['fps'];
      return int.tryParse(fpsStr ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Add or update FPS in URL
  static String withFps(String url, int fps) {
    try {
      final uri = Uri.parse(url);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['fps'] = fps.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return url;
    }
  }

  /// Generate URL hash for thumbnail naming
  static int generateUrlHash(String url) {
    int hash = 0;
    for (final code in url.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  /// Clean up old thumbnail files
  static Future<void> cleanupOldThumbs(
    Directory thumbsDir, {
    int keep = 50,
  }) async {
    try {
      final entries = await thumbsDir.list().where((e) => e is File).toList();
      final files = entries.cast<File>();
      if (files.length <= keep) return;

      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      for (final file in files.skip(keep)) {
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Get thumbnail directory
  static Future<Directory> getThumbsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbsDir = Directory('${dir.path}/thumbs');
    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }
    return thumbsDir;
  }

  /// Generate thumbnail filename
  static String generateThumbnailFilename(String url, int timestamp) {
    final urlHash = generateUrlHash(url);
    return 'detect_care_thumb_${urlHash}_$timestamp.png';
  }
}

/// Extension methods for camera-related operations
extension CameraStringExtensions on String {
  /// Check if string is a valid URL
  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtsp');
    } catch (_) {
      return false;
    }
  }

  /// Trim and check if string is not empty
  bool get isNotEmptyTrimmed => trim().isNotEmpty;
}

extension CameraIntExtensions on int {
  /// Clamp FPS value within valid range
  int clampFps() => clamp(5, 60).toInt();

  /// Clamp retention days within valid range
  int clampRetentionDays() => clamp(1, 30).toInt();
}
