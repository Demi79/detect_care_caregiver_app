import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/models/user_consent.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class ConsentRemoteDataSource {
  final ApiClient _api;

  ConsentRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  /// GET /api/users/{user_id}/consents
  Future<List<UserConsent>> getUserConsents(String userId) async {
    final res = await _api.get('/users/$userId/consents');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET consents failed: ${res.statusCode} ${res.body}');
    }
    final decoded = _api.decodeResponseBody(res);
    if (decoded is! List) {
      throw Exception('Unexpected consents response: ${res.body}');
    }
    return decoded.map((e) => UserConsent.fromJson(e)).toList();
  }

  /// POST /api/users/{user_id}/consents
  Future<UserConsent> createConsent({
    required String userId,
    required ConsentType type,
    required String version,
    required bool consented,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _api.post(
      '/users/$userId/consents',
      body: {
        'type': type.name,
        'version': version,
        'consented': consented,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'metadata': metadata,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST consent failed: ${res.statusCode} ${res.body}');
    }
    final decoded = _api.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected create consent response: ${res.body}');
    }
    return UserConsent.fromJson(decoded);
  }

  /// PUT /api/users/{user_id}/consents/{consent_id}
  Future<UserConsent> updateConsent({
    required String userId,
    required String consentId,
    required bool consented,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _api.put(
      '/users/$userId/consents/$consentId',
      body: {
        'consented': consented,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'metadata': metadata,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT consent failed: ${res.statusCode} ${res.body}');
    }
    final decoded = _api.extractDataFromResponse(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected update consent response: ${res.body}');
    }
    return UserConsent.fromJson(decoded);
  }

  /// GET /api/consent-policies/{type}
  Future<Map<String, dynamic>> getConsentPolicy(ConsentType type) async {
    final res = await _api.get('/consent-policies/${type.name}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'GET consent policy failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = _api.decodeResponseBody(res);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected consent policy response: ${res.body}');
    }
    return decoded.cast<String, dynamic>();
  }
}
