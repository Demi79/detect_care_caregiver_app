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
  final String? createdBy;
  final String? createdByDisplay;
  @override
  final bool? hasEmergencyCall;
  @override
  final bool? hasAlarmActivated;
  @override
  final String? lastEmergencyCallSource;
  @override
  final String? lastAlarmActivatedSource;
  @override
  final DateTime? lastEmergencyCallAt;
  @override
  final DateTime? lastAlarmActivatedAt;
  @override
  final bool? isAlarmTimeoutExpired;
  final String? updatedBy;
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
    this.createdBy,
    this.createdByDisplay,
    this.updatedBy,
    this.hasEmergencyCall,
    this.hasAlarmActivated,
    this.lastEmergencyCallSource,
    this.lastAlarmActivatedSource,
    this.lastEmergencyCallAt,
    this.lastAlarmActivatedAt,
    this.isAlarmTimeoutExpired,
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

    // final rawEventId = first(json, ['event_id', 'eventId', 'id']);
    // final parsedEventId = s(rawEventId) ?? '';
    bool isUuidLoose(String s) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(s.trim());

    final hasEventShape = [
      'event_type',
      'eventType',
      'type',
      'status',
      'event_status',
      'lifecycle_state',
      'lifecycleState',
    ].any((key) => json.containsKey(key));

    final rawEventIdKeys = hasEventShape
        ? ['event_id', 'eventId', 'id']
        : ['event_id', 'eventId'];

    final ev = s(first(json, rawEventIdKeys))?.trim();
    final id = s(first(json, ['id']))?.trim();

    final parsedEventId = (ev != null && ev.isNotEmpty)
        ? ev
        : ((hasEventShape && id != null && id.isNotEmpty && isUuidLoose(id))
              ? id
              : '');

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
    final updatedByValue = s(first(json, ['updated_by', 'updatedBy']));
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
      createdBy: s(first(json, ['created_by', 'createBy', 'create_by'])),
      createdByDisplay: s(
        first(json, [
          'created_by_display',
          'createdByDisplay',
          'creator_name',
          'creatorName',
        ]),
      ),
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
      updatedBy: s(first(json, ['updated_by', 'updatedBy'])),
      hasEmergencyCall:
          (first(json, [
                'has_emergency_call',
                'hasEmergencyCall',
                'emergency_call',
              ]) !=
              null)
          ? (first(json, [
                      'has_emergency_call',
                      'hasEmergencyCall',
                      'emergency_call',
                    ])
                    is bool
                ? first(json, [
                        'has_emergency_call',
                        'hasEmergencyCall',
                        'emergency_call',
                      ])
                      as bool
                : (first(json, [
                            'has_emergency_call',
                            'hasEmergencyCall',
                            'emergency_call',
                          ])
                          is num
                      ? (first(json, [
                                  'has_emergency_call',
                                  'hasEmergencyCall',
                                  'emergency_call',
                                ])
                                as num) !=
                            0
                      : (first(json, [
                              'has_emergency_call',
                              'hasEmergencyCall',
                              'emergency_call',
                            ]).toString().trim().toLowerCase() ==
                            'true')))
          : false,
      hasAlarmActivated:
          (first(json, [
                'has_alarm_activated',
                'hasAlarmActivated',
                'alarm_activated',
              ]) !=
              null)
          ? (first(json, [
                      'has_alarm_activated',
                      'hasAlarmActivated',
                      'alarm_activated',
                    ])
                    is bool
                ? first(json, [
                        'has_alarm_activated',
                        'hasAlarmActivated',
                        'alarm_activated',
                      ])
                      as bool
                : (first(json, [
                            'has_alarm_activated',
                            'hasAlarmActivated',
                            'alarm_activated',
                          ])
                          is num
                      ? (first(json, [
                                  'has_alarm_activated',
                                  'hasAlarmActivated',
                                  'alarm_activated',
                                ])
                                as num) !=
                            0
                      : (first(json, [
                              'has_alarm_activated',
                              'hasAlarmActivated',
                              'alarm_activated',
                            ]).toString().trim().toLowerCase() ==
                            'true')))
          : false,
      lastEmergencyCallSource: s(
        first(json, [
          'last_emergency_call_source',
          'lastEmergencyCallSource',
          'emergency_call_source',
        ]),
      ),
      lastAlarmActivatedSource: s(
        first(json, [
          'last_alarm_activated_source',
          'lastAlarmActivatedSource',
          'alarm_activated_source',
        ]),
      ),
      lastEmergencyCallAt: dt(
        first(json, ['last_emergency_call_at', 'lastEmergencyCallAt']),
      ),
      lastAlarmActivatedAt: dt(
        first(json, ['last_alarm_activated_at', 'lastAlarmActivatedAt']),
      ),
      isAlarmTimeoutExpired:
          (first(json, [
                'isAlarmTimeoutExpired',
                'is_alarm_timeout_expired',
                'alarm_timeout_expired',
              ]) !=
              null)
          ? (first(json, [
                      'isAlarmTimeoutExpired',
                      'is_alarm_timeout_expired',
                      'alarm_timeout_expired',
                    ])
                    is bool
                ? first(json, [
                        'isAlarmTimeoutExpired',
                        'is_alarm_timeout_expired',
                        'alarm_timeout_expired',
                      ])
                      as bool
                : (first(json, [
                            'isAlarmTimeoutExpired',
                            'is_alarm_timeout_expired',
                            'alarm_timeout_expired',
                          ])
                          is num
                      ? (first(json, [
                                  'isAlarmTimeoutExpired',
                                  'is_alarm_timeout_expired',
                                  'alarm_timeout_expired',
                                ])
                                as num) !=
                            0
                      : (first(json, [
                              'isAlarmTimeoutExpired',
                              'is_alarm_timeout_expired',
                              'alarm_timeout_expired',
                            ]).toString().trim().toLowerCase() ==
                            'true')))
          : false,
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
      if (updatedBy != null) 'updated_by': updatedBy,
      if (lifecycleState != null) 'lifecycle_state': lifecycleState,
      if (hasEmergencyCall != null) 'has_emergency_call': hasEmergencyCall,
      if (hasAlarmActivated != null) 'has_alarm_activated': hasAlarmActivated,
      if (lastEmergencyCallSource != null)
        'last_emergency_call_source': lastEmergencyCallSource,
      if (lastAlarmActivatedSource != null)
        'last_alarm_activated_source': lastAlarmActivatedSource,
      if (lastEmergencyCallAt != null)
        'last_emergency_call_at': lastEmergencyCallAt!.toIso8601String(),
      if (lastAlarmActivatedAt != null)
        'last_alarm_activated_at': lastAlarmActivatedAt!.toIso8601String(),
      if (isAlarmTimeoutExpired != null)
        'is_alarm_timeout_expired': isAlarmTimeoutExpired,
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
    String? createdBy,
    String? createdByDisplay,
    String? updatedBy,
    bool? hasEmergencyCall,
    bool? hasAlarmActivated,
    String? lastEmergencyCallSource,
    String? lastAlarmActivatedSource,
    DateTime? lastEmergencyCallAt,
    DateTime? lastAlarmActivatedAt,
    bool? isAlarmTimeoutExpired,
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
    createdBy: createdBy ?? this.createdBy,
    createdByDisplay: createdByDisplay ?? this.createdByDisplay,
    updatedBy: updatedBy ?? this.updatedBy,
    hasEmergencyCall: hasEmergencyCall ?? this.hasEmergencyCall,
    hasAlarmActivated: hasAlarmActivated ?? this.hasAlarmActivated,
    lastEmergencyCallSource:
        lastEmergencyCallSource ?? this.lastEmergencyCallSource,
    lastAlarmActivatedSource:
        lastAlarmActivatedSource ?? this.lastAlarmActivatedSource,
    lastEmergencyCallAt: lastEmergencyCallAt ?? this.lastEmergencyCallAt,
    lastAlarmActivatedAt: lastAlarmActivatedAt ?? this.lastAlarmActivatedAt,
    isAlarmTimeoutExpired: isAlarmTimeoutExpired ?? this.isAlarmTimeoutExpired,
  );
}

