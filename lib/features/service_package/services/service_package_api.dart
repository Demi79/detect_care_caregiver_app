import 'dart:convert';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class ServicePackageApi {
  final String baseUrl;
  final ApiProvider? _api;

  ServicePackageApi({String? baseUrl, ApiProvider? api})
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _api = api {
    // Log baseUrl when initializing (use AppLogger)
    AppLogger.api('[ServicePackageApi] baseUrl=$baseUrl');
  }

  // Lấy danh sách gói dịch vụ từ API
  Future<List<Map<String, dynamic>>> fetchPackages() async {
    AppLogger.api('GET $baseUrl/plan');
    final provider =
        _api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);
    final response = await provider.get('/plan');
    AppLogger.api('Response status: ${response.statusCode}');
    AppLogger.api('Response body: ${response.body}');
    if (response.statusCode == 200) {
      // Safe JSON decoding with error handling
      dynamic responseData;
      try {
        if (response.body.isEmpty) {
          throw Exception('Empty response body');
        }
        responseData = json.decode(response.body);
      } catch (e) {
        AppLogger.apiError('Failed to parse response: $e');
        throw Exception('Failed to parse response: $e');
      }

      // Handle new standardized response format
      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
        final data = responseData['data'];
        if (data is List) {
          AppLogger.api('Parsed data (standardized): $data');
          return data.map((e) => e as Map<String, dynamic>).toList();
        } else {
          throw Exception('Dữ liệu plans không hợp lệ');
        }
      }
      // Fallback for old format (direct array)
      else if (responseData is List) {
        AppLogger.api('Parsed data (legacy): $responseData');
        return responseData.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Định dạng response không hợp lệ');
      }
    } else {
      AppLogger.apiError('Failed to load plans');
      throw Exception('Failed to load plans');
    }
  }

  // NOTE: The old /select-package endpoint was removed from backend. Use the
  // payment flow (PaymentService.createSubscriptionPayment) instead.
}
