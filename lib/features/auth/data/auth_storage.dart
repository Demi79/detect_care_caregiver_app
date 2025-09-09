import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const kUserPhone = 'user_phone';
  static const kUserPin = 'user_pin';
  static const kUserId = 'user_id';
  static const kAccessToken = 'access_token';
  static const kUserJson = 'user_json';

  static Future<void> saveCredentials({
    required String phone,
    required String pin,
    required String userId,
    String? accessToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserPhone, phone);
    await prefs.setString(kUserPin, pin);
    await prefs.setString(kUserId, userId);
    if (accessToken != null) {
      await prefs.setString(kAccessToken, accessToken);
    }
  }

  static Future<void> saveAuthResult({
    required String accessToken,
    required Map<String, dynamic> userJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAccessToken, accessToken);
    await prefs.setString(kUserId, userJson['user_id'] as String? ?? '');
    await prefs.setString(kUserJson, jsonEncode(userJson));
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kUserId);
  }

  static Future<(String?, String?)> getPhonePin() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(kUserPhone), prefs.getString(kUserPin));
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kAccessToken);
  }

  static Future<Map<String, dynamic>?> getUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUserJson);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserPhone);
    await prefs.remove(kUserPin);
    await prefs.remove(kUserId);
    await prefs.remove(kAccessToken);
    await prefs.remove(kUserJson);
  }
}
