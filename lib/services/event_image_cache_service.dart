import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service để cache ảnh event vĩnh viễn thay vì dựa vào signed URL tạm thời
class EventImageCacheService {
  static final EventImageCacheService _instance =
      EventImageCacheService._internal();

  factory EventImageCacheService() {
    return _instance;
  }

  EventImageCacheService._internal();

  /// Inflight lock to prevent concurrent downloads for the same event/cache key
  final Map<String, Future<String?>> _inflight = {};

  /// Cache mapping: cacheKey (evt_/snap_) -> list of local file paths
  final Map<String, List<String>> _cacheIndex = {};

  /// Lấy cache directory cho event images
  Future<Directory> _getEventImageCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    // Use v2 cache folder to avoid collisions with older cache layout.
    final cacheDir = Directory('${dir.path}/event_image_cache_v2');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  String _eventCacheKey(String eventId) => 'evt_${eventId.trim()}';

  String _snapshotCacheKey(String snapshotId) => 'snap_${snapshotId.trim()}';

  /// Lưu ảnh từ URL vào cache vĩnh viễn
  /// Wrapper that prevents duplicate concurrent downloads.
  Future<String?> cacheEventImage({
    required String eventId,
    required String imageUrl,
    int retries = 3,
  }) {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) return Future.value(null);

    final cacheKey = _eventCacheKey(trimmedEventId);
    final urlHash = md5.convert(imageUrl.codeUnits).toString();
    final key = '$cacheKey|$urlHash';

