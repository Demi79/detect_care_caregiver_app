import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import '../models/camera_entry.dart';

class CameraApi {
  final ApiClient apiClient;
  CameraApi(this.apiClient);

  // GET /cameras
  Future<Map<String, dynamic>> getCamerasByUser({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await apiClient.get(
      '/cameras/by-user/$userId',
      query: {'page': page, 'limit': limit},
    );
    final decoded = apiClient.extractDataFromResponse(res);
    return _normalizeResponse(decoded);
  }

  // GET /cameras/:camera_id
  Future<CameraEntry> getCameraDetail(String cameraId) async {
    final res = await apiClient.get('/cameras/$cameraId');
    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic> || decoded['data'] == null) {
      throw Exception('Unexpected camera detail response: ${res.body}');
    }
    return CameraEntry.fromJson(decoded['data']);
  }

  // GET /cameras/:camera_id/events
  Future<Map<String, dynamic>> getCameraEvents(
    String cameraId, {
    int page = 1,
    int limit = 20,
    String? dateFrom,
    String? dateTo,
    String? type,
    String? status,
    String? severity,
    String orderBy = 'detected_at',
    String order = 'DESC',
  }) async {
    final res = await apiClient.get(
      '/cameras/$cameraId/events',
      query: {
        'page': page,
        'limit': limit,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (severity != null) 'severity': severity,
        'orderBy': orderBy,
        'order': order,
      },
    );
    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected camera events response: ${res.body}');
    }
    return decoded;
  }

  // DELETE /cameras/:camera_id
  Future<void> deleteCamera(String cameraId) async {
    await apiClient.delete('/cameras/$cameraId');
  }

  // GET /cameras (admin listing)
  Future<Map<String, dynamic>> getCameras({
    int? page,
    int? limit,
    bool reportedOnly = false,
  }) async {
    final query = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (reportedOnly) 'reportedOnly': 'true',
    };
    final res = await apiClient.get('/cameras', query: query);
    final decoded = apiClient.extractDataFromResponse(res);
    return _normalizeResponse(decoded);
  }

  Map<String, dynamic> _normalizeResponse(dynamic decoded) {
    if (decoded == null) return <String, dynamic>{'data': <dynamic>[]};
    if (decoded is List) return <String, dynamic>{'data': decoded};
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{
      'data': [decoded],
    };
  }

  // POST /cameras
  Future<Map<String, dynamic>> createCamera(Map<String, dynamic> data) async {
    final res = await apiClient.post('/cameras', body: data);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Tạo camera thất bại: ${res.statusCode} ${res.body}');
    }
    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected create camera response: ${res.body}');
    }
    return decoded;
  }

  // PATCH /cameras/:camera_id (partial update)
  Future<Map<String, dynamic>> updateCamera(
    String cameraId,
    Map<String, dynamic> data,
  ) async {
    // Debug: log request payload
    AppLogger.api(
      '🔁 [CameraApi] PATCH /cameras/$cameraId - Yêu cầu cập nhật camera',
    );
    AppLogger.api('🔁 [CameraApi] Thân yêu cầu (body): $data');

    final res = await apiClient.patch('/cameras/$cameraId', body: data);

    // Ghi log phản hồi để dễ chẩn đoán
    AppLogger.api('🔁 [CameraApi] Trạng thái phản hồi: ${res.statusCode}');
    AppLogger.api('🔁 [CameraApi] Thân phản hồi: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError(
        '❌ Cập nhật camera thất bại: ${res.statusCode} ${res.body}',
      );
      throw Exception('Cập nhật camera thất bại: ${res.statusCode}');
    }

    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      AppLogger.apiError(
        '❌ Phản hồi cập nhật camera không hợp lệ: ${res.body}',
      );
      throw Exception('Phản hồi cập nhật camera không hợp lệ');
    }
    return decoded;
  }

  // PUT /cameras/:camera_id (full update)
  Future<Map<String, dynamic>> putUpdateCamera(
    String cameraId,
    Map<String, dynamic> data,
  ) async {
    AppLogger.api(
      '🔁 [CameraApi] PUT /cameras/$cameraId - Yêu cầu cập nhật full',
    );
    AppLogger.api('🔁 [CameraApi] Thân yêu cầu (PUT): $data');

    final res = await apiClient.put('/cameras/$cameraId', body: data);

    AppLogger.api(
      '🔁 [CameraApi] Trạng thái phản hồi (PUT): ${res.statusCode}',
    );
    AppLogger.api('🔁 [CameraApi] Thân phản hồi (PUT): ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError(
        '❌ Cập nhật camera thất bại (PUT): ${res.statusCode} ${res.body}',
      );
      throw Exception('Cập nhật camera thất bại (PUT): ${res.statusCode}');
    }

    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      AppLogger.apiError(
        '❌ Phản hồi PUT cập nhật camera không hợp lệ: ${res.body}',
      );
      throw Exception('Phản hồi PUT cập nhật camera không hợp lệ');
    }
    return decoded;
  }

  // GET /cameras/:camera_id/issues
  Future<Map<String, dynamic>> getCameraIssues(String cameraId) async {
    final res = await apiClient.get('/cameras/$cameraId/issues');
    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response for getCameraIssues: ${res.body}');
    }
    return decoded;
  }

  // POST /cameras/:camera_id/thumbnail/refresh
  /// Refresh thumbnail for a specific camera after user exits live view
  /// Returns the latest thumbnail URL (either new or cached)
  Future<Map<String, dynamic>> refreshThumbnail(String cameraId) async {
    try {
      final res = await apiClient.post(
        '/cameras/$cameraId/thumbnail/refresh',
        body: {},
      );
      final decoded = apiClient.extractDataFromResponse(res);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected thumbnail refresh response: ${res.body}');
      }
      return decoded;
    } catch (e) {
      AppLogger.apiError('❌ Failed to refresh thumbnail for $cameraId: $e');
      rethrow;
    }
  }

  // GET /cameras/:camera_id/thumbnail/latest
  /// Get the latest available thumbnail without triggering a new capture
  Future<Map<String, dynamic>> getLatestThumbnail(String cameraId) async {
    try {
      final res = await apiClient.get('/cameras/$cameraId/thumbnail/latest');
      final decoded = apiClient.extractDataFromResponse(res);
      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Unexpected get latest thumbnail response: ${res.body}',
        );
      }
      return decoded;
    } catch (e) {
      AppLogger.apiError('❌ Failed to get latest thumbnail for $cameraId: $e');
      rethrow;
    }
  }
}
