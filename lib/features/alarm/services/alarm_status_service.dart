import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_status.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';

class AlarmStatusService {
  AlarmStatusService._({AlarmRemoteDataSource? remote})
    : _remote = remote ?? AlarmRemoteDataSource();

  static final AlarmStatusService instance = AlarmStatusService._();

  final AlarmRemoteDataSource _remote;
  final ValueNotifier<AlarmStatus?> statusNotifier = ValueNotifier(null);

  Timer? _timer;
  Duration _interval = const Duration(seconds: 10);
  bool _fetching = false;
  AlarmStatus? _lastStatus;

  AlarmStatus? get lastStatus => _lastStatus;

  void startPolling({Duration? interval}) {
    if (interval != null) {
      _interval = interval;
    }
    if (_timer == null) {
      _timer = Timer.periodic(_interval, (_) => unawaited(refreshStatus()));
    }
    unawaited(refreshStatus());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<AlarmStatus?> refreshStatus() async {
    if (_fetching) return _lastStatus;
    _fetching = true;
    try {
      final status = await _remote.getStatus();
      _lastStatus = status;
      statusNotifier.value = status;
      ActiveAlarmNotifier.instance.updateFromStatus(status);
      return status;
    } catch (e) {
      return _lastStatus;
    } finally {
      _fetching = false;
    }
  }
}
