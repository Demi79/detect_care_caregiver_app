import 'dart:async';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Lớp dịch vụ cho các thao tác liên quan đến camera sử dụng media_kit
class CameraService {
  Player? _player;
  String? _lastUrl;

  /// Tạo Player với các tùy chọn tối ưu
  Future<Player> createController(String url) async {
    // Huỷ controller hiện có (nếu có)
    await _disposeController();

    // Bật wakelock CHỈ khi cần thiết
    try {
      final isEnabled = await WakelockPlus.enabled;
      if (!isEnabled) {
        await WakelockPlus.enable();
      }
    } catch (_) {}

    try {
      _player = Player();
      _lastUrl = url;
      AppLogger.i('💡 🐛 [CameraService] created Media Player for $url');
      return _player!;
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

  /// Open media with retry logic to handle initialization issues
  Future<void> openMedia(String url, {int maxRetries = 5}) async {
    if (_player == null) return;

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        AppLogger.d('🔄 [CameraService] Open media attempt ${attempt + 1}/$maxRetries: $url');
        
        await _player!.open(
          Media(url),
          play: false,
        );
        
        AppLogger.i('✅ [CameraService] Media opened successfully on attempt ${attempt + 1}');
        return;
      } catch (e) {
        attempt++;
        AppLogger.w('⚠️ [CameraService] Open media attempt $attempt failed: $e');
        if (attempt >= maxRetries) {
          AppLogger.e('❌ [CameraService] Open media failed after $maxRetries attempts');
          rethrow;
        }
        // Exponential backoff
        final backoffDuration = Duration(milliseconds: 500 + (attempt - 1) * 200);
        AppLogger.d('⏳ [CameraService] Retrying after ${backoffDuration.inMilliseconds}ms...');
        await Future.delayed(backoffDuration);
      }
    }
  }

  /// Play the media
  Future<void> play() async {
    if (_player == null) return;
    try {
      await _player!.play();
      AppLogger.i('▶️ [CameraService] Playing');
    } catch (e) {
      AppLogger.e('❌ [CameraService] Play failed: $e');
      rethrow;
    }
  }

  /// Pause the media
  Future<void> pause() async {
    if (_player == null) return;
    try {
      await _player!.pause();
      AppLogger.i('⏸️ [CameraService] Paused');
    } catch (e) {
      AppLogger.e('❌ [CameraService] Pause failed: $e');
    }
  }

  /// Stop the media
  Future<void> stop() async {
    if (_player == null) return;
    try {
      await _player!.stop();
      AppLogger.i('⏹️ [CameraService] Stopped');
    } catch (e) {
      AppLogger.e('❌ [CameraService] Stop failed: $e');
    }
  }

  /// Huỷ (dispose) controller hiện tại
  Future<void> _disposeController() async {
    if (_player != null) {
      try {
        await _player!.dispose();
      } catch (_) {}
      _player = null;
      _lastUrl = null;
    }
    // Tắt wakelock để tiết kiệm pin
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  /// Check if media is playing
  Future<bool> isPlaying() async {
    if (_player == null) return false;
    try {
      return _player!.state.playing;
    } catch (_) {
      return false;
    }
  }

  /// Set volume (0-100)
  Future<void> setVolume(int volume) async {
    if (_player == null) return;
    try {
      await _player!.setVolume(volume.clamp(0, 100).toDouble());
    } catch (e) {
      AppLogger.e('❌ [CameraService] Set volume failed: $e');
    }
  }

  /// Safe wrapper to check if playing (compatibility method)
  Future<bool> safeIsPlaying(Player? player) async {
    if (player == null) return false;
    try {
      return player.state.playing;
    } catch (_) {
      return false;
    }
  }

  /// Toggle play/pause (compatibility method)
  Future<void> togglePlayPause(bool isPlaying) async {
    if (_player == null) return;
    try {
      if (isPlaying) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
    } catch (e) {
      AppLogger.e('❌ [CameraService] Toggle play/pause failed: $e');
    }
  }

  /// Toggle mute (compatibility method)
  Future<void> toggleMute(bool isMuted) async {
    if (_player == null) return;
    try {
      if (isMuted) {
        await _player!.setVolume(100);
      } else {
        await _player!.setVolume(0);
      }
    } catch (e) {
      AppLogger.e('❌ [CameraService] Toggle mute failed: $e');
    }
  }

  /// Take snapshot (placeholder - media_kit doesn't provide this directly)
  Future<String?> takeSnapshot() async {
    // Media_kit doesn't have built-in snapshot functionality
    // This is a placeholder for compatibility
    AppLogger.w('⚠️ [CameraService] takeSnapshot not supported with media_kit');
    return null;
  }

  /// Get current player (alias for compatibility)
  Player? get controller => _player;

  /// Get current player
  Player? get player => _player;

  /// Huỷ service và dọn dẹp tài nguyên
  Future<void> dispose() async {
    await WakelockPlus.disable();
    await _disposeController();
  }

  /// Ensure player exists for URL
  Future<Player?> ensureControllerFor(
    String url, {
    Duration waitFor = const Duration(seconds: 2),
  }) async {
    if (_player != null && _lastUrl == url) {
      return _player;
    }

    try {
      final player = await createController(url);
      if (waitFor.inMilliseconds > 0) {
        await Future.delayed(waitFor);
      }
      return player;
    } catch (_) {
      return null;
    }
  }

  /// Stream of duration changes
  Stream<Duration> get durationStream {
    if (_player == null) {
      return const Stream.empty();
    }
    return _player!.stream.duration;
  }

  /// Stream of position changes
  Stream<Duration> get positionStream {
    if (_player == null) {
      return const Stream.empty();
    }
    return _player!.stream.position;
  }
}

/// Thể hiện singleton của CameraService
final cameraService = CameraService();
