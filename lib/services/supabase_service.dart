import 'package:detect_care_caregiver_app/core/alerts/alert_coordinator.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:flutter/foundation.dart';
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

    _healthcareChannel = _supabase.channel('healthcare_events');

    _healthcareChannel =
        _healthcareChannel!.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_detections',
          callback: (payload) async {
            final row = payload.newRecord;

            final mobileEvent = await _mapEventToMobile(row);

            debugPrint(
              '📥 New event: ${mobileEvent['event_type']} '
              '@${mobileEvent['detected_at']} (id=${mobileEvent['event_id']})',
            );

            AlertCoordinator.handle(EventLog.fromJson(mobileEvent));
            onEventReceived(mobileEvent);
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
    final eventType = s(raw['event_type']) ?? '';
    final confidenceScore = d(raw['confidence_score']);
    final detectedAt = iso(raw['detected_at']);
    final createdAt = iso(raw['created_at']);
    final status = s(raw['status']) ?? 'detected';

    String? imageUrl;
    if (raw['snapshots'] is Map) {
      final snapshotsMap = raw['snapshots'] as Map;
      final cloudUrl = snapshotsMap['cloud_url'];
      final imagePath = snapshotsMap['image_path'];
      imageUrl = s(cloudUrl) ?? await _imageUrlFromPath(s(imagePath));
    } else {
      imageUrl = await _getEventImageUrlBySnapshotId(snapshotId);
    }

    return {
      'event_id': eventId,
      'event_type': eventType,
      'event_description': s(raw['event_description']),
      'confidence_score': confidenceScore,
      'status': status,
      'detected_at': detectedAt,
      'created_at': createdAt,
      'detection_data': raw['detection_data'] ?? const {},
      'ai_analysis_result': raw['ai_analysis_result'] ?? const {},
      'context_data': raw['context_data'] ?? const {},
      'bounding_boxes': raw['bounding_boxes'] ?? const {},
      'image_url': imageUrl,
      'snapshot_id': snapshotId,
    };
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
          'event_id,event_type,confidence_score,detected_at,status,snapshot_id,'
          'event_description,created_at,detection_data,ai_analysis_result,context_data,bounding_boxes,';
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
