import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../auth/data/auth_storage.dart';
import 'payment_endpoint_adapter.dart';
import 'payment_status_poller.dart';

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

  // Normalize VNPay reference field casing
  try {
    final ref = m['vnp_TxnRef'] ?? m['vnpTxnRef'] ?? m['txnRef'];
    if (ref != null) {
      m['vnp_TxnRef'] = ref;
      m['vnpTxnRef'] = ref;
    }
  } catch (_) {}

  try {
    final pid = m['paymentId'] ?? m['payment_id'];
    if (pid != null) {
      m['paymentId'] = pid;
      m['payment_id'] = pid;
    }
  } catch (_) {}

  return m;
}

// Helper to inspect various backend response shapes and decide whether the
// confirmation indicates a successful subscription. This mirrors logic used
// in UI controllers but centralizes it here so callers can rely on a
// canonical 'confirmed' field.
bool _confirmIndicatesSuccessForApi(dynamic confirm) {
  if (confirm == null) return false;
  try {
    if (confirm is Map<String, dynamic>) {
      final status = (confirm['status'] ?? '').toString().toLowerCase();
      // If the backend explicitly reports a negative/completion status, treat as not-success
      final negativeStatuses = [
        'failed',
        'fail',
        'cancel',
        'canceled',
        'expired',
        'declined',
      ];
      for (final neg in negativeStatuses) {
        if (status.contains(neg)) return false;
      }

      if (status == 'active' || status == 'success' || status == 'paid') {
        return true;
      }
      if (confirm['success'] == true) return true;
      if (confirm['isSuccess'] == true) return true;

      final subs = confirm['subscriptions'];
      if (subs is List && subs.isNotEmpty) {
        final first = subs.first;
        if (first is Map) {
          final s = (first['status'] ?? '').toString().toLowerCase();
          if (s == 'active' || s == 'success' || s == 'paid') return true;
        }
      }

      final data = confirm['data'];
      if (data is Map) {
        final s = (data['status'] ?? '').toString().toLowerCase();
        for (final neg in [
          'failed',
          'fail',
          'cancel',
          'canceled',
          'expired',
          'declined',
        ]) {
          if (s.contains(neg)) return false;
        }
        if (s == 'active' || s == 'success' || s == 'paid') return true;
        if (data['success'] == true) return true;
      }
    } else if (confirm is List && confirm.isNotEmpty) {
      final first = confirm.first;
      if (first is Map) {
        final s = (first['status'] ?? '').toString().toLowerCase();
        if (s == 'active' || s == 'success' || s == 'paid') return true;
      }
    }
  } catch (_) {}
  return false;
}

class PaymentApi {
  final String baseUrl;
  final ApiProvider? apiProvider;
  late final PaymentEndpointAdapter _adapter;

  /// If [apiProvider] is supplied, PaymentApi will use it (e.g. an instance
  /// of `ApiClient`) to perform requests so the app can reuse shared
  /// authentication/header behavior. If null, the class falls back to using
  /// `http` directly (legacy behavior).
  PaymentApi({required this.baseUrl, this.apiProvider}) {
    _adapter = PaymentEndpointAdapter(
      baseUrl: baseUrl,
      apiProvider: apiProvider,
    );
  }

