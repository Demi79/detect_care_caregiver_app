import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../auth/data/auth_storage.dart';

class PaymentEndpointAdapter {
  final String baseUrl;
  final ApiProvider? apiProvider;

  PaymentEndpointAdapter({required this.baseUrl, this.apiProvider});

  // Helpers for normalizing return shapes and status checks
  Map<String, dynamic> _normalizeCheckoutFields(Map<String, dynamic> src) {
    final m = Map<String, dynamic>.from(src);

    void setIfNull(String k, dynamic v) {
      if (!m.containsKey(k) || m[k] == null) m[k] = v;
    }

    try {
      final val =
          m['paymentUrl'] ??
          m['checkoutUrl'] ??
          m['url'] ??
          m['payment_url'] ??
          m['checkout_url'];
      if (val != null) {
        setIfNull('paymentUrl', val);
        setIfNull('checkoutUrl', val);
      }
    } catch (_) {}

    try {
      final ref = m['vnp_TxnRef'] ?? m['vnpTxnRef'] ?? m['txnRef'];
      if (ref != null) {
        setIfNull('vnp_TxnRef', ref);
        setIfNull('vnpTxnRef', ref);
      }
    } catch (_) {}

    try {
      final pid = m['paymentId'] ?? m['payment_id'];
      if (pid != null) {
        setIfNull('paymentId', pid);
        setIfNull('payment_id', pid);
      }
    } catch (_) {}

    return m;
  }

  bool _isPaidStatus(String? s) {
    final v = (s ?? '').toLowerCase();
    return {
      'paid',
      'success',
      'succeeded',
      'completed',
      'settled',
      'applied',
      'active',
    }.contains(v);
  }

  bool _isFailedStatus(String? s) {
    final v = (s ?? '').toLowerCase();
    return v.contains('fail') ||
        v.contains('canceled') ||
        v.contains('cancel') ||
        v.contains('declined') ||
        v.contains('expired') ||
        v.contains('void') ||
        v.contains('reverse') ||
        v.contains('refund') ||
        v.contains('chargeback') ||
        v == 'error';
  }

  bool _confirmIndicatesSuccessForApi(dynamic confirm) {
    if (confirm == null) return false;
    try {
      if (confirm is Map<String, dynamic>) {
        final status = (confirm['status'] ?? '').toString();
        if (_isFailedStatus(status)) return false;
        if (_isPaidStatus(status)) return true;
        if (confirm['success'] == true || confirm['isSuccess'] == true) {
          return true;
        }

        final subs = confirm['subscriptions'];
        if (subs is List && subs.isNotEmpty && subs.first is Map) {
          final s = (subs.first['status'] ?? '').toString();
          if (_isPaidStatus(s)) return true;
        }

        final data = confirm['data'];
        if (data is Map) {
          final s = (data['status'] ?? '').toString();
          if (_isFailedStatus(s)) return false;
          if (_isPaidStatus(s) || data['success'] == true) return true;
        }
      } else if (confirm is List &&
          confirm.isNotEmpty &&
          confirm.first is Map) {
        final s = (confirm.first['status'] ?? '').toString();
        if (_isPaidStatus(s)) return true;
      }
    } catch (_) {}
    return false;
  }

