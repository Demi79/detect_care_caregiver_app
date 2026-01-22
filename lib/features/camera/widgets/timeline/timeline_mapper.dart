import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:flutter/foundation.dart';

import 'timeline_models.dart';
import 'timeline_utils.dart';

EventLog buildTimelineEventLog(
  CameraTimelineClip clip,
  CameraEntry camera, {
  String? canonicalEventId,
}) {
  final meta = clip.metadata ?? const <String, dynamic>{};

  final status =
      pickString(meta, const ['status', 'event_status', 'lifecycle_state']) ??
      pickString(meta, const ['status_code', 'result']) ??
      'unknown';

  final eventType = pickString(meta, const ['event_type', 'type']) ?? 'unknown';

  final confidence = toDouble(
    meta['confidence_score'] ?? meta['confidence'] ?? meta['score'] ?? 0,
  );

  final resolvedMetaEventId = resolveEventIdStrict(meta);
  final eventId =
      (canonicalEventId?.trim().isNotEmpty == true
              ? canonicalEventId!.trim()
              : (clip.eventId?.trim().isNotEmpty == true
                    ? clip.eventId!.trim()
                    : (resolvedMetaEventId ?? '').trim()))
          .trim();

  AppLogger.d(
    '[Timeline] Resolved eventId="$eventId" clipId=${clip.timelineEntryId} kind=${clip.kind}',
  );
  try {
    debugPrint(
      '[Timeline] Resolved eventId="$eventId" clip.timelineEntryId=${clip.timelineEntryId} kind=${clip.kind} source=${eventId.isEmpty ? 'none' : 'meta'}',
    );
  } catch (_) {}

  final det = Map<String, dynamic>.from(meta);
  if ((det['snapshot_id'] ?? det['snapshotId']) == null &&
      clip.snapshotId != null &&
      clip.snapshotId!.isNotEmpty) {
    det['snapshot_id'] = clip.snapshotId;
  }

  return EventLog(
    eventId: eventId,
    status: status,
    eventType: eventType,
    eventDescription: pickString(meta, const ['description', 'message']),
    confidenceScore: confidence,
    detectedAt: clip.startTime,
    createdAt: clip.startTime,
    detectionData: det,
    // Merge existing context map with timeline identifiers for debugging
    contextData: () {
      final ctx = Map<String, dynamic>.from(
        pickMap(meta, const ['context_data', 'contextData']),
      );
      try {
        ctx['timeline_entry_id'] = clip.timelineEntryId;
        if (clip.snapshotId != null && clip.snapshotId!.isNotEmpty) {
          ctx['snapshot_id'] = clip.snapshotId;
        }
      } catch (_) {}
      return ctx;
    }(),
    boundingBoxes: pickMap(meta, const ['bounding_boxes', 'boundingBoxes']),
    confirmStatus: (meta['confirm_status'] ?? meta['confirmed']) == true,
    lifecycleState: pickString(meta, const [
      'lifecycle_state',
      'lifecycleState',
    ]),
    cameraId: camera.id,
    imageUrls: collectImageUrls(meta, thumb: clip.thumbnailUrl),
  );
}
