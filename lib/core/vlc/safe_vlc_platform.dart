import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vlc_player_platform_interface/flutter_vlc_player_platform_interface.dart';
// ignore: implementation_imports
import 'package:flutter_vlc_player_platform_interface/src/method_channel/method_channel_vlc_player.dart';

/// Wraps the VLC platform interface to swallow early channel-error exceptions
/// and retry with delays to allow native plugin initialization.
class _SafeMethodChannelVlcPlayer extends MethodChannelVlcPlayer {
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(milliseconds: 800);

  /// Call super.init() with retry logic and increasing delays
  @override
  Future<void> init() async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // Delay before each attempt to let native side initialize
        if (attempt > 0) {
          await Future.delayed(_retryDelay * (attempt));
        }
        await super.init();
        debugPrint('[VLC Safe] init() succeeded on attempt ${attempt + 1}');
        return; // Success
      } on PlatformException catch (e) {
        final isChannelError =
            e.code == 'channel-error' &&
            (e.message?.contains('Unable to establish connection') ?? false);

        debugPrint(
          '[VLC Safe] init() attempt ${attempt + 1} failed: ${e.message}',
        );

        if (!isChannelError || attempt == _maxRetries - 1) {
          debugPrint(
            '[VLC Safe] Retries exhausted or non-channel error, rethrowing',
          );
          rethrow;
        }
      }
    }
  }

  /// Call super.create() with retry logic and increasing delays
  @override
  Future<void> create({
    required int viewId,
    required String uri,
    required DataSourceType type,
    String? package,
    bool? autoPlay,
    HwAcc? hwAcc,
    VlcPlayerOptions? options,
  }) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // Delay before each attempt to let native side initialize
        if (attempt > 0) {
          await Future.delayed(_retryDelay * (attempt));
        }
        await super.create(
          viewId: viewId,
          uri: uri,
          type: type,
          package: package,
          autoPlay: autoPlay,
          hwAcc: hwAcc,
          options: options,
        );
        debugPrint('[VLC Safe] create() succeeded on attempt ${attempt + 1}');
        return; // Success
      } on PlatformException catch (e) {
        final isChannelError =
            e.code == 'channel-error' &&
            (e.message?.contains('Unable to establish connection') ?? false);

        debugPrint(
          '[VLC Safe] create() attempt ${attempt + 1} failed: ${e.message}',
        );

        if (!isChannelError || attempt == _maxRetries - 1) {
          debugPrint(
            '[VLC Safe] Retries exhausted or non-channel error, rethrowing',
          );
          rethrow;
        }
      }
    }
  }
}

/// Initialize the safe VLC platform wrapper as early as possible
void ensureSafeVlcPlatform() {
  if (VlcPlayerPlatform.instance is! _SafeMethodChannelVlcPlayer) {
    VlcPlayerPlatform.instance = _SafeMethodChannelVlcPlayer();
  }
}
