import 'dart:async';
import 'dart:io';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraService {
  // Constants
  static const Duration _playbackCheckInterval = Duration(milliseconds: 300);
  static const Duration _defaultWaitDuration = Duration(seconds: 2);
  static const int _minVolume = 0;
  static const int _maxVolume = 100;

  // VLC configuration optimized for RTSP streaming
  static const List<String> _vlcOptions = [];

  // Trạng thái nội bộ
  VlcPlayerController? _controller;
  String? _lastUrl;

  /// Tạo VLC player controller với cấu hình tối ưu cho RTSP streaming.
  ///
  /// Huỷ controller hiện có trước khi tạo controller mới.
  /// Bật wakelock để ngăn màn hình tắt khi đang phát.
  ///
  /// Ném lỗi nếu việc tạo controller thất bại.
  Future<VlcPlayerController> createController(String url) async {
    await _disposeController();
    await _enableWakelockIfNeeded();

    try {
      _controller = VlcPlayerController.network(
        url,
        autoPlay: true,
        hwAcc: HwAcc.full,
        options: VlcPlayerOptions(advanced: VlcAdvancedOptions(_vlcOptions)),
      );

      AppLogger.i('Created VLC controller for: $url');
      return _controller!;
    } catch (e, st) {
      AppLogger.e('Failed to create VLC controller for $url', e, st);
      await _disableWakelock();
      rethrow;
    }
  }

  /// Đảm bảo controller tồn tại cho URL đã cho.
  ///
  /// Tạo controller mới nếu:
  /// - Chưa có controller nào
  /// - URL đã thay đổi so với lần trước
  ///
  /// Chờ phát bắt đầu trước khi trả về. Trả về null nếu thất bại.
  Future<VlcPlayerController?> ensureControllerFor(
    String url, {
    Duration waitFor = _defaultWaitDuration,
  }) async {
    try {
      final needsNewController =
          _controller == null || (_lastUrl != null && _lastUrl != url);

      if (needsNewController) {
        final controller = await createController(url);
        _lastUrl = url;

        final isPlaying = await waitForPlayback(waitFor);
        AppLogger.d('Playback started: $isPlaying');

        return controller;
      }

      return _controller;
    } catch (e, st) {
      AppLogger.e('Failed to ensure controller for $url', e, st);
      return null;
    }
  }

  /// Huỷ controller hiện tại và dọn dẹp tài nguyên.
  Future<void> _disposeController() async {
    final controller = _controller;
    if (controller == null) return;

    await _stopController(controller);
    await _disposeControllerSafely(controller);

    _controller = null;
    _lastUrl = null;

    await _disableWakelock();
  }

  /// Chờ phát video bắt đầu trong khoảng thời gian timeout.
  ///
  /// Kiểm tra trạng thái phát của controller theo các khoảng thời gian đều đặn.
  /// Trả về true nếu bắt đầu phát, false nếu hết thời gian chờ.
  Future<bool> waitForPlayback(Duration timeout) async {
    if (_controller == null) return false;

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (await safeIsPlaying(_controller)) {
        return true;
      }
      await Future.delayed(_playbackCheckInterval);
    }

    return false;
  }

  /// Kiểm tra an toàn xem controller có đang phát hay không.
  ///
  /// Trả về false nếu controller là null hoặc có lỗi xảy ra.
  /// Điều này ngăn chặn crash khi native player chưa được khởi tạo hoàn toàn.
  Future<bool> safeIsPlaying(VlcPlayerController? controller) async {
    if (controller == null) return false;

    try {
      return await controller.isPlaying() == true;
    } catch (e) {
      AppLogger.w('Error checking playback status: $e');
      return false;
    }
  }

  /// Chụp ảnh từ luồng video hiện tại và lưu dưới dạng thumbnail.
  ///
  /// Trả về đường dẫn file của thumbnail đã lưu, hoặc null nếu thất bại.
  Future<String?> takeSnapshot() async {
    final controller = _controller;
    if (controller == null) return null;

    try {
      final bytes = await controller.takeSnapshot();
      if (bytes.isEmpty) {
        AppLogger.w('Snapshot returned empty bytes');
        return null;
      }

      return await _saveThumbnail(bytes);
    } catch (e, st) {
      AppLogger.e('Failed to take snapshot', e, st);
      return null;
    }
  }

  /// Chuyển đổi giữa trạng thái phát và tạm dừng.
  Future<void> togglePlayPause(bool isPlaying) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      if (isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (e, st) {
      AppLogger.e('Failed to toggle play/pause', e, st);
    }
  }

  /// Chuyển đổi trạng thái tắt tiếng.
  Future<void> toggleMute(bool isMuted) async {
    await setVolume(isMuted ? _maxVolume : _minVolume);
  }

  /// Đặt mức âm lượng.
  ///
  /// Âm lượng được giới hạn trong khoảng 0 đến 100.
  Future<void> setVolume(int volume) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final clampedVolume = volume.clamp(_minVolume, _maxVolume);
      await controller.setVolume(clampedVolume);
    } catch (e, st) {
      AppLogger.e('Failed to set volume', e, st);
    }
  }

  /// Lấy instance controller hiện tại.
  VlcPlayerController? get controller => _controller;

  /// Huỷ service và dọn dẹp toàn bộ tài nguyên.
  Future<void> dispose() async {
    await _disposeController();
  }

  // Các phương thức hỗ trợ nội bộ

  Future<void> _enableWakelockIfNeeded() async {
    try {
      final isEnabled = await WakelockPlus.enabled;
      if (!isEnabled) {
        await WakelockPlus.enable();
        AppLogger.d('Wakelock enabled');
      }
    } catch (e) {
      AppLogger.w('Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
      AppLogger.d('Wakelock disabled');
    } catch (e) {
      AppLogger.w('Failed to disable wakelock: $e');
    }
  }

  Future<void> _stopController(VlcPlayerController controller) async {
    try {
      await controller.stop();
    } catch (e) {
      AppLogger.w('Error stopping controller: $e');
    }
  }

  Future<void> _disposeControllerSafely(VlcPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (e) {
      AppLogger.w('Error disposing controller: $e');
    }
  }

  Future<String?> _saveThumbnail(List<int> bytes) async {
    final thumbsDir = await CameraHelpers.getThumbsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = CameraHelpers.generateThumbnailFilename('', timestamp);
    final file = File('${thumbsDir.path}/$filename');

    await file.writeAsBytes(bytes, flush: true);
    await CameraHelpers.cleanupOldThumbs(thumbsDir);

    AppLogger.d('Thumbnail saved: ${file.path}');
    return file.path;
  }
}

/// Instance singleton toàn cục của [CameraService].
///
/// Sử dụng instance này trong toàn bộ ứng dụng để quản lý các thao tác camera.
final cameraService = CameraService();
