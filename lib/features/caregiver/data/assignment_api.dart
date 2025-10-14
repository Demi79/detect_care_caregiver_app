import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:flutter/cupertino.dart';

class AssignmentApi {
  final ApiClient _api;
  AssignmentApi(this._api);

  /// Lấy danh sách assignments của customer hiện tại (GET /assignments/customer/me)
  /// Trả về danh sách assignments với thông tin caregiver
  /// Lấy danh sách assignments của customer hiện tại (GET /assignments/customer/me)
  /// Trả về danh sách assignments với thông tin caregiver
  ///
  /// Expected response shape:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": [
  ///     {
  ///       "id": "assignment_id_123",
  ///       "caregiver_id": "caregiver_id_456",
  ///       "customer_id": "customer_id_789",
  ///       "assignment_type": "daily_care|emergency_care|specialized_care",
  ///       "status": "pending|active|completed|cancelled",
  ///       "notes": "Additional notes about the assignment",
  ///       "created_at": "2024-01-15T10:30:00Z",
  ///       "updated_at": "2024-01-15T10:30:00Z",
  ///       "caregiver_name": "Nguyễn Văn A",
  ///       "caregiver_phone": "+84 123 456 789",
  ///       "caregiver_email": "caregiver@example.com",
  ///       "caregiver_specialization": "general_care|elderly_care|disabled_care"
  ///     }
  ///   ]
  /// }
  /// ```
  ///
  /// Error response:
  /// ```json
  /// {
  ///   "success": false,
  ///   "error": {
  ///     "code": "ASSIGNMENT_NOT_FOUND",
  ///     "message": "No assignments found for this customer"
  ///   }
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getMyAssignments() async {
    final res = await _api.get('/caregiver-invitations/customer/me');
    if (res.statusCode != 200) {
      throw Exception(
        'Lấy danh sách assignments thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Get my assignments response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Get assignments failed';
        debugPrint(
          '❌ AssignmentApi: Get assignments failed with error: $code - $message',
        );
        throw Exception('Lấy danh sách assignments thất bại: $code - $message');
      } else {
        debugPrint(
          '❌ AssignmentApi: Get assignments failed with unknown error format',
        );
        throw Exception(
          'Lấy danh sách assignments thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    // Extract data from response - could be in 'data' key or directly in response
    final dynamic data;
    if (response.containsKey('data')) {
      data = response['data'];
      debugPrint(
        '📦 AssignmentApi: Assignments data extracted from response.data',
      );
    } else {
      data = response;
      debugPrint(
        '📦 AssignmentApi: Assignments data extracted directly from response',
      );
    }

    // Trả về danh sách assignments
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu assignments trả về không hợp lệ');
  }

  /// Lấy danh sách assignments của customer hiện tại theo status (GET /assignments/customer/me?status=...)
  /// Trả về danh sách assignments với thông tin caregiver
  ///
  /// Parameters:
  /// - status: Filter assignments by status ('pending', 'active', 'completed', 'cancelled')
  ///
  /// Expected response shape: Same as getMyAssignments()
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": [
  ///     {
  ///       "id": "assignment_id_123",
  ///       "caregiver_id": "caregiver_id_456",
  ///       "customer_id": "customer_id_789",
  ///       "assignment_type": "daily_care|emergency_care|specialized_care",
  ///       "status": "pending|active|completed|cancelled",
  ///       "notes": "Additional notes about the assignment",
  ///       "created_at": "2024-01-15T10:30:00Z",
  ///       "updated_at": "2024-01-15T10:30:00Z",
  ///       "caregiver_name": "Nguyễn Văn A",
  ///       "caregiver_phone": "+84 123 456 789",
  ///       "caregiver_email": "caregiver@example.com",
  ///       "caregiver_specialization": "general_care|elderly_care|disabled_care"
  ///     }
  ///   ]
  /// }
  /// ```
  ///
  /// Error response: Same as getMyAssignments()
  Future<List<Map<String, dynamic>>> getMyAssignmentsByStatus(
    String status,
  ) async {
    final res = await _api.get(
      '/caregiver-invitations/customer/me',
      query: {'status': status},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Lấy danh sách assignments theo status thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Get my assignments by status response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Get assignments by status failed';
        debugPrint(
          '❌ AssignmentApi: Get assignments by status failed with error: $code - $message',
        );
        throw Exception(
          'Lấy danh sách assignments theo status thất bại: $code - $message',
        );
      } else {
        debugPrint(
          '❌ AssignmentApi: Get assignments by status failed with unknown error format',
        );
        throw Exception(
          'Lấy danh sách assignments theo status thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    // Extract data from response - could be in 'data' key or directly in response
    final dynamic data;
    if (response.containsKey('data')) {
      data = response['data'];
      debugPrint(
        '📦 AssignmentApi: Assignments by status data extracted from response.data',
      );
    } else {
      data = response;
      debugPrint(
        '📦 AssignmentApi: Assignments by status data extracted directly from response',
      );
    }

    // Trả về danh sách assignments
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu assignments trả về không hợp lệ');
  }

  /// Lấy danh sách assignments của caregiver hiện tại (GET /assignments/caregiver/me)
  /// Trả về danh sách assignments với thông tin customer
  /// Expected response shape:
  /// {
  ///   "success": true,
  ///   "data": [
  ///     {
  ///       "id": "assignment_id",
  ///       "customer_id": "uuid",
  ///       "caregiver_id": "uuid",
  ///       "customer_name": "Customer Name",
  ///       "customer_phone": "+1234567890",
  ///       "assignment_type": "General",
  ///       "status": "pending|active|completed",
  ///       "created_at": "2025-01-01T00:00:00Z",
  ///       "notes": "Optional notes"
  ///     }
  ///   ]
  /// }
  Future<List<Map<String, dynamic>>> getMyAssignmentsAsCaregiver() async {
    final res = await _api.get('/caregiver-invitations/caregiver/me');
    if (res.statusCode != 200) {
      throw Exception(
        'Lấy danh sách assignments thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Get my assignments as caregiver response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ??
            'Get assignments as caregiver failed';
        debugPrint(
          '❌ AssignmentApi: Get assignments as caregiver failed with error: $code - $message',
        );
        throw Exception('Lấy danh sách assignments thất bại: $code - $message');
      } else {
        debugPrint(
          '❌ AssignmentApi: Get assignments as caregiver failed with unknown error format',
        );
        throw Exception(
          'Lấy danh sách assignments thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    // Extract data from response - could be in 'data' key or directly in response
    final dynamic data;
    if (response.containsKey('data')) {
      data = response['data'];
      debugPrint(
        '📦 AssignmentApi: My assignments as caregiver data extracted from response.data',
      );
    } else {
      data = response;
      debugPrint(
        '📦 AssignmentApi: My assignments as caregiver data extracted directly from response',
      );
    }

    // Trả về danh sách assignments
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu assignments trả về không hợp lệ');
  }

  /// Lấy danh sách assignments accepted/active của customer hiện tại
  Future<List<Map<String, dynamic>>> getMyActiveAssignments() async {
    return getMyAssignmentsByStatus('active');
  }

  /// Lấy danh sách assignments theo customer ID (GET /assignments/by-customer/:id)
  /// Trả về danh sách assignments với thông tin caregiver cho một customer cụ thể
  ///
  /// Parameters:
  /// - customerId: ID của customer cần lấy assignments
  ///
  /// Expected response shape: Same as getMyAssignments()
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": [
  ///     {
  ///       "id": "assignment_id_123",
  ///       "caregiver_id": "caregiver_id_456",
  ///       "customer_id": "customer_id_789",
  ///       "assignment_type": "daily_care|emergency_care|specialized_care",
  ///       "status": "pending|active|completed|cancelled",
  ///       "notes": "Additional notes about the assignment",
  ///       "created_at": "2024-01-15T10:30:00Z",
  ///       "updated_at": "2024-01-15T10:30:00Z",
  ///       "caregiver_name": "Nguyễn Văn A",
  ///       "caregiver_phone": "+84 123 456 789",
  ///       "caregiver_email": "caregiver@example.com",
  ///       "caregiver_specialization": "general_care|elderly_care|disabled_care"
  ///     }
  ///   ]
  /// }
  /// ```
  ///
  /// Error response: Same as getMyAssignments()
  Future<List<Map<String, dynamic>>> getAssignmentsByCustomer(
    String customerId,
  ) async {
    // Switched to invitations endpoint: /customers/{id}/invitations
    // This endpoint returns invitations/assignments for a specific customer
    final res = await _api.get('/customers/$customerId/invitations');
    if (res.statusCode != 200) {
      throw Exception(
        'Lấy assignments theo customer thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Get assignments by customer response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ??
            'Get assignments by customer failed';
        debugPrint(
          '❌ AssignmentApi: Get assignments by customer failed with error: $code - $message',
        );
        throw Exception(
          'Lấy assignments theo customer thất bại: $code - $message',
        );
      } else {
        debugPrint(
          '❌ AssignmentApi: Get assignments by customer failed with unknown error format',
        );
        throw Exception(
          'Lấy assignments theo customer thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    // Extract data from response - could be in 'data' key or directly in response
    final dynamic data;
    if (response.containsKey('data')) {
      data = response['data'];
      debugPrint(
        '📦 AssignmentApi: Assignments by customer data extracted from response.data',
      );
    } else {
      data = response;
      debugPrint(
        '📦 AssignmentApi: Assignments by customer data extracted directly from response',
      );
    }

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu assignments trả về không hợp lệ');
  }

  /// Chấp nhận assignment (POST /assignments/:id/accept)
  /// Cho phép caregiver chấp nhận một assignment request
  ///
  /// Parameters:
  /// - assignmentId: ID của assignment cần chấp nhận
  ///
  /// Expected response shape:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "id": "assignment_id_123",
  ///     "status": "active",
  ///     "updated_at": "2024-01-15T10:30:00Z",
  ///     "message": "Assignment accepted successfully"
  ///   }
  /// }
  /// ```
  ///
  /// Error response:
  /// ```json
  /// {
  ///   "success": false,
  ///   "error": {
  ///     "code": "ASSIGNMENT_NOT_FOUND",
  ///     "message": "Assignment not found or already processed"
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> acceptAssignment(String assignmentId) async {
    final res = await _api.post('/caregiver-invitations/$assignmentId/accept');
    if (res.statusCode != 200) {
      throw Exception(
        'Chấp nhận assignment thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Accept assignment response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Accept assignment failed';
        debugPrint(
          '❌ AssignmentApi: Accept assignment failed with error: $code - $message',
        );
        throw Exception('Chấp nhận assignment thất bại: $code - $message');
      } else {
        debugPrint(
          '❌ AssignmentApi: Accept assignment failed with unknown error format',
        );
        throw Exception(
          'Chấp nhận assignment thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final Map<String, dynamic> data = _api.extractDataFromResponse(res);
    debugPrint(
      '📦 AssignmentApi: Accept assignment data extracted from response',
    );

    return data;
  }

  /// Từ chối assignment (POST /assignments/:id/reject)
  /// Cho phép caregiver từ chối một assignment request
  ///
  /// Parameters:
  /// - assignmentId: ID của assignment cần từ chối
  /// - reason: Lý do từ chối (optional)
  ///
  /// Expected response shape:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "id": "assignment_id_123",
  ///     "status": "cancelled",
  ///     "updated_at": "2024-01-15T10:30:00Z",
  ///     "message": "Assignment rejected successfully"
  ///   }
  /// }
  /// ```
  ///
  /// Error response:
  /// ```json
  /// {
  ///   "success": false,
  ///   "error": {
  ///     "code": "ASSIGNMENT_NOT_FOUND",
  ///     "message": "Assignment not found or already processed"
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> rejectAssignment(
    String assignmentId, {
    String? reason,
  }) async {
    final res = await _api.post(
      '/caregiver-invitations/$assignmentId/reject',
      body: reason != null ? {'reason': reason} : {},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Từ chối assignment thất bại: ${res.statusCode} ${res.body}',
      );
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Reject assignment response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Reject assignment failed';
        debugPrint(
          '❌ AssignmentApi: Reject assignment failed with error: $code - $message',
        );
        throw Exception('Từ chối assignment thất bại: $code - $message');
      } else {
        debugPrint(
          '❌ AssignmentApi: Reject assignment failed with unknown error format',
        );
        throw Exception(
          'Từ chối assignment thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final Map<String, dynamic> data = _api.extractDataFromResponse(res);
    debugPrint(
      '📦 AssignmentApi: Reject assignment data extracted from response',
    );

    return data;
  }

  /// Tạo assignment mới (POST /assignments)
  /// Tạo một assignment mới giữa customer và caregiver
  ///
  /// Parameters:
  /// - customerId: ID của customer
  /// - caregiverId: ID của caregiver
  /// - assignmentType: Loại assignment ('daily_care', 'emergency_care', 'specialized_care')
  ///
  /// Expected response shape:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "id": "assignment_id_123",
  ///     "customer_id": "customer_id_789",
  ///     "caregiver_id": "caregiver_id_456",
  ///     "assignment_type": "daily_care",
  ///     "status": "pending",
  ///     "created_at": "2024-01-15T10:30:00Z",
  ///     "updated_at": "2024-01-15T10:30:00Z",
  ///     "message": "Assignment created successfully"
  ///   }
  /// }
  /// ```
  ///
  /// Error response:
  /// ```json
  /// {
  ///   "success": false,
  ///   "error": {
  ///     "code": "CUSTOMER_NOT_FOUND",
  ///     "message": "Customer not found"
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> createAssignment({
    required String customerId,
    required String caregiverId,
    required String assignmentType,
  }) async {
    final res = await _api.post(
      '/assignments',
      body: {
        'customer_id': customerId,
        'caregiver_id': caregiverId,
        'assignment_type': assignmentType,
      },
    );
    if (res.statusCode != 201) {
      throw Exception('Tạo assignment thất bại: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> response = _api.decodeResponseBody(res);
    debugPrint(
      '📦 AssignmentApi: Create assignment response keys: ${response.keys.toList()}',
    );

    if (response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Create assignment failed';
        debugPrint(
          '❌ AssignmentApi: Create assignment failed with error: $code - $message',
        );
        throw Exception('Tạo assignment thất bại: $code - $message');
      } else {
        debugPrint(
          '❌ AssignmentApi: Create assignment failed with unknown error format',
        );
        throw Exception(
          'Tạo assignment thất bại: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final Map<String, dynamic> data = _api.extractDataFromResponse(res);
    debugPrint(
      '📦 AssignmentApi: Create assignment data extracted from response',
    );

    return data;
  }
}
