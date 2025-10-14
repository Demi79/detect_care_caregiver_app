import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:flutter/foundation.dart';

class MedicalInfoRemoteDataSource {
  Future<MedicalInfoResponse> createMedicalInfo(
    String userId, {
    required PatientInfo patient,
    required PatientRecord record,
    List<Habit>? habits,
  }) async {
    final body = {
      'patient': patient.toJson(),
      'record': record.toJson(),
      if (habits != null) 'habits': habits.map((e) => e.toJson()).toList(),
      'customer_id': userId,
    };
    final res = await _api.post('/users/$userId/medical-info', body: body);
    if (res.statusCode != 200) {
      throw Exception(
        'Create medical info failed: ${res.statusCode} ${res.body}',
      );
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Create medical info failed';
        throw Exception('Create medical info failed: $code - $message');
      } else {
        throw Exception(
          'Create medical info failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) {
      return MedicalInfoResponse.fromJson(data);
    }
    debugPrint(
      '[MedicalInfoRemoteDataSource.createMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  final ApiClient _api;
  MedicalInfoRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<MedicalInfoResponse> getMedicalInfo(String userId) async {
    final res = await _api.get('/users/$userId/medical-info');
    if (res.statusCode != 200) {
      throw Exception('Get medical info failed: ${res.statusCode} ${res.body}');
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Get medical info failed';
        throw Exception('Get medical info failed: $code - $message');
      } else {
        throw Exception(
          'Get medical info failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return MedicalInfoResponse.fromJson(data);
    debugPrint(
      '[MedicalInfoRemoteDataSource.getMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  Future<MedicalInfoResponse> upsertMedicalInfo(
    String userId, {
    PatientInfo? patient,
    PatientRecord? record,
  }) async {
    final body = <String, dynamic>{};
    if (patient != null) {
      final p = <String, dynamic>{};
      p['name'] = patient.name;
      p['dob'] = patient.dob;
      if (patient.allergies != null) p['allergies'] = patient.allergies;
      if (patient.chronicDiseases != null) {
        p['chronicDiseases'] = patient.chronicDiseases;
      }
      body['patient'] = p;
    }
    if (record != null) body['record'] = record.toJson();
    final res = await _api.put('/users/$userId/medical-info', body: body);
    if (res.statusCode != 200) {
      throw Exception(
        'Upsert medical info failed: ${res.statusCode} ${res.body}',
      );
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message =
            error['message']?.toString() ?? 'Upsert medical info failed';
        throw Exception('Upsert medical info failed: $code - $message');
      } else {
        throw Exception(
          'Upsert medical info failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return MedicalInfoResponse.fromJson(data);
    debugPrint(
      '[MedicalInfoRemoteDataSource.upsertMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  Future<List<EmergencyContact>> listContacts(String userId) async {
    final res = await _api.get('/users/$userId/emergency-contacts');
    if (res.statusCode != 200) {
      throw Exception('List contacts failed: ${res.statusCode} ${res.body}');
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message = error['message']?.toString() ?? 'List contacts failed';
        throw Exception('List contacts failed: $code - $message');
      } else {
        throw Exception(
          'List contacts failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    // Extract data from response - could be in 'data' key or directly in response
    final dynamic data = _api.extractDataFromResponse(res);
    // Log for debugging: show decoded data type and a small preview
    try {
      debugPrint(
        '[MedicalInfoRemoteDataSource.listContacts] decoded data type: ${data.runtimeType}',
      );
      if (data is List) {
        debugPrint(
          '[MedicalInfoRemoteDataSource.listContacts] first item type: ${data.isNotEmpty ? data.first.runtimeType : "<empty>"}',
        );
        debugPrint(
          '[MedicalInfoRemoteDataSource.listContacts] preview: ${data.isNotEmpty ? data.take(3).toList() : []}',
        );
      } else if (data is Map) {
        debugPrint(
          '[MedicalInfoRemoteDataSource.listContacts] data keys: ${data.keys.toList()}',
        );
        debugPrint(
          '[MedicalInfoRemoteDataSource.listContacts] items type: ${data['items']?.runtimeType}',
        );
        if (data['items'] is List) {
          debugPrint(
            '[MedicalInfoRemoteDataSource.listContacts] preview: ${(data['items'] as List).take(3).toList()}',
          );
        }
      } else {
        debugPrint(
          '[MedicalInfoRemoteDataSource.listContacts] data preview: $data',
        );
      }
    } catch (_) {}

    final list = (data is List)
        ? data
        : (data is Map && data['items'] is List)
        ? data['items']
        : <Map<String, dynamic>>[];
    return list.map<EmergencyContact>((e) {
      if (e is EmergencyContact) return e;
      if (e is Map<String, dynamic>) return EmergencyContact.fromJson(e);
      if (e is Map) return EmergencyContact.fromJson(e.cast<String, dynamic>());
      // Fallback: try toString and parse as JSON is not desired here; throw
      throw Exception('Unexpected contact element type: ${e.runtimeType}');
    }).toList();
  }

  Future<EmergencyContact> addContact(
    String userId, {
    required String name,
    required String relation,
    required String phone,
  }) async {
    final res = await _api.post(
      '/users/$userId/emergency-contacts',
      body: {'name': name, 'relation': relation, 'phone': phone},
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Add contact failed: ${res.statusCode} ${res.body}');
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message = error['message']?.toString() ?? 'Add contact failed';
        throw Exception('Add contact failed: $code - $message');
      } else {
        throw Exception(
          'Add contact failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return EmergencyContact.fromJson(data);
    debugPrint(
      '[MedicalInfoRemoteDataSource.addContact] unexpected data type: ${data.runtimeType}',
    );
    throw Exception(
      'Add contact returned unexpected payload type: ${data.runtimeType}',
    );
  }

  Future<EmergencyContact> updateContact(
    String userId,
    String contactId, {
    String? name,
    String? relation,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (relation != null) body['relation'] = relation;
    if (phone != null) body['phone'] = phone;
    final res = await _api.put(
      '/users/$userId/emergency-contacts/$contactId',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Update contact failed: ${res.statusCode} ${res.body}');
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message = error['message']?.toString() ?? 'Update contact failed';
        throw Exception('Update contact failed: $code - $message');
      } else {
        throw Exception(
          'Update contact failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return EmergencyContact.fromJson(data);
    debugPrint(
      '[MedicalInfoRemoteDataSource.updateContact] unexpected data type: ${data.runtimeType}',
    );
    throw Exception(
      'Update contact returned unexpected payload type: ${data.runtimeType}',
    );
  }

  Future<void> deleteContact(String userId, String contactId) async {
    final res = await _api.delete(
      '/users/$userId/emergency-contacts/$contactId',
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Delete contact failed: ${res.statusCode} ${res.body}');
    }
  }
}
