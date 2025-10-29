import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class PatientInfo {
  final String name;
  final String dob;
  final List<String>? allergies;
  final List<String>? chronicDiseases;

  const PatientInfo({
    required this.name,
    required this.dob,
    this.allergies,
    this.chronicDiseases,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) => PatientInfo(
    name: json['name']?.toString() ?? '',
    dob: json['dob']?.toString() ?? '',
    allergies: (json['allergies'] as List?)?.map((e) => e.toString()).toList(),
    chronicDiseases: (json['chronicDiseases'] as List?)
        ?.map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'dob': dob,
    if (allergies != null) 'allergies': allergies,
    if (chronicDiseases != null) 'chronicDiseases': chronicDiseases,
  };

  String get dobViFormat {
    try {
      final date = DateTime.parse(dob);
      return DateFormat('dd/MM/yyyy', 'vi_VN').format(date);
    } catch (_) {
      return dob;
    }
  }
}

/// Hồ sơ bệnh án (record)
class PatientRecord {
  final List<String> conditions;
  final List<String> medications;
  final List<String> history;

  const PatientRecord({
    required this.conditions,
    required this.medications,
    required this.history,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    conditions:
        ((json['name'] as List?) ?? (json['conditions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
    medications: (json['medications'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    history: (json['history'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': conditions,
    if (medications.isNotEmpty) 'medications': medications,
    if (history.isNotEmpty) 'history': history,
  };
}

/// Contact khẩn cấp
class EmergencyContact {
  final String? id;
  final String name;
  final String relation;
  final String phone;
  final int alertLevel; // 1=All, 2=Abnormal, 3=Danger

  const EmergencyContact({
    this.id,
    required this.name,
    required this.relation,
    required this.phone,
    this.alertLevel = 1,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id']?.toString() ?? json['contactId']?.toString(),
        name: (json['name'] ?? '').toString(),
        relation: (json['relation'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        alertLevel: json['alert_level'] != null
            ? int.tryParse(json['alert_level'].toString()) ?? 1
            : 1,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'relation': relation,
    'phone': phone,
    'alert_level': alertLevel,
  };
}

/// Thói quen sinh hoạt (habit)
class Habit {
  final String habitType;
  final String habitName;
  final String? description;
  final String? sleepStart; // HH:mm:ss
  final String? sleepEnd; // HH:mm:ss
  final String? typicalTime;
  final int? durationMinutes;
  final String frequency;
  final List<String>? daysOfWeek;
  final String? location;
  final Map<String, dynamic>? notesMap;
  final String? notesString;
  final bool isActive;

  const Habit({
    required this.habitType,
    required this.habitName,
    this.description,
    this.sleepStart,
    this.sleepEnd,
    this.typicalTime,
    this.durationMinutes,
    required this.frequency,
    this.daysOfWeek,
    this.location,
    this.notesMap,
    this.notesString,
    this.isActive = true,
  });

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    habitType: json['habit_type']?.toString() ?? '',
    habitName: json['habit_name']?.toString() ?? '',
    description: json['description']?.toString(),
    sleepStart: json['sleep_start']?.toString(),
    sleepEnd: json['sleep_end']?.toString(),
    typicalTime: json['typical_time']?.toString(),
    durationMinutes: json['duration_minutes'] != null
        ? int.tryParse(json['duration_minutes'].toString())
        : null,
    frequency: json['frequency']?.toString() ?? '',
    daysOfWeek: (json['days_of_week'] as List?)
        ?.map((e) => e.toString())
        .toList(),
    location: json['location']?.toString(),
    notesMap: json['notes'] is Map
        ? (json['notes'] as Map).cast<String, dynamic>()
        : null,
    notesString: json['notes'] is String ? json['notes']?.toString() : null,
    isActive: json['is_active'] == null
        ? true
        : json['is_active'] == true || json['is_active'].toString() == 'true',
  );

  Map<String, dynamic> toJson() => {
    'habit_type': habitType,
    'habit_name': habitName,
    if (description != null) 'description': description,
    if (sleepStart != null) 'sleep_start': sleepStart,
    if (sleepEnd != null) 'sleep_end': sleepEnd,
    if (typicalTime != null) 'typical_time': typicalTime,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    'frequency': frequency,
    if (daysOfWeek != null) 'days_of_week': daysOfWeek,
    if (location != null) 'location': location,
    if (notesMap != null)
      'notes': notesMap
    else if (notesString != null)
      'notes': notesString,
    'is_active': isActive,
  };
}

/// Gộp toàn bộ dữ liệu phản hồi từ API
class MedicalInfoResponse {
  final PatientInfo? patient;
  final PatientRecord? record;
  final List<Habit> habits;
  final List<EmergencyContact> contacts;

  const MedicalInfoResponse({
    this.patient,
    this.record,
    required this.habits,
    required this.contacts,
  });

  factory MedicalInfoResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('[MedicalInfoResponse.fromJson] keys: ${json.keys.join(', ')}');

    // Chuẩn hóa contacts
    final List<EmergencyContact> contacts = [];
    final rawContacts = json['contacts'];
    if (rawContacts is List) {
      for (final e in rawContacts) {
        if (e is Map)
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
      }
    } else if (rawContacts is Map && rawContacts['items'] is List) {
      for (final e in rawContacts['items'] as List) {
        if (e is Map)
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
      }
    }

    // Chuẩn hóa habits
    final List<Habit> habits = [];
    final rawHabits = json['habits'];
    if (rawHabits is List) {
      for (final e in rawHabits) {
        if (e is Map) habits.add(Habit.fromJson(e.cast<String, dynamic>()));
      }
    } else if (rawHabits is Map && rawHabits['items'] is List) {
      for (final e in rawHabits['items'] as List) {
        if (e is Map) habits.add(Habit.fromJson(e.cast<String, dynamic>()));
      }
    }

    return MedicalInfoResponse(
      patient: json['patient'] is Map
          ? PatientInfo.fromJson(
              (json['patient'] as Map).cast<String, dynamic>(),
            )
          : null,
      record: json['record'] is Map
          ? PatientRecord.fromJson(
              (json['record'] as Map).cast<String, dynamic>(),
            )
          : null,
      habits: habits,
      contacts: contacts,
    );
  }
}
