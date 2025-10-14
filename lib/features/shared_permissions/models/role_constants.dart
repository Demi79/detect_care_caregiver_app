/// Shared role keys and localized labels used across setup and invitations UI.
const Map<String, String> roleLabels = {
  'caregiver': 'Người chăm sóc',
  'support': 'Người hỗ trợ',
  'doctor': 'Bác sĩ',
  'nurse': 'Y tá',
  'supervisor': 'Người giám sát',
  'viewer': 'Người xem',
  'admin': 'Quản trị',
};

/// Preferred role keys to show in simple setup flows (order matters)
const List<String> setupRoleKeys = [
  'caregiver',
  'support',
  'doctor',
  'nurse',
  'supervisor',
];

String roleLabelForKey(String key) => roleLabels[key] ?? key;

String roleKeyForLabel(String label) {
  for (final e in roleLabels.entries) {
    if (e.value == label) return e.key;
  }
  return '';
}
