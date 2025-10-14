import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:flutter/foundation.dart';

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
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response for getCamerasByUser: ${res.body}');
    }
    return decoded;
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
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response for getCameras: ${res.body}');
    }
    return decoded;
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
    debugPrint('🔁 [CameraApi] PATCH /cameras/$cameraId');
    debugPrint('🔁 [CameraApi] Request body: $data');

    final res = await apiClient.patch('/cameras/$cameraId', body: data);

    debugPrint('🔁 [CameraApi] Response status: ${res.statusCode}');
    debugPrint('🔁 [CameraApi] Response body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Cập nhật camera thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected update camera response: ${res.body}');
    }
    return decoded;
  }

  // PUT /cameras/:camera_id (full update)
  Future<Map<String, dynamic>> putUpdateCamera(
    String cameraId,
    Map<String, dynamic> data,
  ) async {
    debugPrint('🔁 [CameraApi] PUT /cameras/$cameraId');
    debugPrint('🔁 [CameraApi] Request body (PUT): $data');

    final res = await apiClient.put('/cameras/$cameraId', body: data);

    debugPrint('🔁 [CameraApi] Response status (PUT): ${res.statusCode}');
    debugPrint('🔁 [CameraApi] Response body (PUT): ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Cập nhật camera thất bại (PUT): ${res.statusCode} ${res.body}',
      );
    }

    final decoded = apiClient.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected put update camera response: ${res.body}');
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
}
