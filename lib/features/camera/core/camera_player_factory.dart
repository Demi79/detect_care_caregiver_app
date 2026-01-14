import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/hls_video_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/rtsp_vlc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/webrtc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';

enum StreamProtocol { rtsp, hls, mp4, webrtc, unknown }

/// Factory for creating appropriate camera player based on URL
class CameraPlayerFactory {
  /// Detect protocol from URL
  static StreamProtocol detectProtocol(String url) {
    if (url.startsWith('rtsp://') || url.startsWith('rtsps://')) {
      return StreamProtocol.rtsp;
    }
    if (url.contains('.m3u8')) {
      return StreamProtocol.hls;
    }
    if (url.contains('.mp4')) {
      return StreamProtocol.mp4;
    }
    if (url.startsWith('webrtc://') || url.startsWith('wss://')) {
      return StreamProtocol.webrtc;
    }
    return StreamProtocol.unknown;
  }

  /// Create appropriate player for URL
  static ICameraPlayer createPlayer(String url) {
    final protocol = detectProtocol(url);

    AppLogger.i(
      '[CameraPlayerFactory] Creating player - protocol: $protocol, url: $url',
    );

    switch (protocol) {
      case StreamProtocol.rtsp:
        return RtspVlcPlayer(url);

      case StreamProtocol.hls:
      case StreamProtocol.mp4:
        return HlsVideoPlayer(url);

      case StreamProtocol.webrtc:
        // Parse WebRTC URL format: webrtc://roomId or wss://signalUrl/roomId
        final roomId = _extractWebrtcRoomId(url);
        return WebrtcPlayer(roomId: roomId, signalUrl: url);

      case StreamProtocol.unknown:
        // Default to HLS player for unknown protocols
        AppLogger.w(
          '[CameraPlayerFactory] Unknown protocol, defaulting to HLS player',
        );
        return HlsVideoPlayer(url);
    }
  }

  /// Create WebRTC player from camera entry
  static WebrtcPlayer? createWebrtcPlayer(CameraEntry camera) {
    if (camera.webrtcUrl == null || camera.webrtcUrl!.isEmpty) {
      return null;
    }

    final roomId = _extractWebrtcRoomId(camera.webrtcUrl!);
    AppLogger.i(
      '[CameraPlayerFactory] Creating WebRTC player for room: $roomId',
    );

    return WebrtcPlayer(roomId: roomId, signalUrl: camera.webrtcUrl!);
  }

  /// Extract room ID from WebRTC URL
  static String _extractWebrtcRoomId(String url) {
    // Handle formats like:
    // - webrtc://room-123
    // - wss://signal.example.com/room-123
    // - wss://signal.example.com:443/room-123

    try {
      if (url.startsWith('webrtc://')) {
        return url.replaceFirst('webrtc://', '').split('?').first;
      }

      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (e) {
      AppLogger.w('[CameraPlayerFactory] Cannot extract room ID: $e');
    }

    return 'unknown-room';
  }

  /// Get best available stream URL from camera entry
  /// Priority: HLS > MP4 > RTSP > generic URL
  static String? getBestStreamUrl(CameraEntry camera) {
    // HLS is stable for streaming over internet
    if (camera.hlsUrl != null && camera.hlsUrl!.isNotEmpty) {
      AppLogger.i('[CameraPlayerFactory] Using HLS stream');
      return camera.hlsUrl;
    }

    // RTSP for local/internal streams
    if (camera.rtspUrl != null && camera.rtspUrl!.isNotEmpty) {
      AppLogger.i('[CameraPlayerFactory] Using RTSP stream');
      return camera.rtspUrl;
    }

    // Generic URL as fallback
    if (camera.url.isNotEmpty) {
      AppLogger.i('[CameraPlayerFactory] Using generic URL');
      return camera.url;
    }

    AppLogger.w('[CameraPlayerFactory] No stream URL available');
    return null;
  }

  /// Get all available stream URLs from camera entry for fallback
  static List<String> getAllStreamUrls(CameraEntry camera) {
    final urls = <String>[];

    // Add in priority order: HLS > RTSP > generic
    if (camera.hlsUrl != null && camera.hlsUrl!.isNotEmpty) {
      urls.add(camera.hlsUrl!);
    }

    if (camera.rtspUrl != null && camera.rtspUrl!.isNotEmpty) {
      urls.add(camera.rtspUrl!);
    }

    if (camera.url.isNotEmpty && !urls.contains(camera.url)) {
      urls.add(camera.url);
    }

    return urls;
  }
}
