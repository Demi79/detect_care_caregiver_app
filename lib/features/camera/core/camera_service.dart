import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camera_constants.dart';
import 'camera_helpers.dart';

class CameraService {
  VlcPlayerController? _controller;

  Future<VlcPlayerController> createController(String url) async {
    await _disposeController();

    await WakelockPlus.enable();

    _controller = VlcPlayerController.network(
      url,
      autoInitialize: true,
      autoPlay: true,
      hwAcc: HwAcc.full,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          '--network-caching=${CameraConstants.networkCaching}',
          '--rtsp-tcp',
          '--live-caching=${CameraConstants.liveCaching}',
          '--clock-jitter=0',
          '--avcodec-hw=auto',
          '--avcodec-threads=0',
          '--video-filter=deinterlace',
          '--deinterlace-mode=blend',
        ]),
      ),
    );

    return _controller!;
  }

  /// Dispose the current controller
  Future<void> _disposeController() async {
    if (_controller != null) {
      try {
        await _controller!.stop();
      } catch (_) {}
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
  }

  /// Wait for playback to start
  Future<bool> waitForPlayback(Duration timeout) async {
    if (_controller == null) return false;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final ok = await _controller!.isPlaying();
        if (ok == true) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  /// Take a snapshot and save it as thumbnail
  Future<String?> takeSnapshot() async {
    if (_controller == null) return null;

    try {
      final Uint8List? bytes = await _controller!.takeSnapshot();
      if (bytes == null || bytes.isEmpty) return null;

      final thumbsDir = await CameraHelpers.getThumbsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = CameraHelpers.generateThumbnailFilename('', timestamp);
      final file = File('${thumbsDir.path}/$filename');

      await file.writeAsBytes(bytes, flush: true);
      await CameraHelpers.cleanupOldThumbs(thumbsDir);

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause(bool isPlaying) async {
    if (_controller == null) return;

    if (isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  /// Toggle mute
  Future<void> toggleMute(bool isMuted) async {
    if (_controller == null) return;

    if (isMuted) {
      await _controller!.setVolume(100);
    } else {
      await _controller!.setVolume(0);
    }
  }

  /// Set volume
  Future<void> setVolume(int volume) async {
    if (_controller == null) return;
    await _controller!.setVolume(volume.clamp(0, 100));
  }

  /// Get current controller
  VlcPlayerController? get controller => _controller;

  /// Dispose service and cleanup resources
  Future<void> dispose() async {
    await WakelockPlus.disable();
    await _disposeController();
  }
}

/// Singleton instance of camera service
final cameraService = CameraService();
