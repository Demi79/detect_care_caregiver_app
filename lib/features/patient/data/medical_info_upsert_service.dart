import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

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
    String userId,
    MedicalInfoUpsertDto dto,
  ) async {
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
    final res = await api.put(
      '/patients/$userId/medical-info',
      body: payload,
      extraHeaders: extraHeaders,
    );
    return res.statusCode == 200;
  }
}
