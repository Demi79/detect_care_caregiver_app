/// Camera-related constants and configuration values
class CameraConstants {
  // Preference keys
  static const String kPrefHd = 'camera_hd_pref';
  static const String kPrefFps = 'camera_fps_pref';
  static const String kPrefRetention = 'camera_retention_days';
  static const String kPrefChannels = 'camera_notify_channels';
  static const String kPrefRtspUrl = 'rtsp_url';

  // Default values
  static const int defaultFps = 25;
  static const int defaultRetentionDays = 7;
  static const Set<String> defaultChannels = {'App'};
  static const bool defaultHd = true;

  // UI Constants
  static const Duration statusPollInterval = Duration(seconds: 4);
  static const Duration controlsAutoHideDelay = Duration(seconds: 3);
  static const Duration startDebounceDelay = Duration(milliseconds: 300);
  static const Duration playbackWaitTimeout = Duration(seconds: 8);

  // VLC Options
  static const int networkCaching = 500;
  static const int liveCaching = 300;

  // Quality subtypes
  static const int hdSubtype = 0; // Main stream
  static const int sdSubtype = 1; // Sub stream

  // Constraints
  static const int minFps = 5;
  static const int maxFps = 60;
  static const int minRetentionDays = 1;
  static const int maxRetentionDays = 30;
  static const int maxThumbnailFiles = 50;

  // Messages
  static const String connectingHdMessage = 'Đang kết nối 1080P...';
  static const String connectingMessage = 'Đang kết nối...';
  static const String playingMessage = 'Đang phát';
  static const String pausedMessage = 'Tạm dừng';
  static const String cannotPlayMessage = 'Không thể phát luồng';
  static const String checkUrlMessage = 'Không thể phát luồng. Kiểm tra URL.';
  static const String hdFallbackMessage =
      'Không thể phát 1080P. Chuyển về SD...';
  static const String connectingWaitMessage = 'Đang kết nối, vui lòng đợi...';
  static const String recordNotSupportedMessage = 'Ghi hình chưa hỗ trợ.';
  static const String snapshotNotSupportedMessage = 'Chụp ảnh chưa hỗ trợ.';
}
