import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import '../ui/in_app_alert.dart';
import '../utils/app_lifecycle.dart';

class AlertCoordinator {
  static final _shownAt = HashMap<String, DateTime>();

  static void handle(LogEntry? e) {
    if (e == null) return;

    if (e.eventId.trim().isEmpty) {
      print('⚠️ AlertCoordinator: skipping event with empty eventId');
      return;
    }
    if ((e is EventLog) && e.eventType.trim().isEmpty) {
      print(
        '⚠️ AlertCoordinator: skipping event with empty eventType (id=${e.eventId})',
      );
      return;
    }

    if (_isDuplicate(e.eventId)) return;

    if (AppLifecycle.isForeground) {
      print('\n🔎 AlertCoordinator handling EventLog:');
      try {
        print(e.toString());
      } catch (_) {}
      InAppAlert.show(e);
      return;
    }
  }

  static bool _isDuplicate(String id) {
    if (id.isEmpty) return false;
    final now = DateTime.now();
    _shownAt.removeWhere((_, t) => now.difference(t).inMinutes >= 2);
    final seen = _shownAt.containsKey(id);
    if (!seen) _shownAt[id] = now;
    return seen;
  }

  static LogEntry? fromData(Map<String, dynamic> data) {
    final isSystemEvent = data['type'] == 'system_event';

    if (isSystemEvent) {
      // Convert system event data to EventLog
      return EventLog.fromJson(data);
    }
    // For actor messages, return null to skip showing alert
    return null;
  }

  static void handleDeeplink(String deeplink) {
    print('🔗 Deeplink received: $deeplink');
  }
}