    return _inflight[key] ??= _cacheEventImageImpl(
      eventId: trimmedEventId,
      cacheKey: cacheKey,
      imageUrl: imageUrl,
      retries: retries,
    ).whenComplete(() => _inflight.remove(key));
  }

  Future<String?> _cacheEventImageImpl({
    required String eventId,
    required String cacheKey,
    required String imageUrl,
    required int retries,
  }) async {
    try {
      // Hash URL để tạo tên file unique (deterministic)
      final urlHash = md5.convert(imageUrl.codeUnits).toString();
      final cacheDir = await _getEventImageCacheDir();

      // Tạo thư mục cho event
      final eventDir = Directory('${cacheDir.path}/$cacheKey');
      if (!await eventDir.exists()) {
        await eventDir.create(recursive: true);
      }

      // Deterministic filename (no timestamp)
      final filename = 'event_$urlHash.jpg';
      final filePath = '${eventDir.path}/$filename';

      // Check if already cached
      final file = File(filePath);
      if (await file.exists()) {
        _addToCache(cacheKey, filePath);
        return filePath;
      }

      // Download with retries
      for (int i = 0; i < retries; i++) {
        try {
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Atomic write: write to tmp then rename
            final tmp = File('$filePath.tmp');
            await tmp.writeAsBytes(response.bodyBytes, flush: true);
            await tmp.rename(filePath);

            _addToCache(cacheKey, filePath);
            AppLogger.d(
              '[EventImageCache] Cached image for $eventId: $filePath',
            );
            return filePath;
          }
        } catch (e, st) {
          if (i < retries - 1) {
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          } else {
            AppLogger.e(
              '[EventImageCache] Failed to cache $imageUrl after $retries retries: $e',
              e,
              st,
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
    final trimmedId = eventId.trim();
    if (trimmedId.isEmpty) return [];
    final cacheKey = _eventCacheKey(trimmedId);

    if (_cacheIndex.containsKey(cacheKey)) {
      final cached = _cacheIndex[cacheKey]!;
      final existing = <String>[];
      for (final path in cached) {
        if (await File(path).exists()) {
          existing.add(path);
        }
      }
      if (existing.length != cached.length) {
        _cacheIndex[cacheKey] = existing;
      }
      return existing;
    }

    try {
      final cacheDir = await _getEventImageCacheDir();
      final eventDir = Directory('${cacheDir.path}/$cacheKey');
      if (!await eventDir.exists()) {
        return [];
      }

      final files = eventDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();

      _cacheIndex[cacheKey] = files;
      return files;
    } catch (e) {
      AppLogger.e('[EventImageCache] Error reading cached images: $e');
      return [];
    }
  }

  /// Snapshot-specific cache helpers. Store snapshot thumbnails under
  /// <cacheDir>/snapshots/<snapshotId>/
  Future<List<String>> getSnapshotImages(String snapshotId) async {
    final trimmedId = snapshotId.trim();
    if (trimmedId.isEmpty) return [];
    final cacheKey = _snapshotCacheKey(trimmedId);

    if (_cacheIndex.containsKey(cacheKey)) {
      final cached = _cacheIndex[cacheKey]!;
      final existing = <String>[];
      for (final path in cached) {
        if (await File(path).exists()) {
          existing.add(path);
        }
      }
      if (existing.length != cached.length) {
        _cacheIndex[cacheKey] = existing;
      }
      return existing;
    }

    try {
      final cacheDir = await _getEventImageCacheDir();
      final snapDir = Directory('${cacheDir.path}/$cacheKey');
      if (!await snapDir.exists()) return [];
      final files = snapDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      _cacheIndex[cacheKey] = files;
      return files;
    } catch (e) {
      AppLogger.e('[EventImageCache] Error reading snapshot cached images: $e');
      return [];
    }
  }

  Future<String?> cacheSnapshotImage({
    required String snapshotId,
    required String imageUrl,
    int retries = 3,
  }) {
    final trimmedId = snapshotId.trim();
    if (trimmedId.isEmpty) return Future.value(null);

    final cacheKey = _snapshotCacheKey(trimmedId);
    final urlHash = _stableUrlHash(imageUrl);
    final key = '$cacheKey|$urlHash';

    return _inflight[key] ??= _cacheSnapshotImageImpl(
      snapshotId: trimmedId,
      cacheKey: cacheKey,
      imageUrl: imageUrl,
      retries: retries,
    ).whenComplete(() => _inflight.remove(key));
  }

  Future<String?> _cacheSnapshotImageImpl({
    required String snapshotId,
    required String cacheKey,
    required String imageUrl,
    required int retries,
  }) async {
    try {
      final urlHash = _stableUrlHash(imageUrl);
      final cacheDir = await _getEventImageCacheDir();

      final snapDir = Directory('${cacheDir.path}/$cacheKey');
      if (!await snapDir.exists()) {
        await snapDir.create(recursive: true);
      }

      final filename = 'snap_$urlHash.jpg';
      final filePath = '${snapDir.path}/$filename';

      final file = File(filePath);
      if (await file.exists()) {
        _addToCache(cacheKey, filePath);
        return filePath;
      }

      for (int i = 0; i < retries; i++) {
        try {
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final tmp = File('$filePath.tmp');
            await tmp.writeAsBytes(response.bodyBytes, flush: true);
            await tmp.rename(filePath);

            _addToCache(cacheKey, filePath);
            AppLogger.d(
              '[EventImageCache] Cached snapshot image $snapshotId: $filePath',
            );
            await _enforceMaxFilesInDir(snapDir, maxFiles: 20);
            return filePath;
          }
        } catch (e, st) {
          if (i < retries - 1) {
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          } else {
            AppLogger.e(
              '[EventImageCache] Failed to cache snapshot $imageUrl after $retries retries: $e',
              e,
              st,
            );
          }
        }
      }
      return null;
    } catch (e, st) {
      AppLogger.e('[EventImageCache] Snapshot cache error: $e', e, st);
      return null;
    }
  }

  Future<void> _enforceMaxFilesInDir(Directory dir, {int maxFiles = 50}) async {
    try {
      final files = dir.listSync().whereType<File>().toList()
        ..sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );
      if (files.length <= maxFiles) return;
      final toDelete = files.sublist(0, files.length - maxFiles);
      for (final f in toDelete) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('[EventImageCache] enforce max files failed: $e');
    }
  }

  String _stableUrlHash(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final path = '${uri.scheme}://${uri.host}${uri.path}';
      return md5.convert(path.codeUnits).toString();
    } catch (_) {
      return md5.convert(imageUrl.codeUnits).toString();
    }
  }

  /// Xóa cache cho event
  Future<void> clearEventCache(String eventId) async {
    final trimmedId = eventId.trim();
    if (trimmedId.isEmpty) return;
    final cacheKey = _eventCacheKey(trimmedId);
    try {
      final cacheDir = await _getEventImageCacheDir();
      final eventDir = Directory('${cacheDir.path}/$cacheKey');
      if (await eventDir.exists()) {
        await eventDir.delete(recursive: true);
      }
      _cacheIndex.remove(cacheKey);
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
      _cacheIndex.clear();
      AppLogger.d('[EventImageCache] Cleared all cache');
    } catch (e) {
      AppLogger.e('[EventImageCache] Error clearing all cache: $e');
    }
  }

  void _addToCache(String cacheKey, String filePath) {
    if (!_cacheIndex.containsKey(cacheKey)) {
      _cacheIndex[cacheKey] = [];
    }
    if (!_cacheIndex[cacheKey]!.contains(filePath)) {
      _cacheIndex[cacheKey]!.add(filePath);
    }
  }
}
