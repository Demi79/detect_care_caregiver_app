class PatientInfo {
  final String id;
  final String? name;
  final String? dob; // yyyy-MM-dd or null
  const PatientInfo({required this.id, this.name, this.dob});
  factory PatientInfo.fromJson(Map<String, dynamic> json) => PatientInfo(
    id: (json['id'] ?? json['user_id'] ?? '').toString(),
    name: json['name']?.toString(),
    dob: json['dob']?.toString(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'dob': dob};
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
  final List<EmergencyContact> contacts;
  const MedicalInfoResponse({
    this.patient,
    this.record,
    required this.contacts,
  });
  factory MedicalInfoResponse.fromJson(Map<String, dynamic> json) {
    final contacts = (json['contacts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => EmergencyContact.fromJson(e.cast<String, dynamic>()))
        .toList();
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
      contacts: contacts,
    );
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String relation;
  final String phone;
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
  });
  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: (json['id'] ?? json['contact_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        relation: (json['relation'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relation': relation,
    'phone': phone,
  };
}
