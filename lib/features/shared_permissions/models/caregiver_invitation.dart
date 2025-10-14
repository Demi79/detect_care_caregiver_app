import 'shared_permissions.dart';

enum InvitationStatus { pending, accepted, rejected, revoked }

class CaregiverInvitation {
  final String id;
  final String caregiverId;
  final String caregiverName;
  final String caregiverEmail;
  final String customerId;
  final String customerName;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseMessage;
  final SharedPermissions? permissions;

  const CaregiverInvitation({
    required this.id,
    required this.caregiverId,
    required this.caregiverName,
    required this.caregiverEmail,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.responseMessage,
    this.permissions,
  });

  factory CaregiverInvitation.fromJson(Map<String, dynamic> json) {
    return CaregiverInvitation(
      id: json['id']?.toString() ?? '',
      caregiverId: json['caregiver_id']?.toString() ?? '',
      caregiverName: json['caregiver_name']?.toString() ?? '',
      caregiverEmail: json['caregiver_email']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvitationStatus.pending,
      ),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      responseMessage: json['response_message']?.toString(),
      permissions: json['permissions'] != null
          ? SharedPermissions.fromJson(json['permissions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caregiver_id': caregiverId,
    'caregiver_name': caregiverName,
    'caregiver_email': caregiverEmail,
    'customer_id': customerId,
    'customer_name': customerName,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'responded_at': respondedAt?.toIso8601String(),
    'response_message': responseMessage,
    'permissions': permissions?.toJson(),
  };

  CaregiverInvitation copyWith({
    String? id,
    String? caregiverId,
    String? caregiverName,
    String? caregiverEmail,
    String? customerId,
    String? customerName,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? responseMessage,
    SharedPermissions? permissions,
  }) {
    return CaregiverInvitation(
      id: id ?? this.id,
      caregiverId: caregiverId ?? this.caregiverId,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverEmail: caregiverEmail ?? this.caregiverEmail,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
      permissions: permissions ?? this.permissions,
    );
  }
}
