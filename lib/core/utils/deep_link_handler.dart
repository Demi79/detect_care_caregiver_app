import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/home/screens/event_detail_screen.dart';
import 'package:detect_care_caregiver_app/main.dart' show NavigatorKey;
import 'package:flutter/material.dart';

class DeepLinkHandler {
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _sub;

  static Future<void> initialize() async {
    AppLogger.d('Initializing DeepLinkHandler (event-only)');
  }

  static Future<void> start() async {
    _appLinks ??= AppLinks();

    // final initial = await _appLinks!.getInitialLink();
    // if (initial != null) {
    //   await _handle(initial);
    // }

    _sub ??= _appLinks!.uriLinkStream.listen(
      (uri) async => await _handle(uri),
      onError: (e) {
        AppLogger.e('DeepLink error: $e');
      },
    );
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<void> _handle(Uri uri) async {
    try {
      AppLogger.d('Received deep link: $uri');

      if (uri.scheme == 'detectcare' && uri.host == 'event') {
        final id = (uri.pathSegments.isNotEmpty)
            ? uri.pathSegments.last
            : uri.path.replaceFirst('/', '');
        if (id.isNotEmpty) {
          NavigatorKey.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Error handling deep link: $e');
    }
  }
}
