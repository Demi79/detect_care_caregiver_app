import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class ScreenshotResponse {
  final bool success;
  final String? snapshotId;
  final String? imageUrl;
  final String? error;

  ScreenshotResponse({
    required this.success,
    this.snapshotId,
    this.imageUrl,
    this.error,
  });

  factory ScreenshotResponse.fromJson(Map<String, dynamic> json) {
    return ScreenshotResponse(
      success: json['success'] ?? false,
      snapshotId: json['snapshot_id'],
      imageUrl: json['image_url'],
      error: json['error'],
    );
  }
}

class BurstScreenshotResponse {
  final List<ScreenshotResponse> screenshots;

  BurstScreenshotResponse({required this.screenshots});

  factory BurstScreenshotResponse.fromJson(List<dynamic> json) {
    return BurstScreenshotResponse(
      screenshots: json
          .map((item) => ScreenshotResponse.fromJson(item))
          .toList(),
    );
  }
}

class ThumbnailRefreshResponse {
  final String cameraId;
  final String status;
  final String? thumbnailUrl;
  final String? capturedAt;
  final bool cached;
  final String? snapshotId;
  final String? error;
  final String? message;

  ThumbnailRefreshResponse({
    required this.cameraId,
    required this.status,
    this.thumbnailUrl,
    this.capturedAt,
    required this.cached,
    this.snapshotId,
    this.error,
    this.message,
  });

  factory ThumbnailRefreshResponse.fromJson(Map<String, dynamic> json) {
    return ThumbnailRefreshResponse(
      cameraId: json['camera_id'] ?? '',
      status: json['status'] ?? 'error',
      thumbnailUrl: json['thumbnail_url'],
      capturedAt: json['captured_at'],
      cached: json['cached'] ?? false,
      snapshotId: json['snapshot_id'],
      error: json['error'],
      message: json['message'],
    );
  }
}

class ThumbnailResponse {
  final String cameraId;
  final String? thumbnailUrl;
  final String? capturedAt;
  final String status;

  ThumbnailResponse({
    required this.cameraId,
    this.thumbnailUrl,
    this.capturedAt,
    required this.status,
  });

  factory ThumbnailResponse.fromJson(Map<String, dynamic> json) {
    return ThumbnailResponse(
      cameraId: json['camera_id'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      capturedAt: json['captured_at'],
      status: json['status'] ?? 'unknown',
    );
  }
}

class CameraScreenshotApi {
  final ApiClient apiClient;

  CameraScreenshotApi(this.apiClient);

