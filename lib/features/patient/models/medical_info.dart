import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

List<String>? _toStringList(dynamic src) {
  if (src == null) return null;
  if (src is List) return src.map((e) => e.toString()).toList();
  if (src is String) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return null;
    return trimmed
        .split(',')
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  try {
    final s = src.toString();
    if (s.isEmpty) return null;
    return s
        .split(',')
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } catch (_) {
    return null;
  }
}

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
    allergies: _parseStringList(json['allergies']),
    chronicDiseases: _parseStringList(json['chronicDiseases']),
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

  static List<String>? _parseStringList(dynamic src) {
    if (src == null) return null;
    if (src is List) {
      return src.map((e) => e.toString()).toList();
    }
    if (src is String) {
      final trimmed = src.trim();
      if (trimmed.isEmpty) return null;
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    try {
      return src
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
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
        _toStringList(json['name']) ??
        _toStringList(json['conditions']) ??
        const [],
    medications: _toStringList(json['medications']) ?? const [],
    history: _toStringList(json['history']) ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'name': conditions,
    if (medications.isNotEmpty) 'medications': medications,
    if (history.isNotEmpty) 'history': history,
  };
}

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
  final String? habitId;
  final String habitName;
  final String? description;
  final String? sleepStart;
  final String? sleepEnd;
  final String? typicalTime;
  final int? durationMinutes;
  final String frequency;
  final List<String>? daysOfWeek;
  final String? location;
  final Map<String, dynamic>? notesMap;
  final String? notesString;
  final bool isActive;

  const Habit({
    this.habitId,
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
    habitId: json['habit_id']?.toString() ?? json['habitId']?.toString(),
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
    daysOfWeek: _toStringList(json['days_of_week']),
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
    if (habitId != null) 'habit_id': habitId,
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

    final List<EmergencyContact> contacts = [];
    final rawContacts = json['contacts'];
    if (rawContacts is List) {
      for (final e in rawContacts) {
        if (e is Map) {
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
        }
      }
    } else if (rawContacts is Map && rawContacts['items'] is List) {
      for (final e in rawContacts['items'] as List) {
        if (e is Map) {
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

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
