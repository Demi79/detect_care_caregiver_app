import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:flutter/services.dart';

abstract class AudioServiceBase {
  Future<void> play({bool urgent = false, bool loud = false});
  Future<void> stop();
}

class AudioService implements AudioServiceBase {
  AudioService._();

  static AudioServiceBase instance = AudioService._();

  bool _isPlaying = false;
  Timer? _repeatTimer;
  int _repeatRemaining = 0;

  @override
  Future<void> play({bool urgent = false, bool loud = false}) async {
    try {
      AppLogger.i('[AudioService] play called urgent=$urgent');
      AppLogger.d('[AudioService] call stack:\n${StackTrace.current}');
      // Temporary safeguard: do not play non-urgent notification sounds
      // (e.g. for events with status 'normal'). This prevents unexpected
      // notification sounds while we trace remaining callers. Remove this
      // once root cause is fixed.
      if (!urgent && !loud) {
        AppLogger.i('[AudioService] Suppressing non-urgent sound (temporary)');
        return;
      }
      // Ensure any previous playback is stopped before starting a new one.
      try {
        if (_repeatTimer != null) {
          try {
            _repeatTimer?.cancel();
          } catch (_) {}
          _repeatTimer = null;
        }
        _repeatRemaining = 0;
        if (_isPlaying) {
          try {
            FlutterRingtonePlayer().stop();
          } catch (_) {}
        }
      } catch (_) {}

      _isPlaying = true;
      if (loud) {
        // Loud alarm for danger: replay alarm a few times and strong haptics
        _repeatRemaining = 3;
        // Play immediately
        try {
          FlutterRingtonePlayer().playAlarm();
        } catch (_) {}
        try {
          HapticFeedback.vibrate();
          HapticFeedback.heavyImpact();
        } catch (_) {}

        // Schedule repeats every 1500ms
        _repeatTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
          _repeatRemaining -= 1;
          if (_repeatRemaining <= 0) {
            try {
              t.cancel();
            } catch (_) {}
            _repeatTimer = null;
            _isPlaying = false;
            return;
          }
          try {
            FlutterRingtonePlayer().playAlarm();
            HapticFeedback.heavyImpact();
          } catch (_) {}
        });
      } else if (urgent) {
        // For warning-level alerts, play alarm once to ensure audibility
        try {
          FlutterRingtonePlayer().playAlarm();
        } catch (_) {}
      } else {
        // fallback: do nothing
      }
    } catch (e, st) {
      AppLogger.e('AudioService.play error: $e', e, st);
      _isPlaying = false;
    }
  }

  /// Stop any playing sound initiated by this service.
  @override
  Future<void> stop() async {
    try {
      AppLogger.i('[AudioService] stop called (isPlaying=$_isPlaying)');
      // defensively clear timers/flags before calling native stop
      try {
        _repeatTimer?.cancel();
      } catch (_) {}
      _repeatTimer = null;
      _repeatRemaining = 0;
      _isPlaying = false;
      try {
        FlutterRingtonePlayer().stop();
      } catch (_) {}
    } catch (e, st) {
      AppLogger.e('AudioService.stop error: $e', e, st);
    } finally {}
  }
}