  ApiProvider _provider() =>
      apiProvider ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Map<String, String> _buildHeaders({String? token, String? idempotencyKey}) {
    final headers = <String, String>{};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    if (token?.isNotEmpty == true) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  /// Generic request helper with retry logic. Returns decoded JSON (Map/List/primitive)
  /// when a successful status code is received.
  Future<dynamic> _requestWithRetries(
    String method,
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
    List<int>? successStatusCodes,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
    Duration? maxBackoff,
  }) async {
    successStatusCodes ??= [200];
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.api('Attempt $attempt/$maxRetries: $method $path');
        final provider = _provider();
        final httpResponse = await _callProvider(
          provider,
          method,
          path,
          body: body,
          extraHeaders: extraHeaders,
        );

        if (successStatusCodes.contains(httpResponse.statusCode)) {
          // Prefer provider's extractor when available to handle
          // standardized responses of the form { success, data, error }
          try {
            final extracted = provider.extractDataFromResponse(httpResponse);
            return extracted;
          } catch (_) {
            // Fallback to raw JSON decode if provider can't extract
            try {
              return json.decode(httpResponse.body);
            } catch (e) {
              // If decode fails, return raw body
              return httpResponse.body;
            }
          }
        }

        if (attempt == maxRetries) {
          throw Exception(
            'Failed $method $path after $maxRetries attempts (status=${httpResponse.statusCode})',
          );
        }
      } catch (e) {
        AppLogger.apiError('Error during $method $path: $e');
        if (attempt == maxRetries) rethrow;
        // exponential backoff
        final factor = 1 << (attempt - 1);
        final ms = retryDelay.inMilliseconds * factor;
        final d = Duration(milliseconds: ms);
        final capped = (maxBackoff != null && d > maxBackoff) ? maxBackoff : d;
        await Future.delayed(capped);
      }
    }

    throw Exception('Unexpected error in request $method $path');
  }

  Future<dynamic> _callProvider(
    ApiProvider provider,
    String method,
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    switch (method.toUpperCase()) {
      case 'GET':
        return provider.get(path, extraHeaders: extraHeaders);
      case 'POST':
        return provider.post(path, body: body, extraHeaders: extraHeaders);
      case 'PUT':
        return provider.put(path, body: body, extraHeaders: extraHeaders);
      case 'PATCH':
        return provider.patch(path, body: body, extraHeaders: extraHeaders);
      case 'DELETE':
        return provider.delete(path, body: body, extraHeaders: extraHeaders);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  /// Get plans list
  /// Get plans list
  /// Target: GET /api/plan
  Future<Map<String, dynamic>> getPlans({
    String? token,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    const path = '/plan';
    final headers = _buildHeaders(token: token);

    final responseData = await _requestWithRetries(
      'GET',
      path,
      extraHeaders: headers,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      maxBackoff: const Duration(seconds: 5),
    );

    if (responseData is List) {
      return {'success': true, 'data': responseData};
    } else if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    throw Exception('Unexpected response shape from getPlans');
  }

  /// Create checkout session
  /// Legacy: POST /payments/vnpay (with plan_code, amount, user_id)
  /// Target: POST /api/payments/create (FE expects this endpoint to create checkout/payment sessions)
  Future<Map<String, dynamic>> createCheckoutSession({
    required String planCode,
    required int amount,
    String? token,
    String? userId,
    String? idempotencyKey,
    String? billingType,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    // Use standardized target endpoint for creating checkout/payment sessions
    const path = '/payments/create';
    final body = {
      'plan_code': planCode,
      'amount': amount,
      if (userId != null) 'user_id': userId,
      if (billingType != null) 'billing_type': billingType,
    };
    final headers = _buildHeaders(token: token, idempotencyKey: idempotencyKey);

    try {
      final responseData = await _requestWithRetries(
        'POST',
        path,
        body: body,
        extraHeaders: headers,
        successStatusCodes: [200, 201],
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        maxBackoff: const Duration(seconds: 5),
      );

      // If backend returns a wrapper like { success: true, data: ... }, the
      // provider.extractDataFromResponse already returns the inner data.
      if (responseData is Map<String, dynamic>) {
        return {'success': true, 'data': responseData};
      }

      // If responseData is a list or primitive, return as data
      return {'success': true, 'data': responseData};
    } catch (e) {
      AppLogger.apiError('createCheckoutSession failed: $e');
      // Surface error to caller
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Prepare upgrade for a subscription
  /// POST /subscriptions/:subscriptionId/upgrade
  /// Request body: { plan_code, paymentProvider: 'vn_pay', idempotencyKey }
  /// Response expected: { status, amountDue, proration, transactionId, ... }
  Future<Map<String, dynamic>> prepareUpgrade({
    required String subscriptionId,
    required String planCode,

    /// Optional billing cycle / duration identifier (e.g. 'monthly', 'yearly', or custom code)
    String? billingCycle,
    String paymentProvider = 'vn_pay',
    String? token,
    String? idempotencyKey,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    final path =
        '/subscriptions/${Uri.encodeComponent(subscriptionId)}/upgrade';
    final body = {
      'plan_code': planCode,
      if (billingCycle != null) 'billing_cycle': billingCycle,
      'paymentProvider': paymentProvider,
    };
    final headers = _buildHeaders(token: token, idempotencyKey: idempotencyKey);

    try {
      final responseData = await _requestWithRetries(
        'POST',
        path,
        body: body,
        extraHeaders: headers,
        successStatusCodes: [200, 201],
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        maxBackoff: const Duration(seconds: 5),
      );

      // Expect backend to return an object with amountDue and status
      if (responseData is Map<String, dynamic>) {
        return {'success': true, 'data': responseData};
      }

      return {'success': true, 'data': responseData};
    } catch (e) {
      AppLogger.apiError('prepareUpgrade failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create VNPay payment
  /// POST /payments/vnpay
  /// Payload: { plan_code, description? } and Idempotency-Key in header
  /// Response: { payment_id, payment_url, vnpTxnRef, amount, ... }
  Future<Map<String, dynamic>> createVnPayPayment({
    required String planCode,

    /// Optional billing cycle/duration to create payment for (e.g. 'monthly', 'yearly')
    String? billingCycle,
    String? description,
    String? token,
    String? idempotencyKey,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    const path = '/payments/vnpay';
    final body = {
      'plan_code': planCode,
      if (billingCycle != null) 'billing_cycle': billingCycle,
      if (description != null) 'description': description,
    };
    final headers = _buildHeaders(token: token, idempotencyKey: idempotencyKey);

    try {
      final responseData = await _requestWithRetries(
        'POST',
        path,
        body: body,
        extraHeaders: headers,
        successStatusCodes: [200, 201],
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        maxBackoff: const Duration(seconds: 5),
      );

      if (responseData is Map<String, dynamic>) {
        return {'success': true, 'data': responseData};
      }

      return {'success': true, 'data': responseData};
    } catch (e) {
      AppLogger.apiError('createVnPayPayment failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Poll payment status with the schedule:
  /// - 2s interval, 5 attempts
  /// - then 5s interval, 6 attempts
  /// Total ~40s-60s depending on delays. Returns last status or timeout.
  Future<Map<String, dynamic>> pollPaymentStatus({
    required String paymentId,
    String? token,
    int shortIntervalSeconds = 2,
    int shortAttempts = 5,
    int longIntervalSeconds = 5,
    int longAttempts = 6,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    // headers not required here because getStatus builds headers internally

    Future<Map<String, dynamic>> checkOnce() async {
      try {
        final statusResp = await getStatus(
          sessionId: paymentId,
          token: token,
          maxRetries: 1,
        );
        return statusResp;
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }

    // short attempts with early fail detection
    for (int i = 0; i < shortAttempts; i++) {
      final resp = await checkOnce();
      if (resp['success'] == true) {
        final data = resp['data'];
        final status = data is Map<String, dynamic>
            ? (data['status'] ?? data['payment_status'] ?? data['state'])
            : null;
        if (_isPaidStatus(status?.toString())) {
          return {'success': true, 'data': data};
        }
        if (_isFailedStatus(status?.toString())) {
          return {'success': false, 'error': 'failed', 'data': data};
        }
      }
      // wait
      await Future.delayed(Duration(seconds: shortIntervalSeconds));
    }

    // long attempts with early fail detection
    for (int i = 0; i < longAttempts; i++) {
      final resp = await checkOnce();
      if (resp['success'] == true) {
        final data = resp['data'];
        final status = data is Map<String, dynamic>
            ? (data['status'] ?? data['payment_status'] ?? data['state'])
            : null;
        if (_isPaidStatus(status?.toString())) {
          return {'success': true, 'data': data};
        }
        if (_isFailedStatus(status?.toString())) {
          return {'success': false, 'error': 'failed', 'data': data};
        }
      }
      await Future.delayed(Duration(seconds: longIntervalSeconds));
    }

    return {
      'success': false,
      'error': 'timeout',
      'message':
          'Payment status polling timed out. Please check manually later.',
    };
  }

  /// Get payment/subscription status
  /// Legacy: GET /payments/querydr/{vnpTxnRef}
  /// Target: GET /api/payments/querydr/{sessionId}
  /// Returns: {success: bool, data: dynamic, headers: Map<String, String>, error?: String}
  Future<Map<String, dynamic>> getStatus({
    String? sessionId,
    String? token,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    final headers = _buildHeaders(token: token);
    if (sessionId == null) {
      throw ArgumentError('sessionId required for checking status');
    }

    final encodedSession = Uri.encodeComponent(sessionId);

    // Primary (current) status endpoint (VNPay querydr passthrough)
    final queryDrPath = '/payments/querydr/$encodedSession';
    final response = await _requestWithRetriesReturnHeaders(
      _provider(),
      'GET',
      queryDrPath,
      extraHeaders: headers,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      maxBackoff: const Duration(seconds: 5),
    );

    if (response['data'] != null) {
      final data = response['data'];
      final norm = data is Map<String, dynamic>
          ? _normalizeCheckoutFields(data)
          : data;
      return {'success': true, 'data': norm, 'headers': response['headers']};
    }

    AppLogger.api('Primary status endpoint returned no data, trying fallbacks');

    final fallbacks = [
      // Legacy/query variants
      '/payments/$encodedSession/status',
      '/payments/status/$encodedSession',
      '/subscriptions/status?session_id=$encodedSession',
      '/transactions/$encodedSession',
    ];

    for (final fb in fallbacks) {
      AppLogger.api('Trying fallback status endpoint: $fb');
      final fbResponse = await _requestWithRetriesReturnHeaders(
        _provider(),
        'GET',
        fb,
        extraHeaders: headers,
        maxRetries: 1,
        retryDelay: retryDelay,
      );
      if (fbResponse['data'] != null) {
        final data = fbResponse['data'];
        final norm = data is Map<String, dynamic>
            ? _normalizeCheckoutFields(data)
            : data;
        return {
          'success': true,
          'data': norm,
          'headers': fbResponse['headers'],
        };
      }
    }

    return {
      'success': false,
      'error': 'Failed to retrieve payment status for session: $sessionId',
      'headers': <String, String>{},
    };
  }

  /// Create subscription after payment
  /// Legacy: POST /subscriptions/paid (with payment_id, plan_code)
  /// Target: Not needed - subscription created automatically via checkout
  Future<Map<String, dynamic>> createSubscriptionAfterPayment({
    String? paymentId,
    required String planCode,
    String? token,
    String? idempotencyKey,
    int maxRetries = 3,
  }) async {
    final headers = _buildHeaders(token: token, idempotencyKey: idempotencyKey);

    // Target architecture: subscription is created automatically after
    // successful checkout on the backend. To surface the subscription to
    // the client, fetch the user's subscriptions list and return it.
    const path = '/subscriptions/me';
    final responseData = await _requestWithRetries(
      'GET',
      path,
      extraHeaders: headers,
      maxRetries: maxRetries,
    );
    return {'success': true, 'data': responseData};
  }

  /// Variant of _requestWithRetries that returns both parsed data and
  /// response headers so callers can use server headers (e.g. Retry-After).
  Future<Map<String, dynamic>> _requestWithRetriesReturnHeaders(
    ApiProvider provider,
    String method,
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
    List<int>? successStatusCodes,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 400),
    Duration? maxBackoff,
  }) async {
    successStatusCodes ??= [200];
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.api('Attempt(headers) $attempt/$maxRetries: $method $path');
        final httpResponse = await _callProvider(
          provider,
          method,
          path,
          body: body,
          extraHeaders: extraHeaders,
        );

        if (successStatusCodes.contains(httpResponse.statusCode)) {
          try {
            final extracted = provider.extractDataFromResponse(httpResponse);
            return {
              'data': extracted,
              'headers': Map<String, String>.from(httpResponse.headers),
            };
          } catch (_) {
            try {
              final decoded = json.decode(httpResponse.body);
              return {
                'data': decoded,
                'headers': Map<String, String>.from(httpResponse.headers),
              };
            } catch (e) {
              return {
                'data': httpResponse.body,
                'headers': Map<String, String>.from(httpResponse.headers),
              };
            }
          }
        }

        if (attempt == maxRetries) {
          throw Exception(
            'Failed $method $path after $maxRetries attempts (status=${httpResponse.statusCode})',
          );
        }
      } catch (e) {
        AppLogger.apiError('Error during $method $path (headers): $e');
        if (attempt == maxRetries) rethrow;
        // exponential backoff
        final factor = 1 << (attempt - 1);
        final ms = retryDelay.inMilliseconds * factor;
        final d = Duration(milliseconds: ms);
        final capped = (maxBackoff != null && d > maxBackoff) ? maxBackoff : d;
        await Future.delayed(capped);
      }
    }

    throw Exception('Unexpected error in request $method $path');
  }
}
