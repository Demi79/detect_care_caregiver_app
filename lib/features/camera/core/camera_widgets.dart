import 'package:flutter/material.dart';

/// UI components for camera functionality
class CameraWidgets {
  /// Build the placeholder widget when no camera is connected
  static Widget buildPlaceholder() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: Colors.black.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.videocam_outlined,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Camera chưa được kết nối',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhấn vào để xem camera',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.71),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the fullscreen view container
  static Widget buildFullscreenContainer({
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
  }) {
    return SafeArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape =
                MediaQuery.of(context).orientation == Orientation.landscape;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Giảm margin bên ngoài và dùng padding khiêm tốn hơn để
              // phần tử con (video stack) có thể chiếm gần như toàn bộ
              // diện tích màn hình khi ở fullscreen. Điều này giảm các
              // khoảng đen hai bên khi xoay màn hình trên các thiết bị
              // có tỉ lệ màn hình khác nhau.
              margin: EdgeInsets.zero,
              width: double.infinity,
              height: double.infinity,
              padding: isLandscape
                  ? const EdgeInsets.symmetric(vertical: 8, horizontal: 12)
                  : const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build the normal view container
  static Widget buildNormalContainer({
    required double? aspectRatio,
    required Widget child,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio ?? 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  /// Build the app bar for the camera screen
  static AppBar buildAppBar({
    required BuildContext context,
    required VoidCallback onFullscreenToggle,
    required bool isFullscreen,
  }) {
    return AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF374151),
            size: 18,
          ),
        ),
      ),
      title: const Text(
        'Camera trực tiếp',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  /// Build the main scaffold
  static Scaffold buildScaffold({
    required AppBar appBar,
    required Widget body,
  }) {
    return Scaffold(appBar: appBar, body: body);
  }

  /// Build loading indicator
  static Widget buildLoadingIndicator({String message = 'Đang tải...'}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  /// Build error state
  static Widget buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  /// Build success feedback
  static Widget buildSuccessFeedback({
    required String message,
    VoidCallback? onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (onDismiss != null)
            IconButton(onPressed: onDismiss, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  /// Build connection status
  static Widget buildConnectionStatus({
    required String status,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Text(
          status,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Build camera control panel
  static Widget buildCameraControlPanel({
    required VoidCallback onPlayPause,
    required VoidCallback onRecord,
    required VoidCallback onMute,
    required VoidCallback onScreenshot,
    required VoidCallback onSettings,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: onPlayPause,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
          ),
          IconButton(
            onPressed: onRecord,
            icon: const Icon(Icons.videocam, color: Colors.white),
          ),
          IconButton(
            onPressed: onMute,
            icon: const Icon(Icons.volume_up, color: Colors.white),
          ),
          IconButton(
            onPressed: onScreenshot,
            icon: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Build quality selector
  static Widget buildQualitySelector({
    required ValueChanged<String> onQualityChanged,
    String currentQuality = 'HD',
  }) {
    return DropdownButton<String>(
      value: currentQuality,
      items: ['SD', 'HD', 'FHD'].map((quality) {
        return DropdownMenuItem(value: quality, child: Text(quality));
      }).toList(),
      onChanged: (value) {
        if (value != null) onQualityChanged(value);
      },
    );
  }

  /// Build zoom control
  static Widget buildZoomControl({
    required double currentZoom,
    required ValueChanged<double> onZoomChanged,
    double minZoom = 1.0,
    double maxZoom = 5.0,
  }) {
    return Column(
      children: [
        Text('Zoom: ${currentZoom.toStringAsFixed(1)}x'),
        Slider(
          value: currentZoom,
          min: minZoom,
          max: maxZoom,
          onChanged: onZoomChanged,
        ),
      ],
    );
  }

  /// Build camera info overlay
  static Widget buildCameraInfoOverlay({
    required String cameraName,
    required String status,
    required String quality,
  }) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  quality,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build camera thumbnail grid
  static Widget buildCameraThumbnailGrid({required List<Widget> thumbnails}) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: thumbnails.length,
      itemBuilder: (context, index) => thumbnails[index],
    );
  }

  /// Build multi-camera view
  static Widget buildMultiCameraView({required List<Widget> cameraViews}) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cameraViews.length,
      itemBuilder: (context, index) => cameraViews[index],
    );
  }
}

/// Extension for building camera-specific UI elements
extension CameraWidgetExtensions on BuildContext {
  /// Show a snackbar with camera-related message
  void showCameraMessage(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Build complete camera screen
Widget buildCompleteCameraScreen({
  required BuildContext context,
  required Widget cameraView,
  required VoidCallback onFullscreenToggle,
  VoidCallback? onConnectionTap,
  VoidCallback? onPlayPause,
  VoidCallback? onRecord,
  VoidCallback? onMute,
  VoidCallback? onScreenshot,
  VoidCallback? onSettings,
  bool isFullscreen = false,
}) {
  return Scaffold(
    appBar: CameraWidgets.buildAppBar(
      context: context,
      onFullscreenToggle: onFullscreenToggle,
      isFullscreen: isFullscreen,
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: isFullscreen
              ? CameraWidgets.buildFullscreenContainer(
                  child: cameraView,
                  onTap: onConnectionTap ?? () {},
                  onDoubleTap: onFullscreenToggle,
                )
              : CameraWidgets.buildNormalContainer(
                  aspectRatio: 16 / 9,
                  child: cameraView,
                ),
        ),
        if (onConnectionTap != null)
          Positioned(
            top: 16,
            right: 16,
            child: CameraWidgets.buildConnectionStatus(
              status: 'Connected',
              onTap: onConnectionTap,
            ),
          ),
        if (onPlayPause != null &&
            onRecord != null &&
            onMute != null &&
            onScreenshot != null &&
            onSettings != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: CameraWidgets.buildCameraControlPanel(
              onPlayPause: onPlayPause,
              onRecord: onRecord,
              onMute: onMute,
              onScreenshot: onScreenshot,
              onSettings: onSettings,
            ),
          ),
      ],
    ),
  );
}

/// Build camera loading screen
Widget buildCameraLoadingScreen() {
  return Scaffold(
    body: Container(
      color: Colors.black,
      child: CameraWidgets.buildLoadingIndicator(
        message: 'Đang kết nối camera...',
      ),
    ),
  );
}

/// Build camera error screen
Widget buildCameraErrorScreen({required VoidCallback onRetry}) {
  return Scaffold(
    body: Container(
      color: Colors.black,
      child: CameraWidgets.buildErrorState(
        message: 'Không thể kết nối camera. Vui lòng kiểm tra URL và thử lại.',
        onRetry: onRetry,
      ),
    ),
  );
}
