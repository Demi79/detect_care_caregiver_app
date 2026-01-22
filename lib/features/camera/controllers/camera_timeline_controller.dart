import 'dart:convert';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_timeline_api.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_demo_data.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_parser.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/timeline_models.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/timeline_utils.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CameraTimelineController extends ChangeNotifier {
  static const String _kTimelineTimezone = 'Asia/Ho_Chi_Minh';
  final CameraTimelineApi api;
  final String cameraId;
  DateTime selectedDay;
  List<CameraTimelineClip> clips = const [];
  List<CameraTimelineEntry> entries = const [];
  String? selectedTimelineEntryId;
  String? selectedEventId;
  int _selectionToken = 0;
  int _loadToken = 0;
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
    // Initialize data after the first frame to avoid triggering layout
    // invalidations while the widget tree is still under construction.
    if (loadFromApi) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        loadTimeline();
        _setupRealtime();
      });
    } else {
      Future.microtask(loadDemo);
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
                callback: (payload) async {
                  AppLogger.d('[Realtime] event_detections payload received');
                  await _handleRealtimePayload(payload);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'event_detections',
                callback: (payload) async {
                  AppLogger.d(
                    '[Realtime] event_detections update payload received',
                  );
                  await _handleRealtimePayload(payload);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'event_detections',
                callback: (payload) async {
                  AppLogger.d(
                    '[Realtime] event_detections delete payload received',
                  );
                  await _handleRealtimePayload(payload);
                },
              )
              // Also listen to the `events` table which some backends write to
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'events',
                callback: (payload) async {
                  AppLogger.d('[Realtime] events insert payload received');
                  await _handleRealtimePayload(payload);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'events',
                callback: (payload) async {
                  AppLogger.d('[Realtime] events update payload received');
                  await _handleRealtimePayload(payload);
                },
              )
              // And snapshots table (if present)
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'snapshots',
                callback: (payload) async {
                  AppLogger.d('[Realtime] snapshots insert payload received');
                  await _handleRealtimePayload(payload);
                },
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
      // Prefer new record (insert/update) and fall back to old record (delete).
      if (newRec is Map && newRec.isNotEmpty) {
        try {
          rowMap = Map<String, dynamic>.from(newRec.cast<String, dynamic>());
        } catch (_) {
          // Fallback to safe conversion when keys are not String typed.
          rowMap = Map<String, dynamic>.fromEntries(
            newRec.entries.map((e) => MapEntry(e.key.toString(), e.value)),
          );
        }
      } else if (oldRec is Map && oldRec.isNotEmpty) {
        try {
          rowMap = Map<String, dynamic>.from(oldRec.cast<String, dynamic>());
        } catch (_) {
          rowMap = Map<String, dynamic>.fromEntries(
            oldRec.entries.map((e) => MapEntry(e.key.toString(), e.value)),
          );
        }
      }
      if (rowMap.isEmpty) return;

      // Attempt to detect camera id from row (support multiple field names)
      final cam =
          (rowMap['camera_id'] ?? rowMap['camera'] ?? rowMap['cameraId'])
              ?.toString();
      if (cam == null || cam.isEmpty) return;
      if (cam != cameraId) return;

      // Only reload realtime when viewing events or snapshots modes
      // (mode 0 = events, mode 2 = snapshots). Avoid noisy reloads for recordings.
      if (selectedModeIndex != 0 && selectedModeIndex != 2) return;

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
    final token = ++_loadToken;
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final dateStr = _formatLocalDate(selectedDay);
      // Debug: log which camera/date/mode we're loading to help diagnose API issues
      AppLogger.api(
        '📡 [CameraTimeline] Loading timeline for cameraId=$cameraId date=$dateStr tz=$_kTimelineTimezone mode=$selectedModeIndex',
      );
      late final List<CameraTimelineClip> parsed;
      if (selectedModeIndex == 0) {
        final data = await api.listEvents(
          cameraId,
          date: dateStr,
          tz: _kTimelineTimezone,
        );
        _logPayload('listEvents', data);
        parsed = parseEventClips(data);
      } else if (selectedModeIndex == 2) {
        final data = await api.listSnapshots(
          cameraId,
          date: dateStr,
          tz: _kTimelineTimezone,
        );
        _logPayload('listSnapshots', data);
        parsed = parseSnapshotClips(data);
      } else {
        final data = await api.listRecordings(
          cameraId,
          date: dateStr,
          tz: _kTimelineTimezone,
        );
        _logPayload('listRecordings', data);
        parsed = parseRecordingClips(data);
      }
      final filtered = _clipsWithThumbnails(parsed);
      final deduped = _dedupeClips(filtered);
      // If a newer load started, discard this result
      if (token != _loadToken) {
        AppLogger.d(
          '[CameraTimeline] Discarding stale load result (token=$token current=$_loadToken)',
        );
        return;
      }
      AppLogger.api(
        '📡 [CameraTimeline] Parsed clips count=${parsed.length} '
        '(${filtered.length} with thumbnails, ${deduped.length} deduped)',
      );
      // Preserve previous selection if still present, otherwise pick first.
      final prevSelected = selectedTimelineEntryId;
      clips = deduped;
      entries = buildEntries(clips);
      final firstKey = clips.isNotEmpty ? clips.first.selectionKey : null;
      final resolvedPrev = prevSelected == null
          ? null
          : _resolveSelectionKey(prevSelected, clips);
      selectedTimelineEntryId = resolvedPrev ?? firstKey;

      // Clear resolved event; we'll re-resolve for current selection below.
      selectedEventId = null;
      isLoading = false;
      _notify();

      // Trigger resolution of canonical event id for current selection
      if (selectedTimelineEntryId != null) {
        selectClip(selectedTimelineEntryId!);
      }
    } catch (e, st) {
      AppLogger.e('CameraTimelineController load error', e, st);
      clips = [];
      entries = [];
      isLoading = false;
      errorMessage = 'Không thể tải dữ liệu timeline.';
      _notify();
    }
  }

  /// Remove obvious duplicates from timeline clips by canonical key.
  /// Prefer explicit ids (image_id / snapshot_id) then timelineEntryId / clip.id
  List<CameraTimelineClip> _dedupeClips(List<CameraTimelineClip> input) {
    final seen = <String>{};
    return input.where((clip) {
      final baseId = _dedupeKeyForClip(clip);
      if (baseId.isEmpty) return true;
      final key = '${clip.kind}:$baseId';
      return seen.add(key);
    }).toList();
  }

  String _dedupeKeyForClip(CameraTimelineClip clip) {
    final candidates = <String?>[
      if (clip.kind == TimelineItemKind.event) clip.eventId,
      if (clip.kind == TimelineItemKind.snapshot) clip.snapshotId,
      if (clip.kind == TimelineItemKind.recording) clip.recordingId,
      clip.timelineEntryId,
      clip.id,
      clip.thumbnailUrl,
    ];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String? _extractSnapshotId(CameraTimelineClip clip) {
    final meta = clip.metadata ?? const <String, dynamic>{};
    final keys = ['snapshot_id', 'snapshotId', 'image_id', 'imageId'];
    for (final key in keys) {
      final value = meta[key];
      if (value == null) continue;
      final trimmed = value.toString().trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final fallback = clip.snapshotId ?? clip.timelineEntryId;
    if (fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
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
    selectedTimelineEntryId = clips.isNotEmpty
        ? clips.first.timelineEntryId
        : null;
    isLoading = false;
    errorMessage = null;
    _notify();
  }

  void changeDay(int offset) {
    final candidate = selectedDay.add(Duration(days: offset));
    final now = DateTime.now().toLocal();
    final maxDay = DateTime(now.year, now.month, now.day);
    final minDay = maxDay.subtract(const Duration(days: 2));
    final candDay = DateTime(candidate.year, candidate.month, candidate.day);
    if (candDay.isBefore(minDay) || candDay.isAfter(maxDay)) {
      AppLogger.d(
        '📡 [CameraTimeline] Attempted to change to $candDay which is outside allowed range ($minDay..$maxDay)',
      );
      return;
    }
    selectedDay = candidate;
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

  void selectClip(String timelineEntryId) {
    final token = ++_selectionToken;
    timelineEntryId = timelineEntryId.trim();
    AppLogger.api(
      '📌 [Timeline] selectClip requested token=$token timelineEntryId=$timelineEntryId '
      'prevSelected=${selectedTimelineEntryId ?? "null"} prevEvent=${selectedEventId ?? "null"}',
    );
    final clip = _findClipBySelection(timelineEntryId);
    final resolvedKey = clip?.selectionKey ?? timelineEntryId;
    selectedTimelineEntryId = resolvedKey;
    selectedEventId = null;
    _notify();

    // CameraTimelineClip? clip;
    // final idx = clips.indexWhere(
    //   (c) => c.timelineEntryId == timelineEntryId || c.id == timelineEntryId,
    // );
    // if (idx == -1) {
    //   clip = null;
    // } else {
    //   clip = clips[idx];
    // }

    if (clip == null) {
      AppLogger.api(
        '⚠️ [Timeline] clip not found for timelineEntryId=$timelineEntryId',
      );
      return;
    }

    final meta = clip.metadata ?? <String, dynamic>{};
    final resolvedMetaEventId = resolveEventIdStrict(meta);
    final canonicalEventId =
        (clip.eventId?.trim().isNotEmpty == true
                ? clip.eventId!.trim()
                : resolvedMetaEventId?.trim())
            ?.trim();

    AppLogger.api(
      '📌 [Timeline] found clip id=${clip.id} timelineEntryId=${clip.timelineEntryId} thumbnail=${clip.thumbnailUrl ?? "-"} metaKeys=${meta.keys.toList()}',
    );

    if (canonicalEventId != null && canonicalEventId.isNotEmpty) {
      if (token != _selectionToken) {
        AppLogger.api(
          '⛔ [Timeline] token mismatch after resolving event, discarding (resolvedToken=$token currentToken=$_selectionToken) for timelineEntryId=$timelineEntryId',
        );
        return;
      }
      selectedEventId = canonicalEventId;
      AppLogger.api(
        '✅ [Timeline] selectedEventId set=$selectedEventId for token=$token',
      );
      _notify();
      return;
    }

    // Only attempt snapshot->event resolution for snapshot items.
    final snapshotId = _extractSnapshotId(clip);
    AppLogger.api(
      'ℹ️ [Timeline] clip has no linked event in metadata for id=${clip.id} snapshotId=$snapshotId kind=${clip.kind}',
    );

    // If clip is a recording, attempt to resolve via recording_id metadata
    // or the clip.recordingId field. This helps when events were created
    // separately (e.g. via alarm button) and only reference the recording.
    if (clip.kind == TimelineItemKind.recording) {
      final recordingId =
          (meta['recording_id'] ?? meta['recordingId'] ?? clip.recordingId)
              ?.toString()
              .trim();
      if (loadFromApi && recordingId != null && recordingId.isNotEmpty) {
        Future.microtask(() async {
          try {
            AppLogger.api(
              '[Timeline] attempting recording->event lookup for $recordingId (token=$token)',
            );
            final resolver = EventsRemoteDataSource();
            final found = await resolver.listEvents(
              limit: 1,
              extraQuery: {'recording_id': recordingId},
            );
            if (token != _selectionToken) {
              AppLogger.api(
                '[Timeline] token changed during recording lookup (token=$token current=$_selectionToken), discarding result',
              );
              return;
            }
            if (found.isNotEmpty) {
              final resolved = EventLog.fromJson(found.first);
              selectedEventId = (resolved.eventId).trim();
              AppLogger.d(
                '[Timeline] Resolved eventId=$selectedEventId from recordingId=$recordingId',
              );
              _notify();
              return;
            } else {
              AppLogger.api(
                '[Timeline] recording->event lookup returned empty for $recordingId',
              );
            }
          } catch (e, st) {
            AppLogger.e('[Timeline] recording->event lookup failed: $e', e, st);
          }
        });
        return;
      }
      AppLogger.d(
        '[Timeline] recording has no recording_id metadata, skipping recording lookup for kind=${clip.kind}',
      );
      return;
    }

    if (clip.kind != TimelineItemKind.snapshot) {
      AppLogger.d(
        '[Timeline] skipping snapshot->event lookup for kind=${clip.kind}',
      );
      return;
    }

    if (loadFromApi && snapshotId != null && snapshotId.isNotEmpty) {
      Future.microtask(() async {
        try {
          AppLogger.api(
            '[Timeline] attempting snapshot->event lookup for $snapshotId (token=$token)',
          );
          final resolver = EventsRemoteDataSource();
          final found = await resolver.listEvents(
            limit: 1,
            extraQuery: {'snapshot_id': snapshotId},
          );
          if (token != _selectionToken) {
            AppLogger.api(
              '[Timeline] token changed during network lookup (token=$token current=$_selectionToken), discarding result',
            );
            return;
          }
          if (found.isNotEmpty) {
            final resolved = EventLog.fromJson(found.first);
            selectedEventId = (resolved.eventId).trim();
            AppLogger.d(
              '[Timeline] Resolved eventId=$selectedEventId from snapshotId=$snapshotId',
            );
            _notify();
          } else {
            AppLogger.api(
              '[Timeline] snapshot->event lookup returned empty for $snapshotId',
            );
          }
        } catch (e, st) {
          AppLogger.e('[Timeline] snapshot->event lookup failed: $e', e, st);
        }
      });
    }
  }

  String? _resolveSelectionKey(
    String selection,
    List<CameraTimelineClip> list,
  ) {
    final normalized = selection.trim();
    for (final clip in list) {
      if (clip.selectionKey == normalized ||
          clip.timelineEntryId == normalized ||
          clip.id == normalized) {
        return clip.selectionKey;
      }
    }
    return null;
  }

  CameraTimelineClip? _findClipBySelection(String selection) {
    final normalized = selection.trim();
    for (final clip in clips) {
      if (clip.selectionKey == normalized ||
          clip.timelineEntryId == normalized ||
          clip.id == normalized) {
        return clip;
      }
    }
    return null;
  }

  void adjustZoom(double delta) {
    zoomLevel = (zoomLevel + delta).clamp(0.0, 1.0).toDouble();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _formatLocalDate(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    return localDate.toIso8601String().split('T').first;
  }

  /// Returns the maximum selectable day (today, local date).
  DateTime get maxSelectableDay {
    final now = DateTime.now().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  /// Returns the minimum selectable day (today minus two days).
  DateTime get minSelectableDay =>
      maxSelectableDay.subtract(const Duration(days: 2));

  bool get canGoPrev {
    final sel = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    return sel.isAfter(minSelectableDay);
  }

  bool get canGoNext {
    final sel = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    return sel.isBefore(maxSelectableDay);
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
