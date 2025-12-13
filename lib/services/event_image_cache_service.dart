import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

/// Service để cache ảnh event vĩnh viễn thay vì dựa vào signed URL tạm thời
class EventImageCacheService {
  static final EventImageCacheService _instance =
      EventImageCacheService._internal();

  factory EventImageCacheService() {
    return _instance;
  }

  EventImageCacheService._internal();

  /// Cache mapping: eventId -> list of local file paths
  final Map<String, List<String>> _eventImageCache = {};

  /// Lấy cache directory cho event images
  Future<Directory> _getEventImageCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/event_image_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Lưu ảnh từ URL vào cache vĩnh viễn
  Future<String?> cacheEventImage({
    required String eventId,
    required String imageUrl,
    int retries = 3,
  }) async {
    try {
      // Hash URL để tạo tên file unique
      final urlHash = md5.convert(imageUrl.codeUnits).toString();
      final cacheDir = await _getEventImageCacheDir();

      // Tạo thư mục cho event
      final eventDir = Directory('${cacheDir.path}/$eventId');
      if (!await eventDir.exists()) {
        await eventDir.create(recursive: true);
      }

      final filename =
          'event_${urlHash}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${eventDir.path}/$filename';

      // Check if already cached
      final file = File(filePath);
      if (await file.exists()) {
        _addToCache(eventId, filePath);
        return filePath;
      }

      // Download with retries
      for (int i = 0; i < retries; i++) {
        try {
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes, flush: true);
            _addToCache(eventId, filePath);
            AppLogger.d(
              '[EventImageCache] Cached image for $eventId: $filePath',
            );
            return filePath;
          }
        } catch (e) {
          if (i < retries - 1) {
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          } else {
            AppLogger.e(
              '[EventImageCache] Failed to cache $imageUrl after $retries retries: $e',
            );
          }
        }
      }
      return null;
    } catch (e, st) {
      AppLogger.e('[EventImageCache] Cache error: $e', e, st);
      return null;
    }
  }

  /// Lấy danh sách ảnh cached cho event
  Future<List<String>> getEventImages(String eventId) async {
    // Check memory cache first
    if (_eventImageCache.containsKey(eventId)) {
      final cached = _eventImageCache[eventId]!;
      final existing = <String>[];
      for (final path in cached) {
        if (await File(path).exists()) {
          existing.add(path);
        }
      }
      // Update cache if some files were deleted
      if (existing.length != cached.length) {
        _eventImageCache[eventId] = existing;
      }
      return existing;
    }

    // Check disk
    try {
      final cacheDir = await _getEventImageCacheDir();
      final eventDir = Directory('${cacheDir.path}/$eventId');
      if (!await eventDir.exists()) {
        return [];
      }

      final files = eventDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();

      _eventImageCache[eventId] = files;
      return files;
    } catch (e) {
      AppLogger.e('[EventImageCache] Error reading cached images: $e');
      return [];
    }
  }

  /// Xóa cache cho event
  Future<void> clearEventCache(String eventId) async {
    try {
      final cacheDir = await _getEventImageCacheDir();
      final eventDir = Directory('${cacheDir.path}/$eventId');
      if (await eventDir.exists()) {
        await eventDir.delete(recursive: true);
      }
      _eventImageCache.remove(eventId);
      AppLogger.d('[EventImageCache] Cleared cache for $eventId');
    } catch (e) {
      AppLogger.e('[EventImageCache] Error clearing cache: $e');
    }
  }

  /// Xóa tất cả cache (maintenance)
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getEventImageCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _eventImageCache.clear();
      AppLogger.d('[EventImageCache] Cleared all cache');
    } catch (e) {
      AppLogger.e('[EventImageCache] Error clearing all cache: $e');
    }
  }

  void _addToCache(String eventId, String filePath) {
    if (!_eventImageCache.containsKey(eventId)) {
      _eventImageCache[eventId] = [];
    }
    if (!_eventImageCache[eventId]!.contains(filePath)) {
      _eventImageCache[eventId]!.add(filePath);
    }
  }
}
