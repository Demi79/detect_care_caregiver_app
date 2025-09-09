import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_api.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/otp_request_result.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/models/login_result.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'auth_endpoints.dart';

class AuthRemoteDataSource {
  final AuthEndpoints endpoints;
  late final AuthApi _authApi;
  late final ApiClient _api;

  AuthRemoteDataSource({required this.endpoints}) {
    debugPrint('🌐 API Base URL: ${AppConfig.apiBaseUrl}');
    _api = ApiClient(tokenProvider: AuthStorage.getAccessToken);
    _authApi = AuthApi(ApiClient(tokenProvider: AuthStorage.getAccessToken));
  }

  Future<http.Response> _get(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return http.get(Uri.parse(url)).timeout(timeout);
  }

  List<dynamic> _decodeList(String body) => json.decode(body) as List<dynamic>;

  Future<List<User>> fetchUsers() async {
    final res = await _get(endpoints.users);

    if (res.statusCode == 200) {
      return _decodeList(
        res.body,
      ).map((e) => User.fromJson((e as Map).cast<String, dynamic>())).toList();
    }
    throw Exception('Failed to load users (status ${res.statusCode})');
  }

  Future<User> createUser(String phone, String password) async {
    final res = await http
        .post(
          Uri.parse(endpoints.users),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'phone': phone,
            'password': password,
            'role': 'user',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return User.fromJson(json.decode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create user (status ${res.statusCode})');
  }

  Future<OtpRequestResult> sendOtp(String phone) async {
    return _authApi.requestOtp(phone);
  }

  Future<LoginResult> verifyOtp(String phone, String code) async {
    final result = await _authApi.loginWithOtp(phone, code);
    final token = result['access_token']?.toString();
    final userMap = (result['user'] is Map)
        ? (result['user'] as Map).cast<String, dynamic>()
        : null;

    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access_token trong phản hồi');
    }
    if (userMap == null) {
      throw Exception('Thiếu user trong phản hồi');
    }

    return LoginResult(
      accessToken: token,
      userServerJson: userMap,
      user: User.fromJson(userMap),
    );
  }

  Future<User> me() async {
    final map = await _authApi.me();

    final raw = (map['user'] is Map)
        ? (map['user'] as Map).cast<String, dynamic>()
        : map.cast<String, dynamic>();

    final serverKeyed = <String, dynamic>{
      'user_id': raw['user_id']?.toString() ?? raw['id']?.toString() ?? '',
      'username': raw['username']?.toString() ?? '',
      'full_name':
          raw['full_name']?.toString() ?? raw['name']?.toString() ?? '',
      'email': raw['email']?.toString() ?? '',
      'role': raw['role']?.toString() ?? '',
      'phone_number':
          raw['phone_number']?.toString() ?? raw['phone']?.toString() ?? '',
      'is_first_login': raw['is_first_login'] ?? false,
      'avatar_url': raw['avatar_url'],
      'is_assigned': raw['is_assigned'] ?? false,
    };

    return User.fromJson(serverKeyed);
  }

  Future<LoginResult> caregiverLogin(String phone, String code) async {
    final res = await _api.post(
      '/auth/caregiver/login',
      body: {'phone_number': phone, 'otp_code': code},
    );

    if (res.statusCode != 200) {
      throw Exception('Caregiver login failed: ${res.statusCode} ${res.body}');
    }

    final result = json.decode(res.body) as Map<String, dynamic>;
    final token = result['access_token']?.toString();
    final userMap = (result['user'] as Map).cast<String, dynamic>();

    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access_token trong phản hồi caregiver login');
    }

    return LoginResult(
      accessToken: token,
      userServerJson: userMap,
      user: User.fromJson(userMap),
    );
  }

  Future<LoginResult> caregiverLoginWithPassword(
    String email,
    String password,
  ) async {
    final body = {'email': email, 'password': password};

    final res = await _api.post('/auth/caregiver/login', body: body);

    if (res.statusCode != 200) {
      throw Exception('Caregiver login failed: ${res.statusCode} ${res.body}');
    }

    final result = json.decode(res.body) as Map<String, dynamic>;
    final token = result['access_token']?.toString();
    final userMap = (result['user'] as Map).cast<String, dynamic>();

    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access_token trong phản hồi caregiver login');
    }

    return LoginResult(
      accessToken: token,
      userServerJson: userMap,
      user: User.fromJson(userMap),
    );
  }

  Future<void> saveFcmToken(String userId) async {
    debugPrint('🔄 Getting FCM token for user $userId...');
    final fcm = FirebaseMessaging.instance;
    final token = await fcm.getToken();
    if (token == null) {
      debugPrint('❌ FCM token is null');
      throw Exception("Không lấy được FCM token");
    }

    debugPrint('📱 FCM Token: $token');
    debugPrint('🔄 Saving FCM token to server...');

    final payloads = [
      {"userId": userId, "token": token, "type": "device"},
      {"userId": userId, "token": token, "type": "caregiver"},
    ];

    bool _is2xx(int code) => code >= 200 && code < 300;

    final results = await Future.wait(
      payloads.map((body) {
        return _api.post('/fcm/token', body: body);
      }),
    );

    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      final type = payloads[i]['type'];

      bool ok = _is2xx(res.statusCode);
      bool successField = false;
      try {
        final m = json.decode(res.body);
        successField = m is Map && (m['success'] == true || m['ok'] == true);
      } catch (_) {}

      if (!ok && !successField) {
        debugPrint(
          '❌ Save FCM token failed ($type): ${res.statusCode} ${res.body}',
        );
        throw Exception(
          'Save FCM token failed ($type): ${res.statusCode} ${res.body}',
        );
      } else {
        debugPrint(
          '✅ Saved FCM token for type=$type (status ${res.statusCode})',
        );
      }
    }
  }
}
