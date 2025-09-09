import 'package:flutter/widgets.dart';

class AppLifecycle {
  static bool isForeground = true;
  static AppLifecycleListener? _listener;

  static void init() {
    _listener ??= AppLifecycleListener(
      onStateChange: (state) {
        isForeground = state == AppLifecycleState.resumed;
      },
    );
  }
}
