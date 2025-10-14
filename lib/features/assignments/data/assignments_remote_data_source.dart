import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:flutter/foundation.dart';

class Assignment {
  final String assignmentId;
  final String caregiverId;
  final String customerId;
  final bool isActive;
  final String status;
  final String assignedAt;
  final String? unassignedAt;
  final String? notes;
  final String? customerName;
  final String? customerUsername;

  const Assignment({
    required this.assignmentId,
    required this.caregiverId,
    required this.customerId,
    required this.isActive,
    required this.status,
    required this.assignedAt,
    this.unassignedAt,
    this.notes,
    this.customerName,
    this.customerUsername,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    String? stringOrNull(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

    final customer = json['customer'] as Map<String, dynamic>?;

    return Assignment(
      assignmentId: (json['assignment_id'] ?? json['id'] ?? '').toString(),
      caregiverId: (json['caregiver_id'] ?? '').toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      isActive: json['is_active'] == true,
      status: (json['status'] ?? '').toString(),
      assignedAt: (json['assigned_at'] ?? '').toString(),
      unassignedAt: stringOrNull(json['unassigned_at']),
      notes: stringOrNull(json['assignment_notes'] ?? json['notes']),
      customerName: customer?['full_name']?.toString(),
      customerUsername: customer?['username']?.toString(),
    );
  }
}

class AssignmentsRemoteDataSource {
  final ApiClient _api;
  AssignmentsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  bool _isValidUUID(String? id) {
    if (id == null || id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
  }

  Future<Assignment> create({
    required String caregiverId,
    required String customerId,
    String? notes,
  }) async {
    debugPrint('\n📝 Creating new assignment (pending)...');
    debugPrint('   Caregiver: $caregiverId');
    debugPrint('   Customer: $customerId');
    debugPrint('   Notes: ${notes ?? 'N/A'}');

    if (!_isValidUUID(caregiverId)) {
      throw Exception('Invalid caregiver_id format: $caregiverId');
    }
    if (!_isValidUUID(customerId)) {
      throw Exception('Invalid customer_id format: $customerId');
    }

    final payload = {
      'caregiver_id': caregiverId,
      'customer_id': customerId,
      if (notes != null && notes.isNotEmpty) 'assignment_notes': notes,
    };

    final res = await _api.post('/assignments', body: payload);

    if (res.statusCode != 201) {
      debugPrint('❌ Assignment creation failed: ${res.statusCode} ${res.body}');
      throw Exception(
        'Create assignment failed: ${res.statusCode} ${res.body}',
      );
    }

    if (res.body.isEmpty) {
      debugPrint('❌ Empty response body from server');
      throw Exception('Server returned empty response');
    }

    try {
      final decoded = json.decode(res.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response format (not an object)');
      }

      if (!decoded.containsKey('assignment_id')) {
        throw Exception('Response missing assignment_id');
      }

      final assignment = Assignment.fromJson(decoded);
      debugPrint(
        '✅ Assignment created successfully: ${assignment.assignmentId}',
      );
      return assignment;
    } catch (e) {
      debugPrint('❌ Error decoding assignment: $e');
      throw Exception('Failed to process server response: $e');
    }
  }

  Future<Assignment?> deleteById(String assignmentId) async {
    debugPrint('\n❌ Deleting assignment: $assignmentId');
    final res = await _api.delete('/caregiver-invitations/$assignmentId');
    debugPrint('📥 Delete response:');
    debugPrint('   Status: ${res.statusCode}');
    debugPrint('   Body: ${res.body}');
    debugPrint('   Headers: ${res.headers}');

    if (res.statusCode == 204 || res.body.isEmpty) {
      debugPrint('✅ Assignment deleted successfully (no content)');
      return null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 500) {
        debugPrint(
          '❌ Server error on delete. Attempting to parse error details...',
        );
        try {
          final decoded = json.decode(res.body);
          final errorMsg =
              decoded['message'] ?? decoded['error'] ?? 'Unknown server error';
          throw Exception('Server error: $errorMsg');
        } catch (e) {
          debugPrint('❌ Could not parse error details: $e');
        }
      }
      throw Exception(
        'Delete assignment failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);
    final map = (decoded is Map && decoded['data'] is Map)
        ? (decoded['data'] as Map).cast<String, dynamic>()
        : (decoded as Map).cast<String, dynamic>();

    return Assignment.fromJson(map);
  }

  @Deprecated('Use deleteById instead')
  Future<Assignment?> softUnassignById(String assignmentId) {
    return deleteById(assignmentId);
  }

  Future<int> deleteByPair({
    required String caregiverId,
    required String customerId,
  }) async {
    final res = await _api.delete(
      '/assignments',
      query: {'caregiver_id': caregiverId, 'customer_id': customerId},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete pair failed: ${res.statusCode} ${res.body}');
    }

    if (res.body.isEmpty) return 0;

    final decoded = json.decode(res.body);

    if (decoded is num) return decoded.toInt();

    if (decoded is Map) {
      final map = decoded.cast<String, dynamic>();

      int? pickNum(dynamic v) => (v is num) ? v.toInt() : null;

      for (final k in ['updated', 'deleted', 'count', 'affected', 'changes']) {
        final n = pickNum(map[k]);
        if (n != null) return n;
      }

      final data = map['data'];
      if (data is List) return data.length;
      if (data is Map) {
        for (final k in [
          'updated',
          'deleted',
          'count',
          'affected',
          'changes',
        ]) {
          final n = pickNum(data[k]);
          if (n != null) return n;
        }
      }
    }

    return 1;
  }

  @Deprecated('Use deleteByPair instead')
  Future<int> softUnassignPair({
    required String caregiverId,
    required String customerId,
  }) {
    return deleteByPair(caregiverId: caregiverId, customerId: customerId);
  }

  Future<List<Assignment>> listByCustomer({
    required String customerId,
    bool activeOnly = true,
  }) async {
    final res = await _api.get(
      '/caregiver-invitations/by-customer/$customerId',
      query: {'active_only': activeOnly.toString()},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Fetch assignments by customer failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);

    final List list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      list = decoded['data'] as List;
    } else {
      throw Exception('Unexpected response format for assignments list');
    }

    return list
        .cast<Map>()
        .map((e) => Assignment.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<Assignment>> listPending({bool? isActive, String? status}) async {
    final Map<String, String> query = {};
    if (isActive != null) query['active_only'] = isActive.toString();
    if (status != null) query['status'] = status;

    final res = await _api.get(
      '/caregiver-invitations/caregiver/me',
      query: query,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch pending failed: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);
    final List data;
    if (decoded is List) {
      data = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      data = decoded['data'] as List;
    } else {
      throw Exception('Unexpected response format for pending assignments');
    }

    final assignments = data
        .cast<Map>()
        .map((e) => Assignment.fromJson(e.cast<String, dynamic>()))
        .toList();

    assignments.sort((a, b) {
      final dateA = DateTime.tryParse(a.assignedAt) ?? DateTime(0);
      final dateB = DateTime.tryParse(b.assignedAt) ?? DateTime(0);
      return dateB.compareTo(dateA);
    });
    // print("assignments: $assignments");

    return assignments;
  }

  Future<Assignment> accept(String assignmentId) async {
    final res = await _api.post('/caregiver-invitations/$assignmentId/accept');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Accept assignment failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);
    final data = (decoded is Map && decoded['data'] is Map)
        ? (decoded['data'] as Map).cast<String, dynamic>()
        : decoded as Map<String, dynamic>;

    return Assignment.fromJson(data);
  }

  Future<Assignment> reject(String assignmentId) async {
    final res = await _api.post('/caregiver-invitations/$assignmentId/reject');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Reject assignment failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);
    final data = (decoded is Map && decoded['data'] is Map)
        ? (decoded['data'] as Map).cast<String, dynamic>()
        : decoded as Map<String, dynamic>;

    return Assignment.fromJson(data);
  }
}
