import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';

class MedicalInfoRemoteDataSource {
  final ApiClient _api;
  MedicalInfoRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<MedicalInfoResponse> getMedicalInfo(String userId) async {
    final res = await _api.get('/users/$userId/medical-info');
    if (res.statusCode != 200) {
      throw Exception('Get medical info failed: ${res.statusCode} ${res.body}');
    }
    return MedicalInfoResponse.fromJson(
      json.decode(res.body) as Map<String, dynamic>,
    );
  }

  Future<MedicalInfoResponse> upsertMedicalInfo(
    String userId, {
    PatientInfo? patient,
    PatientRecord? record,
  }) async {
    final body = <String, dynamic>{};
    if (patient != null) {
      final p = <String, dynamic>{};
      if (patient.name != null) p['name'] = patient.name;
      if (patient.dob != null) p['dob'] = patient.dob;
      body['patient'] = p;
    }
    if (record != null) body['record'] = record.toJson();
    final res = await _api.put('/users/$userId/medical-info', body: body);
    if (res.statusCode != 200) {
      throw Exception(
        'Upsert medical info failed: ${res.statusCode} ${res.body}',
      );
    }
    return MedicalInfoResponse.fromJson(
      json.decode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<EmergencyContact>> listContacts(String userId) async {
    final res = await _api.get('/users/$userId/emergency-contacts');
    if (res.statusCode != 200) {
      throw Exception('List contacts failed: ${res.statusCode} ${res.body}');
    }
    final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map(EmergencyContact.fromJson).toList();
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
    return EmergencyContact.fromJson(
      json.decode(res.body) as Map<String, dynamic>,
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
    return EmergencyContact.fromJson(
      json.decode(res.body) as Map<String, dynamic>,
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
