import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/hls_video_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/rtsp_vlc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/webrtc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';

enum StreamProtocol { rtsp, hls, mp4, webrtc, unknown }

/// Factory for creating appropriate camera player based on URL
class CameraPlayerFactory {
  /// Detect protocol from URL with more robust parsing
  static StreamProtocol detectProtocol(String url) {
    final raw = url.trim();
    final lower = raw.toLowerCase();

    // RTSP explicit
    if (lower.startsWith('rtsp://') || lower.startsWith('rtsps://')) {
      return StreamProtocol.rtsp;
    }

    // strong WebRTC scheme
    if (lower.startsWith('webrtc://')) return StreamProtocol.webrtc;

    final uri = Uri.tryParse(raw);
    final path = (uri?.path ?? raw).toLowerCase();

    // HLS/MP4 by path extension (handle querystrings since we check path)
    if (path.endsWith('.m3u8')) return StreamProtocol.hls;
    if (path.endsWith('.mp4')) return StreamProtocol.mp4;

    // WebRTC detection by path (avoid treating every wss:// as webrtc)
    final looksLikeWebrtcPath =
        path.contains('/webrtc') || path.contains('webrtc/');
    final looksLikeWebrtcPage =
        lower.contains('/pages/player/webrtc') ||
        lower.contains('/player/webrtc/');
    if (looksLikeWebrtcPath || looksLikeWebrtcPage) {
      return StreamProtocol.webrtc;
    }

    // If scheme is wss and path contains hints, mark webrtc; otherwise unknown
    if (lower.startsWith('wss://') &&
        (looksLikeWebrtcPath || lower.contains('webrtc'))) {
      return StreamProtocol.webrtc;
    }

    return StreamProtocol.unknown;
  }

  /// Create appropriate player for URL
  static ICameraPlayer createPlayer(String url) {
    final protocol = detectProtocol(url);

    AppLogger.i('[CameraPlayerFactory] Creating player - $protocol, url=$url');

    switch (protocol) {
      case StreamProtocol.rtsp:
        return RtspVlcPlayer(url);

      case StreamProtocol.hls:
      case StreamProtocol.mp4:
        return HlsVideoPlayer(url);

      case StreamProtocol.webrtc:
        final roomId = _extractWebrtcRoomId(url);
        return WebrtcPlayer(roomId: roomId, signalUrl: url);

      case StreamProtocol.unknown:
        final u = Uri.tryParse(url);
        final scheme = (u?.scheme ?? '').toLowerCase();
        if (scheme == 'http' || scheme == 'https') {
          AppLogger.w(
            '[CameraPlayerFactory] Unknown HTTP stream; trying HlsVideoPlayer as fallback',
          );
          return HlsVideoPlayer(url);
        }
        AppLogger.w(
          '[CameraPlayerFactory] Unsupported/unknown stream scheme; fallback to HlsVideoPlayer may fail',
        );
        return HlsVideoPlayer(url);
    }
  }

  /// Create WebRTC player from camera entry
  static WebrtcPlayer? createWebrtcPlayer(CameraEntry camera) {
    final s = camera.webrtcUrl?.trim();
    if (s == null || s.isEmpty) return null;

    final roomId = _extractWebrtcRoomId(s);
    AppLogger.i(
      '[CameraPlayerFactory] Creating WebRTC player for room=$roomId',
    );
    return WebrtcPlayer(roomId: roomId, signalUrl: s);
  }

  /// Extract room ID from WebRTC URL
  static String _extractWebrtcRoomId(String url) {
    try {
      final raw = url.trim();

      if (raw.toLowerCase().startsWith('webrtc://')) {
        return raw.substring('webrtc://'.length).split('?').first;
      }

      final uri = Uri.tryParse(raw);
      if (uri == null) return 'unknown-room';

      // Prefer query params commonly used by signaling servers
      const keys = ['room', 'roomId', 'stream', 'streamId', 'id'];
      for (final k in keys) {
        final v = uri.queryParameters[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }

      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final idx = segments.indexWhere((s) => s.toLowerCase() == 'webrtc');
        if (idx >= 0 && idx < segments.length - 1) {
          return segments.sublist(idx + 1).join('/');
        }
        return segments.last;
      }
    } catch (e) {
      AppLogger.w('[CameraPlayerFactory] Cannot extract room ID: $e');
    }
    return 'unknown-room';
  }

  /// Get best available stream URL from camera entry
  /// Priority: HLS > MP4 > RTSP > generic (camera.url)
  /// If preferWebrtc==true, attempt WebRTC URL first.
  static String? getBestStreamUrl(
    CameraEntry camera, {
    bool preferWebrtc = false,
  }) {
    if (preferWebrtc) {
      final webrtc = camera.webrtcUrl?.trim();
      if (webrtc != null && webrtc.isNotEmpty) {
        AppLogger.i('[CameraPlayerFactory] Using WebRTC stream');
        return webrtc;
      }
    }

    final hls = camera.hlsUrl?.trim();
    if (hls != null && hls.isNotEmpty) {
      AppLogger.i('[CameraPlayerFactory] Using HLS stream');
      return hls;
    }

    // camera.url may itself be an mp4/hls/rtsp style; detect it
    final generic = camera.url.trim();
    if (generic.isNotEmpty) {
      final p = detectProtocol(generic);
      AppLogger.i('[CameraPlayerFactory] Using generic stream (detected=$p)');
      return generic;
    }

    final rtsp = camera.rtspUrl?.trim();
    if (rtsp != null && rtsp.isNotEmpty) {
      AppLogger.i('[CameraPlayerFactory] Using RTSP stream');
      return rtsp;
    }

    AppLogger.w('[CameraPlayerFactory] No stream URL available');
    return null;
  }

  /// Get all available stream URLs from camera entry for fallback
  static List<String> getAllStreamUrls(
    CameraEntry camera, {
    bool includeWebrtc = false,
  }) {
    final urls = <String>[];

    void add(String? u) {
      final v = u?.trim();
      if (v == null || v.isEmpty) return;
      if (!urls.contains(v)) urls.add(v);
    }

    if (includeWebrtc) add(camera.webrtcUrl);
    add(camera.hlsUrl);
    add(camera.url);
    add(camera.rtspUrl);

    return urls;
  }
}
