import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get flavor => dotenv.env['FLAVOR'] ?? 'development';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseKey => dotenv.env['SUPABASE_KEY'] ?? '';

  static String? get logsUrl => dotenv.env['LOGS_URL'];

  static bool get useCustomNotificationSounds =>
      (dotenv.env['USE_CUSTOM_NOTIFICATION_SOUNDS'] ?? 'false').toLowerCase() ==
      'true';

  static bool get logHttpRequests {
    final v = (dotenv.env['HTTP_DEBUG'] ?? '').toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
    return flavor.toLowerCase() != 'production';
  }

  /// Alarm control endpoint.
  static String get alarmControlUrl =>
      dotenv.env['ALARM_CONTROL_URL'] ??
      'https://alarm.cicca.dpdns.org/api/alarm/control';

  /// Alarm status endpoint.
  static String get alarmStatusUrl =>
      dotenv.env['ALARM_STATUS_URL'] ??
      'https://alarm.cicca.dpdns.org/api/alarm/status';
}
