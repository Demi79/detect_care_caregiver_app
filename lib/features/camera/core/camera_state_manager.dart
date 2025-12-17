import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_constants.dart';
import 'camera_helpers.dart';
import 'camera_models.dart';
import 'camera_service.dart';

/// State management for camera functionality
class CameraStateManager {
  // ... existing code ...
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  final TextEditingController urlController = TextEditingController();
  Timer? _statusTimer;
  Timer? _startDebounce;
  Timer? _controlsTimer;
  VlcPlayerController? _controller;
  final bool loadCache;

  CameraStateManager({this.loadCache = true});

  CameraState _state = CameraState.initial();

  CameraState get state => _state;

  // Getters for easy access
  bool get isPlaying => _state.isPlaying;
  bool get isMuted => _state.isMuted;
  bool get isFullscreen => _state.isFullscreen;
  bool get isHd => _state.isHd;
  bool get isStarting => _state.isStarting;
  bool get initLoading => _state.initLoading;
  bool get controlsVisible => _state.controlsVisible;
  String? get currentUrl => _state.currentUrl;
  String? get statusMessage => _state.statusMessage;
  double? get videoAspectRatio => _state.videoAspectRatio;
  CameraSettings get settings => _state.settings;

  // Stream for state changes
  final StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();
  Stream<CameraState> get stateStream => _stateController.stream;

  void init() {
    if (loadCache) {
      _restoreLastUrl();
    } else {
      _updateState(_state.copyWith(initLoading: false));
    }

    // Only start polling timer if not in test environment
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startStatusPolling();
    }
  }

  void dispose() {
    _isDisposed = true;

    // Cancel all timers to prevent memory leaks
    _statusTimer?.cancel();
    _statusTimer = null;

    _startDebounce?.cancel();
    _startDebounce = null;

    _controlsTimer?.cancel();
    _controlsTimer = null;

    // Only dispose controller if we created it ourselves, not if it was set from outside
    // The service that created the controller should dispose it
    _controller = null; // Clear reference

    // Don't dispose urlController here as it might still be used by widgets
    // Let the widget that owns it dispose it properly

    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }

  void _updateState(CameraState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  Future<void> _restoreLastUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(CameraConstants.kPrefRtspUrl) ?? '';
      urlController.text = url;

      final subtype = CameraHelpers.readSubtype(url);
      final isHd = subtype == CameraConstants.hdSubtype;

      final fps = CameraHelpers.tryReadFps(url) ?? CameraConstants.defaultFps;
      final retentionDays =
          prefs.getInt(CameraConstants.kPrefRetention) ??
          CameraConstants.defaultRetentionDays;
      final channelsList =
          prefs.getStringList(CameraConstants.kPrefChannels) ??
          CameraConstants.defaultChannels.toList();
      final channels = Set<String>.from(channelsList);

      final newSettings = CameraSettings(
        isHd: isHd,
        fps: fps,
        retentionDays: retentionDays,
        channels: channels,
      );

      _updateState(
        _state.copyWith(isHd: isHd, initLoading: false, settings: newSettings),
      );
    } catch (e) {
      _updateState(_state.copyWith(initLoading: false));
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(CameraConstants.statusPollInterval, (
      timer,
    ) async {
      // Don't poll if disposed or controller is null
      if (_isDisposed || _controller == null) {
        timer.cancel();
        return;
      }

      if (isStarting && !isPlaying) return;

      try {
        final playing = await cameraService.safeIsPlaying(_controller);
        if (playing == true &&
            (statusMessage == null ||
                statusMessage != CameraConstants.playingMessage)) {
          _updateState(
            _state.copyWith(
              statusMessage: CameraConstants.playingMessage,
              isPlaying: true,
            ),
          );
        }
      } catch (_) {}
    });
  }

  Future<void> saveUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != prefs.getString(CameraConstants.kPrefRtspUrl)) {
        await prefs.setString(CameraConstants.kPrefRtspUrl, url);
      }
    } catch (_) {}
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CameraConstants.kPrefHd, settings.isHd);
      await prefs.setInt(CameraConstants.kPrefFps, settings.fps);
      await prefs.setInt(
        CameraConstants.kPrefRetention,
        settings.retentionDays,
      );
      await prefs.setStringList(
        CameraConstants.kPrefChannels,
        settings.channels.toList(),
      );
    } catch (_) {}
  }

  void updateSettings({
    bool? isHd,
    int? fps,
    int? retentionDays,
    Set<String>? channels,
  }) {
    final newSettings = settings.copyWith(
      isHd: isHd,
      fps: fps,
      retentionDays: retentionDays,
      channels: channels,
    );
    _updateState(_state.copyWith(settings: newSettings));
    saveSettings();
  }

  void showControlsTemporarily() {
    _updateState(_state.copyWith(controlsVisible: true));
    _controlsTimer?.cancel();
    _controlsTimer = Timer(CameraConstants.controlsAutoHideDelay, () {
      if (_isDisposed) return;
      _updateState(_state.copyWith(controlsVisible: false));
    });
  }

  void toggleFullscreen() {
    final newFullscreen = !isFullscreen;
    _updateState(_state.copyWith(isFullscreen: newFullscreen));

    if (newFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    HapticFeedback.selectionClick();
    // Khi chuyển sang fullscreen, thử resume playback nếu controller đã
    // tồn tại nhưng playback bị tạm dừng do thay đổi UI/orientation.
    if (newFullscreen && _controller != null) {
      try {
        _controller!.play();
        // Log playback state shortly after trying to resume (async)
        // Avoid unhandled exceptions from isPlaying() if the controller
        // is not yet initialized by the native side. Attach a catchError
        // so any failure is swallowed and doesn't crash the UI.
        cameraService
            .safeIsPlaying(_controller)
            .then((playing) {
              try {
                // ignore: avoid_print
                print(
                  '🐛 [CameraStateManager] fullscreen resume play -> isPlaying=$playing',
                );
              } catch (_) {}
            })
            .catchError((_) {
              // ignore errors from safeIsPlaying (shouldn't be necessary)
            });
      } catch (_) {}
    }
  }

  void setVideoAspectRatio(double? aspectRatio) {
    _updateState(_state.copyWith(videoAspectRatio: aspectRatio));
  }

  void setStatusMessage(String? message) {
    _updateState(_state.copyWith(statusMessage: message));
  }

  void setStarting(bool starting) {
    _updateState(_state.copyWith(isStarting: starting));
  }

  void setCurrentUrl(String? url) {
    _updateState(_state.copyWith(currentUrl: url));
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CameraConstants.kPrefRtspUrl);
      await prefs.remove(CameraConstants.kPrefHd);
      await prefs.remove(CameraConstants.kPrefFps);
      await prefs.remove(CameraConstants.kPrefRetention);
      await prefs.remove(CameraConstants.kPrefChannels);

      // Clear URL controller
      urlController.clear();

      // Reset state with default settings
      _updateState(
        _state.copyWith(
          isHd: false,
          settings: const CameraSettings(
            isHd: false,
            fps: 25,
            retentionDays: 7,
            channels: {'App'},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  void setController(VlcPlayerController? controller) {
    _controller = controller;
  }

  void clearController() {
    _controller = null;
  }

  VlcPlayerController? getController() => _controller;
}
