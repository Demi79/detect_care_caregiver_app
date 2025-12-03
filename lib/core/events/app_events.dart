import 'dart:async';

class AppEvents {
  AppEvents._();

  static final AppEvents instance = AppEvents._();

  final StreamController<void> _eventsChanged =
      StreamController<void>.broadcast();

  final StreamController<Map<String, dynamic>> _eventUpdated =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<void> get eventsChanged => _eventsChanged.stream;

  Stream<Map<String, dynamic>> get eventUpdated => _eventUpdated.stream;

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

  void dispose() {
    try {
      _eventsChanged.close();
      _eventUpdated.close();
    } catch (_) {}
  }
}
