import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  RealtimeChannel? _realtimeChannel;
  DateTime? _lastRealtimeReload;
  static const int _kRealtimeThrottleMs = 1000;
  static const int _kPreviewMax = 1500;

  CameraTimelineController({
    required this.api,
    required this.cameraId,
    required DateTime initialDay,
    this.loadFromApi = true,
  }) : selectedDay = initialDay {
    // Initialize data
    if (loadFromApi) {
      loadTimeline();
      // subscribe to realtime updates for this camera so timeline refreshes
      _setupRealtime();
    } else {
      loadDemo();
    }
  }

  void _setupRealtime() {
    try {
      final supabase = Supabase.instance.client;
      _realtimeChannel = supabase.channel('camera_timeline_$cameraId');
      // Subscribe to inserts/updates/deletes so timeline reflects new data quickly.
      _realtimeChannel =
          _realtimeChannel!
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'event_detections',
                callback: (payload) async => _handleRealtimePayload(payload),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'event_detections',
                callback: (payload) async => _handleRealtimePayload(payload),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'event_detections',
                callback: (payload) async => _handleRealtimePayload(payload),
              )
            ..subscribe();
    } catch (e, st) {
      AppLogger.w(
        'Failed to subscribe realtime for camera timeline: $e',
        e,
        st,
      );
    }
  }

  Future<void> _handleRealtimePayload(PostgresChangePayload payload) async {
    try {
      // Prefer newRecord (insert/update). For deletes, newRecord may be empty; fallback to oldRecord.
      final dynamic newRec = payload.newRecord;
      final dynamic oldRec = payload.oldRecord;
      Map<String, dynamic> rowMap = {};
      if (newRec is Map && newRec.isNotEmpty) {
        rowMap = Map<String, dynamic>.fromEntries(
          newRec.entries.map((e) => MapEntry(e.key.toString(), e.value)),
        );
      } else if (oldRec is Map && oldRec.isNotEmpty) {
        rowMap = Map<String, dynamic>.fromEntries(
          oldRec.entries.map((e) => MapEntry(e.key.toString(), e.value)),
        );
      }
      if (rowMap.isEmpty) return;

      // Attempt to detect camera id from row (support multiple field names)
      final cam =
          (rowMap['camera_id'] ?? rowMap['camera'] ?? rowMap['cameraId'])
              ?.toString();
      if (cam == null || cam.isEmpty) return;
      if (cam != cameraId) return;

      // Parse detectedAt/created_at and compare day with selectedDay when available
      final da =
          rowMap['detected_at'] ??
          rowMap['detectedAt'] ??
          rowMap['created_at'] ??
          rowMap['createdAt'];
      final DateTime? detectedAt = _parseTimestamp(da);

      final now = DateTime.now();
      // Throttle reloads: avoid reloading more than once every 1 second
      if (_lastRealtimeReload != null &&
          now.difference(_lastRealtimeReload!).inMilliseconds <
              _kRealtimeThrottleMs) {
        return;
      }

      if (detectedAt != null) {
        final sel = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
        );
        final detLocal = detectedAt.toLocal();
        final detDay = DateTime(detLocal.year, detLocal.month, detLocal.day);
        if (sel != detDay) return;
      }

      _lastRealtimeReload = now;
      // Trigger reload asynchronously
      Future.microtask(() => loadTimeline());
    } catch (e, st) {
      AppLogger.e('Realtime timeline processing error', e, st);
    }
  }

  Future<void> loadTimeline() async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final dateStr = selectedDay.toIso8601String().split('T').first;
      // Debug: log which camera/date/mode we're loading to help diagnose API issues
      AppLogger.api(
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
        final data = await api.listRecordings(cameraId, date: dateStr);
        _logPayload('listRecordings', data);
        parsed = parseRecordingClips(data);
      }
      final filtered = _clipsWithThumbnails(parsed);
      AppLogger.api(
        '📡 [CameraTimeline] Parsed clips count=${parsed.length} '
        '(${filtered.length} with thumbnails)',
      );
      clips = filtered;
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
        AppLogger.api('📡 [CameraTimeline] $label -> null payload');
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
            parts.add(k.toString());
          }
        });
        AppLogger.api(
          '📡 [CameraTimeline] $label -> keys: $keys; summary: ${parts.join(', ')}',
        );
      }

      final preview = _previewForPayload(payload);
      if (preview.isNotEmpty) {
        AppLogger.api('📡 [CameraTimeline] $label preview: $preview');
      }
    } catch (e, st) {
      AppLogger.d('Failed to log payload for $label: $e', e, st);
    }
  }

  DateTime? _parseTimestamp(dynamic da) {
    if (da == null) return null;
    try {
      if (da is String) return DateTime.tryParse(da);
      if (da is int || da is double) {
        final numVal = da is int ? da : (da as double).toInt();
        if (numVal > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(numVal);
        }
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
      }
      return DateTime.tryParse(da.toString());
    } catch (_) {
      return null;
    }
  }

  List<CameraTimelineClip> _clipsWithThumbnails(
    List<CameraTimelineClip> clips,
  ) {
    return clips
        .where((clip) => clip.thumbnailUrl?.trim().isNotEmpty == true)
        .toList();
  }

  String _previewForPayload(dynamic payload) {
    try {
      if (payload == null) return '';
      if (payload is Map) {
        if (payload.length > 10) {
          final short = <String>[];
          int i = 0;
          for (final k in payload.keys) {
            if (i++ >= 10) break;
            final v = payload[k];
            if (v is List) {
              short.add('$k:list(${v.length})');
            } else if (v is Map) {
              short.add('$k:map(${v.keys.length})');
            } else {
              short.add('$k:${v.toString()}');
            }
          }
          final preview = '{${short.join(', ')}}';
          return preview.length > _kPreviewMax
              ? '${preview.substring(0, _kPreviewMax)}... (truncated)'
              : preview;
        }
        final full = jsonEncode(payload);
        return full.length > _kPreviewMax
            ? '${full.substring(0, _kPreviewMax)}... (truncated)'
            : full;
      }
      if (payload is List) {
        if (payload.length <= 20) return jsonEncode(payload);
        return 'list(${payload.length})';
      }
      final s = payload.toString();
      return s.length > _kPreviewMax
          ? '${s.substring(0, _kPreviewMax)}... (truncated)'
          : s;
    } catch (_) {
      return '';
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
    zoomLevel = (zoomLevel + delta).clamp(0.0, 1.0).toDouble();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    } catch (_) {}
    super.dispose();
  }
}
