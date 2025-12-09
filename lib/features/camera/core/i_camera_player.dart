import 'package:flutter/material.dart';

/// Abstract interface for camera player implementations
/// Supports multiple protocols: RTSP, HLS, MP4, WebRTC
abstract class ICameraPlayer {
  /// Initialize the player with configuration
  Future<void> initialize();

  /// Build the video widget for display
  Widget buildView();

  /// Play the stream
  Future<void> play();

  /// Pause the stream
  Future<void> pause();

  /// Dispose resources
  Future<void> dispose();

  /// Get current stream URL
  String get streamUrl;

  /// Get protocol type (rtsp, hls, mp4, webrtc)
  String get protocol;

  Future<String?> takeSnapshot();
}
