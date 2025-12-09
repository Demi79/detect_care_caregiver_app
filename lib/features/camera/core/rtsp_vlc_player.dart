import 'dart:io';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_helpers.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

/// RTSP Player using flutter_vlc_player
/// Used for local/internal RTSP streams
class RtspVlcPlayer implements ICameraPlayer {
  final String url;
  VlcPlayerController? _controller;
  bool _isDisposed = false;

  RtspVlcPlayer(this.url);

  @override
  String get streamUrl => url;

  @override
  String get protocol => 'rtsp';

  @override
  Future<void> initialize() async {
    if (_isDisposed) {
      AppLogger.w('[RtspVlcPlayer] Cannot initialize: player is disposed');
      return;
    }

    try {
      // Dispose existing controller if any
      if (_controller != null) {
        await _controller!.dispose();
      }

      AppLogger.i('[RtspVlcPlayer] Initializing RTSP: $url');

      _controller = VlcPlayerController.network(
        url,
        autoInitialize: false,
        autoPlay: false,
        hwAcc: HwAcc.full,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=500',
            '--rtsp-tcp',
            '--live-caching=100',
            '--verbose=-1',
            '--quiet',
          ]),
        ),
      );

      AppLogger.i('[RtspVlcPlayer] Controller created, initializing...');

      // Wait for controller to initialize
      await _controller!.initialize();

      AppLogger.i('[RtspVlcPlayer] Controller initialized successfully');
    } catch (e, st) {
      AppLogger.e('[RtspVlcPlayer] Initialize failed: $e', e, st);
      rethrow;
    }
  }

  @override
  Widget buildView() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return VlcPlayer(controller: _controller!, aspectRatio: 16 / 9);
  }

  @override
  Future<void> play() async {
    try {
      if (_controller != null && !_isDisposed) {
        await _controller!.play();
        AppLogger.i('[RtspVlcPlayer] Play started');
      }
    } catch (e) {
      AppLogger.e('[RtspVlcPlayer] Play failed: $e', e);
    }
  }

  @override
  Future<void> pause() async {
    try {
      if (_controller != null && !_isDisposed) {
        await _controller!.pause();
        AppLogger.i('[RtspVlcPlayer] Paused');
      }
    } catch (e) {
      AppLogger.e('[RtspVlcPlayer] Pause failed: $e', e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      if (_controller != null) {
        try {
          await _controller!.stop();
        } catch (_) {}
        try {
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }
      _isDisposed = true;
      AppLogger.i('[RtspVlcPlayer] Disposed');
    } catch (e) {
      AppLogger.e('[RtspVlcPlayer] Dispose error: $e', e);
    }
  }

  @override
  Future<String?> takeSnapshot() async {
    if (_controller == null) {
      AppLogger.w('[RtspVlcPlayer] takeSnapshot: controller is null');
      return null;
    }

    try {
      final bytes = await _controller!.takeSnapshot();
      if (bytes == null || bytes.isEmpty) {
        AppLogger.w('[RtspVlcPlayer] takeSnapshot returned empty/null bytes');
        return null;
      }

      // Save to thumbnails directory
      try {
        final thumbsDir = await CameraHelpers.getThumbsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = CameraHelpers.generateThumbnailFilename(
          url,
          timestamp,
        );
        final file = File('${thumbsDir.path}/$filename');
        AppLogger.d(
          '[RtspVlcPlayer] Writing snapshot ${bytes.length} bytes to ${file.path}',
        );
        await file.writeAsBytes(bytes, flush: true);
        await CameraHelpers.cleanupOldThumbs(thumbsDir);
        AppLogger.d('[RtspVlcPlayer] Snapshot saved: ${file.path}');
        return file.path;
      } catch (e, st) {
        AppLogger.e('[RtspVlcPlayer] Failed to save snapshot: $e', e, st);
        return null;
      }
    } catch (e, st) {
      AppLogger.e('[RtspVlcPlayer] takeSnapshot failed: $e', e, st);
      return null;
    }
  }
}
