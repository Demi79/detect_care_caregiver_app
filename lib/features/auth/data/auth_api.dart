import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/models/otp_request_result.dart';

class AuthApi {
  final ApiClient _api;
  AuthApi(this._api);

  String _normalizePhoneTo84(String phone) {
    var p = phone.trim();
    p = p.replaceAll(RegExp(r'[\s-]'), '');
    if (p.startsWith('+84')) return '84${p.substring(3)}';
    if (p.startsWith('084')) return '84${p.substring(3)}';
    if (p.startsWith('0') && p.length > 1) return '84${p.substring(1)}';
    return p;
  }

  Future<OtpRequestResult> requestOtp(
    String phone, {
    String method = 'sms',
  }) async {
    final normalized = _normalizePhoneTo84(phone);
    final res = await _api.post(
      '/auth/request-otp',
      body: {'phone_number': normalized, 'method': method},
    );
    Map<String, dynamic> data = const {};
    try {
      data = json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode != 200) {
      final msg = data['message']?.toString() ?? 'OTP request failed';
      throw Exception('OTP request failed: ${res.statusCode} $msg');
    }
    return OtpRequestResult.fromJson(data);
  }

  Future<Map<String, dynamic>> loginWithOtp(String phone, String code) async {
    final normalized = _normalizePhoneTo84(phone);
    final res = await _api.post(
      '/auth/login',
      body: {'phone_number': normalized, 'otp_code': code},
    );
    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/auth/me');
    if (res.statusCode != 200) {
      throw Exception('Get profile failed: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
  }
}
