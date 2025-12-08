import 'dart:async';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:flutter/material.dart';

// NOTE: flutter_webrtc v0.11.6+hotfix.1 has Android compatibility issues with this Flutter version
// (Registrar class was removed in newer Flutter versions).
// This is a stub implementation that provides the interface while development continues.
// To enable full WebRTC functionality:
// 1. Update to Flutter 3.13+ or
// 2. Find a compatible flutter_webrtc version, or
// 3. Use an alternative WebRTC solution

enum WebRtcConnectionState { connecting, connected, failed, disconnected }

/// WebRTC Player for real-time low-latency streaming (STUB - Not yet functional)
/// Used for Realtime Mode in camera monitoring
///
/// TODO: Implement full WebRTC functionality when compatible version is available
class WebrtcPlayer implements ICameraPlayer {
  final String roomId;
  final String signalUrl;
  WebRtcConnectionState _connectionState = WebRtcConnectionState.disconnected;
  bool _isDisposed = false;
  final _stateController = StreamController<WebRtcConnectionState>.broadcast();

  WebrtcPlayer({required this.roomId, required this.signalUrl});

  Stream<WebRtcConnectionState> get connectionStateStream =>
      _stateController.stream;

  WebRtcConnectionState get connectionState => _connectionState;

  @override
  String get streamUrl => 'webrtc://$roomId';

  @override
  String get protocol => 'webrtc';

  void _setConnectionState(WebRtcConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _stateController.add(state);
      AppLogger.i('[WebrtcPlayer] Connection state: $state');
    }
  }

  @override
  Future<void> initialize() async {
    if (_isDisposed) {
      AppLogger.w('[WebrtcPlayer] Cannot initialize: player is disposed');
      return;
    }

    try {
      AppLogger.i(
        '[WebrtcPlayer] STUB: WebRTC initialization not yet supported. '
        'Requires flutter_webrtc compatible version. Room: $roomId',
      );

      _setConnectionState(WebRtcConnectionState.failed);

      // In production, this would:
      // 1. Create RTCPeerConnection
      // 2. Connect to signaling server
      // 3. Exchange SDP offer/answer
      // 4. Monitor connection state
    } catch (e, st) {
      AppLogger.e('[WebrtcPlayer] Initialize failed: $e', e, st);
      _setConnectionState(WebRtcConnectionState.failed);
    }
  }

  @override
  Widget buildView() {
    return StreamBuilder<WebRtcConnectionState>(
      stream: connectionStateStream,
      initialData: _connectionState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _connectionState;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder video area
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_off,
                      color: Colors.white54,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WebRTC Unavailable',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Requires compatible flutter_webrtc version',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Status indicator
            Positioned(top: 16, right: 16, child: _buildStatusIndicator(state)),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator(WebRtcConnectionState state) {
    final (color, label) = switch (state) {
      WebRtcConnectionState.connecting => (Colors.orange, 'Connecting...'),
      WebRtcConnectionState.connected => (Colors.green, 'Live'),
      WebRtcConnectionState.failed => (Colors.red, 'Failed'),
      WebRtcConnectionState.disconnected => (Colors.grey, 'Unavailable'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> play() async {
    try {
      AppLogger.i('[WebrtcPlayer] STUB: Play called (no-op)');
    } catch (e) {
      AppLogger.e('[WebrtcPlayer] Play failed: $e', e);
    }
  }

  @override
  Future<void> pause() async {
    try {
      _setConnectionState(WebRtcConnectionState.disconnected);
      AppLogger.i('[WebrtcPlayer] Paused');
    } catch (e) {
      AppLogger.e('[WebrtcPlayer] Pause failed: $e', e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      await _stateController.close();
      _isDisposed = true;
      AppLogger.i('[WebrtcPlayer] Disposed');
    } catch (e) {
      AppLogger.e('[WebrtcPlayer] Dispose error: $e', e);
    }
  }

  /// Get connection quality (for UI feedback)
  Future<String> getConnectionQuality() async {
    return 'Unknown - WebRTC unavailable';
  }
}
