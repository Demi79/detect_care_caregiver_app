class CameraSettings {
  final bool isHd;
  final int fps;
  final int retentionDays;
  final Set<String> channels;

  const CameraSettings({
    required this.isHd,
    required this.fps,
    required this.retentionDays,
    required this.channels,
  });

  CameraSettings copyWith({
    bool? isHd,
    int? fps,
    int? retentionDays,
    Set<String>? channels,
  }) {
    return CameraSettings(
      isHd: isHd ?? this.isHd,
      fps: fps ?? this.fps,
      retentionDays: retentionDays ?? this.retentionDays,
      channels: channels ?? this.channels,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isHd': isHd,
      'fps': fps,
      'retentionDays': retentionDays,
      'channels': channels.toList(),
    };
  }

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      isHd: json['isHd'] ?? true,
      fps: json['fps'] ?? 25,
      retentionDays: json['retentionDays'] ?? 7,
      channels: Set<String>.from(json['channels'] ?? ['App']),
    );
  }
}

class CameraState {
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final bool isHd;
  final bool isStarting;
  final bool initLoading;
  final bool controlsVisible;
  final String? currentUrl;
  final String? statusMessage;
  final double? videoAspectRatio;
  final CameraSettings settings;

  const CameraState({
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.isHd,
    required this.isStarting,
    required this.initLoading,
    required this.controlsVisible,
    this.currentUrl,
    this.statusMessage,
    this.videoAspectRatio,
    required this.settings,
  });

  CameraState copyWith({
    bool? isPlaying,
    bool? isMuted,
    bool? isFullscreen,
    bool? isHd,
    bool? isStarting,
    bool? initLoading,
    bool? controlsVisible,
    String? currentUrl,
    String? statusMessage,
    double? videoAspectRatio,
    CameraSettings? settings,
  }) {
    return CameraState(
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isHd: isHd ?? this.isHd,
      isStarting: isStarting ?? this.isStarting,
      initLoading: initLoading ?? this.initLoading,
      controlsVisible: controlsVisible ?? this.controlsVisible,
      currentUrl: currentUrl ?? this.currentUrl,
      statusMessage: statusMessage ?? this.statusMessage,
      videoAspectRatio: videoAspectRatio ?? this.videoAspectRatio,
      settings: settings ?? this.settings,
    );
  }

  factory CameraState.initial() {
    return CameraState(
      isPlaying: false,
      isMuted: false,
      isFullscreen: false,
      isHd: true,
      isStarting: false,
      initLoading: true,
      controlsVisible: true,
      settings: const CameraSettings(
        isHd: true,
        fps: 25,
        retentionDays: 7,
        channels: {'App'},
      ),
    );
  }
}

enum CameraQuality {
  hd,
  sd;

  int get subtype => this == hd ? 0 : 1;
  String get displayName => this == hd ? 'HD' : 'SD';
}

enum PlaybackState { stopped, connecting, playing, paused, error }
