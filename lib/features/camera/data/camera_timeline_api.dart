import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:http/http.dart' as http;

/// Lớp cung cấp API timeline/snapshot/Event cho camera – mỗi bước đều được chú thích.
class CameraTimelineApi {
  CameraTimelineApi({ApiClient? client})
    : _client = client ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  final ApiClient _client;
  static const String _kDateParam = 'date';
  static const String _kTzParam = 'tz';

  /// Bước 1: Lấy danh sách bản ghi theo ngày (có hỗ trợ page/limit/extra query).
  Future<Map<String, dynamic>> listRecordings(
    String cameraId, {
    required String date,
    String? tz,
    int? page,
    int? limit,
    Map<String, dynamic>? extraQuery,
  }) async {
    return _getMap(
      '/cameras/$cameraId/recordings',
      query: _mergeQuery(
        {
          'date': date,
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
          'all': true,
          ...?extraQuery,
        },
        date: date,
        tz: tz,
      ),
    );
  }

  /// Bước 2: Lấy chi tiết một bản ghi (metadata + URL phát).
  Future<Map<String, dynamic>> getRecordingDetail(String recordingId) async {
    return _getMap('/recordings/$recordingId');
  }

  /// Bước 3: Lấy binary/response thumbnail cho bản ghi (trả về Response gốc).
  Future<http.Response> getRecordingThumbnail(String recordingId) async {
    final res = await _client.get('/recordings/$recordingId/thumbnail');
    _ensureSuccess(res);
    return res;
  }

  /// Một helper bổ sung: nếu backend trả thumbnail dưới dạng JSON
  /// (ví dụ { "thumbnail_url": "https://..." }), FE có thể dùng
  /// method này để nhận Map đã giải mã thay vì xử lý http.Response thô.
  Future<Map<String, dynamic>> getRecordingThumbnailJson(
    String recordingId,
  ) async {
    return _getMap('/recordings/$recordingId/thumbnail');
  }

  /// Bước 4: Lấy danh sách snapshot theo ngày.
  Future<Map<String, dynamic>> listSnapshots(
    String cameraId, {
    required String date,
    String? tz,
  }) async {
    return _getMap(
      '/cameras/$cameraId/snapshots',
      query: _mergeQuery(const {}, date: date, tz: tz),
    );
  }

  /// Bước 5: Lấy danh sách sự kiện camera theo ngày.
  Future<Map<String, dynamic>> listEvents(
    String cameraId, {
    required String date,
    String? tz,
  }) async {
    return _getMap(
      '/cameras/$cameraId/events',
      query: _mergeQuery(const {}, date: date, tz: tz),
    );
  }

  /// Bước 6: Lấy lịch những ngày có bản ghi (dạng YYYY-MM).
  Future<Map<String, dynamic>> getCalendar(
    String cameraId, {
    required String month,
  }) async {
    return _getMap(
      '/cameras/$cameraId/recordings/calendar',
      query: {'month': month},
    );
  }

  /// Bước 7: Lấy heatmap số bản ghi theo giờ trong ngày.
  Future<Map<String, dynamic>> getHeatmap(
    String cameraId, {
    required String date,
  }) async {
    return _getMap(
      '/cameras/$cameraId/recordings/heatmap',
      query: {'date': date},
    );
  }

  /// Helper: đảm bảo response thành công; log và throw nếu lỗi.
  void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    AppLogger.apiError(
      'CameraTimelineApi request failed (${res.statusCode}): ${res.body}',
    );
    throw Exception('Camera timeline request failed (${res.statusCode})');
  }

  /// Helper: Chuẩn hoá payload về Map để UI dễ dùng.
  Map<String, dynamic> _wrapData(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is List) return {'items': payload};
    return {'data': payload};
  }

  /// Helper: GET chung, ghép query, check lỗi, trả Map.
  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _client.get(path, query: query);
    _ensureSuccess(res);

    final raw = _client.extractDataFromResponse(res);

    // Log a concise preview of the payload to help debugging runtime shapes.
    try {
      if (raw is Map) {
        final keys = raw.keys.join(', ');
        final buffers = <String>[];
        raw.forEach((k, v) {
          if (v is List) {
            buffers.add('$k(list:${v.length})');
          } else if (v is Map) {
            buffers.add('$k(map:${v.keys.length})');
          } else {
            buffers.add(k);
          }
        });
        AppLogger.api(
          'GET $path -> keys: $keys; summary: ${buffers.join(', ')}',
        );
      } else if (raw is List) {
        AppLogger.api('GET $path -> list(${raw.length})');
      } else {
        AppLogger.api('GET $path -> payload type: ${raw.runtimeType}');
      }

      // small preview (truncated)
      final preview = jsonEncode(raw);
      if (preview.length > 2000) {
        AppLogger.api(
          'GET $path -> preview: ${preview.substring(0, 2000)}... (truncated)',
        );
      } else {
        AppLogger.api('GET $path -> preview: $preview');
      }
    } catch (e, st) {
      AppLogger.api('GET $path -> failed to stringify preview: $e', e, st);
    }

    return _wrapData(raw);
  }

  Map<String, dynamic> _mergeQuery(
    Map<String, dynamic> base, {
    required String date,
    String? tz,
  }) {
    final query = <String, dynamic>{_kDateParam: date, ...base};
    if (tz != null && tz.isNotEmpty) {
      query[_kTzParam] = tz;
    }
    return query;
  }
}
