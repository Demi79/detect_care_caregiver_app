import 'dart:async';

import 'package:flutter/material.dart';
import '../../main.dart';

void showOverlayToast(
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final navigatorState = NavigatorKey.navigatorKey.currentState;
  if (navigatorState == null) return;
  final ctx = navigatorState.context;
  final overlayState = Overlay.of(ctx);

  final entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        bottom: 56,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    },
  );

  overlayState.insert(entry);

  Timer(duration, () {
    try {
      entry.remove();
    } catch (_) {}
  });
}
