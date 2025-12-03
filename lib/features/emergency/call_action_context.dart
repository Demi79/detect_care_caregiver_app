library;

export 'package:detect_care_caregiver_app/features/emergency/call_action_manager.dart';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_manager.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/caregiver_permission.dart';

CallActionManager callActionManager(BuildContext context) {
  final rawRole = context.select<AuthProvider, String?>(
    (auth) => auth.user?.role,
  );
  // We don't depend on a concrete provider type here to keep this util
  // decoupled from provider implementation details. Try to read a
  // permissions list from any provider that exposes `permissions`.
  final hasCaregiver =
      context.select<dynamic, bool?>((provider) {
        try {
          final perms = (provider as dynamic).permissions;
          if (perms == null) return false;
          return (perms as List).isNotEmpty;
        } catch (_) {
          return false;
        }
      }) ??
      false;

  return CallActionManager.fromRawRole(
    rawRole,
    hasAssignedCaregiver: hasCaregiver,
  );
}

String? firstAssignedCaregiverPhone(BuildContext context) {
  final permissions =
      context.select<dynamic, List<CaregiverPermission>?>((provider) {
        try {
          final perms = (provider as dynamic).permissions;
          if (perms == null) return null;
          return (perms as List).cast<CaregiverPermission>();
        } catch (_) {
          return null;
        }
      }) ??
      <CaregiverPermission>[];
  for (final permission in permissions) {
    final phone = permission.caregiverPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
  }
  return null;
}
