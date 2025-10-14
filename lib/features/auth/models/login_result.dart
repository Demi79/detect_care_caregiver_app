import 'package:detect_care_caregiver_app/features/auth/models/user.dart';

class LoginResult {
  final String accessToken;
  final Map<String, dynamic> userServerJson;
  final User user;

  LoginResult({
    required this.accessToken,
    required this.userServerJson,
    required this.user,
  });

  factory LoginResult.fromApi(Map<String, dynamic> json) {
    final data = json['data'] ?? {};

    final rawUser = (data['user'] as Map).cast<String, dynamic>();
    final token = data['access_token'] as String;

    return LoginResult(
      accessToken: token,
      userServerJson: rawUser,
      user: User.fromJson(rawUser),
    );
  }
}
