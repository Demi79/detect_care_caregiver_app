String generateCaregiverId(String name, String phone) {
  // Normalize name: lower-case, replace non-alphanum with underscores,
  // collapse repeated underscores and trim leading/trailing underscores.
  var sanitizedName = name.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  sanitizedName = sanitizedName.replaceAll(RegExp(r'_+'), '_');
  sanitizedName = sanitizedName.replaceAll(RegExp(r'^_|_\$'), '');

  final digitsOnly = phone.replaceAll(RegExp(r"[^0-9]+"), '');

  // If both parts are empty, return empty string (cannot generate id)
  if (sanitizedName.isEmpty && digitsOnly.isEmpty) return '';

  if (sanitizedName.isEmpty) return digitsOnly;
  if (digitsOnly.isEmpty) return sanitizedName;

  return '${sanitizedName}_$digitsOnly';
}
