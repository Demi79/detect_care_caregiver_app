import 'dart:ui';

import 'package:flutter/material.dart';

class CameraControlsOverlay extends StatefulWidget {
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;
  final VoidCallback onReload;
  final VoidCallback onRecord;
  final VoidCallback onSnapshot;
  final Future<void> Function()? onAlarm;
  final Future<void> Function()? onEmergency;

  const CameraControlsOverlay({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onMute,
    required this.onFullscreen,
    required this.onReload,
    required this.onRecord,
    required this.onSnapshot,
    this.onAlarm,
    this.onEmergency,
  });

  @override
  State<CameraControlsOverlay> createState() => _CameraControlsOverlayState();
}

class _CameraControlsOverlayState extends State<CameraControlsOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _fadeAnim = Tween(
    begin: 0.0,
    end: 1.0,
  ).animate(CurveTween(curve: Curves.easeOut).animate(_fadeController));

  @override
  void initState() {
    super.initState();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _doPressAnimation() async {
    try {
      await _pressController.forward();
      await _pressController.reverse();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: widget.isFullscreen
              ? const EdgeInsets.fromLTRB(12, 12, 12, 28)
              : const EdgeInsets.all(12),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            // Khi fullscreen + landscape, thêm padding phía dưới để đẩy
            // controls lên tránh va chạm với bottom nav của ứng dụng.
            // Padding này được animate để chuyển cảnh mượt hơn khi xoay
            // màn hình hoặc đổi trạng thái fullscreen.
            padding:
                (widget.isFullscreen &&
                    MediaQuery.of(context).orientation == Orientation.landscape)
                ? const EdgeInsets.only(bottom: 36)
                : EdgeInsets.zero,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.black.withAlpha(140),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(60), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 24,
                    spreadRadius: 3,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withAlpha(20),
                    blurRadius: 2,
                    spreadRadius: 0,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          !widget.isFullscreen && constraints.maxWidth < 420;

                      Widget buildWithDividers(List<Widget> controls) {
                        if (compact) {
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: controls,
                          );
                        }

                        final items = <Widget>[];
                        for (var i = 0; i < controls.length; i++) {
                          if (i > 0) items.add(_buildDivider());
                          items.add(controls[i]);
                        }
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: items,
                        );
                      }

                      final controls = <Widget>[
                        _buildControlButton(
                          icon: widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: widget.isPlaying ? 'Tạm dừng' : 'Phát',
                          onTap: () async {
                            await _doPressAnimation();
                            widget.onPlayPause();
                          },
                          color: Colors.white,
                          size: 28,
                          showLabel: !compact,
                        ),
                        _buildControlButton(
                          icon: widget.isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: widget.isMuted ? 'Bật tiếng' : 'Tắt tiếng',
                          onTap: widget.onMute,
                          color: Colors.white,
                          size: 24,
                          showLabel: !compact,
                        ),
                        _buildControlButton(
                          icon: widget.isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          label: widget.isFullscreen
                              ? 'Thoát'
                              : 'Toàn màn hình',
                          onTap: widget.onFullscreen,
                          color: Colors.blueAccent,
                          size: 24,
                          showLabel: !compact,
                        ),
                        _buildControlButton(
                          icon: Icons.refresh_rounded,
                          label: 'Tải lại',
                          onTap: () async {
                            await _doPressAnimation();
                            widget.onReload();
                          },
                          color: Colors.white,
                          size: 22,
                          showLabel: !compact,
                        ),
                        _buildControlButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'Chụp & Báo động',
                          onTap: () async {
                            await _doPressAnimation();
                            if (widget.onAlarm != null) await widget.onAlarm!();
                          },
                          color: Colors.redAccent,
                          size: 20,
                          showLabel: !compact,
                        ),
                        _buildControlButton(
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Gọi khẩn cấp',
                          onTap: () async {
                            await _doPressAnimation();
                            if (widget.onEmergency != null) {
                              await widget.onEmergency!();
                            }
                          },
                          color: Colors.orangeAccent,
                          size: 20,
                          showLabel: !compact,
                        ),
                      ];

                      return buildWithDividers(controls);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required double size,
    bool showLabel = true,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withAlpha(60),
          highlightColor: color.withAlpha(30),
          child: AnimatedBuilder(
            animation: _pressController,
            builder: (context, child) {
              final scale = 1.0 - (_pressController.value * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(15),
                        Colors.white.withAlpha(5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: color,
                        size: size,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      if (showLabel) const SizedBox(height: 6),
                      if (showLabel)
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.0,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(60),
        borderRadius: BorderRadius.circular(0.5),
      ),
    );
  }
}
