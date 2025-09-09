import 'package:flutter/material.dart';

DateTimeRange todayRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return DateTimeRange(start: start, end: start);
}

class HomeFilters {
  static const statusOptions = ['All', 'danger', 'warning', 'normal'];

  static const periodOptions = [
    'All',
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];

  static const String defaultStatus = 'All';
  static const String defaultPeriod = 'All';

  static DateTimeRange get defaultDayRange => todayRange();
}
