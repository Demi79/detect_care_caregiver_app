import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_constants.dart';
import 'camera_helpers.dart';
import 'camera_models.dart';

class CameraStateManager {
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

  final StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();
  Stream<CameraState> get stateStream => _stateController.stream;

  void init() {
    if (loadCache) {
      _restoreLastUrl();
    } else {
      _updateState(_state.copyWith(initLoading: false));
    }

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startStatusPolling();
    }
  }

  void dispose() {
    _isDisposed = true;

    _statusTimer?.cancel();
    _statusTimer = null;

    _startDebounce?.cancel();
    _startDebounce = null;

    _controlsTimer?.cancel();
    _controlsTimer = null;

    _controller = null;

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
      if (_isDisposed || _controller == null) {
        timer.cancel();
        return;
      }

      if (isStarting && !isPlaying) return;

      try {
        final playing = await _controller!.isPlaying();
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

      urlController.clear();

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
