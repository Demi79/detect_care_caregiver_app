import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_screenshot_api.dart';

/// High-level camera screenshot use cases
/// Combines API calls with business logic
class CameraScreenshotUseCase {
  final CameraScreenshotApi _api;

  CameraScreenshotUseCase(ApiClient apiClient)
    : _api = CameraScreenshotApi(apiClient);

  /// Capture screenshot with fallback to network image download
  /// Used when need to ensure screenshot is captured
  Future<String?> captureScreenshotWithFallback({
    required String cameraId,
    String? fallbackImageUrl,
  }) async {
    try {
      // Try direct screenshot capture first
      final result = await _api.captureScreenshot(cameraId: cameraId);

      if (result.success && result.imageUrl != null) {
        AppLogger.api('✅ Screenshot captured: ${result.imageUrl}');
        return result.imageUrl;
      }

      // Fallback to network image download
      if (fallbackImageUrl != null && fallbackImageUrl.isNotEmpty) {
        AppLogger.w(
          '⚠️ Direct capture failed, using fallback image: $fallbackImageUrl',
        );
        return fallbackImageUrl;
      }

      AppLogger.e('❌ No screenshot and no fallback available');
      return null;
    } catch (e, st) {
      AppLogger.e('❌ Screenshot capture error: $e', e, st);
      return null;
    }
  }

  /// Capture burst screenshots for event analysis
  /// Useful for recording multiple frames of an incident
  Future<List<String>> captureEventFrames({
    required String cameraId,
    int frameCount = 5,
    int intervalMs = 500,
  }) async {
    try {
      final result = await _api.captureScreenshotBurst(
        cameraId: cameraId,
        count: frameCount,
        interval: intervalMs,
      );

      if (result == null) {
        AppLogger.w('⚠️ Burst capture returned null');
        return [];
      }

      final urls = result.screenshots
          .where((s) => s.success && s.imageUrl != null)
          .map((s) => s.imageUrl!)
          .toList();

      AppLogger.api(
        '✅ Captured ${urls.length}/$frameCount frames for event analysis',
      );
      return urls;
    } catch (e, st) {
      AppLogger.e('❌ Event frame capture error: $e', e, st);
      return [];
    }
  }

  /// Smart thumbnail refresh after user views camera
  /// Returns thumbnail URL (either cached or newly captured)
  Future<String?> refreshThumbnailAfterCameraView({
    required String cameraId,
  }) async {
    try {
      final result = await _api.refreshThumbnail(cameraId: cameraId);

      if (result?.status == 'success' && result?.thumbnailUrl != null) {
        final cacheStatus = result!.cached ? 'cached' : 'freshly captured';
        AppLogger.api(
          '✅ Thumbnail refreshed ($cacheStatus): ${result.thumbnailUrl}',
        );
        return result.thumbnailUrl;
      }

      if (result?.status == 'error') {
        AppLogger.w('⚠️ Thumbnail refresh error: ${result?.error}');
      }

      return null;
    } catch (e, st) {
      AppLogger.e('❌ Thumbnail refresh error: $e', e, st);
      return null;
    }
  }

  /// Get current thumbnail without triggering new capture
  /// Fast endpoint for showing latest thumbnail in list views
  Future<String?> getCurrentThumbnail({required String cameraId}) async {
    try {
      final result = await _api.getLatestThumbnail(cameraId: cameraId);

      if (result?.thumbnailUrl != null) {
        AppLogger.api('✅ Got current thumbnail (${result?.status})');
        return result?.thumbnailUrl;
      }

      return null;
    } catch (e, st) {
      AppLogger.e('❌ Get current thumbnail error: $e', e, st);
      return null;
    }
  }

  /// Alert flow: Capture and return screenshot for notification
  /// This is called when alert is triggered
  Future<String?> captureAlertScreenshot({required String cameraId}) async {
    try {
      AppLogger.api('🚨 [CameraScreenshotUseCase] Capturing alert screenshot');

      final result = await _api.captureScreenshot(cameraId: cameraId);

      if (result.success && result.imageUrl != null) {
        AppLogger.api('✅ Alert screenshot: ${result.imageUrl}');
        return result.imageUrl;
      }

      AppLogger.w('⚠️ Alert screenshot failed: ${result.error}');
      return null;
    } catch (e, st) {
      AppLogger.e('❌ Alert screenshot error: $e', e, st);
      return null;
    }
  }

  /// Batch refresh thumbnails for multiple cameras
  /// Useful for camera list view update
  Future<Map<String, String>> refreshMultipleThumbnails({
    required List<String> cameraIds,
  }) async {
    final result = <String, String>{};

    for (final cameraId in cameraIds) {
      try {
        final url = await refreshThumbnailAfterCameraView(cameraId: cameraId);
        if (url != null) {
          result[cameraId] = url;
        }
      } catch (e) {
        AppLogger.w('⚠️ Failed to refresh thumbnail for $cameraId: $e');
      }
    }

    AppLogger.api(
      '✅ Batch refresh complete: ${result.length}/${cameraIds.length}',
    );
    return result;
  }
}

/// Get singleton instance of CameraScreenshotUseCase
late CameraScreenshotUseCase _cameraScreenshotUseCase;

/// Initialize the use case (call once at app startup)
void initializeCameraScreenshotUseCase(ApiClient apiClient) {
  _cameraScreenshotUseCase = CameraScreenshotUseCase(apiClient);
}

/// Get the singleton instance
CameraScreenshotUseCase getCameraScreenshotUseCase() {
  return _cameraScreenshotUseCase;
}
