import 'dart:convert';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_player_factory.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/rtsp_vlc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/webrtc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:http/http.dart' as http;

class CameraStreamHelper {
  static const _hlsProbeRangeHeader = 'bytes=0-2047';
  static const _hlsProbeTimeout = Duration(seconds: 15);
  static final Map<String, bool> _hlsProbeCache = {};
  static const _maxProbeCache = 200;
  static final List<String> _probeKeys = <String>[];
  static void _cacheProbe(String url, bool ok) {
    if (_hlsProbeCache.containsKey(url)) {
      _hlsProbeCache[url] = ok;
      return;
    }
    _hlsProbeCache[url] = ok;
    _probeKeys.add(url);
    if (_probeKeys.length > _maxProbeCache) {
      final oldest = _probeKeys.removeAt(0);
      _hlsProbeCache.remove(oldest);
      _hlsNormalizedCandidates.remove(oldest);
    }
  }

  static final Map<String, String> _hlsNormalizedCandidates = {};

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

    final normalizedInitial =
        _hlsNormalizedCandidates[initialUrl] ?? initialUrl;
    final shouldAttemptInitial = await _shouldAttemptInitialUrl(initialUrl);

    Future<ICameraPlayer?> tryPlay(String url, {required String tag}) async {
      final player = CameraPlayerFactory.createPlayer(url);
      try {
        await player.initialize();
        await player.play();

        if (initTimeout.inMilliseconds > 0) {
          Future.delayed(initTimeout).then((_) {
            AppLogger.d(
              '[CameraStreamHelper] Stream stabilization check completed ($tag)',
            );
          });
        }

        AppLogger.i(
          '[CameraStreamHelper] ✅ Stream started ($tag): ${player.protocol} - $url',
        );
        return player;
      } catch (e) {
        AppLogger.w('[CameraStreamHelper] Play failed ($tag): $e');
        // If HLS failed and it looks like LL-HLS, try VLC as a tolerant fallback
        try {
          final proto = CameraPlayerFactory.detectProtocol(url);
          if (proto == StreamProtocol.hls) {
            final ll = await isLikelyLlHls(url);
            if (ll) {
              AppLogger.i(
                '[CameraStreamHelper] Detected LL-HLS, attempting VLC fallback for $url',
              );
              final vlc = RtspVlcPlayer(url);
              try {
                await vlc.initialize();
                await vlc.play();
                AppLogger.i(
                  '[CameraStreamHelper] ✅ VLC fallback succeeded for $url',
                );
                return vlc;
              } catch (e2) {
                AppLogger.w('[CameraStreamHelper] VLC fallback failed: $e2');
                await vlc.dispose();
              }
            }
          }
        } catch (_) {}
        await player.dispose();
        return null;
      }
    }

    if (!shouldAttemptInitial) {
      AppLogger.w(
        '[CameraStreamHelper] HLS probe indicates no playlist, but will still try once: $initialUrl',
      );
    }

    // Try initial (use normalized candidate if present)
    final initialPlayer = await tryPlay(normalizedInitial, tag: 'initial');
    if (initialPlayer != null) return initialPlayer;

    // Retry attempts (regardless of probe result)
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      AppLogger.i(
        '[CameraStreamHelper] Retry attempt $attempt/$maxRetries for $normalizedInitial',
      );
      await Future.delayed(retryDelay);

