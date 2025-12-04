import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import '../../auth/data/auth_storage.dart';
import '../../emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import '../models/plan.dart';

class ServicePackageApi {
  final ApiClient _apiClient;
  ServicePackageApi()
    : _apiClient = ApiClient(tokenProvider: AuthStorage.getAccessToken);

  // Public endpoint - no authentication required
  Future<List<Plan>> fetchPlans() async {
    // Use shared ApiClient to fetch public plans so we get consistent logging
    // and response decoding. The endpoint is public so no auth header is
    // required; ApiClient will still set Content-Type and log the request.
    final response = await _apiClient.get('/plan');

    AppLogger.api('[ServicePackageApi] GET /plan');
    AppLogger.api('Response status: ${response.statusCode}');
    AppLogger.api('Response body: ${response.body}');

    if (response.statusCode == 200) {
      // Safe JSON decoding with error handling using ApiClient helper
      dynamic responseData;
      try {
        responseData = _apiClient.decodeResponseBody(response);
      } catch (e) {
        throw Exception('Failed to parse response: $e');
      }

      // Handle new standardized response format
      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
        final data = responseData['data'];
        if (data is List) {
          return data.map((e) => Plan.fromJson(e)).toList();
        } else if (data is Map<String, dynamic>) {
          return [Plan.fromJson(data)];
        } else {
          throw Exception('Dữ liệu plans không hợp lệ');
        }
      }
      // Fallback for old format (direct array or object)
      else if (responseData is List) {
        return responseData.map((e) => Plan.fromJson(e)).toList();
      } else if (responseData is Map<String, dynamic>) {
        return [Plan.fromJson(responseData)];
      } else {
        throw Exception('Định dạng response không hợp lệ');
      }
    } else {
      throw Exception(
        'Không thể lấy danh sách gói dịch vụ: ${response.statusCode}',
      );
    }
  }

  // Get specific plan by code - authenticated
  Future<Plan?> fetchPlanByCode(String code) async {
    try {
      final response = await _apiClient.get('/plan/$code');

      if (response.statusCode == 200) {
        final responseData = _apiClient.extractDataFromResponse(response);

        // Handle new standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            return Plan.fromJson(data);
          } else {
            AppLogger.api('Failed to fetch plan $code: Invalid data format');
            return null;
          }
        }
        // Fallback for old format
        else if (responseData is Map<String, dynamic>) {
          return Plan.fromJson(responseData);
        } else {
          AppLogger.api(
            'Failed to fetch plan $code: Unexpected response format',
          );
          return null;
        }
      } else {
        AppLogger.api('Failed to fetch plan $code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.apiError('Error fetching plan $code: $e');
      return null;
    }
  }

  // Authenticated endpoints using ApiClient
  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    try {
      const endpoint = '/subscriptions/me';
      final resp = await _apiClient.get(endpoint);

      AppLogger.api(
        '[ServicePackageApi] GET $endpoint status=${resp.statusCode}',
      );
      if (resp.statusCode != 200) return null;

      final decoded = _apiClient.extractDataFromResponse(resp);
      // Hỗ trợ cả new-format {success:true,data:{...}} và legacy
      final payload =
          (decoded is Map<String, dynamic> && decoded['success'] == true)
          ? decoded['data']
          : decoded;

      if (payload is! Map<String, dynamic>) {
        return {'plan': null, 'subscription': null};
      }

      Map<String, dynamic>? subscriptionMap;
      Map<String, dynamic>? planMap;

      final subs = payload['subscriptions'];
      if (subs is List && subs.isNotEmpty) {
        // Future-proofing: handle multiple subscriptions by prioritizing active status
        // and most recent current_period_end
        final subscriptions =
            subs
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
              ..sort((a, b) {
                final sa = (a['status'] ?? '').toString();
                final sb = (b['status'] ?? '').toString();
                final wa = sa == 'active' ? 1 : 0;
                final wb = sb == 'active' ? 1 : 0;
                if (wa != wb) return wb - wa;
                final ea =
                    DateTime.tryParse(
                      (a['current_period_end'] ?? '').toString(),
                    ) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final eb =
                    DateTime.tryParse(
                      (b['current_period_end'] ?? '').toString(),
                    ) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return eb.compareTo(ea);
              });

        final rawSub = subscriptions.isNotEmpty ? subscriptions.first : null;
        if (rawSub != null) {
          subscriptionMap = Map<String, dynamic>.from(rawSub);

          // Ưu tiên lấy plan từ "plans" → "plan" → "plan_snapshot"
          Map<String, dynamic>? derivePlan(Map<String, dynamic> s) {
            final dynamic candidate =
                s['plans'] ?? s['plan'] ?? s['plan_snapshot'];
            if (candidate is Map) return Map<String, dynamic>.from(candidate);

            // Fallback: build tối thiểu từ plan_code
            final planCode = s['plan_code'] ?? s['code'];
            if (planCode != null) {
              return <String, dynamic>{
                'code': planCode,
                'plan_code': planCode,
                'name': s['plan_name'] ?? planCode.toString(),
                'billing_period': s['billing_period'],
              };
            }
            return null;
          }

          planMap = derivePlan(subscriptionMap);

          // Chỉ thêm fallback nếu thật sự thiếu (không ghi đè)
          if (!subscriptionMap.containsKey('plan_code')) {
            final fallbackCode = planMap?['code'];
            if (fallbackCode != null) {
              subscriptionMap['plan_code'] = fallbackCode;
            }
          }
          if (!subscriptionMap.containsKey('current_period_end') &&
              subscriptionMap['current_period_end'] != null) {
            subscriptionMap['current_period_end'] =
                subscriptionMap['current_period_end'];
          }
        }
      }

      final normalized = {'plan': planMap, 'subscription': subscriptionMap};
      AppLogger.api(
        '[ServicePackageApi] Normalized current subscription: $normalized',
      );
      return normalized;
    } catch (e) {
      AppLogger.apiError('❌ Error fetching current subscription: $e');
      return null;
    }
  }

  // Backwards-compatible alias for callers that still use the old name.
  // Prefer calling getCurrentSubscription() directly.
  Future<Map<String, dynamic>?> getCurrentPlan() async =>
      await getCurrentSubscription();

  /// Helper to convert normalized plan data to a UI-friendly view model
  /// Returns a flattened map with common fields for easier UI access
  Map<String, dynamic> toCurrentPlanVM(Map<String, dynamic>? normalized) {
    final sub = normalized?['subscription'] as Map<String, dynamic>?;
    final plan = normalized?['plan'] as Map<String, dynamic>?;
    final status = sub?['status']?.toString();
    final endsAt = DateTime.tryParse('${sub?['current_period_end'] ?? ''}');
    final isActive = status == 'active';
    final planCode = (sub?['plan_code'] ?? plan?['code'])?.toString();

    // Đặc biệt: unit_amount_minor là string "0"
    final priceMinor = sub?['unit_amount_minor']?.toString();
    final isZeroPriced = priceMinor == '0';

    return {
      'isActive': isActive,
      'planCode': planCode,
      'planName': plan?['name'],
      'billingPeriod': sub?['billing_period'] ?? plan?['billing_period'],
      'expiresAt': endsAt?.toIso8601String(),
      'isZeroPriced': isZeroPriced,
    };
  }

  Future<Map<String, dynamic>?> getCurrentQuota() async {
    try {
      final ds = EmergencyContactsRemoteDataSource(api: _apiClient);
      final customerId = await ds.resolveCustomerId();
      if (customerId == null || customerId.isEmpty) return null;

      final response = await _apiClient.get('/users/$customerId/quota');

      if (response.statusCode == 200) {
        final responseData = _apiClient.extractDataFromResponse(response);

        // Handle new standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          return responseData['data'] as Map<String, dynamic>?;
        }
        // Fallback for old format
        else if (responseData is Map<String, dynamic>) {
          return responseData;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      AppLogger.apiError('Error fetching current quota: $e');
      return null;
    }
  }

  /// Helper to return the active subscription id for the current user.
  /// Returns null when there's no active subscription or on error.
  Future<String?> getActiveSubscriptionId() async {
    try {
      final response = await _apiClient.get('/subscriptions/me');
      if (response.statusCode != 200) return null;
      final decoded = _apiClient.extractDataFromResponse(response);
      final data =
          (decoded is Map<String, dynamic> && decoded['success'] == true)
          ? decoded['data']
          : decoded;
      if (data is Map<String, dynamic> && data['subscriptions'] is List) {
        final subs = data['subscriptions'] as List;
        if (subs.isNotEmpty) {
          final sub = subs.first as Map<String, dynamic>;
          return (sub['subscription_id'] ?? sub['id'])?.toString();
        }
      }
      return null;
    } catch (e) {
      AppLogger.apiError('Error in getActiveSubscriptionId: $e');
      return null;
    }
  }

  /// Fallback endpoint to upgrade by plan code when subscription-based
  /// upgrade is not available on the backend.
  Future<Map<String, dynamic>> upgradePlanFallback({
    required String planCode,
  }) async {
    try {
      final response = await _apiClient.put(
        '/plan/upgrade',
        body: {'plan_code': planCode},
      );

      AppLogger.api(
        '[ServicePackageApi] PUT /plan/upgrade status=${response.statusCode}',
      );
      AppLogger.api(
        '[ServicePackageApi] PUT /plan/upgrade body=${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _apiClient.extractDataFromResponse(response);
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          return responseData['data'] as Map<String, dynamic>;
        } else if (responseData is Map<String, dynamic>) {
          return responseData;
        }
        return {'status': 'error', 'message': 'Lên cấp thất bại (fallback)'};
      } else {
        final responseData = _apiClient.extractDataFromResponse(response);
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Lên cấp thất bại (fallback)',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Lên cấp thất bại (fallback): $e'};
    }
  }

  Future<Map<String, dynamic>> registerFreePlan(String planCode) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions',
        // Send both camelCase and snake_case keys for backward compatibility
        body: {'planCode': planCode, 'plan_code': planCode},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _apiClient.extractDataFromResponse(response);

        // Handle new standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          return responseData['data'] as Map<String, dynamic>;
        }
        // Fallback for old format
        else if (responseData is Map<String, dynamic>) {
          return responseData;
        } else {
          return {'status': 'error', 'message': 'Đăng ký thất bại'};
        }
      } else {
        final responseData = _apiClient.extractDataFromResponse(response);
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Đăng ký thất bại',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Đăng ký thất bại: $e'};
    }
  }

  Future<Map<String, dynamic>> upgradeSubscription({
    required String subscriptionId,
    required String targetPlanCode,
    double? prorationAmount,
    bool? effectiveImmediately,
    String? idempotencyKey,
  }) async {
    try {
      final body = {
        'plan_code': targetPlanCode,
        'target_plan_code': targetPlanCode,
        if (prorationAmount != null) 'proration_amount': prorationAmount,
        if (effectiveImmediately != null)
          'effective_immediately': effectiveImmediately,
      };

      final extraHeaders = idempotencyKey != null
          ? <String, String>{'Idempotency-Key': idempotencyKey}
          : null;

      final response = await _apiClient.post(
        '/subscriptions/$subscriptionId/upgrade',
        body: body,
        extraHeaders: extraHeaders,
      );

      AppLogger.api(
        '[ServicePackageApi] POST /subscriptions/$subscriptionId/upgrade REQUEST body=$body',
      );
      AppLogger.api(
        '[ServicePackageApi] POST /subscriptions/$subscriptionId/upgrade status=${response.statusCode}',
      );
      AppLogger.api(
        '[ServicePackageApi] POST /subscriptions/$subscriptionId/upgrade raw body=${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = _apiClient.extractDataFromResponse(response);

        // Handle new standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          AppLogger.api(
            '[ServicePackageApi] Upgrade response (standardized): ${responseData['data']}',
          );
          return responseData['data'] as Map<String, dynamic>;
        }
        // Fallback for old format
        else if (responseData is Map<String, dynamic>) {
          AppLogger.api(
            '[ServicePackageApi] Upgrade response (legacy): $responseData',
          );
          return responseData;
        } else {
          return {'status': 'error', 'message': 'Nâng cấp thất bại'};
        }
      } else {
        final responseData = _apiClient.extractDataFromResponse(response);
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Nâng cấp thất bại',
        };
      }
    } catch (e) {
      AppLogger.apiError(
        '[ServicePackageApi] Error upgrading subscription: $e',
      );
      return {'status': 'error', 'message': 'Nâng cấp thất bại: $e'};
    }
  }

  Future<Map<String, dynamic>> scheduleDowngrade({
    required String targetPlanCode,
  }) async {
    try {
      final response = await _apiClient.put(
        '/plan/downgrade',
        body: {'plan_code': targetPlanCode, 'payment_provider': 'vn_pay'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _apiClient.extractDataFromResponse(response);

        // Handle new standardized response format
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          return responseData['data'] as Map<String, dynamic>;
        }
        // Fallback for old format
        else if (responseData is Map<String, dynamic>) {
          return responseData;
        } else {
          return {'status': 'error', 'message': 'Lên lịch hạ cấp thất bại'};
        }
      } else {
        final responseData = _apiClient.extractDataFromResponse(response);
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Lên lịch hạ cấp thất bại',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Lên lịch hạ cấp thất bại: $e'};
    }
  }
}
