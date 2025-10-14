import 'shared_permissions.dart';

class CaregiverPermission {
  final String customerId;
  final String caregiverId;
  final String caregiverUsername;
  final String? caregiverPhone;
  final String caregiverFullName;
  final SharedPermissions permissions;

  const CaregiverPermission({
    required this.customerId,
    required this.caregiverId,
    required this.caregiverUsername,
    this.caregiverPhone,
    required this.caregiverFullName,
    required this.permissions,
  });
  factory CaregiverPermission.fromJson(Map<String, dynamic> json) {
    // Build permissionsJson by accepting both colon and underscore key styles.
    final permissionsJson = <String, dynamic>{};

    // Known boolean permission keys in underscore form
    const boolKeys = ['stream_view', 'alert_read', 'alert_ack', 'profile_view'];

    // Copy booleans: accept either 'stream_view' or 'stream:view'
    for (final k in boolKeys) {
      if (json.containsKey(k)) {
        permissionsJson[k] = json[k];
      } else {
        final alt = k.replaceAll('_', ':');
        if (json.containsKey(alt)) {
          permissionsJson[k] = json[alt];
        } else {
          // fallback mặc định false để tránh null
          permissionsJson[k] = false;
        }
      }
    }

    // Numeric / array keys
    if (json.containsKey('log_access_days')) {
      permissionsJson['log_access_days'] =
          int.tryParse(json['log_access_days'].toString()) ?? 0;
    } else if (json.containsKey('log:access_days')) {
      permissionsJson['log_access_days'] =
          int.tryParse(json['log:access_days'].toString()) ?? 0;
    } else {
      permissionsJson['log_access_days'] = 0;
    }

    if (json.containsKey('report_access_days')) {
      permissionsJson['report_access_days'] =
          int.tryParse(json['report_access_days'].toString()) ?? 0;
    } else if (json.containsKey('report:access_days')) {
      permissionsJson['report_access_days'] =
          int.tryParse(json['report:access_days'].toString()) ?? 0;
    } else {
      permissionsJson['report_access_days'] = 0;
    }

    // Array: notification_channel
    if (json.containsKey('notification_channel')) {
      permissionsJson['notification_channel'] =
          (json['notification_channel'] is List)
          ? json['notification_channel']
          : [];
    } else if (json.containsKey('notification:channel')) {
      permissionsJson['notification_channel'] =
          (json['notification:channel'] is List)
          ? json['notification:channel']
          : [];
    } else {
      permissionsJson['notification_channel'] = [];
    }

    // ✅ Build final model
    return CaregiverPermission(
      customerId: json['customer_id'] ?? '',
      caregiverId: json['caregiver_id'] ?? '',
      caregiverUsername: json['caregiver_username'] ?? '',
      caregiverPhone: json['caregiver_phone']?.toString(),
      caregiverFullName: json['caregiver_full_name'] ?? '',
      permissions: SharedPermissions.fromJson(permissionsJson),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'customer_id': customerId,
      'caregiver_id': caregiverId,
      'caregiver_username': caregiverUsername,
      if (caregiverPhone != null) 'caregiver_phone': caregiverPhone,
      'caregiver_full_name': caregiverFullName,
    };

    // Attach permissions using underscore keys (match API docs examples).
    final permissionsJson = permissions.toJson();
    permissionsJson.forEach((key, value) {
      json[key] = value;
    });

    return json;
  }

  CaregiverPermission copyWith({
    String? customerId,
    String? caregiverId,
    String? caregiverUsername,
    String? caregiverFullName,
    SharedPermissions? permissions,
  }) {
    return CaregiverPermission(
      customerId: customerId ?? this.customerId,
      caregiverId: caregiverId ?? this.caregiverId,
      caregiverUsername: caregiverUsername ?? this.caregiverUsername,
      caregiverFullName: caregiverFullName ?? this.caregiverFullName,
      permissions: permissions ?? this.permissions,
    );
  }
}
