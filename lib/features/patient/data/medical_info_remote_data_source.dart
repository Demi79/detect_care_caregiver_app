import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/features/patient/models/sleep_checkin.dart';

import 'package:flutter/foundation.dart';

class MedicalInfoRemoteDataSource {
  Future<MedicalInfoResponse> edicalIedicalInfoF(
    String customerId, {
    required PatientInfo patient,
    required PatientRecord record,
    List<Habit>? habits,
  }) async {
    final body = {
      'patient': patient.toJson(),
      'record': record.toJson(),
      if (habits != null) 'habits': habits.map((e) => e.toJson()).toList(),
      'customer_id': customerId,
    };
    final res = await _api.post(
      '/patients/$customerId/medical-info',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Create medical info failed: ${res.statusCode} ${res.body}',
      );
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format (only if response is a Map)
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

    // Extract data from response using helper
    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) {
      return MedicalInfoResponse.fromJson(data);
    }
    // If data is not a Map, return empty response to avoid crashes and log for debugging
    print(
      '[MedicalInfoRemoteDataSource.createMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  final ApiClient _api;
  MedicalInfoRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<MedicalInfoResponse> getMedicalInfo(String customerId) async {
    final res = await _api.get('/patients/$customerId/medical-info');
    if (res.statusCode != 200) {
      throw Exception('Get medical info failed: ${res.statusCode} ${res.body}');
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format
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

    // Extract data from response using helper
    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return MedicalInfoResponse.fromJson(data);
    print(
      '[MedicalInfoRemoteDataSource.getMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  Future<MedicalInfoResponse> upsertMedicalInfo(
    String customerId, {
    PatientInfo? patient,
    PatientRecord? record,
    List<Habit>? habits,
  }) async {
    final body = <String, dynamic>{};

    if (patient != null) {
      final p = <String, dynamic>{};
      if (patient.name.isNotEmpty) p['name'] = patient.name;
      if (patient.dob.isNotEmpty) p['dob'] = patient.dob;
      if (patient.allergies != null && patient.allergies!.isNotEmpty) {
        p['allergies'] = patient.allergies;
      }
      if (patient.chronicDiseases != null &&
          patient.chronicDiseases!.isNotEmpty) {
        p['chronicDiseases'] = patient.chronicDiseases;
      }
      if (p.isNotEmpty) body['patient'] = p;
    }

    if (record != null) {
      final r = <String, dynamic>{};
      if (record.conditions.isNotEmpty) r['name'] = record.conditions;
      if (record.medications.isNotEmpty) r['medications'] = record.medications;
      if (record.history.isNotEmpty) r['history'] = record.history;
      if (r.isNotEmpty) body['record'] = r;
    }
    if (habits != null && habits.isNotEmpty) {
      body['habits'] = habits.map((e) => e.toJson()).toList();
    }
    AppLogger.api(
      '[MedicalInfoRemoteDataSource] PUT /patients/$customerId/medical-info payload: $body',
    );
    final res = await _api.put(
      '/patients/$customerId/medical-info',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Upsert medical info failed: ${res.statusCode} ${res.body}',
      );
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format
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

    // Extract data from response using helper
    try {
      final dynamic decoded = _api.decodeResponseBody(res);
      AppLogger.api(
        '[MedicalInfoRemoteDataSource] response status=${res.statusCode} decoded=${decoded.runtimeType}',
      );
    } catch (e) {
      AppLogger.w(
        '[MedicalInfoRemoteDataSource] failed to decode response: $e',
      );
      print(
        '[MedicalInfoRemoteDataSource.upsertMedicalInfo] raw body: ${res.body}',
      );
    }

    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return MedicalInfoResponse.fromJson(data);
    AppLogger.w(
      '[MedicalInfoRemoteDataSource.upsertMedicalInfo] unexpected data type: ${data.runtimeType}',
    );
    return MedicalInfoResponse.fromJson(<String, dynamic>{});
  }

  Future<List<EmergencyContact>> listContacts(String customerId) async {
    final res = await _api.get('/users/$customerId/emergency-contacts');
    if (res.statusCode != 200) {
      throw Exception('List contacts failed: ${res.statusCode} ${res.body}');
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format
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
      print(
        '[MedicalInfoRemoteDataSource.listContacts] decoded data type: ${data.runtimeType}',
      );
      if (data is List) {
        print(
          '[MedicalInfoRemoteDataSource.listContacts] first item type: ${data.isNotEmpty ? data.first.runtimeType : "<empty>"}',
        );
        print(
          '[MedicalInfoRemoteDataSource.listContacts] preview: ${data.isNotEmpty ? data.take(3).toList() : []}',
        );
      } else if (data is Map) {
        print(
          '[MedicalInfoRemoteDataSource.listContacts] data keys: ${data.keys.toList()}',
        );
        print(
          '[MedicalInfoRemoteDataSource.listContacts] items type: ${data['items']?.runtimeType}',
        );
        if (data['items'] is List) {
          print(
            '[MedicalInfoRemoteDataSource.listContacts] preview: ${(data['items'] as List).take(3).toList()}',
          );
        }
      } else {
        print('[MedicalInfoRemoteDataSource.listContacts] data preview: $data');
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
    String customerId, {
    required String name,
    required String relation,
    required String phone,
  }) async {
    final res = await _api.post(
      '/users/$customerId/emergency-contacts',
      body: {'name': name, 'relation': relation, 'phone': phone},
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Add contact failed: ${res.statusCode} ${res.body}');
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format
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

    // Extract data from response using helper
    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return EmergencyContact.fromJson(data);
    print(
      '[MedicalInfoRemoteDataSource.addContact] unexpected data type: ${data.runtimeType}',
    );
    throw Exception(
      'Add contact returned unexpected payload type: ${data.runtimeType}',
    );
  }

  Future<EmergencyContact> updateContact(
    String customerId,
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
      '/users/$customerId/emergency-contacts/$contactId',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Update contact failed: ${res.statusCode} ${res.body}');
    }

    // Parse response with new format
    final dynamic response = _api.decodeResponseBody(res);

    // Check for new error format
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

    // Extract data from response using helper
    final dynamic data = _api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) return EmergencyContact.fromJson(data);
    print(
      '[MedicalInfoRemoteDataSource.updateContact] unexpected data type: ${data.runtimeType}',
    );
    throw Exception(
      'Update contact returned unexpected payload type: ${data.runtimeType}',
    );
  }

  Future<void> deleteContact(String customerId, String contactId) async {
    final res = await _api.delete(
      '/users/$customerId/emergency-contacts/$contactId',
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Delete contact failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> sleepCheckin(
    String customerId, {
    required String state, // "sleep" hoặc "awake"
    required DateTime timestamp,
  }) async {
    final body = {
      'state': state,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': 'app',
    };

    final res = await _api.post(
      '/patients/$customerId/sleep-checkin',
      body: body,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Sleep checkin failed: ${res.statusCode} ${res.body}');
    }

    final dynamic response = _api.decodeResponseBody(res);

    if (response is Map && response['success'] == false) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code']?.toString() ?? 'UNKNOWN_ERROR';
        final message = error['message']?.toString() ?? 'Sleep checkin failed';
        throw Exception('Sleep checkin failed: $code - $message');
      } else {
        throw Exception(
          'Sleep checkin failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    }

    print('[sleepCheckin] success: ${response.toString()}');
  }

  Future<SleepCheckinPage> getSleepCheckins(
    String customerId, {
    int page = 1,
    int limit = 50,
  }) async {
    final query = {"page": page.toString(), "limit": limit.toString()};

    final res = await _api.get(
      '/patients/$customerId/sleep-checkins',
      query: query,
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Get sleep checkins failed: ${res.statusCode} ${res.body}',
      );
    }

    final body = _api.decodeResponseBody(res);

    // Print full response details to terminal for debugging
    try {
      print('[getSleepCheckins] HTTP status: ${res.statusCode}');
      print('[getSleepCheckins] Raw response body: ${res.body}');
      print('[getSleepCheckins] Decoded body: $body');
      final extracted = _api.extractDataFromResponse(res);
      print('[getSleepCheckins] Extracted data: $extracted');
    } catch (e) {
      print('[getSleepCheckins] Error printing response: $e');
    }

    if (body is Map && body["success"] == false) {
      throw Exception(body["error"].toString());
    }

    final data = _api.extractDataFromResponse(res);
    if (data is List) {
      return SleepCheckinPage(
        page: page,
        limit: limit,
        total: data.length,
        items: data
            .map(
              (e) => SleepCheckin.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
    }

    if (data is Map && data["items"] is List) {
      return SleepCheckinPage.fromJson(data.cast<String, dynamic>());
    }

    debugPrint("[getSleepCheckins] Unexpected format: ${data.runtimeType}");

    return SleepCheckinPage(page: 1, limit: 20, total: 0, items: []);
  }
}
