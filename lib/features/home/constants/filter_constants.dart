import 'package:flutter/material.dart';

DateTimeRange todayRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return DateTimeRange(start: start, end: start);
}

class HomeFilters {
  static const statusOptions = [
    'all',
    'abnormal',
    'danger',
    'warning',
    'normal',
  ];

  static const periodOptions = ['all', '00-06', '06-12', '12-18', '18-24'];

  static const String defaultStatus = 'abnormal';
  static const String defaultPeriod = 'all';

  static DateTimeRange get defaultDayRange => todayRange();
}
