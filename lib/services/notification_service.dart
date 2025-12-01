import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import './alert_settings_manager.dart';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _instance =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'alert_channel';
  static const String _soundResource = 'warning';

  static FlutterLocalNotificationsPlugin get instance => _instance;

  static Future<void> show(
    String? title,
    String? body, {
    bool urgent = false,
    String severity = 'info',
  }) async {
    AppLogger.i(
      '[NotificationService] show called urgent=$urgent severity=$severity',
    );
    AppLogger.d('[NotificationService] call stack:\n${StackTrace.current}');

    final shouldShow = AlertSettingsManager.instance.settings.shouldShowPush(
      severity,
    );
    if (!shouldShow) {
      AppLogger.i('Notification suppressed by settings for severity=$severity');
      return;
    }

    try {
      final bigPicture = await _loadAssetBytes('assets/notification_icon.png');

      final android = AndroidNotificationDetails(
        channelId,
        'Alerts',
        channelDescription: 'Important system alerts',
        importance: urgent ? Importance.max : Importance.defaultImportance,
        priority: urgent ? Priority.high : Priority.defaultPriority,
        largeIcon: bigPicture != null
            ? ByteArrayAndroidBitmap(bigPicture)
            : null,
        sound: AppConfig.useCustomNotificationSounds
            ? RawResourceAndroidNotificationSound(_soundResource)
            : null,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      );

      final iOS = DarwinNotificationDetails(
        sound: AppConfig.useCustomNotificationSounds ? 'warning.mp3' : null,
      );

      final detail = NotificationDetails(android: android, iOS: iOS);

      final soundName = AppConfig.useCustomNotificationSounds
          ? _soundResource
          : 'default';
      AppLogger.i(
        '[NotificationService] Prepared notification: sound=$soundName urgent=$urgent',
      );
      AppLogger.d(
        '[NotificationService] NotificationDetails: android=$android iOS=$iOS',
      );

      AppLogger.i('[NotificationService] Calling local notifications .show()');
      await _instance.show(0, title, body, detail, payload: null);
      AppLogger.i(
        '[NotificationService] Local notifications .show() completed',
      );
    } catch (e) {
      AppLogger.e('Failed to show notification: $e', e);
    }
  }

  static Future<Uint8List?> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
