import 'dart:async';

class AppEvents {
  AppEvents._();

  static final AppEvents instance = AppEvents._();

  final StreamController<void> _eventsChanged =
      StreamController<void>.broadcast();

  Stream<void> get eventsChanged => _eventsChanged.stream;

  void notifyEventsChanged() {
    try {
      _eventsChanged.add(null);
    } catch (_) {}
  }

  void dispose() {
    try {
      _eventsChanged.close();
    } catch (_) {}
  }
}
