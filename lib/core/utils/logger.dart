import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void payment(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.i('[PAYMENT] $message', error: error, stackTrace: stackTrace);
  }

  static void paymentError(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.e('[PAYMENT] $message', error: error, stackTrace: stackTrace);
  }

  static void paymentSuccess(dynamic message) {
    _logger.i('[PAYMENT] ✅ $message');
  }

  static void api(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d('[API] $message', error: error, stackTrace: stackTrace);
  }

  static void apiError(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.e('[API] $message', error: error, stackTrace: stackTrace);
  }

  static void fcm(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d('[FCM] $message', error: error, stackTrace: stackTrace);
  }

  static void fcmError(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.e('[FCM] $message', error: error, stackTrace: stackTrace);
  }
}
