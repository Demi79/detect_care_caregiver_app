import 'package:flutter/material.dart';

class CompletionSuccessIcon extends StatefulWidget {
  final AnimationController animationController;
  final AnimationController successController;

  const CompletionSuccessIcon({
    super.key,
    required this.animationController,
    required this.successController,
  });

  @override
  State<CompletionSuccessIcon> createState() => _CompletionSuccessIconState();
}

class _CompletionSuccessIconState extends State<CompletionSuccessIcon> {
  late Animation<double> _scaleAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.successController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _successAnimation,
        builder: (context, child) {
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981),
                  const Color(0xFF34D399).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ScaleTransition(
              scale: _successAnimation,
              child: const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
