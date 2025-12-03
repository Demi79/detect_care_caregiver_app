import 'dart:async';
import 'dart:io';

import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camera_constants.dart';
import 'camera_helpers.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

/// Lớp dịch vụ cho các thao tác liên quan đến camera
class CameraService {
  VlcPlayerController? _controller;
  String? _lastUrl;

  /// Tạo VlcPlayerController với các tùy chọn tối ưu
  Future<VlcPlayerController> createController(String url) async {
    // Huỷ controller hiện có (nếu có)
    await _disposeController();

    // Bật wakelock để tránh thiết bị ngủ trong lúc phát
    await WakelockPlus.enable();

    try {
      _controller = VlcPlayerController.network(
        url,
        autoInitialize: true,
        autoPlay: true,
        hwAcc: HwAcc.disabled,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=${CameraConstants.networkCaching}',
            '--rtsp-tcp',
            '--live-caching=${CameraConstants.liveCaching}',
            '--clock-jitter=0',
            '--avcodec-threads=0',
            '--video-filter=deinterlace',
            '--deinterlace-mode=blend',
          ]),
        ),
      );

      AppLogger.i('🐛 [CameraService] created VlcPlayerController for $url');

      return _controller!;
    } catch (e, st) {
      AppLogger.e(
        '❌ [CameraService] createController failed for $url: $e',
        e,
        st,
      );
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      rethrow;
    }
  }

  /// Ensure a controller exists for the given URL. If an existing controller
  /// is for a different URL or missing, recreate it and optionally wait for
  /// playback to start. Returns the created/ensured controller or null on
  /// failure.
  Future<VlcPlayerController?> ensureControllerFor(
    String url, {
    Duration waitFor = const Duration(seconds: 2),
  }) async {
    try {
      if (_controller == null || (_lastUrl != null && _lastUrl != url)) {
        final c = await createController(url);
        _lastUrl = url;
        // Try to wait briefly for playback
        final started = await waitForPlayback(waitFor);
        if (started) return c;
        // Even if not started, return the controller so caller can decide
        return c;
      }
      return _controller;
    } catch (e, st) {
      AppLogger.e(
        '❌ [CameraService] ensureControllerFor failed for $url: $e',
        e,
        st,
      );
      return null;
    }
  }

  /// Huỷ (dispose) controller hiện tại
  Future<void> _disposeController() async {
    if (_controller != null) {
      try {
        await _controller!.stop();
      } catch (_) {}
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
      _lastUrl = null;
    }
  }

  /// Đợi playback bắt đầu
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

  /// Safe wrapper around controller.isPlaying() which may throw if the
  /// native player isn't fully initialized yet. Returns false on any error.
  Future<bool> safeIsPlaying(VlcPlayerController? controller) async {
    if (controller == null) return false;
    try {
      final ok = await controller.isPlaying();
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Chụp snapshot từ video và lưu thành thumbnail
  Future<String?> takeSnapshot() async {
    if (_controller == null) return null;

    try {
      final bytes = await _controller!.takeSnapshot();
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

  /// Chuyển trạng thái phát/tạm dừng
  Future<void> togglePlayPause(bool isPlaying) async {
    if (_controller == null) return;

    if (isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  /// Bật/tắt âm
  Future<void> toggleMute(bool isMuted) async {
    if (_controller == null) return;

    if (isMuted) {
      await _controller!.setVolume(100);
    } else {
      await _controller!.setVolume(0);
    }
  }

  /// Đặt âm lượng
  Future<void> setVolume(int volume) async {
    if (_controller == null) return;
    await _controller!.setVolume(volume.clamp(0, 100));
  }

  /// Lấy controller hiện tại
  VlcPlayerController? get controller => _controller;

  /// Huỷ service và dọn dẹp tài nguyên
  Future<void> dispose() async {
    await WakelockPlus.disable();
    await _disposeController();
  }
}

/// Thể hiện singleton của CameraService
final cameraService = CameraService();
