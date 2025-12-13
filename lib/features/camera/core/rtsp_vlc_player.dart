import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

class RtspVlcPlayer implements ICameraPlayer {
  final String url;
  VlcPlayerController? _controller;
  bool _isDisposed = false;
  bool _pendingPlay = false;
  final GlobalKey<_RtspVlcPlatformViewState> _platformViewKey =
      GlobalKey<_RtspVlcPlatformViewState>();
  VlcPlayerController? get controller => _controller;

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
        autoInitialize: true,
        autoPlay: true,
        hwAcc: HwAcc.auto,
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

      AppLogger.i(
        '[RtspVlcPlayer] Controller created (initialization deferred until widget mounts)',
      );
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

    return _RtspVlcPlatformView(
      key: _platformViewKey,
      player: this,
      controller: _controller!,
    );
  }

  @override
  Future<void> play() async {
    if (_controller == null || _isDisposed) {
      AppLogger.w(
        '[RtspVlcPlayer] Play called but controller is null/disposed',
      );
      return;
    }

    final c = _controller!;
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    try {
      while (!c.value.isInitialized && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (!c.value.isInitialized) {
        AppLogger.w(
          '[RtspVlcPlayer] Controller not initialized after wait; deferring play',
        );
        _pendingPlay = true;
        return;
      }

      await c.play();
      AppLogger.i('[RtspVlcPlayer] Play started');
    } catch (e, st) {
      AppLogger.e('[RtspVlcPlayer] Play failed: $e', e, st);
      _pendingPlay = true;
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
          // Best-effort stop/pause before disposing to give the native
          // decoder time to release surfaces. This helps avoid Android
          // BufferQueue "abandoned" errors when the platform view is
          // torn down shortly after dispose.
          try {
            await _controller!.stop();
          } catch (_) {}
          await _controller!.pause();
        } catch (e) {
          AppLogger.w('[RtspVlcPlayer] pause() failed during dispose: $e');
        }
        try {
          // Wait briefly after stopping to allow native resources to flush.
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller!.dispose();
        } catch (e) {
          AppLogger.w('[RtspVlcPlayer] controller.dispose() failed: $e');
        }
        _controller = null;
      }
      _isDisposed = true;
      AppLogger.i('[RtspVlcPlayer] Disposed');
    } catch (e, st) {
      AppLogger.e('[RtspVlcPlayer] Dispose error: $e', e, st);
    }
  }
}

class _RtspVlcPlatformView extends StatefulWidget {
  final RtspVlcPlayer player;
  final VlcPlayerController controller;

  const _RtspVlcPlatformView({
    required this.player,
    required this.controller,
    super.key,
  });

  @override
  State<_RtspVlcPlatformView> createState() => _RtspVlcPlatformViewState();
}

class _RtspVlcPlatformViewState extends State<_RtspVlcPlatformView> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      try {
        AppLogger.d(
          '[RtspVlcPlayer] Waiting for platform view to be initialized',
        );
        final start = DateTime.now();
        while (mounted &&
            !widget.controller.value.isInitialized &&
            DateTime.now().difference(start) < const Duration(seconds: 3)) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        _initialized = widget.controller.value.isInitialized;
        if (!_initialized) {
          AppLogger.w(
            '[RtspVlcPlayer] Platform view did not become initialized in time',
          );
        }
        if (widget.player._pendingPlay && _initialized) {
          try {
            await widget.controller.play();
            widget.player._pendingPlay = false;
            AppLogger.i(
              '[RtspVlcPlayer] Pending play executed after view ready',
            );
          } catch (e) {
            AppLogger.w(
              '[RtspVlcPlayer] Pending play failed after view ready: $e',
            );
          }
        }
      } catch (e, st) {
        AppLogger.e('[RtspVlcPlayer] Platform view wait failed: $e', e, st);
      }
    });
  }

  @override
  void dispose() {
    // Best-effort stop when the platform view widget is removed. This is
    // defensive: callers should dispose the player/controller before the
    // widget is unmounted, but a final attempt here reduces races.
    try {
      widget.controller.stop();
    } catch (e) {
      AppLogger.w('[RtspVlcPlayer] platform view dispose stop failed: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VlcPlayer(controller: widget.controller, aspectRatio: 16 / 9);
  }
}
