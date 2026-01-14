import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class PatientUpsertDto {
  final String? name;
  final String? dob;
  final List<String>? allergies;
  final List<String>? chronicDiseases;
  PatientUpsertDto({this.name, this.dob, this.allergies, this.chronicDiseases});
  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (dob != null) 'dob': dob,
    if (allergies != null) 'allergies': allergies,
    if (chronicDiseases != null) 'chronicDiseases': chronicDiseases,
  };
}

class MedicalRecordUpsertDto {
  final List<String>? conditions;
  final List<String>? medications;
  final List<String>? history;
  MedicalRecordUpsertDto({this.conditions, this.medications, this.history});
  Map<String, dynamic> toJson() => {
    if (conditions != null) 'conditions': conditions,
    if (medications != null) 'medications': medications,
    if (history != null) 'history': history,
  };
}

class HabitItemDto {
  final String? habitType;
  final String? habitId;
  final String? habitName;
  final String? description;
  final String? sleepStart;
  final String? sleepEnd;
  final String? typicalTime;
  final int? durationMinutes;
  final String? frequency;
  final List<String>? daysOfWeek;
  final String? location;
  final dynamic notes;
  final bool? isActive;
  HabitItemDto({
    this.habitId,
    this.habitType,
    this.habitName,
    this.description,
    this.sleepStart,
    this.sleepEnd,
    this.typicalTime,
    this.durationMinutes,
    this.frequency,
    this.daysOfWeek,
    this.location,
    this.notes,
    this.isActive,
  });
  Map<String, dynamic> toJson() => {
    if (habitId != null) 'habit_id': habitId,
    if (habitType != null) 'habit_type': habitType,
    if (habitName != null) 'habit_name': habitName,
    if (description != null) 'description': description,
    if (sleepStart != null) 'sleep_start': sleepStart,
    if (sleepEnd != null) 'sleep_end': sleepEnd,
    if (typicalTime != null) 'typical_time': typicalTime,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (frequency != null) 'frequency': frequency,
    if (daysOfWeek != null) 'days_of_week': daysOfWeek,
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
    if (isActive != null) 'is_active': isActive,
  };

