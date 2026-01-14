import 'dart:async';
import 'dart:io';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraService {
  // Constants
  static const Duration _defaultWaitDuration = Duration(seconds: 2);
  static const int _minVolume = 0;
  static const int _maxVolume = 100;

  // VLC configuration optimized for RTSP streaming
  // Các tùy chọn này được tối ưu cho camera IP 24/7
  static const List<String> _vlcOptions = [
    '--network-caching=500',
    '--rtsp-tcp', // Use TCP for reliable RTSP delivery
    '--live-caching=100', // Live stream buffer: 100ms (low latency)
  ];

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
      AppLogger.d('Creating VLC controller with options: $_vlcOptions');

      _controller = VlcPlayerController.network(
        url,
        autoPlay: true,
        hwAcc: HwAcc.full,
        options: VlcPlayerOptions(advanced: VlcAdvancedOptions(_vlcOptions)),
      );

      AppLogger.i('Created VLC controller for: $url');

      // Không gọi initialize() ở đây - VLC sẽ tự initialize khi widget được render
      // VLC tự động play khi autoPlay: true được set
      // Chỉ chờ một chút để VLC backend khởi động
      await Future.delayed(const Duration(milliseconds: 100));

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
  /// Kiểm tra xem stream có đang phát không. Nếu không phát được sau timeout,
  /// vẫn trả về true vì controller đã sẵn sàng (stream có thể phát ở backend
  /// nhưng network bị hạn chế).
  ///
  /// Trả về false chỉ khi controller null.
  Future<bool> waitForPlayback(Duration timeout) async {
    if (_controller == null) {
      AppLogger.w('❌ Controller is null');
      return false;
    }

    final deadline = DateTime.now().add(timeout);

    // Thử kiểm tra xem stream có phát không (3-4 lần với 200ms interval)
    while (DateTime.now().isBefore(deadline)) {
      try {
        final isPlaying = await _controller!.isPlaying();
        if (isPlaying == true) {
          AppLogger.d('✅ Stream started playing');
          return true;
        }
      } catch (e) {
        AppLogger.w('Error checking isPlaying: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Timeout nhưng controller vẫn sẵn sàng - không hiển thị error overlay
    // Vì stream có thể phát ở backend (network bị hạn chế)
    AppLogger.w('⏱️ Timeout but controller ready, stream may be running');
    return true;
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
  /// Trả về đường dẫn file của thumbnail đã lưu, hoặc null nếu thất bại.
  Future<String?> takeSnapshot({VlcPlayerController? controller}) async {
    final target = controller ?? _controller;
    if (target == null) {
      AppLogger.d(
        '[CameraService.takeSnapshot] No controller available, returning null',
      );
      return null;
    }

    try {
      AppLogger.api(
        '📸 [CameraService.takeSnapshot] Starting snapshot capture...',
      );

      final bytes = await target.takeSnapshot();
      if (bytes.isEmpty) {
        AppLogger.w('⚠️ [CameraService.takeSnapshot] Snapshot bytes empty');
        return null;
      }

      AppLogger.api(
        '📸 [CameraService.takeSnapshot] Captured ${bytes.length} bytes',
      );

      final thumbsDir = await CameraHelpers.getThumbsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = CameraHelpers.generateThumbnailFilename('', timestamp);
      final file = File('${thumbsDir.path}/$filename');

      await file.writeAsBytes(bytes, flush: true);
      await CameraHelpers.cleanupOldThumbs(thumbsDir);

      AppLogger.api('✅ [CameraService.takeSnapshot] Saved to: ${file.path}');
      return file.path;
    } catch (e, st) {
      AppLogger.e('❌ [CameraService.takeSnapshot] Failed: $e', e, st);
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

    try {
      AppLogger.d(
        'Writing thumbnail bytes length=${bytes.length} to ${file.path}',
      );
      await file.writeAsBytes(bytes, flush: true);
      await CameraHelpers.cleanupOldThumbs(thumbsDir);
      AppLogger.d('Thumbnail saved: ${file.path}');
      return file.path;
    } catch (e, st) {
      AppLogger.e('Failed to write thumbnail file ${file.path}: $e', e, st);
      return null;
    }
  }
}

/// Instance singleton toàn cục của [CameraService].
///
/// Sử dụng instance này trong toàn bộ ứng dụng để quản lý các thao tác camera.
final cameraService = CameraService();
