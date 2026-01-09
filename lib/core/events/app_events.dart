import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

/// Small app-wide event bus for simple signals used by UI to refresh data.
class AppEvents {
  AppEvents._();

  static final AppEvents instance = AppEvents._();

  final StreamController<void> _eventsChanged =
      StreamController<void>.broadcast();

  final StreamController<Map<String, dynamic>> _eventUpdated =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<String> _tableChanged =
      StreamController<String>.broadcast();
  final StreamController<void> _notificationReceived =
      StreamController<void>.broadcast();

  final Map<String, DateTime> _lastTableEmit = {};

  final Duration _tableDebounce = const Duration(milliseconds: 1500);

  Stream<void> get eventsChanged => _eventsChanged.stream;

  Stream<Map<String, dynamic>> get eventUpdated => _eventUpdated.stream;

  Stream<String> get tableChanged => _tableChanged.stream;
  Stream<void> get notificationReceived => _notificationReceived.stream;

  void notifyEventsChanged() {
    try {
      _eventsChanged.add(null);
    } catch (_) {}
  }

  void notifyEventUpdated(Map<String, dynamic> event) {
    try {
      _eventUpdated.add(event);
    } catch (_) {}
  }

  void notifyTableChanged(String table) {
    try {
      final now = DateTime.now();
      final last = _lastTableEmit[table];
      if (last != null && now.difference(last) < _tableDebounce) {
        return;
      }
      _lastTableEmit[table] = now;
      _tableChanged.add(table);
      try {
        if (kDebugMode) {
          final st = StackTrace.current;
          AppLogger.d('AppEvents.notifyTableChanged: $table\n${st.toString()}');
        }
      } catch (_) {}
    } catch (_) {}
  }

  void notifyNotificationReceived() {
    try {
      _notificationReceived.add(null);
    } catch (_) {}
  }

  void dispose() {
    try {
      _eventsChanged.close();
      _eventUpdated.close();
      _notificationReceived.close();
    } catch (_) {}
  }
}
