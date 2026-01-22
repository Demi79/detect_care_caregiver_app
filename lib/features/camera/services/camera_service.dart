import 'dart:async';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_timeline_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_parser.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  final CameraApi _cameraApi;
  final CameraQuotaService _quotaService;
  final CameraTimelineApi _timelineApi;

  CameraService()
    : _cameraApi = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      ),
      _quotaService = CameraQuotaService(ServicePackageApi()),
      _timelineApi = CameraTimelineApi();

  Future<List<CameraEntry>> loadCameras() async {
    try {
      String? customerId;
      try {
        final assignmentsDs = AssignmentsRemoteDataSource();
        final assignments = await assignmentsDs.listPending(status: 'accepted');
        final active = assignments
            .where((a) => a.isActive && (a.status.toLowerCase() == 'accepted'))
            .toList();
        if (active.isNotEmpty) customerId = active.first.customerId;
      } catch (_) {}

      customerId ??= await AuthStorage.getUserId();

      if (customerId == null || customerId.isEmpty) {
        throw Exception(
          'Không thể xác định người dùng để lấy danh sách camera.',
        );
      }

      final api = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );

      final result = await _cameraApi.getCamerasByUser(userId: customerId);
      final List<dynamic> data = result['data'] ?? [];
      return data.map((e) => CameraEntry.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách camera: $e');
    }
  }

  Future<CameraEntry> createCamera(Map<String, dynamic> cameraData) async {
    try {
      // Validate camera quota before creating
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
      // Only send allowed updatable fields to backend to avoid validation errors
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

      // Ensure updated_at is set
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
      // Surface detailed message for debug, but keep user-facing message concise
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
    // Method placeholder - implement when CameraApi supports this
    if (kDebugMode) {
      debugPrint('Thumbnail refresh requested for ${cameraIds.length} cameras');
    }
    // TODO: Implement actual thumbnail refresh when API supports it
    // For now, just add a small delay to simulate network call
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Refresh thumbnail for a camera after user exits live view
  /// This triggers the backend to create a new snapshot request
  Future<String?> refreshCameraThumbnail(String cameraId) async {
    try {
      final response = await _cameraApi.refreshThumbnail(cameraId);

      // Extract thumbnail URL from response
      final thumbnailUrl = response['thumbnail_url'] as String?;
      final status = response['status'] as String?;

      if (status == 'success' && thumbnailUrl != null) {
        return thumbnailUrl;
      }

      // If error but has old thumbnail, return it
      if (status == 'error' && thumbnailUrl != null) {
        debugPrint('Camera offline, using cached thumbnail for $cameraId');
        return thumbnailUrl;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to refresh thumbnail for $cameraId: $e');
      return null;
    }
  }

  /// Get latest thumbnail without triggering new capture
  /// Used for quick display in camera list
  Future<String?> getLatestThumbnail(String cameraId) async {
    try {
      final response = await _cameraApi.getLatestThumbnail(cameraId);
      return response['thumbnail_url'] as String?;
    } catch (e) {
      debugPrint('Failed to get latest thumbnail for $cameraId: $e');
      return null;
    }
  }

  @Deprecated('Use refreshCameraThumbnail or getLatestThumbnail instead')
  Future<String?> fetchTimelineThumbnail(String cameraId) async {
    try {
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final data = await _timelineApi.listRecordings(
        cameraId,
        date: dateStr,
        limit: 1,
      );
      final clips = parseRecordingClips(data);
      if (clips.isEmpty) return null;
      final clip = clips.firstWhere(
        (c) => c.thumbnailUrl?.isNotEmpty == true,
        orElse: () => clips.first,
      );
      return clip.thumbnailUrl;
    } catch (e) {
      debugPrint('Timeline thumbnail fetch failed for $cameraId: $e');
      return null;
    }
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

  /// Replace a camera record entirely (PUT /cameras/:camera_id)
  /// Use when the backend expects a full entity replacement rather than a partial update.
  Future<CameraEntry> replaceCamera(
    String cameraId,
    Map<String, dynamic> cameraData,
  ) async {
    try {
      // Prepare payload and ensure updated_at exists
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
