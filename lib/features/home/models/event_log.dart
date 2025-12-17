import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';

class EventLog implements LogEntry {
  @override
  final String eventId;
  @override
  final String status;
  @override
  final String eventType;
  @override
  final String? eventDescription;
  final String? notes;
  @override
  final double confidenceScore;
  @override
  final DateTime? detectedAt;
  @override
  final DateTime? createdAt;
  @override
  final Map<String, dynamic> detectionData;
  @override
  final Map<String, dynamic> aiAnalysisResult;
  @override
  final Map<String, dynamic> contextData;
  @override
  final Map<String, dynamic> boundingBoxes;
  @override
  final String? cameraId;
  @override
  final bool confirmStatus;
  @override
  final String? lifecycleState;
  @override
  final String? createBy;
  final List<String> imageUrls;

  final String? confirmationState;
  final String? proposedStatus;
  final String? proposedEventType;
  final String? previousStatus;
  final String? proposedBy;
  final String? pendingReason;
  final DateTime? pendingUntil;

  EventLog({
    required this.eventId,
    required this.status,
    required this.eventType,
    this.eventDescription,
    this.notes,
    required this.confidenceScore,
    this.detectedAt,
    this.createdAt,
    this.detectionData = const {},
    this.aiAnalysisResult = const {},
    this.contextData = const {},
    this.boundingBoxes = const {},
    required this.confirmStatus,
    this.confirmationState,
    this.proposedStatus,
    this.proposedEventType,
    this.previousStatus,
    this.proposedBy,
    this.pendingReason,
    this.pendingUntil,
    this.imageUrls = const [],
    this.lifecycleState,
    this.cameraId,
    this.createBy,
  });

