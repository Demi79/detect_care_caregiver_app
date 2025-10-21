import 'dart:convert';
import 'dart:developer' as dev;

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class EmergencyContactDto {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final int alertLevel;

  EmergencyContactDto({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.alertLevel,
  });

  factory EmergencyContactDto.fromJson(Map<String, dynamic> j) {
    int parseAlertLevel(dynamic v) {
      if (v == null) return 1;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 1;
    }

    return EmergencyContactDto(
      id: (j['id'] ?? j['contact_id'] ?? '').toString(),
      name: j['name']?.toString() ?? '',
      relation: j['relation']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      alertLevel: parseAlertLevel(j['alert_level']),
    );
  }

  Map<String, dynamic> toBody() => {
    'name': name,
    'relation': relation,
    'phone': phone,
    'alert_level': alertLevel,
  };

  EmergencyContactDto copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    int? alertLevel,
  }) => EmergencyContactDto(
    id: id ?? this.id,
    name: name ?? this.name,
    relation: relation ?? this.relation,
    phone: phone ?? this.phone,
    alertLevel: alertLevel ?? this.alertLevel,
  );
}

class EmergencyContactsRemoteDataSource {
  final ApiClient _api;
  EmergencyContactsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  String _base(String userId) => '/users/$userId/emergency-contacts';

  Future<List<EmergencyContactDto>> list(String userId) async {
    final res = await _api.get(_base(userId));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List contacts failed: ${res.statusCode} ${res.body}');
    }

    dynamic extracted;
    try {
      extracted = _api.extractDataFromResponse(res);
    } catch (_) {
      // ignore and fallback to raw decode
    }

    final raw = extracted ?? json.decode(res.body);

    dev.log('[EmergencyContacts] list response parsed: ${raw.runtimeType}');

    if (raw is List) {
      return raw
          .cast<Map<String, dynamic>>()
          .map<EmergencyContactDto>(EmergencyContactDto.fromJson)
          .toList();
    }

    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .cast<Map<String, dynamic>>()
          .map<EmergencyContactDto>(EmergencyContactDto.fromJson)
          .toList();
    }

    if (raw is Map) {
      for (final v in raw.values) {
        if (v is List) {
          return v
              .cast<Map<String, dynamic>>()
              .map<EmergencyContactDto>(EmergencyContactDto.fromJson)
              .toList();
        }
      }
    }

    throw Exception('Unexpected response shape when listing contacts: $raw');
  }

  Future<EmergencyContactDto> create(
    String userId,
    EmergencyContactDto body,
  ) async {
    final res = await _api.post(_base(userId), body: body.toBody());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create contact failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return EmergencyContactDto.fromJson(map);
  }

  Future<EmergencyContactDto> update(
    String userId,
    String contactId,
    EmergencyContactDto body,
  ) async {
    final res = await _api.put(
      '${_base(userId)}/$contactId',
      body: body.toBody(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update contact failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return EmergencyContactDto.fromJson(map);
  }

  Future<void> delete(String userId, String contactId) async {
    final res = await _api.delete('${_base(userId)}/$contactId');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete contact failed: ${res.statusCode} ${res.body}');
    }
  }
}
