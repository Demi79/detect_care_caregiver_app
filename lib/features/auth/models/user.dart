class User {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String phone;
  final bool isFirstLogin;
  final bool isActive;
  final String? avatarUrl;
  final bool isAssigned;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phone,
    this.isFirstLogin = false,
    this.isActive = false,
    this.avatarUrl,
    this.isAssigned = false,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();
  static bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: _s(j['user_id'] ?? j['id']),
    username: _s(j['username']),
    fullName: _s(j['full_name'] ?? j['username']),
    email: _s(j['email']),
    role: _s(j['role']),
    phone: _s(j['phone_number'] ?? j['phone']),
    isFirstLogin: _b(j['is_first_login']),
    isActive: _b(j['is_active']),
    avatarUrl: j['avatar_url']?.toString(),
    isAssigned: _b(j['is_assigned']),
  );
}
