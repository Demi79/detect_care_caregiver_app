import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';

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
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // GET /cameras/:camera_id
  Future<CameraEntry> getCameraDetail(String cameraId) async {
    final res = await apiClient.get('/cameras/$cameraId');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return CameraEntry.fromJson(data['data']);
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
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // DELETE /cameras/:camera_id
  Future<void> deleteCamera(String cameraId) async {
    await apiClient.delete('/cameras/$cameraId');
  }

  // POST /cameras
  Future<Map<String, dynamic>> createCamera(Map<String, dynamic> data) async {
    final res = await apiClient.post('/cameras', body: data);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Tạo camera thất bại: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }
}
