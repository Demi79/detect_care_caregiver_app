import 'package:flutter/material.dart';

class QualityBadge extends StatefulWidget {
  final bool isHd;
  final VoidCallback onTap;
  const QualityBadge({super.key, required this.isHd, required this.onTap});

  @override
  State<QualityBadge> createState() => _QualityBadgeState();
}

class _QualityBadgeState extends State<QualityBadge>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -0.08),
    end: Offset.zero,
  ).animate(CurveTween(curve: Curves.easeOut).animate(_ctrl));

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scaleAnim = Tween(
    begin: 1.0,
    end: 1.08,
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_pressController);

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pressController.dispose();
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
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _ctrl,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: InkWell(
            onTap: () async {
              await _doPressAnimation();
              widget.onTap();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isHd
                      ? [
                          Colors.greenAccent.shade400.withAlpha(200),
                          Colors.greenAccent.shade700.withAlpha(200),
                        ]
                      : [
                          Colors.orangeAccent.shade400.withAlpha(200),
                          Colors.orangeAccent.shade700.withAlpha(200),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(60), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: widget.isHd
                        ? Colors.greenAccent.shade400.withAlpha(100)
                        : Colors.orangeAccent.shade400.withAlpha(100),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isHd ? Icons.high_quality_rounded : Icons.sd_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isHd ? 'HD 1080P' : 'SD 720P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withAlpha(180),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
