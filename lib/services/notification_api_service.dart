import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/models/notification.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class NotificationApiService {
  final ApiClient _apiClient;

  NotificationApiService({ApiClient? apiClient})
    : _apiClient =
          apiClient ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  /// Lấy danh sách notifications với pagination và filtering
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 20,
    NotificationFilter? filter,
    String? searchQuery,
  }) async {
    debugPrint(
      '🔔 NotificationApiService: getNotifications called with page=$page, pageSize=$pageSize',
    );
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      // Thêm filter params
      if (filter != null) {
        queryParams.addAll(filter.toQueryParams());
      }

      // Thêm search query
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      final response = await _apiClient.get(
        '/notifications',
        query: queryParams,
      );

      if (response.statusCode == 200) {
        final data = _apiClient.extractDataFromResponse(response);
        debugPrint('🔔 Notification API Response: $data');

        // Handle API response format: { success, data, message, timestamp }
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final actualData = data['data'];
          if (actualData is Map<String, dynamic>) {
            return NotificationListResponse.fromJson(actualData);
          } else {
            // If data is not a map, assume it's the direct response
            return NotificationListResponse.fromJson(data);
          }
        } else {
          // Fallback for direct response format
          return NotificationListResponse.fromJson(data);
        }
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      throw Exception('Không thể tải danh sách thông báo: $e');
    }
  }

  /// Lấy chi tiết một notification
  Future<NotificationModel> getNotification(String notificationId) async {
    try {
      final response = await _apiClient.get('/notifications/$notificationId');

      if (response.statusCode == 200) {
        final data = _apiClient.extractDataFromResponse(response);
        return NotificationModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy thông báo');
      } else {
        throw Exception('Failed to load notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notification $notificationId: $e');
      throw Exception('Không thể tải thông báo: $e');
    }
  }

  /// Đánh dấu notification đã đọc
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiClient.patch(
        '/notifications/$notificationId/read',
        body: {'is_read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to mark notification as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error marking notification $notificationId as read: $e');
      throw Exception('Không thể đánh dấu đã đọc: $e');
    }
  }

  /// Đánh dấu notification chưa đọc
  Future<bool> markAsUnread(String notificationId) async {
    try {
      final response = await _apiClient.patch(
        '/notifications/$notificationId/read',
        body: {'is_read': false},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to mark notification as unread: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error marking notification $notificationId as unread: $e');
      throw Exception('Không thể đánh dấu chưa đọc: $e');
    }
  }

  /// Xóa một notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      // Include user identifier if available for backend validation/audit
      final userId = await AuthStorage.getUserId();
      final trimmed = (userId ?? '').trim();

      final query = trimmed.isNotEmpty ? {'user_id': trimmed} : null;
      final extraHeaders = trimmed.isNotEmpty ? {'X-User-Id': trimmed} : null;

      final response = await _apiClient.delete(
        '/notifications/$notificationId',
        query: query,
        extraHeaders: extraHeaders,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception(
          'Failed to delete notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification $notificationId: $e');
      throw Exception('Không thể xóa thông báo: $e');
    }
  }

  /// Đánh dấu tất cả notifications đã đọc
  Future<bool> markAllAsRead() async {
    try {
      final userId = await AuthStorage.getUserId();
      final rawUserId = userId ?? '';
      final trimmed = rawUserId.trim();

      // UUIDv4 regex (ensure correct version/variant positions)
      final uuidV4Regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      );
      debugPrint('🔔 markAllAsRead userId raw: "$rawUserId"');
      debugPrint(
        '🔔 markAllAsRead userId trimmed: "$trimmed" (length=${trimmed.length})',
      );
      debugPrint(
        '🔔 markAllAsRead userId matches v4 regex: ${uuidV4Regex.hasMatch(trimmed)}',
      );
      debugPrint(
        '🔔 markAllAsRead userId codeUnits: ${trimmed.codeUnits.map((c) => c.toRadixString(16)).toList()}',
      );

      final query = trimmed.isNotEmpty ? {'user_id': trimmed} : null;
      final extraHeaders = trimmed.isNotEmpty ? {'X-User-Id': trimmed} : null;

      final response = await _apiClient.patch(
        '/notifications/mark-all-read',
        query: query,
        extraHeaders: extraHeaders,
        body: {},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      throw Exception('Không thể đánh dấu tất cả đã đọc: $e');
    }
  }

  /// Xóa nhiều notifications
  Future<bool> deleteMultipleNotifications(List<String> notificationIds) async {
    try {
      final response = await _apiClient.delete(
        '/notifications/batch',
        query: {'ids': notificationIds.join(',')},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception(
          'Failed to delete notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting multiple notifications: $e');
      throw Exception('Không thể xóa thông báo: $e');
    }
  }

  /// Lấy số lượng notifications chưa đọc
  Future<int> getUnreadCount() async {
    try {
      // Include user identifier to satisfy backend UUID validation
      final userId = await AuthStorage.getUserId();
      final rawUserId = userId ?? '';
      final trimmed = rawUserId.trim();
      if (trimmed.isEmpty) {
        debugPrint('🔔 NotificationApiService: no userId, returning 0 unread');
        return 0;
      }

      // Debug: ensure userId looks like UUID v4
      final uuidV4Regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      );
      debugPrint('🔔 getUnreadCount userId raw: "$rawUserId"');
      debugPrint(
        '🔔 getUnreadCount userId trimmed: "$trimmed" (length=${trimmed.length})',
      );
      debugPrint(
        '🔔 getUnreadCount userId matches v4 regex: ${uuidV4Regex.hasMatch(trimmed)}',
      );
      debugPrint(
        '🔔 getUnreadCount userId codeUnits: ${trimmed.codeUnits.map((c) => c.toRadixString(16)).toList()}',
      );

      final response = await _apiClient.get(
        '/notifications/unread-count',
        query: {'user_id': trimmed},
        extraHeaders: {'X-User-Id': trimmed},
      );

      if (response.statusCode == 200) {
        final data = _apiClient.extractDataFromResponse(response);
        return data['count'] ?? 0;
      } else {
        throw Exception('Failed to get unread count: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0; // Return 0 on error to avoid breaking UI
    }
  }

  /// Tạo notification mới (cho admin/caregiver)
  Future<NotificationModel> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? patientId,
    Map<String, dynamic>? metadata,
    String? actionUrl,
    int? priority,
  }) async {
    try {
      final body = {
        'title': title,
        'message': message,
        'type': type.value,
        'patient_id': patientId,
        'metadata': metadata,
        'action_url': actionUrl,
        'priority': priority ?? 0,
      };

      final response = await _apiClient.post('/notifications', body: body);

      if (response.statusCode == 201) {
        final data = _apiClient.extractDataFromResponse(response);
        return NotificationModel.fromJson(data);
      } else {
        throw Exception(
          'Failed to create notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error creating notification: $e');
      throw Exception('Không thể tạo thông báo: $e');
    }
  }

  /// Cập nhật notification
  Future<NotificationModel> updateNotification(
    String notificationId, {
    String? title,
    String? message,
    NotificationType? type,
    Map<String, dynamic>? metadata,
    String? actionUrl,
    int? priority,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (title != null) body['title'] = title;
      if (message != null) body['message'] = message;
      if (type != null) body['type'] = type.value;
      if (metadata != null) body['metadata'] = metadata;
      if (actionUrl != null) body['action_url'] = actionUrl;
      if (priority != null) body['priority'] = priority;

      final response = await _apiClient.patch(
        '/notifications/$notificationId',
        body: body,
      );

      if (response.statusCode == 200) {
        final data = _apiClient.extractDataFromResponse(response);
        return NotificationModel.fromJson(data);
      } else {
        throw Exception(
          'Failed to update notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error updating notification $notificationId: $e');
      throw Exception('Không thể cập nhật thông báo: $e');
    }
  }

  /// Lấy notifications theo patient
  Future<NotificationListResponse> getNotificationsByPatient(
    String patientId, {
    int page = 1,
    int pageSize = 20,
    NotificationFilter? filter,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'patient_id': patientId,
      };

      // Thêm filter params
      if (filter != null) {
        queryParams.addAll(filter.toQueryParams());
      }

      final response = await _apiClient.get(
        '/patients/$patientId/notifications',
        query: queryParams,
      );

      if (response.statusCode == 200) {
        final data = _apiClient.extractDataFromResponse(response);
        return NotificationListResponse.fromJson(data);
      } else {
        throw Exception(
          'Failed to load patient notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching notifications for patient $patientId: $e');
      throw Exception('Không thể tải thông báo của bệnh nhân: $e');
    }
  }

  /// Lấy thống kê notifications
  Future<Map<String, dynamic>> getNotificationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await _apiClient.get(
        '/notifications/stats',
        query: queryParams,
      );

      if (response.statusCode == 200) {
        return _apiClient.extractDataFromResponse(response);
      } else {
        throw Exception(
          'Failed to load notification stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching notification stats: $e');
      throw Exception('Không thể tải thống kê thông báo: $e');
    }
  }
}
