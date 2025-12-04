import 'dart:convert';
import 'dart:developer' as dev;

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
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

  Future<String?> resolveCustomerId() async {
    try {
      final assignmentsDs = AssignmentsRemoteDataSource();
      final assignments = await assignmentsDs.listPending(status: 'accepted');

      final active = assignments
          .where((a) => a.isActive && a.status.toLowerCase() == 'accepted')
          .toList();

      if (active.isNotEmpty) {
        return active.first.customerId;
      }
    } catch (_) {}

    try {
      final userJson = await AuthStorage.getUserJson();
      if (userJson != null) {
        final c1 = userJson['customer_id']?.toString();
        if (c1 != null && c1.isNotEmpty) return c1;

        final linked = userJson['linked_customer_id']?.toString();
        if (linked != null && linked.isNotEmpty) return linked;

        final custObj = userJson['customer'];
        if (custObj is Map && custObj['id'] != null) {
          final cid = custObj['id']?.toString();
          if (cid != null && cid.isNotEmpty) return cid;
        }
      }
    } catch (_) {}

    return null;
  }

  String _base(String customerId) => '/users/$customerId/emergency-contacts';

  Future<List<EmergencyContactDto>> list(String customerId) async {
    final res = await _api.get(_base(customerId));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List contacts failed: ${res.statusCode} ${res.body}');
    }

    dynamic extracted;
    try {
      extracted = _api.extractDataFromResponse(res);
    } catch (_) {}

    final raw = extracted ?? json.decode(res.body);

    dev.log('[EmergencyContacts] list response parsed: ${raw.runtimeType}');

    if (raw is List) {
      return raw.map((e) => EmergencyContactDto.fromJson(e)).toList();
    }

    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .map((e) => EmergencyContactDto.fromJson(e))
          .toList();
    }

    if (raw is Map) {
      for (final v in raw.values) {
        if (v is List) {
          return v.map((e) => EmergencyContactDto.fromJson(e)).toList();
        }
      }
    }

    throw Exception('Unexpected response shape when listing contacts: $raw');
  }

  Future<EmergencyContactDto> create(
    String customerId,
    EmergencyContactDto body,
  ) async {
    final res = await _api.post(_base(customerId), body: body.toBody());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create contact failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return EmergencyContactDto.fromJson(map);
  }

  Future<EmergencyContactDto> update(
    String customerId,
    String contactId,
    EmergencyContactDto body,
  ) async {
    final res = await _api.put(
      '${_base(customerId)}/$contactId',
      body: body.toBody(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update contact failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return EmergencyContactDto.fromJson(map);
  }

  Future<void> delete(String customerId, String contactId) async {
    final res = await _api.delete('${_base(customerId)}/$contactId');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete contact failed: ${res.statusCode} ${res.body}');
    }
  }
}
