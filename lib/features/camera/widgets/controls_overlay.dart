import 'package:flutter/material.dart';

class CameraControlsOverlay extends StatelessWidget {
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;
  final VoidCallback onRecord;
  final VoidCallback onSnapshot;

  const CameraControlsOverlay({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onMute,
    required this.onFullscreen,
    required this.onRecord,
    required this.onSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _roundBtn(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              onTap: onPlayPause,
            ),
            const SizedBox(width: 16),
            _roundBtn(
              icon: isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: onMute,
            ),
            const SizedBox(width: 16),
            _roundBtn(icon: Icons.fiber_manual_record, onTap: onRecord),
            const SizedBox(width: 16),
            _roundBtn(icon: Icons.photo_camera_outlined, onTap: onSnapshot),
            const SizedBox(width: 16),
            _roundBtn(
              icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              onTap: onFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onTap}) {
    return ClipOval(
      child: Material(
        color: Colors.white24,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
