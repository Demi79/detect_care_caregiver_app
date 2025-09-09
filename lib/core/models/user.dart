class User {
  final String id;
  final String phone;
  final String password;
  final String role;

  User({
    required this.id,
    required this.phone,
    required this.password,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    phone: json['phone'] as String,
    password: json['password'] as String,
    role: json['role'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'password': password,
    'role': role,
  };
}
