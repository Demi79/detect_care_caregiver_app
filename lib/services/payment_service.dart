import 'dart:convert';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

Map<String, dynamic> _normalizeCheckoutFields(Map<String, dynamic> m) {
  try {
    final val =
        m['paymentUrl'] ??
        m['checkoutUrl'] ??
        m['url'] ??
        m['payment_url'] ??
        m['checkout_url'];
    if (val != null) {
      m['paymentUrl'] = val;
      m['checkoutUrl'] = val;
    }
  } catch (_) {}
  return m;
}

class PaymentService {
  final String baseUrl;
  final ApiProvider? _api;

  PaymentService({String? baseUrl, ApiProvider? api})
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _api = api {
    AppLogger.api('[PaymentService] baseUrl=$baseUrl');
  }

  /// Tạo payment và subscription tự động cho mobile app
  Future<Map<String, dynamic>> createSubscriptionPayment({
    required String planCode,
    required double amount,
    required String userId,
    String? description,
    double? taxRate, // optional tax rate as fraction (e.g. 0.1 for 10%)
  }) async {
    AppLogger.api('POST $baseUrl/payments/create');
    // Normalize amounts to integer VND where appropriate and include tax
    final int amountVnd = amount.round();
    final double appliedTaxRate = taxRate ?? 0.0;
    final int taxAmount = (amountVnd * appliedTaxRate).round();
    final int totalAmount = amountVnd + taxAmount;

    final bodyObj = {
      'plan_code': planCode,
      'amount': amountVnd,
      'currency': 'VND',
      'user_id': userId,
      'tax_rate': appliedTaxRate,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      if (description != null) 'description': description,
    };
    AppLogger.api('Request body: $bodyObj');

    final provider =
        _api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);
    final response = await provider.post('/payments/create', body: bodyObj);
    AppLogger.api('Response status: ${response.statusCode}');
    AppLogger.api('Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
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

      // Handle standardized response format
      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
        final data = responseData['data'];
        if (data is Map<String, dynamic>) {
          AppLogger.api('Subscription payment created: $data');
          return _normalizeCheckoutFields(data);
        } else {
          throw Exception('Dữ liệu payment không hợp lệ');
        }
      }
      // Fallback for direct response
      else if (responseData is Map<String, dynamic>) {
        AppLogger.api('Subscription payment created (legacy): $responseData');
        return _normalizeCheckoutFields(responseData);
      } else {
        throw Exception('Định dạng response không hợp lệ');
      }
    } else {
      AppLogger.apiError('Failed to create subscription payment');
      throw Exception(
        'Failed to create subscription payment: ${response.statusCode}',
      );
    }
  }

  /// Kiểm tra trạng thái payment
  Future<Map<String, dynamic>?> checkPaymentStatus(String transactionId) async {
    AppLogger.api('GET $baseUrl/payments/$transactionId/status');
    final provider =
        _api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);
    final response = await provider.get('/payments/$transactionId/status');
    AppLogger.api('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return _normalizeCheckoutFields(data);
      return null;
    } else {
      AppLogger.apiError('Failed to check payment status');
      return null;
    }
  }
}