  Future<Map<String, dynamic>> createPayment(
    String planCode,
    int amount,
    String token, {
    String? billingType,
    String? userId,
    String? idempotencyKey,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Function(bool)? onLoading,
  }) async {
    try {
      onLoading?.call(true);
      final result = await _adapter.createCheckoutSession(
        planCode: planCode,
        amount: amount,
        token: token,
        userId: userId,
        idempotencyKey: idempotencyKey,
        billingType: billingType,
        maxRetries: maxRetries,
      );

      if (result['success'] == true) {
        onLoading?.call(false);
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          return _normalizeCheckoutFields(data);
        }
        return {'status': 'success', 'data': data};
      } else {
        onLoading?.call(false);
        final err = result['error'] ?? 'Tạo payment thất bại';
        return {'status': 'error', 'message': err};
      }
    } catch (e) {
      AppLogger.apiError('Error in createPayment: $e');
      onLoading?.call(false);
      return {'status': 'error', 'message': 'Tạo payment thất bại: $e'};
    }
  }

  Future<({Map<String, dynamic> data, Map<String, String> headers})>
  getPaymentStatus(
    String transactionRef,
    String token, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Function(bool)? onLoading,
  }) async {
    try {
      onLoading?.call(true);

      // Adapter now targets standardized OpenAPI endpoints; transactionRef
      // here is used as the sessionId returned by the checkout flow.
      final result = await _adapter.getStatus(
        sessionId: transactionRef,
        token: token,
        maxRetries: maxRetries,
      );

      if (result['success'] == true) {
        onLoading?.call(false);
        return (
          data: _normalizeCheckoutFields(
            result['data'] as Map<String, dynamic>,
          ),
          headers: result['headers'] as Map<String, String>,
        );
      } else {
        onLoading?.call(false);
        return (
          data: result,
          headers:
              result['headers'] as Map<String, String>? ?? <String, String>{},
        );
      }
    } catch (e) {
      AppLogger.apiError('Error in getPaymentStatus: $e');
      onLoading?.call(false);
      return (
        data: {
          'status': 'error',
          'message': 'Không thể kiểm tra trạng thái payment: $e',
        },
        headers: <String, String>{},
      );
    }
  }

  Future<Map<String, dynamic>> createPaidSubscription(
    String paymentId,
    String planCode,
    String token, {
    String? idempotencyKey,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Function(bool)? onLoading,
  }) async {
    try {
      onLoading?.call(true);
      final result = await _adapter.createSubscriptionAfterPayment(
        paymentId: paymentId,
        planCode: planCode,
        token: token,
        idempotencyKey: idempotencyKey,
        maxRetries: maxRetries,
      );

      onLoading?.call(false);
      // Build canonical response: include whether the result indicates
      // confirmation, a message if present, and the raw payload.
      final raw = result['data'] ?? result;
      final message = (result['message'] ?? result['error'])?.toString();

      // Initial success detection based on various shapes
      var confirmed = _confirmIndicatesSuccessForApi(raw);

      // Additional strictness: require concrete evidence of a finalized
      // subscription/payment in the returned payload to avoid false
      // positives when backends return ambiguous shapes. Evidence includes
      // a subscription object/id, invoice, or paid timestamp.
      bool hasFinalizationEvidence(dynamic payload) {
        try {
          if (payload == null) return false;
          if (payload is Map<String, dynamic>) {
            // Top-level paid timestamp
            if (payload.containsKey('paid_at') ||
                payload.containsKey('paidAt')) {
              return true;
            }
            // Invoice or receipt
            if (payload.containsKey('invoice') ||
                payload.containsKey('invoice_url')) {
              return true;
            }
            // Subscription object or id
            if (payload.containsKey('subscription') &&
                payload['subscription'] is Map &&
                (payload['subscription']['id'] != null ||
                    payload['subscription']['status'] != null)) {
              return true;
            }
            if (payload.containsKey('subscription_id') ||
                payload.containsKey('subscriptionId') ||
                payload.containsKey('id')) {
              return true;
            }
            // Nested 'data'
            final nested = payload['data'];
            if (nested is Map) return hasFinalizationEvidence(nested);
          }
          // Lists: check first item
          if (payload is List && payload.isNotEmpty) {
            return hasFinalizationEvidence(payload.first);
          }
          return false;
        } catch (_) {
          return false;
        }
      }

      if (confirmed && raw is Map<String, dynamic>) {
        if (!hasFinalizationEvidence(raw)) {
          // If no solid evidence exists, don't mark as confirmed to avoid
          // recording cancellations/ambiguous responses as success. Include
          // the raw payload for logging/inspection.
          AppLogger.api(
            'createPaidSubscription: suspicious confirm payload without finalization evidence: ${raw.keys.toList()}',
          );
          confirmed = false;
        }
      }

      if (confirmed && raw is Map<String, dynamic>) {
        return {
          'confirmed': true,
          'message': message,
          'raw': raw,
          'data': _normalizeCheckoutFields(raw),
        };
      }

      // Not confirmed or no map data -> return canonical shape plus raw
      return {'confirmed': confirmed, 'message': message, 'raw': raw};
    } catch (e) {
      AppLogger.apiError('Error in createPaidSubscription: $e');
      onLoading?.call(false);
      return {
        'status': 'error',
        'message': 'Đăng ký subscription thất bại: $e',
      };
    }
  }

  Future<Map<String, dynamic>> createSubscription(
    String planCode,
    String token, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Function(bool)? onLoading,
  }) async {
    try {
      onLoading?.call(true);
      final result = await _adapter.createSubscriptionAfterPayment(
        planCode: planCode,
        token: token,
        maxRetries: maxRetries,
      );

      if (result['success'] == true) {
        onLoading?.call(false);
        return _normalizeCheckoutFields(result['data'] as Map<String, dynamic>);
      } else {
        onLoading?.call(false);
        return result;
      }
    } catch (e) {
      AppLogger.apiError('Error in createSubscription: $e');
      onLoading?.call(false);
      return {'status': 'error', 'message': 'Đăng ký thất bại: $e'};
    }
  }

  /// Fetch invoice count for badge display
  Future<int> getInvoiceCount(String token) async {
    final path = '/transactions/billing/history';
    final query = <String, String>{};
    final headers = <String, String>{};
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    try {
      AppLogger.api('Fetching invoice count from: $baseUrl$path');

      final provider =
          apiProvider ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);
      final response = await provider.get(
        path,
        extraHeaders: headers,
        query: query,
      );

      AppLogger.api('Invoice count response status: ${response.statusCode}');
      AppLogger.api('Invoice count response body: ${response.body}');

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          AppLogger.apiError('Failed to parse invoice count response: $e');
          return 0;
        }

        // Handle standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            return data['total'] as int? ?? 0;
          }
        }

        // Fallback for direct array response
        if (responseData is List) {
          return responseData.length;
        }

        return 0;
      } else {
        if (response.statusCode == 404) {
          try {
            AppLogger.api(
              'Invoice endpoint returned 404 — trying alternate base',
            );

            String providerBase = baseUrl;
            try {
              final apiClientFromArg = apiProvider is ApiClient
                  ? apiProvider
                  : null;
              final apiClientFromLocal = provider is ApiClient
                  ? provider
                  : null;
              providerBase =
                  (apiClientFromArg is ApiClient
                      ? apiClientFromArg.base
                      : null) ??
                  (apiClientFromLocal is ApiClient
                      ? apiClientFromLocal.base
                      : null) ??
                  providerBase;
            } catch (_) {}

            String altBase = providerBase;
            if (altBase.endsWith('/api')) {
              altBase = altBase.substring(0, altBase.length - 4);
            } else {
              altBase = '$altBase/api';
            }
            // Normalize trailing slash
            if (altBase.endsWith('/')) {
              altBase = altBase.substring(0, altBase.length - 1);
            }
            final altUri = Uri.parse(
              '$altBase$path',
            ).replace(queryParameters: query);
            final altHeaders = <String, String>{};
            if (token.isNotEmpty) altHeaders['Authorization'] = 'Bearer $token';

            final altRes = await http.get(altUri, headers: altHeaders);
            AppLogger.api(
              'Alternate invoice URL response status: ${altRes.statusCode}',
            );
            AppLogger.api(
              'Alternate invoice URL response body: ${altRes.body}',
            );

            if (altRes.statusCode == 200) {
              dynamic responseData;
              try {
                responseData = json.decode(altRes.body);
              } catch (e) {
                AppLogger.apiError(
                  'Failed to parse alternate invoice response: $e',
                );
                return 0;
              }

              if (responseData is Map<String, dynamic> &&
                  responseData['success'] == true) {
                final data = responseData['data'];
                if (data is Map<String, dynamic>) {
                  return data['total'] as int? ?? 0;
                }
              }

              if (responseData is List) {
                return responseData.length;
              }
            }
          } catch (e) {
            AppLogger.apiError('Alternate invoice fetch failed: $e');
          }
        }

        AppLogger.api('Failed to fetch invoice count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      AppLogger.apiError('Error fetching invoice count: $e');
      return 0;
    }
  }

  /// Poll payment status with exponential backoff until completion
  ///
  /// This method repeatedly checks payment status using the configured endpoint
  /// (legacy VNPay or target OpenAPI) with exponential backoff until the payment
  /// is completed or failed.
  ///
  /// [vnpTxnRef] - Transaction reference for legacy VNPay endpoints
  /// [sessionId] - Session ID for target OpenAPI endpoints
  /// [token] - Authentication token
  /// [maxAttempts] - Maximum polling attempts (default: 30)
  /// [initialDelay] - Initial delay between polls in seconds (default: 2)
  /// [maxDelay] - Maximum delay between polls in seconds (default: 30)
  /// [onProgress] - Optional callback for each polling attempt
  /// [onComplete] - Optional callback when polling completes
  /// [onError] - Optional callback when polling fails
  Future<Map<String, dynamic>> pollPaymentStatus({
    required String sessionId,
    required String token,
    int maxAttempts = 30,
    int initialDelay = 2,
    int maxDelay = 30,
    Function(int attempt, Map<String, dynamic> data)? onProgress,
    Function(Map<String, dynamic> data)? onComplete,
    Function(String error)? onError,
  }) async {
    // Adapter uses OpenAPI endpoints; require sessionId and poll via OpenAPI
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId is required for polling status');
    }

    return PaymentStatusPoller.pollVNPayStatus(
      getStatus: () => getPaymentStatus(sessionId, token),
      isPaymentComplete: PaymentStatusPoller.isOpenApiPaymentComplete,
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
      maxDelay: maxDelay,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
  }
}
