import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_timeline_api.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_parser.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_demo_data.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_components.dart';

class CameraTimelineController extends ChangeNotifier {
  final CameraTimelineApi api;
  final String cameraId;
  DateTime selectedDay;
  List<CameraTimelineClip> clips = const [];
  List<CameraTimelineEntry> entries = const [];
  String? selectedClipId;
  int selectedModeIndex = 1;
  double zoomLevel = 0.4;
  bool isLoading = false;
  String? errorMessage;
  final bool loadFromApi;

  bool _disposed = false;

  CameraTimelineController({
    required this.api,
    required this.cameraId,
    required DateTime initialDay,
    this.loadFromApi = true,
  }) : selectedDay = initialDay {
    // Initialize data
    if (loadFromApi) {
      loadTimeline();
    } else {
      loadDemo();
    }
  }

  Future<void> loadTimeline() async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final dateStr = selectedDay.toIso8601String().split('T').first;
      // Debug: log which camera/date/mode we're loading to help diagnose API issues
      debugPrint(
        '📡 [CameraTimeline] Loading timeline for cameraId=$cameraId date=$dateStr mode=$selectedModeIndex',
      );
      List<CameraTimelineClip> parsed;
      if (selectedModeIndex == 0) {
        final data = await api.listEvents(cameraId, date: dateStr);
        _logPayload('listEvents', data);
        parsed = parseEventClips(data);
      } else if (selectedModeIndex == 2) {
        final data = await api.listSnapshots(cameraId, date: dateStr);
        _logPayload('listSnapshots', data);
        parsed = parseSnapshotClips(data);
      } else {
        final data = await api.listRecordings(
          cameraId,
          date: dateStr,
          limit: 200,
        );
        _logPayload('listRecordings', data);
        parsed = parseRecordingClips(data);
      }
      debugPrint('📡 [CameraTimeline] Parsed clips count=${parsed.length}');
      clips = parsed;
      entries = buildEntries(clips);
      selectedClipId = clips.isNotEmpty ? clips.first.id : null;
      isLoading = false;
      _notify();
    } catch (e, st) {
      AppLogger.e('CameraTimelineController load error', e, st);
      clips = [];
      entries = [];
      isLoading = false;
      errorMessage = 'Không thể tải dữ liệu timeline.';
      _notify();
    }
  }

  void _logPayload(String label, dynamic payload) {
    try {
      if (payload == null) {
        debugPrint('📡 [CameraTimeline] $label -> null payload');
        return;
      }
      // If payload is a Map and contains data.records / records / items, log counts
      if (payload is Map) {
        final keys = payload.keys.join(', ');
        final parts = <String>[];
        payload.forEach((k, v) {
          if (v is List) {
            parts.add('$k(list:${v.length})');
          } else if (v is Map) {
            parts.add('$k(map:${v.keys.length})');
          } else {
            parts.add(k);
          }
        });
        debugPrint(
          '📡 [CameraTimeline] $label -> keys: $keys; summary: ${parts.join(', ')}',
        );
      } else if (payload is List) {
        debugPrint('📡 [CameraTimeline] $label -> list(${payload.length})');
      } else {
        debugPrint('📡 [CameraTimeline] $label -> type=${payload.runtimeType}');
      }

      final preview = jsonEncode(payload);
      if (preview.length > 1500) {
        debugPrint(
          '📡 [CameraTimeline] $label preview: ${preview.substring(0, 1500)}... (truncated)',
        );
      } else {
        debugPrint('📡 [CameraTimeline] $label preview: $preview');
      }
    } catch (e, st) {
      AppLogger.d('Failed to log payload for $label: $e', e, st);
    }
  }

  void loadDemo() {
    final demo = DemoTimelineData.generate(selectedDay);
    clips = demo.clips;
    entries = demo.entries;
    selectedClipId = clips.isNotEmpty ? clips.first.id : null;
    isLoading = false;
    errorMessage = null;
    _notify();
  }

  void changeDay(int offset) {
    selectedDay = selectedDay.add(Duration(days: offset));
    if (loadFromApi) {
      loadTimeline();
    } else {
      loadDemo();
    }
  }

  void changeMode(int index) {
    if (selectedModeIndex == index) return;
    selectedModeIndex = index;
    if (loadFromApi) {
      loadTimeline();
    } else {
      loadDemo();
    }
  }

  void selectClip(String id) {
    selectedClipId = id;
    _notify();
  }

  void adjustZoom(double delta) {
    zoomLevel = (zoomLevel + delta).clamp(0.0, 1.0);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