  /// Endpoint: POST /api/cameras/{camera_id}/screenshot/capture
  /// Returns: [ScreenshotResponse] with image URL if successful
  Future<ScreenshotResponse> captureScreenshot({
    required String cameraId,
  }) async {
    try {
      AppLogger.api(
        '📸 [CameraScreenshotApi] Capturing screenshot for $cameraId',
      );

      final response = await apiClient.post(
        '/cameras/$cameraId/screenshot/capture',
        body: {},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.e(
          '❌ [CameraScreenshotApi] Capture failed: ${response.statusCode}',
        );
        return ScreenshotResponse(
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final decoded = apiClient.extractDataFromResponse(response);
      if (decoded is Map<String, dynamic>) {
        final result = ScreenshotResponse.fromJson(decoded);
        if (result.success && result.imageUrl != null) {
          AppLogger.api(
            '✅ [CameraScreenshotApi] Screenshot captured: ${result.snapshotId}',
          );
        }
        return result;
      }

      return ScreenshotResponse(success: false, error: 'Invalid response');
    } catch (e, st) {
      AppLogger.e('❌ [CameraScreenshotApi] Exception: $e', e, st);
      return ScreenshotResponse(success: false, error: e.toString());
    }
  }

  /// Capture multiple screenshots in burst (for event analysis)
  ///
  /// Endpoint: POST /api/cameras/{camera_id}/screenshot/burst
  /// Parameters:
  ///   - count: Number of screenshots (1-10, default: 3)
  ///   - interval: Interval between captures in ms (min: 100, default: 500)
  Future<BurstScreenshotResponse?> captureScreenshotBurst({
    required String cameraId,
    int count = 3,
    int interval = 500,
  }) async {
    try {
      AppLogger.api(
        '📸 [CameraScreenshotApi] Capturing burst: count=$count, interval=${interval}ms for $cameraId',
      );

      final response = await apiClient.post(
        '/cameras/$cameraId/screenshot/burst',
        query: {
          'count': count.clamp(1, 10).toString(),
          'interval': interval.clamp(100, 5000).toString(),
        },
        body: {},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.e(
          '❌ [CameraScreenshotApi] Burst capture failed: ${response.statusCode}',
        );
        return null;
      }

      final decoded = apiClient.extractDataFromResponse(response);
      if (decoded is List) {
        final result = BurstScreenshotResponse.fromJson(decoded);
        final successCount = result.screenshots.where((s) => s.success).length;
        AppLogger.api(
          '✅ [CameraScreenshotApi] Burst captured: $successCount/${result.screenshots.length}',
        );
        return result;
      }

      return null;
    } catch (e, st) {
      AppLogger.e('❌ [CameraScreenshotApi] Burst exception: $e', e, st);
      return null;
    }
  }

  /// Refresh thumbnail with smart cache (30s TTL)
  ///
  /// Endpoint: POST /api/cameras/{camera_id}/thumbnail/refresh
  /// Smart logic:
  ///   - Returns cached thumbnail if < 30s old
  ///   - Triggers new capture if older or no cache
  Future<ThumbnailRefreshResponse?> refreshThumbnail({
    required String cameraId,
  }) async {
    try {
      AppLogger.api(
        '🔄 [CameraScreenshotApi] Refreshing thumbnail for $cameraId',
      );

      final response = await apiClient.post(
        '/cameras/$cameraId/thumbnail/refresh',
        body: {},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          '⚠️ [CameraScreenshotApi] Refresh returned ${response.statusCode}',
        );
        return null;
      }

      final decoded = apiClient.extractDataFromResponse(response);
      if (decoded is Map<String, dynamic>) {
        final result = ThumbnailRefreshResponse.fromJson(decoded);
        if (result.status == 'success') {
          final cacheStatus = result.cached ? '(cached)' : '(new capture)';
          AppLogger.api(
            '✅ [CameraScreenshotApi] Thumbnail refreshed $cacheStatus',
          );
        } else {
          AppLogger.w(
            '⚠️ [CameraScreenshotApi] Thumbnail refresh error: ${result.error}',
          );
        }
        return result;
      }

      return null;
    } catch (e, st) {
      AppLogger.e('❌ [CameraScreenshotApi] Refresh exception: $e', e, st);
      return null;
    }
  }

  /// Get latest thumbnail without triggering capture
  ///
  /// Endpoint: GET /api/cameras/{camera_id}/thumbnail/latest
  /// Fast endpoint - just returns existing thumbnail
  Future<ThumbnailResponse?> getLatestThumbnail({
    required String cameraId,
  }) async {
    try {
      AppLogger.api(
        '🖼️ [CameraScreenshotApi] Getting latest thumbnail for $cameraId',
      );

      final response = await apiClient.get(
        '/cameras/$cameraId/thumbnail/latest',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          '⚠️ [CameraScreenshotApi] Get thumbnail returned ${response.statusCode}',
        );
        return null;
      }

      final decoded = apiClient.extractDataFromResponse(response);
      if (decoded is Map<String, dynamic>) {
        final result = ThumbnailResponse.fromJson(decoded);
        AppLogger.api(
          '✅ [CameraScreenshotApi] Got thumbnail (${result.status})',
        );
        return result;
      }

      return null;
    } catch (e, st) {
      AppLogger.e('❌ [CameraScreenshotApi] Get thumbnail exception: $e', e, st);
      return null;
    }
  }
}
