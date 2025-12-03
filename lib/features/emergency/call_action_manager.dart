library;

enum CallAction { emergency, caregiver, doctor, hospital, family, customer }

enum CallerRole { customer, caregiver, unknown }

class CallActionPolicy {
  const CallActionPolicy({
    required this.canCallEmergency,
    required this.canCallCaregiver,
    required this.canCallDoctor,
    required this.canCallHospital,
    required this.canCallFamily,
    required this.canCallCustomer,
  });

  final bool canCallEmergency;
  final bool canCallCaregiver;
  final bool canCallDoctor;
  final bool canCallHospital;
  final bool canCallFamily;
  final bool canCallCustomer;

  Set<CallAction> get allowedActions {
    final actions = <CallAction>{};
    if (canCallEmergency) actions.add(CallAction.emergency);
    if (canCallCaregiver) actions.add(CallAction.caregiver);
    if (canCallDoctor) actions.add(CallAction.doctor);
    if (canCallHospital) actions.add(CallAction.hospital);
    if (canCallFamily) actions.add(CallAction.family);
    if (canCallCustomer) actions.add(CallAction.customer);
    return actions;
  }

  CallActionPolicy copyWith({
    bool? canCallEmergency,
    bool? canCallCaregiver,
    bool? canCallDoctor,
    bool? canCallHospital,
    bool? canCallFamily,
    bool? canCallCustomer,
  }) {
    return CallActionPolicy(
      canCallEmergency: canCallEmergency ?? this.canCallEmergency,
      canCallCaregiver: canCallCaregiver ?? this.canCallCaregiver,
      canCallDoctor: canCallDoctor ?? this.canCallDoctor,
      canCallHospital: canCallHospital ?? this.canCallHospital,
      canCallFamily: canCallFamily ?? this.canCallFamily,
      canCallCustomer: canCallCustomer ?? this.canCallCustomer,
    );
  }

  static const CallActionPolicy customerWithoutCaregiver = CallActionPolicy(
    canCallEmergency: true,
    canCallCaregiver: false,
    canCallDoctor: false,
    canCallHospital: false,
    canCallFamily: true,
    canCallCustomer: false,
  );

  static const CallActionPolicy customerWithCaregiver = CallActionPolicy(
    canCallEmergency: false,
    canCallCaregiver: true,
    canCallDoctor: false,
    canCallHospital: false,
    canCallFamily: true,
    canCallCustomer: false,
  );

  static const CallActionPolicy caregiverDefault = CallActionPolicy(
    canCallEmergency: true,
    canCallCaregiver: false,
    canCallDoctor: true,
    canCallHospital: true,
    canCallFamily: true,
    canCallCustomer: true,
  );
}

class CallActionManager {
  const CallActionManager({
    required this.role,
    this.hasAssignedCaregiver = false,
  });

  final CallerRole role;
  final bool hasAssignedCaregiver;

  factory CallActionManager.fromRawRole(
    String? rawRole, {
    bool hasAssignedCaregiver = false,
  }) {
    return CallActionManager(
      role: _normalizeRole(rawRole),
      hasAssignedCaregiver: hasAssignedCaregiver,
    );
  }

  Set<CallAction> get allowedActions => policy.allowedActions;

  CallActionPolicy get policy {
    switch (role) {
      case CallerRole.customer:
        return hasAssignedCaregiver
            ? CallActionPolicy.customerWithCaregiver
            : CallActionPolicy.customerWithoutCaregiver;
      case CallerRole.caregiver:
        return CallActionPolicy.caregiverDefault;
      case CallerRole.unknown:
      default:
        return CallActionPolicy(
          canCallEmergency: true,
          canCallCaregiver: false,
          canCallDoctor: false,
          canCallHospital: false,
          canCallFamily: false,
          canCallCustomer: false,
        );
    }
  }

  static CallerRole _normalizeRole(String? rawRole) {
    final role = rawRole?.toLowerCase().trim() ?? '';
    if (role.contains('caregiver')) return CallerRole.caregiver;
    if (role.contains('customer')) return CallerRole.customer;
    return CallerRole.unknown;
  }
}
