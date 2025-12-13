import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_stream_helper.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HlsVideoPlayer implements ICameraPlayer {
  final String url;
  VideoPlayerController? _controller;
  bool _isDisposed = false;

  HlsVideoPlayer(this.url);

  @override
  String get streamUrl => url;

  @override
  String get protocol {
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mp4')) return 'mp4';
    return 'video';
  }

  @override
  Future<void> initialize() async {
    if (_isDisposed) {
      AppLogger.w('[HlsVideoPlayer] Cannot initialize: player is disposed');
      return;
    }

    try {
      // Dispose existing controller if any
      if (_controller != null) {
        await _controller!.dispose();
      }

      final proto = protocol;
      AppLogger.i('[HlsVideoPlayer] Initializing $proto: $url');

      if (proto == 'hls' && !await CameraStreamHelper.probeHlsPlaylist(url)) {
        AppLogger.w(
          '[HlsVideoPlayer] HLS preflight could not confirm playlist, will still attempt initialize: $url',
        );
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {'User-Agent': 'DetectCare-Mobile/1.0'},
      );

      await _controller!.initialize();

      AppLogger.i(
        '[HlsVideoPlayer] Initialized successfully (duration: ${_controller!.value.duration})',
      );
    } catch (e, st) {
      AppLogger.e('[HlsVideoPlayer] Initialize failed: $e', e, st);
      rethrow;
    }
  }

  @override
  Widget buildView() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio == 0
          ? 16 / 9
          : _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }

  @override
  Future<void> play() async {
    try {
      if (_controller != null && !_isDisposed) {
        await _controller!.play();
        AppLogger.i('[HlsVideoPlayer] Play started');
      }
    } catch (e) {
      AppLogger.e('[HlsVideoPlayer] Play failed: $e', e);
    }
  }

  @override
  Future<void> pause() async {
    try {
      if (_controller != null && !_isDisposed) {
        await _controller!.pause();
        AppLogger.i('[HlsVideoPlayer] Paused');
      }
    } catch (e) {
      AppLogger.e('[HlsVideoPlayer] Pause failed: $e', e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      _isDisposed = true;
      AppLogger.i('[HlsVideoPlayer] Disposed');
    } catch (e) {
      AppLogger.e('[HlsVideoPlayer] Dispose error: $e', e);
    }
  }
}