extension EventLogEmergencyHelpers on EventLog {
  bool get _hasEmergencyCall => hasEmergencyCall ?? false;
  bool get _hasAlarmActivated => hasAlarmActivated ?? false;
  String? get _lastEmergencySource => lastEmergencyCallSource;
  String? get _lastAlarmSource => lastAlarmActivatedSource;
  bool get _isAlarmTimeoutExpired => isAlarmTimeoutExpired ?? false;

  AlertActionDecision getAlertActionDecision() {
    final emSrc = (_lastEmergencySource ?? '').toString().toUpperCase();
    final alSrc = (_lastAlarmSource ?? '').toString().toUpperCase();

    // 1) Caregiver CALL (highest priority)
    if (_hasEmergencyCall && emSrc == 'CAREGIVER') {
      return AlertActionDecision(
        mode: AlertActionMode.caregiverCall,
        disableCall: true,
        disableAlarm: true,
        disableCancel: true,
      );
    }

    // 2) Customer CALL (user-initiated by customer)
    if (_hasEmergencyCall && emSrc == 'CUSTOMER') {
      return AlertActionDecision(
        mode: AlertActionMode.customerCall,
        disableCall: true,
        disableAlarm: false,
        disableCancel: true,
      );
    }

    // 3) System AUTO CALL
    if (_hasEmergencyCall && emSrc == 'SYSTEM') {
      return AlertActionDecision(
        mode: AlertActionMode.systemCall,
        disableCall: true,
        disableAlarm: false,
        disableCancel: false,
      );
    }

    // 4) System AUTO ALARM (only disables alarm if timeout not expired)
    if (_hasAlarmActivated && alSrc == 'SYSTEM' && !_isAlarmTimeoutExpired) {
      return AlertActionDecision(
        mode: AlertActionMode.systemAlarm,
        disableCall: false,
        disableAlarm: true,
        disableCancel: false,
      );
    }

    // 5) User ALARM (Customer or Caregiver) -> disables alarm and cancel
    if (_hasAlarmActivated && (alSrc == 'CUSTOMER' || alSrc == 'CAREGIVER')) {
      return AlertActionDecision(
        mode: AlertActionMode.userAlarm,
        disableCall: false,
        disableAlarm: true,
        disableCancel: true,
      );
    }

    // 6) Fallbacks: if unknown emergency source but emergency present, behave like customer call
    if (_hasEmergencyCall) {
      return AlertActionDecision(
        mode: AlertActionMode.customerCall,
        disableCall: true,
        disableAlarm: false,
        disableCancel: true,
      );
    }

    // Default: nothing disabled
    return AlertActionDecision(mode: AlertActionMode.none);
  }

  bool get isCallDisabled => getAlertActionDecision().disableCall;
  bool get isAlarmDisabled => getAlertActionDecision().disableAlarm;
  bool get isCancelDisabled => getAlertActionDecision().disableCancel;
}

enum AlertActionMode {
  none,
  systemCall,
  customerCall,
  caregiverCall,
  systemAlarm,
  userAlarm,
}

class AlertActionDecision {
  final AlertActionMode mode;
  final bool disableCall;
  final bool disableAlarm;
  final bool disableCancel;

  const AlertActionDecision({
    this.mode = AlertActionMode.none,
    this.disableCall = false,
    this.disableAlarm = false,
    this.disableCancel = false,
  });
}
