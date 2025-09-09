import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:flutter/cupertino.dart';

class CaregiverApi {
  final ApiClient _api;
  CaregiverApi(this._api);

  Future<Map<String, dynamic>> createCaregiver({
    required String username,
    required String fullName,
    required String email,
    required String phone,
    required String pin,
  }) async {
    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('00')) {
      phone = '84${phone.substring(2)}';
    } else if (phone.startsWith('+84')) {
      phone = '84${phone.substring(3)}';
    } else if (phone.startsWith('0')) {
      phone = '84${phone.substring(1)}';
    } else if (!phone.startsWith('84')) {
      phone = '84$phone';
    }

    final res = await _api.post(
      '/caregivers',
      body: {
        'username': username,
        'full_name': fullName,
        'email': email,
        'phone_number': phone,
        'pin': pin,
      },
    );
    if (res.statusCode != 201) {
      throw Exception(
        'Đăng ký caregiver thất bại: ${res.statusCode} ${res.body}',
      );
    }

    debugPrint('Đăng ký caregiver thành công: ${res.statusCode} ${res.body}');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Lấy thông tin caregiver theo id (GET /caregivers/:id)
  Future<Map<String, dynamic>> getCaregiver(String id) async {
    final res = await _api.get('/caregivers/$id');
    if (res.statusCode != 200) {
      throw Exception('Lấy caregiver thất bại: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Lấy danh sách caregivers có phân trang (GET /caregivers)
  Future<List<Map<String, dynamic>>> getCaregivers({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      '/caregivers',
      query: {'page': page, 'limit': limit},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Lấy danh sách caregivers thất bại: ${res.statusCode} ${res.body}',
      );
    }
    final data = json.decode(res.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu trả về không hợp lệ');
  }

  /// Cập nhật thông tin caregiver (PUT /caregivers/:id)
  Future<Map<String, dynamic>> updateCaregiver(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put('/caregivers/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(
        'Cập nhật caregiver thất bại: ${res.statusCode} ${res.body}',
      );
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchCaregiverStatus(
    String id,
    String status,
  ) async {
    final res = await _api.patch(
      '/caregivers/$id/status',
      body: {'status': status},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Cập nhật trạng thái caregiver thất bại: ${res.statusCode} ${res.body}',
      );
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Xóa caregiver (DELETE /caregivers/:id hoặc /caregivers/:id/soft)
  /// Nếu soft=true thì xóa mềm
  Future<bool> deleteCaregiver(String id, {bool soft = false}) async {
    final path = soft ? '/caregivers/$id/soft' : '/caregivers/$id';
    final res = await _api.delete(path);
    if (res.statusCode != 200) {
      throw Exception('Xóa caregiver thất bại: ${res.statusCode} ${res.body}');
    }
    final data = json.decode(res.body);
    return data is Map && data['deleted'] == true;
  }

  /// Tìm kiếm caregivers theo từ khóa (GET /caregivers/search)
  Future<List<Map<String, dynamic>>> searchCaregivers({
    required String keyword,
    int page = 1,
    int limit = 20,
    String order = 'desc',
  }) async {
    final res = await _api.get(
      '/caregivers/search',
      query: {'keyword': keyword, 'page': page, 'limit': limit, 'order': order},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Tìm kiếm caregivers thất bại: ${res.statusCode} ${res.body}',
      );
    }
    final data = json.decode(res.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    }
    throw Exception('Dữ liệu trả về không hợp lệ');
  }
}
