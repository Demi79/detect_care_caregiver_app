import 'package:flutter/material.dart';

class ActiveAlarmNotifier extends ValueNotifier<bool> {
  ActiveAlarmNotifier._() : super(false);

  static final instance = ActiveAlarmNotifier._();

  bool get active => value;

  void update(bool isActive) {
    if (value == isActive) return;
    value = isActive;
  }
}
