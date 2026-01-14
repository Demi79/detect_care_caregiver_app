import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_player_factory.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/webrtc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';

/// Helper class for managing camera stream playback with fallback logic
class CameraStreamHelper {
  /// Play stream with automatic fallback if initial URL fails
  /// Returns the player if successful, null if all attempts failed
  static Future<ICameraPlayer?> playWithFallback({
    required String initialUrl,
    required CameraEntry? camera,
    int maxRetries = 1,
    Duration retryDelay = const Duration(milliseconds: 500),
    Duration initTimeout = const Duration(seconds: 2),
  }) async {
    if (initialUrl.isEmpty) {
      AppLogger.w('[CameraStreamHelper] Empty initial URL');
      return null;
    }

    // First attempt with initial URL
    final player = CameraPlayerFactory.createPlayer(initialUrl);

    try {
      await player.initialize();
      await player.play();

      // Give it a moment to start
      await Future.delayed(initTimeout);

      AppLogger.i(
        '[CameraStreamHelper] ✅ Stream started: ${player.protocol} - $initialUrl',
      );
      return player;
    } catch (e) {
      AppLogger.w('[CameraStreamHelper] Initial URL failed: $e');
      await player.dispose();

      // Try retries with same URL
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        AppLogger.i(
          '[CameraStreamHelper] Retry attempt $attempt/$maxRetries for $initialUrl',
        );

        await Future.delayed(retryDelay);

        final retryPlayer = CameraPlayerFactory.createPlayer(initialUrl);
        try {
          await retryPlayer.initialize();
          await retryPlayer.play();
          await Future.delayed(initTimeout);

          AppLogger.i(
            '[CameraStreamHelper] ✅ Stream started on retry $attempt',
          );
          return retryPlayer;
        } catch (retryE) {
          AppLogger.w('[CameraStreamHelper] Retry $attempt failed: $retryE');
          await retryPlayer.dispose();
        }
      }

      // Try fallback URLs from camera entry
      if (camera != null) {
        final fallbackUrls = CameraPlayerFactory.getAllStreamUrls(camera);

        // Remove the URL we already tried
        fallbackUrls.removeWhere((url) => url == initialUrl);

        for (final fallbackUrl in fallbackUrls) {
          AppLogger.i('[CameraStreamHelper] Trying fallback: $fallbackUrl');

          final fallbackPlayer = CameraPlayerFactory.createPlayer(fallbackUrl);
          try {
            await fallbackPlayer.initialize();
            await fallbackPlayer.play();
            await Future.delayed(initTimeout);

            AppLogger.i(
              '[CameraStreamHelper] ✅ Stream started with fallback: ${fallbackPlayer.protocol}',
            );
            return fallbackPlayer;
          } catch (fallbackE) {
            AppLogger.w('[CameraStreamHelper] Fallback failed: $fallbackE');
            await fallbackPlayer.dispose();
          }
        }
      }

      AppLogger.e('[CameraStreamHelper] All attempts failed for stream');
      return null;
    }
  }

  /// Play WebRTC stream with connection monitoring
  static Future<WebrtcPlayer?> playWebrtcStream({
    required CameraEntry camera,
    Duration initTimeout = const Duration(seconds: 5),
  }) async {
    final player = CameraPlayerFactory.createWebrtcPlayer(camera);

    if (player == null) {
      AppLogger.w(
        '[CameraStreamHelper] WebRTC URL not available in camera config',
      );
      return null;
    }

    try {
      AppLogger.i(
        '[CameraStreamHelper] Starting WebRTC stream for ${camera.name}',
      );

      await player.initialize();
      await player.play();

      // Wait for connection to establish
      await Future.delayed(initTimeout);

      // Check connection state
      if (player.connectionState == WebRtcConnectionState.connected) {
        AppLogger.i(
          '[CameraStreamHelper] ✅ WebRTC stream connected for ${camera.name}',
        );
        return player;
      } else {
        AppLogger.w(
          '[CameraStreamHelper] WebRTC connection not ready: ${player.connectionState}',
        );
        // Connection might still establish, return player anyway
        // Caller can monitor connectionStateStream for updates
        return player;
      }
    } catch (e, st) {
      AppLogger.e(
        '[CameraStreamHelper] WebRTC initialization failed: $e',
        e,
        st,
      );
      await player.dispose();
      return null;
    }
  }

  /// Get best available URL from camera entry
  static String? getBestUrl(CameraEntry? camera, {String? initialUrl}) {
    // If explicit URL provided, use it
    if (initialUrl != null && initialUrl.isNotEmpty) {
      return initialUrl;
    }

    // Otherwise get best from camera entry
    if (camera != null) {
      return CameraPlayerFactory.getBestStreamUrl(camera);
    }

    return null;
  }

  /// Get protocol priority list for the camera
  static List<String> getProtocolPriority(CameraEntry? camera) {
    if (camera == null) return [];

    final priority = <String>[];

    if (camera.hlsUrl != null && camera.hlsUrl!.isNotEmpty) {
      priority.add('HLS (${camera.hlsUrl!.length} chars)');
    }

    if (camera.rtspUrl != null && camera.rtspUrl!.isNotEmpty) {
      priority.add('RTSP (${camera.rtspUrl!.length} chars)');
    }

    if (camera.webrtcUrl != null && camera.webrtcUrl!.isNotEmpty) {
      priority.add('WebRTC (${camera.webrtcUrl!.length} chars)');
    }

    if (camera.url.isNotEmpty) {
      priority.add('Generic (${camera.url.length} chars)');
    }

    return priority;
  }
}