  factory HabitItemDto.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic v) =>
        (v is String && v.isNotEmpty) ? v : (v != null ? v.toString() : null);
    int? asInt(dynamic v) =>
        (v is num) ? v.toInt() : (v is String ? int.tryParse(v) : null);
    List<String>? asStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    return HabitItemDto(
      habitId: asString(json['habit_id'] ?? json['id']),
      habitType: asString(json['habit_type']),
      habitName: asString(json['habit_name'] ?? json['name']),
      description: asString(json['description']),
      sleepStart: asString(json['sleep_start']),
      sleepEnd: asString(json['sleep_end']),
      typicalTime: asString(json['typical_time']),
      durationMinutes: asInt(json['duration_minutes']),
      frequency: asString(json['frequency']),
      daysOfWeek: asStringList(json['days_of_week']),
      location: asString(json['location']),
      notes: json['notes'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

class MedicalInfoUpsertDto {
  final PatientUpsertDto? patient;
  final MedicalRecordUpsertDto? record;
  final List<HabitItemDto>? habits;
  final String? customerId;
  MedicalInfoUpsertDto({
    this.patient,
    this.record,
    this.habits,
    this.customerId,
  });
  Map<String, dynamic> toJson() => {
    if (patient != null) 'patient': patient!.toJson(),
    if (record != null) 'record': record!.toJson(),
    if (habits != null) 'habits': habits!.map((e) => e.toJson()).toList(),
    if (customerId != null) 'customer_id': customerId,
  };
}

class MedicalInfoUpsertService {
  final String baseUrl;
  MedicalInfoUpsertService(this.baseUrl);

  // Normalize various DOB input formats to ISO yyyy-MM-dd expected by backend
  String? _normalizeDob(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Already ISO-like (yyyy-MM-dd or full ISO datetime)
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt.toIso8601String().substring(0, 10);
    } catch (_) {}

    // Common localized formats: dd/MM/yyyy or dd-MM-yyyy
    final slashMatch = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
    ).firstMatch(s);
    if (slashMatch != null) {
      final d = int.tryParse(slashMatch.group(1) ?? '0') ?? 0;
      final m = int.tryParse(slashMatch.group(2) ?? '0') ?? 0;
      var y = int.tryParse(slashMatch.group(3) ?? '0') ?? 0;
      // two-digit year heuristic: 70-99 => 1900s, else 2000s
      if (y < 100) {
        y += (y >= 70) ? 1900 : 2000;
      }
      try {
        final dt = DateTime(y, m, d);
        return dt.toIso8601String().substring(0, 10);
      } catch (_) {}
    }

    // As a last resort return the original string (backend will validate)
    return s;
  }

  Future<bool> updateMedicalInfo(
    String? customerId,
    MedicalInfoUpsertDto dto,
  ) async {
    if (customerId == null || customerId.isEmpty) {
      try {
        final ds = AssignmentsRemoteDataSource();
        final list = await ds.listPending(status: 'accepted');
        if (list.isNotEmpty) customerId = list.first.customerId;
      } catch (e) {
        AppLogger.w(
          '[MedicalInfoUpsertService] failed to resolve customerId: $e',
        );
      }
    }
    if (customerId == null || customerId.isEmpty) {
      AppLogger.w(
        '[MedicalInfoUpsertService] no customerId available, aborting update',
      );
      return false;
    }
    // final url = '$baseUrl/users/$userId/medical-info';
    final token = await AuthStorage.getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    // Ensure DOB is normalized to ISO yyyy-MM-dd expected by backend
    final payload = Map<String, dynamic>.from(dto.toJson());
    if (payload.containsKey('patient')) {
      final patient = payload['patient'] as Map<String, dynamic>;
      if (patient.containsKey('dob')) {
        patient['dob'] = _normalizeDob(patient['dob']?.toString());
      }
    }

    final api = ApiClient();
    final extraHeaders = Map<String, String>.from(headers);
    AppLogger.api(
      '[MedicalInfoUpsertService] PUT /patients/$customerId/medical-info payload: $payload',
    );
    final res = await api.put(
      '/patients/$customerId/medical-info',
      body: payload,
      extraHeaders: extraHeaders,
    );
    try {
      final dynamic decoded = api.decodeResponseBody(res);
      AppLogger.api(
        '[MedicalInfoUpsertService] response status=${res.statusCode} decoded=${decoded.runtimeType} payloadPreview=${decoded is Map || decoded is List ? (decoded is Map ? decoded.keys.toList() : (decoded as List).take(3).toList()) : decoded}',
      );
    } catch (e) {
      AppLogger.w('[MedicalInfoUpsertService] failed to decode response: $e');
      AppLogger.api(
        '[MedicalInfoUpsertService] raw response status=${res.statusCode} body=${res.body}',
      );
    }
    return res.statusCode == 200;
  }

  Future<bool> deleteHabit(String? customerId, String habitId) async {
    if (customerId == null || customerId.isEmpty) {
      try {
        final ds = AssignmentsRemoteDataSource();
        final list = await ds.listPending(status: 'accepted');
        if (list.isNotEmpty) customerId = list.first.customerId;
      } catch (e) {
        AppLogger.w(
          '[MedicalInfoUpsertService] failed to resolve customerId for delete: $e',
        );
      }
    }
    if (customerId == null || customerId.isEmpty) {
      AppLogger.w(
        '[MedicalInfoUpsertService] no customerId available, aborting delete',
      );
      return false;
    }

    final token = await AuthStorage.getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final api = ApiClient();
    AppLogger.api(
      '[MedicalInfoUpsertService] DELETE /patients/$customerId/habits/$habitId',
    );
    final res = await api.delete(
      '/patients/$customerId/habits/$habitId',
      extraHeaders: Map<String, String>.from(headers),
    );
    AppLogger.api(
      '[MedicalInfoUpsertService] delete response status=${res.statusCode}',
    );
    if (res.statusCode == 200 || res.statusCode == 204) return true;
    try {
      final decoded = api.decodeResponseBody(res);
      AppLogger.w('[MedicalInfoUpsertService] delete failed decoded=$decoded');
    } catch (e) {
      AppLogger.w(
        '[MedicalInfoUpsertService] delete failed and could not decode response: $e',
      );
    }
    return false;
  }

  Future<HabitItemDto?> createHabit(
    String? customerId,
    HabitItemDto dto,
  ) async {
    if (customerId == null || customerId.isEmpty) {
      try {
        final ds = AssignmentsRemoteDataSource();
        final list = await ds.listPending(status: 'accepted');
        if (list.isNotEmpty) customerId = list.first.customerId;
      } catch (e) {
        AppLogger.w(
          '[MedicalInfoUpsertService] failed to resolve customerId for create: $e',
        );
      }
    }
    if (customerId == null || customerId.isEmpty) {
      AppLogger.w(
        '[MedicalInfoUpsertService] no customerId available, aborting create',
      );
      return null;
    }

    final token = await AuthStorage.getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final api = ApiClient();
    final body = dto.toJson();
    AppLogger.api(
      '[MedicalInfoUpsertService] POST /patients/$customerId/habits payload: $body',
    );
    final res = await api.post(
      '/patients/$customerId/habits',
      body: body,
      extraHeaders: Map<String, String>.from(headers),
    );
    AppLogger.api(
      '[MedicalInfoUpsertService] create habit response status=${res.statusCode}',
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      try {
        final decoded = api.decodeResponseBody(res);
        AppLogger.w(
          '[MedicalInfoUpsertService] create failed decoded=$decoded',
        );
      } catch (e) {
        AppLogger.w(
          '[MedicalInfoUpsertService] create failed and could not decode response: $e',
        );
      }
      return null;
    }

    try {
      final decoded = api.decodeResponseBody(res);
      final data = api.extractDataFromResponse(res);
      if (data is Map<String, dynamic>) {
        return HabitItemDto.fromJson(data);
      }
      if (data is List && data.isNotEmpty && data.first is Map) {
        return HabitItemDto.fromJson(
          (data.first as Map).cast<String, dynamic>(),
        );
      }
    } catch (e) {
      AppLogger.w(
        '[MedicalInfoUpsertService] failed to parse create response: $e',
      );
    }
    return null;
  }
}
