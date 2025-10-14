import 'package:flutter/material.dart';

class PatientInfo {
  final String name;
  final String dob;
  // final String phone;
  // final String address;
  final List<String>? allergies;
  final List<String>? chronicDiseases;

  const PatientInfo({
    required this.name,
    required this.dob,
    // required this.phone,
    // required this.address,
    this.allergies,
    this.chronicDiseases,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) => PatientInfo(
    name: json['name']?.toString() ?? '',
    dob: json['dob']?.toString() ?? '',
    // phone: json['phone']?.toString() ?? '',
    // address: json['address']?.toString() ?? '',
    allergies: (json['allergies'] as List?)?.map((e) => e.toString()).toList(),
    chronicDiseases: (json['chronicDiseases'] as List?)
        ?.map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'dob': dob,
    // 'phone': phone,
    // 'address': address,
    if (allergies != null) 'allergies': allergies,
    if (chronicDiseases != null) 'chronicDiseases': chronicDiseases,
  };
}

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
    conditions: (json['conditions'] as List? ?? const [])
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
    'conditions': conditions,
    'medications': medications,
    'history': history,
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
    debugPrint(
      '[MedicalInfoResponse.fromJson] incoming json keys: ${json.keys.toList()}',
    );
    debugPrint(
      '[MedicalInfoResponse.fromJson] contacts raw: ${json['contacts']?.runtimeType}',
    );
    debugPrint(
      '[MedicalInfoResponse.fromJson] habits raw: ${json['habits']?.runtimeType}',
    );
    try {
      final rc = json['contacts'];
      if (rc is List) {
        debugPrint(
          '[MedicalInfoResponse.fromJson] contacts preview: ${rc.isNotEmpty ? rc.take(3).toList() : []}',
        );
      }
      if (rc is Map) {
        debugPrint(
          '[MedicalInfoResponse.fromJson] contacts keys: ${rc.keys.toList()}',
        );
      }
    } catch (_) {}
    try {
      final rh = json['habits'];
      if (rh is List) {
        debugPrint(
          '[MedicalInfoResponse.fromJson] habits preview: ${rh.isNotEmpty ? rh.take(3).toList() : []}',
        );
      }
      if (rh is Map) {
        debugPrint(
          '[MedicalInfoResponse.fromJson] habits keys: ${rh.keys.toList()}',
        );
      }
    } catch (_) {}

    final dynamic rawContacts = json['contacts'];
    final List<EmergencyContact> contacts = <EmergencyContact>[];
    if (rawContacts is List) {
      for (final e in rawContacts) {
        if (e is EmergencyContact) {
          contacts.add(e);
        } else if (e is Map<String, dynamic>) {
          contacts.add(EmergencyContact.fromJson(e));
        } else if (e is Map) {
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
        }
      }
    } else if (rawContacts is Map && rawContacts['items'] is List) {
      for (final e in rawContacts['items'] as List) {
        if (e is EmergencyContact) {
          contacts.add(e);
        } else if (e is Map<String, dynamic>) {
          contacts.add(EmergencyContact.fromJson(e));
        } else if (e is Map) {
          contacts.add(EmergencyContact.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    final dynamic rawHabits = json['habits'];
    final List<Habit> habits = <Habit>[];
    if (rawHabits is List) {
      for (final e in rawHabits) {
        if (e is Habit) {
          habits.add(e);
        } else if (e is Map) {
          habits.add(Habit.fromJson(e.cast<String, dynamic>()));
        }
      }
    } else if (rawHabits is Map && rawHabits['items'] is List) {
      for (final e in rawHabits['items'] as List) {
        if (e is Habit) {
          habits.add(e);
        } else if (e is Map) {
          habits.add(Habit.fromJson(e.cast<String, dynamic>()));
        }
      }
    }
    return MedicalInfoResponse(
      patient: (json['patient'] is Map)
          ? PatientInfo.fromJson(
              (json['patient'] as Map).cast<String, dynamic>(),
            )
          : null,
      record: (json['record'] is Map)
          ? PatientRecord.fromJson(
              (json['record'] as Map).cast<String, dynamic>(),
            )
          : null,
      habits: habits,
      contacts: contacts,
    );
  }
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

class Habit {
  final String habitType;
  final String habitName;
  final String? description;
  final String? typicalTime;
  final int? durationMinutes;
  final String frequency;
  final List<String>? daysOfWeek;
  final String? location;
  final String? notes;
  final bool isActive;

  const Habit({
    required this.habitType,
    required this.habitName,
    this.description,
    this.typicalTime,
    this.durationMinutes,
    required this.frequency,
    this.daysOfWeek,
    this.location,
    this.notes,
    this.isActive = true,
  });

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    habitType: json['habit_type']?.toString() ?? '',
    habitName: json['habit_name']?.toString() ?? '',
    description: json['description']?.toString(),
    typicalTime: json['typical_time']?.toString(),
    durationMinutes: json['duration_minutes'] != null
        ? int.tryParse(json['duration_minutes'].toString())
        : null,
    frequency: json['frequency']?.toString() ?? '',
    daysOfWeek: (json['days_of_week'] as List?)
        ?.map((e) => e.toString())
        .toList(),
    location: json['location']?.toString(),
    notes: json['notes']?.toString(),
    isActive: json['is_active'] == null
        ? true
        : json['is_active'] == true || json['is_active'].toString() == 'true',
  );

  Map<String, dynamic> toJson() => {
    'habit_type': habitType,
    'habit_name': habitName,
    if (description != null) 'description': description,
    if (typicalTime != null) 'typical_time': typicalTime,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    'frequency': frequency,
    if (daysOfWeek != null) 'days_of_week': daysOfWeek,
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
    'is_active': isActive,
  };
}
