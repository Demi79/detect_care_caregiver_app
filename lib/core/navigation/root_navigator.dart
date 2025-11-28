import 'package:flutter/widgets.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void navigateToLoginAndClearStack() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {}
  });
}
