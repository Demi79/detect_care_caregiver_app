import 'dart:async';

import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/screens/phone_login_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/controls_overlay.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/features_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/quality_badge.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class LiveCameraScreen extends StatefulWidget {
  final String? initialUrl;
  final bool loadCache;

  const LiveCameraScreen({super.key, this.initialUrl, this.loadCache = true});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  late final CameraStateManager _stateManager;
  late final CameraService _cameraService;
  Timer? _startDebounce;
  bool _streamDisposed = false;
  bool _stateDisposed = false;

  @override
  void initState() {
    super.initState();
    final shouldLoadCache = widget.initialUrl == null && widget.loadCache;
    _stateManager = CameraStateManager(loadCache: shouldLoadCache);
    _cameraService = CameraService();
    _stateManager.init();

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _stateManager.urlController.text = widget.initialUrl!;
      _stateManager.setCurrentUrl(widget.initialUrl!);
      _startPlay();
    }
  }

  Future<void> _disposeStreamResources() async {
    if (_streamDisposed) return;
    _streamDisposed = true;

    _startDebounce?.cancel();
    _startDebounce = null;

    await _cameraService.dispose();

    _stateManager.clearController();
  }

  @override
  void dispose() {
    unawaited(_disposeStreamResources());

    if (!_stateDisposed) {
      _stateManager.dispose();
      _stateDisposed = true;
    }

    _stateManager.urlController.dispose();
    super.dispose();
  }

  Future<void> _startPlay({bool allowFallback = true}) async {
    final allowed = await _ensureSubscriptionAllowed();
    if (!allowed) return;

    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    if (_stateManager.isStarting) {
      return;
    }
    if (_stateManager.currentUrl == url && _cameraService.controller != null) {
      return;
    }

    _stateManager.setStarting(true);
    _stateManager.setStatusMessage(
      _stateManager.isHd
          ? CameraConstants.connectingHdMessage
          : CameraConstants.connectingMessage,
    );
    _stateManager.setCurrentUrl(url);

    await _stateManager.saveUrl(url);

    try {
      final controller = await _cameraService.createController(url);
      _stateManager.setController(controller);

      controller.addListener(() {
        final size = controller.value.size;
        if (size.width > 0 && size.height > 0) {
          final newAspectRatio = size.width / size.height;
          if (_stateManager.videoAspectRatio != newAspectRatio) {
            _stateManager.setVideoAspectRatio(newAspectRatio);
          }
        }
      });

      final started = await _cameraService.waitForPlayback(
        CameraConstants.playbackWaitTimeout,
      );

      if (!mounted) return;

      if (started) {
        _stateManager.setStatusMessage(CameraConstants.playingMessage);
        _stateManager.showControlsTemporarily();
        return;
      }

      if (allowFallback && _stateManager.isHd) {
        final sdUrl = CameraHelpers.withSubtype(url, CameraConstants.sdSubtype);
        context.showCameraMessage(CameraConstants.hdFallbackMessage);

        _stateManager.updateSettings(isHd: false);
        _stateManager.urlController.text = sdUrl;
        _stateManager.setStarting(false);
        await _startPlay(allowFallback: false);
        return;
      }

      _stateManager.setStatusMessage(CameraConstants.cannotPlayMessage);
    } catch (e) {
      if (mounted) {
        _stateManager.setStatusMessage(CameraConstants.cannotPlayMessage);
        context.showCameraMessage(CameraConstants.checkUrlMessage);
      }
    }

    _stateManager.setStarting(false);
  }

  Future<bool> _ensureSubscriptionAllowed() async {
    try {
      final token = await AuthStorage.getAccessToken();
      if (token == null) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Yêu cầu đăng nhập'),
            content: const Text('Bạn cần đăng nhập để sử dụng camera.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                  );
                },
                child: const Text('Đăng nhập'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _toggleQuality() async {
    if (_stateManager.isStarting) {
      context.showCameraMessage(CameraConstants.connectingWaitMessage);
      return;
    }

    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    final nextHd = !_stateManager.isHd;
    final targetSubtype = nextHd
        ? CameraConstants.hdSubtype
        : CameraConstants.sdSubtype;
    final newUrl = CameraHelpers.withSubtype(url, targetSubtype);

    _stateManager.updateSettings(isHd: nextHd);
    _stateManager.urlController.text = newUrl;

    if (newUrl != _stateManager.currentUrl) {
      await _startPlay();
    }

    HapticFeedback.selectionClick();
  }

  Future<void> _changeFps(int newFps) async {
    if (_stateManager.isStarting) return;

    final fps = newFps.clampFps();
    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    final newUrl = CameraHelpers.withFps(url, fps);
    _stateManager.updateSettings(fps: fps);
    _stateManager.urlController.text = newUrl;

    if (newUrl != _stateManager.currentUrl) {
      await _startPlay();
    }
  }

  Future<void> _changeRetentionDays(int days) async {
    _stateManager.updateSettings(retentionDays: days.clampRetentionDays());
  }

  Future<void> _changeChannels(Set<String> channels) async {
    _stateManager.updateSettings(channels: channels);
  }

  Future<void> _togglePlayPause() async {
    await _cameraService.togglePlayPause(_stateManager.isPlaying);
    _stateManager.showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    await _cameraService.toggleMute(_stateManager.isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_stateManager.isFullscreen) {
          _stateManager.toggleFullscreen();
          return;
        }

        String? snapshotPath;
        try {
          snapshotPath = await _cameraService.takeSnapshot();
        } catch (_) {}

        if (snapshotPath != null && context.mounted) {
          Navigator.of(context).pop(snapshotPath);
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: StreamBuilder<CameraState>(
        stream: _stateManager.stateStream,
        initialData: _stateManager.state,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (_stateManager.isDisposed) {
            return const SizedBox.shrink();
          }
          final state = snapshot.data ?? _stateManager.state;
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: CameraWidgets.buildAppBar(
              onFullscreenToggle: _stateManager.toggleFullscreen,
              isFullscreen: state.isFullscreen,
            ),
            body: _buildBody(state),
          );
        },
      ),
    );
  }

  Widget _buildBody(CameraState state) {
    if (state.isFullscreen) {
      return CameraWidgets.buildFullscreenContainer(
        onTap: _stateManager.showControlsTemporarily,
        onDoubleTap: _stateManager.toggleFullscreen,
        child: _buildVideoStack(state),
      );
    }

    return Column(
      children: [
        // UrlInputRow(
        //   controller: _stateManager.urlController,
        //   starting: state.isStarting,
        //   onStart: () {
        //     _startDebounce?.cancel();
        //     _startDebounce = Timer(
        //       CameraConstants.startDebounceDelay,
        //       _startPlay,
        //     );
        //   },
        // ),
        Flexible(
          child: CameraWidgets.buildNormalContainer(
            aspectRatio: state.videoAspectRatio,
            child: _buildVideoContent(state),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: CameraFeaturesPanel(
            fps: state.settings.fps,
            onFpsChanged: _changeFps,
            retentionDays: state.settings.retentionDays,
            onRetentionChanged: _changeRetentionDays,
            channels: state.settings.channels,
            onChannelsChanged: _changeChannels,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoContent(CameraState state) {
    if (state.initLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cameraService.controller == null) {
      return CameraWidgets.buildPlaceholder();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stateManager.showControlsTemporarily,
      onDoubleTap: _stateManager.toggleFullscreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: VlcPlayer(
              controller: _cameraService.controller!,
              aspectRatio: state.videoAspectRatio ?? 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            ),
          ),
          if (state.statusMessage != null)
            CameraStatusChip(text: state.statusMessage!),
          Positioned(
            top: 12,
            right: 12,
            child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
          ),
          if (state.isStarting)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (state.controlsVisible)
            Builder(
              builder: (context) => CameraControlsOverlay(
                isPlaying: state.isPlaying,
                isMuted: state.isMuted,
                isFullscreen: state.isFullscreen,
                onPlayPause: _togglePlayPause,
                onMute: _toggleMute,
                onFullscreen: _stateManager.toggleFullscreen,
                onRecord: () {
                  context.showCameraMessage(
                    CameraConstants.recordNotSupportedMessage,
                  );
                },
                onSnapshot: () {
                  context.showCameraMessage(
                    CameraConstants.snapshotNotSupportedMessage,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoStack(CameraState state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cameraService.controller != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: VlcPlayer(
              controller: _cameraService.controller!,
              aspectRatio: state.videoAspectRatio ?? 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            ),
          )
        else
          CameraWidgets.buildPlaceholder(),
        if (state.statusMessage != null)
          CameraStatusChip(text: state.statusMessage!),
        Positioned(
          top: 16,
          right: 16,
          child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
        ),
        if (state.isStarting)
          Container(
            color: Colors.black38,
            child: const Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Quay về',
            ),
          ),
        ),
        if (state.controlsVisible)
          Builder(
            builder: (context) => CameraControlsOverlay(
              isPlaying: state.isPlaying,
              isMuted: state.isMuted,
              isFullscreen: state.isFullscreen,
              onPlayPause: _togglePlayPause,
              onMute: _toggleMute,
              onFullscreen: _stateManager.toggleFullscreen,
              onRecord: () {
                context.showCameraMessage(
                  CameraConstants.recordNotSupportedMessage,
                );
              },
              onSnapshot: () {
                context.showCameraMessage(
                  CameraConstants.snapshotNotSupportedMessage,
                );
              },
            ),
          ),
      ],
    );
  }
}
