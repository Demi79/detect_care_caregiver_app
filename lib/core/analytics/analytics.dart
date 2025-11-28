import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class Analytics {
  Analytics._();
  static void logEvent(String name, [Map<String, dynamic>? params]) {
    try {
      AppLogger.i(
        '[ANALYTICS] $name ${params != null ? params.toString() : ''}',
      );
    } catch (_) {}
  }
}
