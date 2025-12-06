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
  final Future<void> Function()? onCancelAlarm;
  final bool initialAlarmActive;

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
    this.onCancelAlarm,
    this.initialAlarmActive = false,
  });

  @override
  State<CameraControlsOverlay> createState() => _CameraControlsOverlayState();
}

class _CameraControlsOverlayState extends State<CameraControlsOverlay>
    with TickerProviderStateMixin {
  bool _alarmRunning = false;
  bool _emergencyRunning = false;
  bool _alarmActive = false;
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
    _alarmActive = widget.initialAlarmActive;
    _fadeController.forward();
  }

  Widget _buildLargeActionRow(bool compact) {
    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLargeActionButton(
            icon: Icons.warning_amber_rounded,
            label: _alarmRunning ? 'Đang...' : 'CHỤP ẢNH & BÁO ĐỘNG',
            background: const LinearGradient(
              colors: [Color(0xFFFF7043), Color(0xFFEF5350)],
            ),
            onTap: () async => _handleAlarm(),
            loading: _alarmRunning,
          ),
          _buildLargeActionButton(
            icon: Icons.phone_in_talk_rounded,
            label: _emergencyRunning ? 'Đang...' : 'GỌI KHẨN CẤP',
            background: const LinearGradient(
              colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
            ),
            onTap: () async => _handleEmergency(),
            loading: _emergencyRunning,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLargeActionButton(
          icon: Icons.warning_amber_rounded,
          label: _alarmRunning ? 'Đang...' : 'CHỤP ẢNH & BÁO ĐỘNG',
          background: const LinearGradient(
            colors: [Color(0xFFFF7043), Color(0xFFEF5350)],
          ),
          onTap: () async => _handleAlarm(),
          loading: _alarmRunning,
        ),
        const SizedBox(width: 8),
        _buildLargeActionButton(
          icon: Icons.phone_in_talk_rounded,
          label: _emergencyRunning ? 'Đang...' : 'GỌI KHẨN CẤP',
          background: const LinearGradient(
            colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
          ),
          onTap: () async => _handleEmergency(),
          loading: _emergencyRunning,
        ),
      ],
    );
  }

  Future<void> _handleAlarm() async {
    if (_alarmRunning || widget.onAlarm == null) return;
    setState(() => _alarmRunning = true);
    try {
      await _doPressAnimation();
      await widget.onAlarm!();
      if (mounted) setState(() => _alarmActive = true);
    } finally {
      if (mounted) setState(() => _alarmRunning = false);
    }
  }

  Future<void> _handleEmergency() async {
    if (_emergencyRunning) return;
    setState(() => _emergencyRunning = true);
    try {
      await _doPressAnimation();
      if (widget.onEmergency != null) await widget.onEmergency!();
    } finally {
      if (mounted) setState(() => _emergencyRunning = false);
    }
  }

  Widget _buildLargeActionButton({
    required IconData icon,
    required String label,
    required LinearGradient background,
    required Future<void> Function() onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 160,
          minHeight: 44,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: background,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: background.colors.last.withOpacity(0.4),
              blurRadius: 14,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                fontSize: 12,
              ),
            ),
            if (loading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

                      final primaryControls = <Widget>[
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
                        // _buildControlButton(
                        //   icon: _emergencyRunning
                        //       ? Icons.hourglass_top
                        //       : Icons.phone_in_talk_rounded,
                        //   label: _emergencyRunning ? 'Đang...' : 'GỌI KHẨN CẤP',
                        //   onTap: () async {
                        //     if (_emergencyRunning) return;
                        //     setState(() => _emergencyRunning = true);
                        //     try {
                        //       await _doPressAnimation();
                        //       if (widget.onEmergency != null) {
                        //         await widget.onEmergency!();
                        //       }
                        //     } finally {
                        //       if (mounted)
                        //         setState(() => _emergencyRunning = false);
                        //     }
                        //   },
                        //   color: Colors.orangeAccent,
                        //   size: 20,
                        //   showLabel: !compact,
                        // ),
                      ];

                      final actionRow = _alarmActive
                          ? _buildActiveAlarmRow(compact)
                          : _buildLargeActionRow(compact);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildWithDividers(primaryControls),
                          const SizedBox(height: 8),
                          actionRow,
                        ],
                      );
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

  Widget _buildActiveAlarmRow(bool compact) {
    final buttons = [
      _buildControlButton(
        icon: Icons.cancel_outlined,
        label: 'HỦY BÁO ĐỘNG',
        onTap: () async {
          if (widget.onCancelAlarm == null) return;
          try {
            await _doPressAnimation();
            await widget.onCancelAlarm!();
            if (mounted) setState(() => _alarmActive = false);
          } catch (_) {}
        },
        color: Colors.white,
        size: 20,
        showLabel: !compact,
      ),
      _buildControlButton(
        icon: _emergencyRunning
            ? Icons.hourglass_top
            : Icons.phone_in_talk_rounded,
        label: _emergencyRunning ? 'Đang...' : 'GỌI KHẨN CẤP',
        onTap: () async {
          if (_emergencyRunning) return;
          setState(() => _emergencyRunning = true);
          try {
            await _doPressAnimation();
            if (widget.onEmergency != null) {
              await widget.onEmergency!();
            }
          } finally {
            if (mounted) setState(() => _emergencyRunning = false);
          }
        },
        color: Colors.orangeAccent,
        size: 20,
        showLabel: !compact,
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: buttons,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [buttons[0], const SizedBox(width: 8), buttons[1]],
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
