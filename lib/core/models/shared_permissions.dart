class SharedPermission {
  final String id;
  final String caregiverId;
  final String customerId;
  final Map<String, bool> permissions;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final String? notes;
  final Map<String, dynamic>? metadata;

  const SharedPermission({
    required this.id,
    required this.caregiverId,
    required this.customerId,
    required this.permissions,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.notes,
    this.metadata,
  });

  factory SharedPermission.fromJson(Map<String, dynamic> json) {
    return SharedPermission(
      id: json['id']?.toString() ?? '',
      caregiverId: json['caregiver_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      notes: json['notes']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caregiver_id': caregiverId,
    'customer_id': customerId,
    'permissions': permissions,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'notes': notes,
    'metadata': metadata,
  };

  SharedPermission copyWith({
    String? id,
    String? caregiverId,
    String? customerId,
    Map<String, bool>? permissions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return SharedPermission(
      id: id ?? this.id,
      caregiverId: caregiverId ?? this.caregiverId,
      customerId: customerId ?? this.customerId,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isExpiredOrInactive => !isActive || isExpired;
}

class PermissionInvitation {
  final String id;
  final String inviterId;
  final String inviteeId;
  final String inviterRole;
  final String inviteeRole;
  final Map<String, bool> requestedPermissions;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;

  const PermissionInvitation({
    required this.id,
    required this.inviterId,
    required this.inviteeId,
    required this.inviterRole,
    required this.inviteeRole,
    required this.requestedPermissions,
    required this.status,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.metadata,
  });

  factory PermissionInvitation.fromJson(Map<String, dynamic> json) {
    return PermissionInvitation(
      id: json['id']?.toString() ?? '',
      inviterId: json['inviter_id']?.toString() ?? '',
      inviteeId: json['invitee_id']?.toString() ?? '',
      inviterRole: json['inviter_role']?.toString() ?? '',
      inviteeRole: json['invitee_role']?.toString() ?? '',
      requestedPermissions: Map<String, bool>.from(
        json['requested_permissions'] ?? {},
      ),
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inviter_id': inviterId,
    'invitee_id': inviteeId,
    'inviter_role': inviterRole,
    'invitee_role': inviteeRole,
    'requested_permissions': requestedPermissions,
    'status': status,
    'message': message,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'metadata': metadata,
  };

  PermissionInvitation copyWith({
    String? id,
    String? inviterId,
    String? inviteeId,
    String? inviterRole,
    String? inviteeRole,
    Map<String, bool>? requestedPermissions,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) {
    return PermissionInvitation(
      id: id ?? this.id,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      inviterRole: inviterRole ?? this.inviterRole,
      inviteeRole: inviteeRole ?? this.inviteeRole,
      requestedPermissions: requestedPermissions ?? this.requestedPermissions,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class PermissionAccessCheck {
  final bool hasAccess;
  final Map<String, bool> grantedPermissions;
  final Map<String, bool> deniedPermissions;
  final String? reason;
  final Map<String, dynamic>? details;

  const PermissionAccessCheck({
    required this.hasAccess,
    required this.grantedPermissions,
    required this.deniedPermissions,
    this.reason,
    this.details,
  });

  factory PermissionAccessCheck.fromJson(Map<String, dynamic> json) {
    return PermissionAccessCheck(
      hasAccess: json['has_access'] ?? false,
      grantedPermissions: Map<String, bool>.from(
        json['granted_permissions'] ?? {},
      ),
      deniedPermissions: Map<String, bool>.from(
        json['denied_permissions'] ?? {},
      ),
      reason: json['reason']?.toString(),
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'has_access': hasAccess,
    'granted_permissions': grantedPermissions,
    'denied_permissions': deniedPermissions,
    'reason': reason,
    'details': details,
  };

  PermissionAccessCheck copyWith({
    bool? hasAccess,
    Map<String, bool>? grantedPermissions,
    Map<String, bool>? deniedPermissions,
    String? reason,
    Map<String, dynamic>? details,
  }) {
    return PermissionAccessCheck(
      hasAccess: hasAccess ?? this.hasAccess,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      deniedPermissions: deniedPermissions ?? this.deniedPermissions,
      reason: reason ?? this.reason,
      details: details ?? this.details,
    );
  }
}

enum PermissionType {
  viewCameras,
  controlCameras,
  viewEvents,
  manageEvents,
  viewHealthData,
  manageHealthData,
  viewSettings,
  manageSettings,
  viewInvoices,
  manageInvoices,
  emergencyAccess,
  fullAccess,
}

extension PermissionTypeExtension on PermissionType {
  String get displayName {
    switch (this) {
      case PermissionType.viewCameras:
        return 'Xem camera';
      case PermissionType.controlCameras:
        return 'Điều khiển camera';
      case PermissionType.viewEvents:
        return 'Xem sự kiện';
      case PermissionType.manageEvents:
        return 'Quản lý sự kiện';
      case PermissionType.viewHealthData:
        return 'Xem dữ liệu sức khỏe';
      case PermissionType.manageHealthData:
        return 'Quản lý dữ liệu sức khỏe';
      case PermissionType.viewSettings:
        return 'Xem cài đặt';
      case PermissionType.manageSettings:
        return 'Quản lý cài đặt';
      case PermissionType.viewInvoices:
        return 'Xem hóa đơn';
      case PermissionType.manageInvoices:
        return 'Quản lý hóa đơn';
      case PermissionType.emergencyAccess:
        return 'Truy cập khẩn cấp';
      case PermissionType.fullAccess:
        return 'Toàn quyền truy cập';
    }
  }

  String get code {
    switch (this) {
      case PermissionType.viewCameras:
        return 'view_cameras';
      case PermissionType.controlCameras:
        return 'control_cameras';
      case PermissionType.viewEvents:
        return 'view_events';
      case PermissionType.manageEvents:
        return 'manage_events';
      case PermissionType.viewHealthData:
        return 'view_health_data';
      case PermissionType.manageHealthData:
        return 'manage_health_data';
      case PermissionType.viewSettings:
        return 'view_settings';
      case PermissionType.manageSettings:
        return 'manage_settings';
      case PermissionType.viewInvoices:
        return 'view_invoices';
      case PermissionType.manageInvoices:
        return 'manage_invoices';
      case PermissionType.emergencyAccess:
        return 'emergency_access';
      case PermissionType.fullAccess:
        return 'full_access';
    }
  }
}
