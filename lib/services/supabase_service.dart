import 'package:detect_care_caregiver_app/core/alerts/alert_coordinator.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _healthcareChannel;

  void initRealtimeSubscription({
    required Function(Map<String, dynamic>) onEventReceived,
  }) {
    debugPrint('\n🔌 Initializing Supabase Realtime connection...');

    dispose();

    _healthcareChannel = _supabase.channel('realtime:event_detections');

    _healthcareChannel =
        _healthcareChannel!.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_detections',
          callback: (payload) async {
            try {
              print('🟢 Supabase realtime callback fired');
              try {
                print('🔔 payload:');
                try {
                  print(payload.newRecord);
                } catch (e) {
                  print('⚠️ error printing payload.newRecord: $e');
                }

                print('🔔 oldRecord:');
                try {
                  print(payload.oldRecord);
                } catch (e) {
                  print('⚠️ error printing payload.oldRecord: $e');
                }

                print('🔔 type:');
                try {
                  print(payload.eventType);
                } catch (e) {
                  print('⚠️ error printing payload.eventType: $e');
                }
              } catch (e) {
                print(
                  '⚠️ unexpected error while logging payload debug info: $e',
                );
              }

              final row = payload.newRecord;
              try {
                debugPrint(
                  '\n🔍 Supabase payload.newRecord (runtimeType=${row.runtimeType}):',
                );
                debugPrint(row.toString());
                if (row.isEmpty) {
                  debugPrint('⚠️ payload.newRecord is an empty Map');
                }
              } catch (e) {
                debugPrint('⚠️ Error printing payload.newRecord: $e');
              }

              try {
                final snapshot = {
                  'newRecord': row,
                  'oldRecord': payload.oldRecord,
                  'eventType': payload.eventType.toString(),
                };
                final enc = _toJsonEncodable(snapshot);
                debugPrint('🔔 full payload JSON:');
                debugPrint(jsonEncode(enc), wrapWidth: 2048);
              } catch (e) {
                debugPrint('⚠️ Error JSON-encoding payload snapshot: $e');
              }

              var mobileEvent = await _mapEventToMobile(row);

              if ((mobileEvent['event_id'] == null ||
                      (mobileEvent['event_id'] as String).isEmpty) ||
                  (mobileEvent['event_type'] == null ||
                      (mobileEvent['event_type'] as String).isEmpty)) {
                try {
                  print(
                    '⚠️ Realtime payload had no id/type — fetching latest event as fallback',
                  );
                  final recent = await fetchRecentEvents(limit: 1);
                  if (recent.isNotEmpty) {
                    mobileEvent = recent.first;
                    print(
                      'ℹ️ Using latest event from DB: ${mobileEvent['event_id']}',
                    );
                  } else {
                    print('⚠️ No recent events found as fallback');
                  }
                } catch (e) {
                  print('⚠️ Error fetching recent events fallback: $e');
                }
              }
              print('📥 New event (normalized mobileEvent):');
              print(mobileEvent.toString());
              print(
                '📥 New event summary: ${mobileEvent['event_type']} '
                '@${mobileEvent['detected_at']} (id=${mobileEvent['event_id']})',
              );

              AlertCoordinator.handle(EventLog.fromJson(mobileEvent));
              onEventReceived(mobileEvent);
            } catch (e, st) {
              debugPrint('⚠️ Uncaught error in realtime callback: $e');
              debugPrint(st.toString());
            }
          },
        )..subscribe((status, error) {
          if (error != null) {
            debugPrint('❌ Supabase connection error: $error');
            Future.delayed(const Duration(seconds: 5), () {
              if (_healthcareChannel != null) {
                debugPrint('🔄 Attempting to reconnect...');
                _healthcareChannel!.subscribe();
              }
            });
            return;
          }

          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              debugPrint('✅ Successfully connected to Supabase Realtime');
              break;
            case RealtimeSubscribeStatus.closed:
              debugPrint('📴 Supabase connection closed');
              break;
            case RealtimeSubscribeStatus.channelError:
              debugPrint('⚠️ Supabase channel error');
              Future.delayed(const Duration(seconds: 3), () {
                if (_healthcareChannel != null) {
                  debugPrint('🔄 Attempting to resubscribe...');
                  _healthcareChannel!.subscribe();
                }
              });
              break;
            default:
              debugPrint('ℹ️ Supabase status: $status');
          }
        });
  }

  Future<Map<String, dynamic>> _mapEventToMobile(
    Map<String, dynamic> raw,
  ) async {
    String? s(dynamic v) => v?.toString();
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    String? iso(dynamic v) {
      if (v == null) return null;
      var s = v.toString().trim();
      if (s.contains(' ') && !s.contains('T')) s = s.replaceFirst(' ', 'T');
      s = s.replaceFirst(RegExp(r'\+00(?::00)?$'), 'Z');
      s = s.replaceFirstMapped(RegExp(r'([+-]\d{2})$'), (m) => '${m[1]}:00');
      return s;
    }

    final eventId = s(raw['event_id']) ?? s(raw['id']) ?? '';
    final snapshotId = s(raw['snapshot_id']);
    final notes = s(raw['notes']);
    final userId = s(raw['user_id']);
    String eventType = s(raw['event_type']) ?? '';
    double confidenceScore = d(raw['confidence_score']);
    final detectedAt = iso(raw['detected_at']);
    final createdAt = iso(raw['created_at']);
    final status = s(raw['status']) ?? 'detected';
    final lifecycleState =
        s(raw['lifecycle_state']) ?? s(raw['lifecycleState']);

    String? imageUrl;
    if (raw['snapshots'] is Map) {
      final snapshotsMap = raw['snapshots'] as Map;
      final cloudUrl = snapshotsMap['cloud_url'];
      final imagePath = snapshotsMap['image_path'];
      imageUrl = s(cloudUrl) ?? await _imageUrlFromPath(s(imagePath));
    } else {
      imageUrl = await _getEventImageUrlBySnapshotId(snapshotId);
    }

    Map<String, dynamic> normMap(dynamic v) {
      if (v == null) return {};
      if (v is Map) return v.cast<String, dynamic>();
      if (v is String) {
        try {
          final parsed = json.decode(v);
          if (parsed is Map) return parsed.cast<String, dynamic>();
        } catch (_) {
          // ignore parse errors
        }
      }
      return {};
    }

    final detectionData = normMap(raw['detection_data']);
    final aiAnalysis = normMap(raw['ai_analysis_result']);
    final contextData = normMap(raw['context_data']);
    final boundingBoxes = normMap(raw['bounding_boxes']);

    final String? verifiedAt = iso(raw['verified_at']);
    final verifiedBy = s(raw['verified_by']);
    final String? acknowledgedAt = iso(raw['acknowledged_at']);
    final acknowledgedBy = s(raw['acknowledged_by']);
    final String? dismissedAt = iso(raw['dismissed_at']);
    bool? confirmStatus;
    try {
      final rawConfirm = raw['confirm_status'];
      if (rawConfirm == null) {
        confirmStatus = null;
      } else if (rawConfirm is bool)
        confirmStatus = rawConfirm;
      else if (rawConfirm is num)
        confirmStatus = rawConfirm != 0;
      else if (rawConfirm is String) {
        final t = rawConfirm.trim().toLowerCase();
        confirmStatus = ['true', '1', 't', 'yes', 'y'].contains(t);
      }
    } catch (_) {
      confirmStatus = null;
    }

    final confirmationState = s(raw['confirmation_state']);
    final pendingUntil = iso(raw['pending_until']);
    final proposedStatus = s(raw['proposed_status']);
    final proposedEventType = s(raw['proposed_event_type']);
    final proposedReason = s(raw['proposed_reason']);
    final proposedBy = s(raw['proposed_by']);

    if (eventType.isEmpty) {
      eventType =
          s(detectionData['type']) ?? s(contextData['type']) ?? eventType;
      if (eventType.isEmpty) {
        final msg = s(raw['message']) ?? s(raw['payload']) ?? '';
        final m = RegExp(
          r'Type:\s*(\w+)',
          caseSensitive: false,
        ).firstMatch(msg);
        if (m != null) eventType = m.group(1) ?? eventType;
      }
    }

    if (confidenceScore == 0) {
      confidenceScore = d(
        detectionData['confidence'] ??
            detectionData['confidence_score'] ??
            contextData['confidence'],
      );
    }

    String? description =
        s(raw['event_description']) ??
        s(detectionData['description']) ??
        s(contextData['description']);
    if ((description == null || description.isEmpty)) {
      final msg = s(raw['message']) ?? s(raw['payload']) ?? '';
      final m = RegExp(
        r'Description:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(msg);
      if (m != null) description = m.group(1)?.trim();
    }

    String? cameraId;
    cameraId =
        s(detectionData['camera_id']) ??
        s(detectionData['camera']) ??
        s(contextData['camera_id']) ??
        s(contextData['camera']) ??
        s(raw['camera']);
    if (cameraId == null || cameraId.isEmpty) {
      final msg = s(raw['message']) ?? s(raw['payload']) ?? '';
      final m = RegExp(
        r'Camera:\s*([A-Za-z0-9\-_.]+)',
        caseSensitive: false,
      ).firstMatch(msg);
      if (m != null) cameraId = m.group(1);
    }

    return {
      'event_id': eventId,
      'event_type': eventType,
      'event_description': description,
      'notes': notes,
      'confidence_score': confidenceScore,
      'status': status,
      'confirm_status': confirmStatus,
      'confirmation_state': confirmationState,
      'proposed_status': proposedStatus,
      'proposed_event_type': proposedEventType,
      'proposed_reason': proposedReason,
      'proposed_by': proposedBy,
      'pending_until': pendingUntil,
      'verified_at': verifiedAt,
      'verified_by': verifiedBy,
      'acknowledged_at': acknowledgedAt,
      'acknowledged_by': acknowledgedBy,
      'dismissed_at': dismissedAt,
      'user_id': userId,
      'detected_at': detectedAt,
      'created_at': createdAt,
      'detection_data': detectionData,
      'ai_analysis_result': aiAnalysis,
      'context_data': contextData,
      'bounding_boxes': boundingBoxes,
      'image_url': imageUrl,
      'snapshot_id': snapshotId,
      'camera_id': cameraId,
      'lifecycle_state': lifecycleState,
    };
  }

  dynamic _toJsonEncodable(dynamic v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((key, value) {
        out[key.toString()] = _toJsonEncodable(value);
      });
      return out;
    }
    if (v is Iterable) return v.map(_toJsonEncodable).toList();
    try {
      final maybe = v.toString();
      return maybe;
    } catch (_) {
      return '$v';
    }
  }

  Future<String?> _getEventImageUrlBySnapshotId(String? snapshotId) async {
    if (snapshotId == null || snapshotId.isEmpty) return null;
    try {
      final snap = await _supabase
          .from('snapshots')
          .select('cloud_url,image_path')
          .eq('snapshot_id', snapshotId)
          .maybeSingle();

      if (snap == null) return null;
      final cloud = snap['cloud_url'] as String?;
      if (cloud != null && cloud.isNotEmpty) return cloud;

      final path = snap['image_path'] as String?;
      return _imageUrlFromPath(path);
    } catch (e) {
      debugPrint('⚠️ _getEventImageUrlBySnapshotId error: $e');
      return null;
    }
  }

  Future<String?> _imageUrlFromPath(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    const bucket = 'events';
    try {
      final String signedUrl = await _supabase.storage
          .from(bucket)
          .createSignedUrl(imagePath, 3600);
      return signedUrl;
    } catch (_) {
      final pub = _supabase.storage.from(bucket).getPublicUrl(imagePath);
      return pub;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentEvents({int limit = 20}) async {
    try {
      final select =
          'event_id,event_type,confidence_score,detected_at,status,lifecycle_state,snapshot_id, '
          'event_description,notes,created_at,detection_data,ai_analysis_result,context_data,bounding_boxes, '
          'confirm_status,confirmation_state,pending_until,proposed_status,proposed_event_type,proposed_reason,proposed_by, '
          'verified_at,verified_by,acknowledged_at,acknowledged_by,dismissed_at,user_id,camera_id';
      // 'snapshots(cloud_url,image_path,captured_at)';

      final rows = await _supabase
          .from('event_detections')
          .select(select)
          .order('detected_at', ascending: false)
          .limit(limit);

      final events = await Future.wait(
        (rows as List).map((e) => _mapEventToMobile(e as Map<String, dynamic>)),
      );

      return events;
    } catch (e) {
      debugPrint('Error fetching recent events: $e');
      return [];
    }
  }

  void dispose() {
    if (_healthcareChannel != null) {
      debugPrint('🔌 Disposing Supabase Realtime connection...');
      _healthcareChannel!.unsubscribe();
      _healthcareChannel = null;
    }
  }
}