  factory EventLog.fromJson(Map<String, dynamic> json) {
    print('\n📥 [EventLog] Parsing JSON:');
    json.forEach((k, v) => print('  $k: $v (${v?.runtimeType})'));

    String? s(dynamic v) => v?.toString();
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    Map<String, dynamic> m(dynamic v) =>
        (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

    dynamic first(Map j, List<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k) && j[k] != null) return j[k];
      }
      return null;
    }

    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is num) {
        final n = v.toInt();
        try {
          if (n > 1000000000000000) {
            return DateTime.fromMicrosecondsSinceEpoch(n);
          }
          if (n > 1000000000000) {
            return DateTime.fromMillisecondsSinceEpoch(n);
          }
          if (n > 1000000000) {
            return DateTime.fromMillisecondsSinceEpoch(n);
          }
          return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        } catch (_) {
          return null;
        }
      }

      if (v is String) {
        if (v.isEmpty) return null;
        try {
          return DateTime.parse(v);
        } catch (_) {
          final norm = _normalizeIso8601(v);
          try {
            return DateTime.parse(norm);
          } catch (_) {
            return null;
          }
        }
      }
      return null;
    }

    final rawEventId = first(json, ['event_id', 'eventId', 'id']);
    final parsedEventId = s(rawEventId) ?? '';

    final confirmKeys = [
      'confirm_status',
      'confirmed',
      'confirmStatus',
      'is_confirmed',
    ];
    final rawConfirm = first(json, confirmKeys);
    final parsedConfirm = _parseConfirmStatus(rawConfirm);
    final ctxMap = m(first(json, ['context_data', 'contextData']));
    final detMap = m(first(json, ['detection_data', 'detectionData']));

    final topCamera = first(json, ['camera_id', 'cameraId', 'camera']);
    if (topCamera != null && topCamera.toString().isNotEmpty) {
      if (!ctxMap.containsKey('camera_id') && !ctxMap.containsKey('camera')) {
        ctxMap['camera_id'] = topCamera;
      }
      if (!detMap.containsKey('camera_id') && !detMap.containsKey('camera')) {
        detMap['camera_id'] = topCamera;
      }
    }

    // Fallback: propagate snapshot_id if missing
    final topSnapshot = first(json, ['snapshot_id', 'snapshotId']);
    if (topSnapshot != null && topSnapshot.toString().isNotEmpty) {
      if (!detMap.containsKey('snapshot_id') &&
          !ctxMap.containsKey('snapshot_id')) {
        detMap['snapshot_id'] = topSnapshot;
      }
    }

    final rawDetected = first(json, ['detected_at', 'detectedAt']);
    final rawCreated = first(json, ['created_at', 'createdAt']);
    final parsedDetected = dt(rawDetected);
    final parsedCreated = dt(rawCreated);

    print(
      '[EventLog] raw detected_at: $rawDetected (${rawDetected?.runtimeType})',
    );
    print('[EventLog] parsed detectedAt (UTC): $parsedDetected');
    try {
      print(
        '[EventLog] parsed detectedAt (local): ${parsedDetected?.toLocal()}',
      );
    } catch (_) {}

    print(
      '[EventLog] raw created_at: $rawCreated (${rawCreated?.runtimeType})',
    );
    print('[EventLog] parsed createdAt (UTC): $parsedCreated');
    try {
      print('[EventLog] parsed createdAt (local): ${parsedCreated?.toLocal()}');
    } catch (_) {}

    // 🔍 Fallback lấy cameraId từ nhiều tầng dữ liệu khác nhau
    // 🔍 Fallback lấy cameraId từ nhiều tầng dữ liệu khác nhau
    dynamic fallbackCamera = topCamera;

    // 1️⃣ Nếu chưa có, thử từ "cameras" (có thể là object hoặc list)
    if (fallbackCamera == null) {
      final cameras = first(json, ['cameras']);
      if (cameras is Map && cameras['camera_id'] != null) {
        fallbackCamera = cameras['camera_id'];
      } else if (cameras is List && cameras.isNotEmpty) {
        final firstCam = cameras.first;
        if (firstCam is Map && firstCam['camera_id'] != null) {
          fallbackCamera = firstCam['camera_id'];
        } else if (firstCam is String) {
          fallbackCamera = firstCam;
        }
      }
    }

    // 2️⃣ Nếu vẫn null, thử từ "snapshots"
    if (fallbackCamera == null) {
      final snaps = first(json, ['snapshots', 'snapshot']);
      if (snaps is Map && snaps['camera_id'] != null) {
        fallbackCamera = snaps['camera_id'];
      } else if (snaps is List && snaps.isNotEmpty) {
        final firstSnap = snaps.first;
        if (firstSnap is Map && firstSnap['camera_id'] != null) {
          fallbackCamera = firstSnap['camera_id'];
        }
      }
    }

    // 3️⃣ Nếu vẫn null, thử từ "history"
    if (fallbackCamera == null) {
      final history = first(json, ['history']);
      if (history is List) {
        for (final h in history) {
          if (h is Map && h['camera_id'] != null) {
            fallbackCamera = h['camera_id'];
            break;
          }
        }
      }
    }

    // 4️⃣ Cuối cùng, fallback từ detection/context
    fallbackCamera ??=
        detMap['camera_id'] ?? ctxMap['camera_id'] ?? detMap['camera'];

    // 🖼️ Extract image URLs
    final images = <String>[];
    try {
      final snapUrl = first(json, ['snapshot_url', 'snapshotUrl']);
      if (snapUrl != null && snapUrl.toString().isNotEmpty) {
        images.add(snapUrl.toString());
      }
      final snaps = first(json, ['snapshot', 'snapshots']);
      if (snaps != null) {
        if (snaps is String) {
          images.add(snaps);
        } else if (snaps is Map) {
          if (snaps.containsKey('files') && snaps['files'] is List) {
            for (final f in (snaps['files'] as List)) {
              if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                final u = (f['cloud_url'] ?? f['url']).toString();
                if (u.isNotEmpty) images.add(u);
              }
            }
          } else if ((snaps['cloud_url'] ?? snaps['url']) != null) {
            images.add((snaps['cloud_url'] ?? snaps['url']).toString());
          }
        } else if (snaps is List) {
          for (final s in snaps) {
            if (s is String && s.isNotEmpty) {
              images.add(s);
            } else if (s is Map) {
              if (s.containsKey('files') && s['files'] is List) {
                for (final f in (s['files'] as List)) {
                  if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                    final u = (f['cloud_url'] ?? f['url']).toString();
                    if (u.isNotEmpty) images.add(u);
                  }
                }
              } else if ((s['cloud_url'] ?? s['url']) != null) {
                images.add((s['cloud_url'] ?? s['url']).toString());
              }
            }
          }
        }
      }
    } catch (_) {}

    return EventLog(
      eventId: parsedEventId,
      status: s(first(json, ['status'])) ?? '',
      eventType: s(first(json, ['event_type', 'eventType'])) ?? '',
      eventDescription: s(
        first(json, ['event_description', 'eventDescription']),
      ),
      notes: s(first(json, ['notes'])),
      confidenceScore: d(
        first(json, ['confidence_score', 'confidenceScore', 'confidence']),
      ),
      detectedAt: parsedDetected,
      createdAt: parsedCreated ?? parsedDetected,
      detectionData: detMap,
      aiAnalysisResult: m(
        first(json, ['ai_analysis_result', 'aiAnalysisResult']),
      ),
      contextData: ctxMap,
      boundingBoxes: m(first(json, ['bounding_boxes', 'boundingBoxes'])),
      confirmStatus: parsedConfirm,
      createBy: s(first(json, ['create_by', 'created_by', 'createBy'])),
      confirmationState: s(
        first(json, ['confirmation_state', 'confirmationState']),
      ),
      proposedStatus: s(first(json, ['proposed_status', 'proposedStatus'])),
      proposedEventType: s(
        first(json, ['proposed_event_type', 'proposedEventType']),
      ),
      previousStatus: s(first(json, ['previous_status', 'previousStatus'])),
      proposedBy: s(first(json, ['proposed_by', 'proposedBy'])),
      pendingReason: s(first(json, ['pending_reason', 'pendingReason'])),
      pendingUntil: dt(first(json, ['pending_until', 'pendingUntil'])),
      imageUrls: images,
      lifecycleState: s(first(json, ['lifecycle_state', 'lifecycleState'])),
      cameraId:
          s(fallbackCamera) ??
          s(topCamera) ??
          s(detMap['camera_id']) ??
          s(ctxMap['camera_id']),
    );
  }

  Map<String, dynamic> toMapString() {
    return {
      'event_id': eventId,
      'status': status,
      'event_type': eventType,
      'event_description': eventDescription,
      'notes': notes,
      'confidence_score': confidenceScore,
      if (detectedAt != null) 'detected_at': detectedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'detection_data': detectionData,
      'ai_analysis_result': aiAnalysisResult,
      'context_data': contextData,
      'bounding_boxes': boundingBoxes,
      'confirm_status': confirmStatus,
      'confirmation_state': confirmationState,
      'proposed_status': proposedStatus,
      'proposed_event_type': proposedEventType,
      'previous_status': previousStatus,
      'proposed_by': proposedBy,
      'pending_reason': pendingReason,
      if (pendingUntil != null)
        'pending_until': pendingUntil!.toIso8601String(),
      if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
      if (cameraId != null) 'camera_id': cameraId,
      if (createBy != null) 'create_by': createBy,
      if (lifecycleState != null) 'lifecycle_state': lifecycleState,
    };
  }

  static String _normalizeIso8601(String s) {
    var out = s.trim();
    if (out.contains(' ') && !out.contains('T')) {
      out = out.replaceFirst(' ', 'T');
    }
    out = out.replaceFirstMapped(RegExp(r'([+-]\d{2})$'), (m) => '${m[1]}:00');
    out = out.replaceFirst(RegExp(r'\+00(?::00)?$'), 'Z');
    return out;
  }

  static bool _parseConfirmStatus(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (['true', 't', '1', 'yes', 'y'].contains(s)) return true;
      if (['false', 'f', '0', 'no', 'n'].contains(s)) return false;
    }
    return false;
  }

  EventLog copyWith({
    String? status,
    bool? confirmStatus,
    String? proposedStatus,
    String? proposedEventType,
    String? pendingReason,
    String? confirmationState,
    String? cameraId,
    String? createBy,
  }) => EventLog(
    eventId: eventId,
    status: status ?? this.status,
    eventType: eventType,
    eventDescription: eventDescription,
    confidenceScore: confidenceScore,
    detectedAt: detectedAt,
    createdAt: createdAt,
    detectionData: detectionData,
    aiAnalysisResult: aiAnalysisResult,
    contextData: contextData,
    boundingBoxes: boundingBoxes,
    confirmStatus: confirmStatus ?? this.confirmStatus,
    proposedStatus: proposedStatus ?? this.proposedStatus,
    proposedEventType: proposedEventType ?? this.proposedEventType,
    pendingReason: pendingReason ?? this.pendingReason,
    confirmationState: confirmationState ?? this.confirmationState,
    cameraId: cameraId ?? this.cameraId,
    createBy: createBy ?? this.createBy,
  );
}
