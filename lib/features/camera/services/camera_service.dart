import 'dart:async';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  final CameraApi _cameraApi;
  final CameraQuotaService _quotaService;

  CameraService()
    : _cameraApi = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      ),
      _quotaService = CameraQuotaService();

  Future<List<CameraEntry>> loadCameras() async {
    try {
      final userId = await AuthStorage.getUserId();
      final result = await _cameraApi.getCamerasByUser(userId: userId ?? '');
      final List<dynamic> data = result['data'] ?? [];
      return data.map((e) => CameraEntry.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách camera: $e');
    }
  }

  Future<CameraEntry> createCamera(Map<String, dynamic> cameraData) async {
    try {
      final userId = await AuthStorage.getUserId();
      if (userId != null) {
        final cameras = await loadCameras();
        final validationResult = await _quotaService.canAddCamera(
          cameras.length,
        );

        if (!validationResult.canAdd) {
          throw Exception(validationResult.message ?? 'Không thể thêm camera');
        }
      }

      final result = await _cameraApi.createCamera(cameraData);
      return CameraEntry.fromJson(result);
    } catch (e) {
      throw Exception('Không thể tạo camera: $e');
    }
  }

  Future<CameraEntry> updateCamera(
    String cameraId,
    Map<String, dynamic> cameraData,
  ) async {
    try {
      final allowedUpdates = <String>{
        'camera_name',
        'camera_type',
        'ip_address',
        'port',
        'rtsp_url',
        'username',
        'password',
        'location_in_room',
        'resolution',
        'fps',
        'status',
        'updated_at',
      };

      final filtered = <String, dynamic>{};
      for (final entry in cameraData.entries) {
        if (allowedUpdates.contains(entry.key) && entry.value != null) {
          filtered[entry.key] = entry.value;
        }
      }

      filtered.putIfAbsent(
        'updated_at',
        () => DateTime.now().toIso8601String(),
      );

      debugPrint(
        '[CameraService] Updating camera $cameraId with (filtered): $filtered',
      );
      final result = await _cameraApi.updateCamera(cameraId, filtered);
      debugPrint('[CameraService] Update response: $result');
      final payload = result['data'] is Map ? result['data'] : result;
      return CameraEntry.fromJson(payload);
    } catch (e) {
      debugPrint('[CameraService] Error updating camera $cameraId: $e');
      if (kDebugMode) {
        throw Exception('Không thể cập nhật camera: $e');
      }
      throw Exception('Không thể cập nhật camera');
    }
  }

  Future<void> deleteCamera(String cameraId) async {
    try {
      await _cameraApi.deleteCamera(cameraId);
    } catch (e) {
      throw Exception('Không thể xóa camera: $e');
    }
  }

  Future<void> refreshThumbnails(List<String> cameraIds) async {
    debugPrint('Thumbnail refresh requested for ${cameraIds.length} cameras');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  String cacheBustThumb(String? thumb) {
    if (thumb == null || thumb.isEmpty || !thumb.startsWith('http')) {
      return thumb ?? '';
    }

    final uri = Uri.parse(thumb);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['t'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  List<CameraEntry> filterAndSortCameras(
    List<CameraEntry> cameras,
    String searchQuery,
    bool sortAscending,
  ) {
    if (cameras.isEmpty) return const [];

    var filtered = cameras;
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((camera) => camera.name.toLowerCase().contains(query))
          .toList();
    }

    filtered.sort((a, b) {
      final comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<CameraEntry> replaceCamera(
    String cameraId,
    Map<String, dynamic> cameraData,
  ) async {
    try {
      final data = Map<String, dynamic>.from(cameraData);
      data.putIfAbsent('updated_at', () => DateTime.now().toIso8601String());

      debugPrint(
        '[CameraService] Replacing camera $cameraId with (PUT): $data',
      );
      final result = await _cameraApi.putUpdateCamera(cameraId, data);
      debugPrint('[CameraService] Replace response: $result');
      final payload = result['data'] is Map ? result['data'] : result;
      return CameraEntry.fromJson(payload);
    } catch (e) {
      debugPrint('[CameraService] Error replacing camera $cameraId: $e');
      if (kDebugMode) {
        throw Exception('Không thể thay thế camera: $e');
      }
      throw Exception('Không thể cập nhật camera');
    }
  }
}