      final retryPlayer = await tryPlay(
        normalizedInitial,
        tag: 'retry-$attempt',
      );
      if (retryPlayer != null) return retryPlayer;
    }

    // Try fallback URLs from camera entry
    if (camera != null) {
      final fallbackUrls = CameraPlayerFactory.getAllStreamUrls(camera);

      // Remove the URLs we already tried (original + normalized candidate)
      fallbackUrls.removeWhere(
        (url) => url == initialUrl || url == normalizedInitial,
      );

      for (final fallbackUrl in fallbackUrls) {
        AppLogger.i('[CameraStreamHelper] Trying fallback: $fallbackUrl');

        final fallbackProtocol = CameraPlayerFactory.detectProtocol(
          fallbackUrl,
        );
        if (fallbackProtocol == StreamProtocol.hls) {
          final ok = await _shouldAttemptInitialUrl(fallbackUrl);
          if (!ok) {
            AppLogger.w(
              '[CameraStreamHelper] HLS probe indicates no playlist for fallback but will still try once: $fallbackUrl',
            );
          }
        }

        final fallbackUrlToUse =
            _hlsNormalizedCandidates[fallbackUrl] ?? fallbackUrl;
        final fallbackPlayer = await tryPlay(fallbackUrlToUse, tag: 'fallback');
        if (fallbackPlayer != null) return fallbackPlayer;
      }
    }

    AppLogger.e('[CameraStreamHelper] All attempts failed for stream');
    return null;
  }

  /// Prepare (initialize) a player for the best available URL without starting playback.
  /// Caller must mount the view and call `play()` after the widget is attached.
  static Future<ICameraPlayer?> prepareWithFallback({
    required String initialUrl,
    required CameraEntry? camera,
    int maxRetries = 1,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    if (initialUrl.isEmpty) {
      AppLogger.w('[CameraStreamHelper] Empty initial URL');
      return null;
    }

    final normalizedInitial =
        _hlsNormalizedCandidates[initialUrl] ?? initialUrl;
    final shouldAttemptInitial = await _shouldAttemptInitialUrl(initialUrl);

    Future<ICameraPlayer?> tryPrepare(String url, {required String tag}) async {
      final player = CameraPlayerFactory.createPlayer(url);
      try {
        await player.initialize();
        AppLogger.i(
          '[CameraStreamHelper] Prepared player ($tag): ${player.protocol} - $url',
        );
        return player;
      } catch (e) {
        AppLogger.w('[CameraStreamHelper] Prepare failed ($tag): $e');
        // If HLS prepare failed and it looks like LL-HLS, try preparing VLC
        try {
          final proto = CameraPlayerFactory.detectProtocol(url);
          if (proto == StreamProtocol.hls) {
            final ll = await isLikelyLlHls(url);
            if (ll) {
              AppLogger.i(
                '[CameraStreamHelper] Detected LL-HLS, preparing VLC fallback for $url',
              );
              final vlc = RtspVlcPlayer(url);
              try {
                await vlc.initialize();
                AppLogger.i('[CameraStreamHelper] VLC prepared for $url');
                return vlc;
              } catch (e2) {
                AppLogger.w('[CameraStreamHelper] VLC prepare failed: $e2');
                await vlc.dispose();
              }
            }
          }
        } catch (_) {}
        await player.dispose();
        return null;
      }
    }

    if (!shouldAttemptInitial) {
      AppLogger.w(
        '[CameraStreamHelper] HLS probe indicates no playlist, but will still prepare once: $initialUrl',
      );
    }

    // Try initial (normalized if available)
    final initialPlayer = await tryPrepare(normalizedInitial, tag: 'initial');
    if (initialPlayer != null) return initialPlayer;

    // Retries
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      AppLogger.i(
        '[CameraStreamHelper] Prepare retry $attempt/$maxRetries for $normalizedInitial',
      );
      await Future.delayed(retryDelay);
      final p = await tryPrepare(normalizedInitial, tag: 'retry-$attempt');
      if (p != null) return p;
    }

    // Fallbacks
    if (camera != null) {
      final fallbackUrls = CameraPlayerFactory.getAllStreamUrls(camera);
      fallbackUrls.removeWhere(
        (u) => u == initialUrl || u == normalizedInitial,
      );

      for (final fallbackUrl in fallbackUrls) {
        AppLogger.i('[CameraStreamHelper] Preparing fallback: $fallbackUrl');
        final fallbackProtocol = CameraPlayerFactory.detectProtocol(
          fallbackUrl,
        );
        if (fallbackProtocol == StreamProtocol.hls) {
          final ok = await _shouldAttemptInitialUrl(fallbackUrl);
          if (!ok) {
            AppLogger.w(
              '[CameraStreamHelper] HLS probe failed for fallback but will still try prepare once: $fallbackUrl',
            );
          }
        }

        final fallbackUrlToUse =
            _hlsNormalizedCandidates[fallbackUrl] ?? fallbackUrl;
        final prepared = await tryPrepare(fallbackUrlToUse, tag: 'fallback');
        if (prepared != null) return prepared;
      }
    }

    AppLogger.e('[CameraStreamHelper] All prepare attempts failed for stream');
    return null;
  }

  static Future<bool> _shouldAttemptInitialUrl(String url) async {
    final protocol = CameraPlayerFactory.detectProtocol(url);
    if (protocol != StreamProtocol.hls) return true;

    // Probe the provided URL for an HLS playlist header.
    final isPlaylist = await _probeHlsPlaylist(url);
    if (isPlaylist) return true;

    AppLogger.w(
      '[CameraStreamHelper] HLS probe failed to find a playlist header for $url',
    );

    if (url.contains('hlsll')) {
      final candidate = url.replaceAll('hlsll', 'hls');
      AppLogger.i(
        '[CameraStreamHelper] Trying normalized HLS candidate: $candidate',
      );

      final candidateOk = await _probeHlsPlaylist(candidate);
      if (candidateOk) {
        AppLogger.i(
          '[CameraStreamHelper] Normalized HLS candidate is a valid playlist: $candidate',
        );
        // Cache positive result for both original and candidate so subsequent
        // checks will succeed.
        _cacheProbe(url, true);
        _cacheProbe(candidate, true);
        _hlsNormalizedCandidates[url] = candidate;
        return true;
      }

      AppLogger.w(
        '[CameraStreamHelper] Normalized HLS candidate also failed: $candidate',
      );
    }

    return false;
  }

  static Future<bool> _probeHlsPlaylist(String url) async {
    final cached = _hlsProbeCache[url];
    if (cached != null) return cached;

    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _cacheProbe(url, true);
      return true;
    }
    final client = http.Client();
    try {
      var current = uri;
      const maxRedirects = 5;
      int redirects = 0;
      http.StreamedResponse res;

      while (true) {
        final req = http.Request('GET', current)
          ..headers.addAll({
            'User-Agent': 'DetectCare-Mobile/1.0',
            'Accept-Encoding': 'identity',
            'Range': _hlsProbeRangeHeader,
            'Accept':
                'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
          });

        res = await client.send(req).timeout(_hlsProbeTimeout);
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final loc = res.headers['location'];
          AppLogger.d(
            '[CameraStreamHelper] redirect ${res.statusCode} -> $loc',
          );
          if (loc == null || redirects++ >= maxRedirects) break;
          current = current.resolve(loc);
          continue;
        }

        if (res.statusCode == 416) {
          final r2 = http.Request('GET', current)
            ..headers.addAll({
              'User-Agent': 'DetectCare-Mobile/1.0',
              'Accept':
                  'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
            });
          res = await client.send(r2).timeout(_hlsProbeTimeout);
        }

        break;
      }

      final status = res.statusCode;
      final ct = res.headers['content-type'];
      final loc = res.headers['location'];
      if (status >= 400) {
        AppLogger.w(
          '[CameraStreamHelper] probe failed $status ct=$ct loc=$loc',
        );
        _cacheProbe(url, false);
        return false;
      }

      final buf = <int>[];
      await for (final chunk in res.stream) {
        buf.addAll(chunk);
        if (buf.length >= 2048) break;
      }

      final snippet = utf8.decode(buf, allowMalformed: true);
      final head = snippet.length > 200 ? snippet.substring(0, 200) : snippet;
      final normalized = snippet.trimLeft().toUpperCase();
      final contentTypeLooksLikeM3u8 = (ct ?? '').toLowerCase().contains(
        'mpegurl',
      );
      final ok = normalized.contains('#EXTM3U') || contentTypeLooksLikeM3u8;
      AppLogger.d(
        '[CameraStreamHelper] probe status=$status ct=$ct loc=$loc head="$head"',
      );
      _cacheProbe(url, ok);
      return ok;
    } catch (e, st) {
      AppLogger.d('[CameraStreamHelper] probe error for $url: $e', e, st);
      _cacheProbe(url, false);
      return false;
    } finally {
      client.close();
    }
  }

  static Future<bool> isLikelyLlHls(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final client = http.Client();
    try {
      final req = http.Request('GET', uri)
        ..headers.addAll({
          'User-Agent': 'DetectCare-Mobile/1.0',
          'Accept-Encoding': 'identity',
          'Accept': 'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
        });

      final res = await client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return false;

      final buf = <int>[];
      await for (final chunk in res.stream) {
        buf.addAll(chunk);
        if (buf.length >= 2048) break;
      }

      final snippet = utf8.decode(buf, allowMalformed: true);
      final s = snippet.toUpperCase();
      return s.contains('#EXT-X-PART') || s.contains('EXT-X-SERVER-CONTROL');
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<bool> probeHlsPlaylist(String url) async =>
      _probeHlsPlaylist(url);

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

    // If no camera provided, nothing to do
    if (camera == null) return null;

    // Mobile / other: prefer HLS -> WebRTC -> RTSP -> generic
    final hls = camera.hlsUrl?.trim();
    if (hls != null && hls.isNotEmpty) {
      AppLogger.i('[CameraStreamHelper] getBestUrl: choosing HLS');
      return hls;
    }

    final webrtc = camera.webrtcUrl?.trim();
    if (webrtc != null && webrtc.isNotEmpty) {
      AppLogger.i('[CameraStreamHelper] getBestUrl: choosing WebRTC');
      return webrtc;
    }

    final rtsp = camera.rtspUrl?.trim();
    if (rtsp != null && rtsp.isNotEmpty) {
      AppLogger.i('[CameraStreamHelper] getBestUrl: choosing RTSP');
      return rtsp;
    }

    final generic = camera.url.trim();
    if (generic.isNotEmpty) {
      AppLogger.i('[CameraStreamHelper] getBestUrl: choosing generic');
      return generic;
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
