import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/features/alarm/data/alarm_status.dart';

class ActiveAlarmNotifier extends ValueNotifier<bool> {
  ActiveAlarmNotifier._() : super(false);

  static final instance = ActiveAlarmNotifier._();

  AlarmStatus? _lastStatus;

  AlarmStatus? get lastStatus => _lastStatus;

  bool get active => value;

  void update(bool isActive) {
    if (value == isActive) return;
    value = isActive;
  }

  void updateFromStatus(AlarmStatus status) {
    _lastStatus = status;
    if (value != status.isPlaying) {
      value = status.isPlaying;
    } else {
      notifyListeners();
    }
  }
}
