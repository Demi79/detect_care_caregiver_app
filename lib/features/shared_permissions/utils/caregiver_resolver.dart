import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/utils/caregiver_id.dart';

/// Result of attempting to resolve a caregiver from backend search
class CaregiverResolveResult {
  final ResolvedCaregiver? resolved;
  final List<User>? candidates;

  CaregiverResolveResult({this.resolved, this.candidates});
}

class ResolvedCaregiver {
  final String caregiverId;
  final String caregiverUsername;
  final String caregiverFullName;
  final String? caregiverPhone;

  ResolvedCaregiver({
    required this.caregiverId,
    required this.caregiverUsername,
    required this.caregiverFullName,
    this.caregiverPhone,
  });
}

/// Attempt to resolve a caregiver using the provided [search] function.
///
/// The [search] function should accept a keyword and return a list of
/// `User` results from the backend. Resolution strategy:
/// 1. If `phone` is provided, search by phone first. If single result -> resolved.
///    If multiple -> return candidates for UI selection.
/// 2. If no phone-match, and `name` provided -> search by name. Same logic.
/// 3. If no backend matches, return a deterministic fallback id using
///    `generateCaregiverId(name, phone)` and include phone in the resolved
///    record so callers can include `caregiver_phone` in payloads.
Future<CaregiverResolveResult> resolveCaregiver({
  required String name,
  required String phone,
  required Future<List<User>> Function(String keyword) search,
}) async {
  // 1) Try phone search if available
  if (phone.trim().isNotEmpty) {
    try {
      final byPhone = await search(phone.trim());
      if (byPhone.isNotEmpty) {
        if (byPhone.length == 1) {
          final u = byPhone.first;
          return CaregiverResolveResult(
            resolved: ResolvedCaregiver(
              caregiverId: u.id,
              caregiverUsername: u.username,
              caregiverFullName: u.fullName.isNotEmpty
                  ? u.fullName
                  : u.username,
              caregiverPhone: u.phone.isNotEmpty ? u.phone : phone.trim(),
            ),
          );
        }
        return CaregiverResolveResult(candidates: byPhone);
      }
    } catch (_) {
      // ignore search errors and continue to name search / fallback
    }
  }

  // 2) Try name search
  if (name.trim().isNotEmpty) {
    try {
      final byName = await search(name.trim());
      if (byName.isNotEmpty) {
        if (byName.length == 1) {
          final u = byName.first;
          return CaregiverResolveResult(
            resolved: ResolvedCaregiver(
              caregiverId: u.id,
              caregiverUsername: u.username,
              caregiverFullName: u.fullName.isNotEmpty
                  ? u.fullName
                  : u.username,
              caregiverPhone: u.phone.isNotEmpty
                  ? u.phone
                  : (phone.trim().isNotEmpty ? phone.trim() : null),
            ),
          );
        }
        return CaregiverResolveResult(candidates: byName);
      }
    } catch (_) {
      // ignore and fallback
    }
  }

  // 3) Fallback: deterministic id generation
  final genId = generateCaregiverId(name.trim(), phone.trim());
  // If generation failed (both name and phone empty) treat as unresolved so
  // callers don't send invalid placeholder ids (like '_') to the server.
  if (genId.isEmpty) return CaregiverResolveResult();

  return CaregiverResolveResult(
    resolved: ResolvedCaregiver(
      caregiverId: genId,
      caregiverUsername: '',
      caregiverFullName: name.trim(),
      caregiverPhone: phone.trim().isNotEmpty ? phone.trim() : null,
    ),
  );
}
