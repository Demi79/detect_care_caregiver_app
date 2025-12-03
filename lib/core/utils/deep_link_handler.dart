import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/home/screens/event_detail_screen.dart';
import 'package:detect_care_caregiver_app/features/notification/screens/notification_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/payment_api.dart';
import 'package:detect_care_caregiver_app/features/subscription/providers/subscriptions_provider.dart';
import 'package:detect_care_caregiver_app/features/subscription/stores/subscription_store.dart';
import 'package:detect_care_caregiver_app/main.dart' show NavigatorKey;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkHandler {
  static Future<void> initialize() async {
    AppLogger.payment('Initializing DeepLinkHandler');
    await checkAndRetryPendingConfirmations();
  }

  static const _scheme = 'detectcare';
  static const _host = 'payment';
  static const _successPath = '/success';
  static const _eventHost = 'event';

  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _sub;
  static String? _lastTxnRef;
  static const _processedTxnRefsKey = 'processed_payment_txn_refs';

  /// Get list of processed transaction references from shared preferences
  static Future<Set<String>> _getProcessedTxnRefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refs = prefs.getStringList(_processedTxnRefsKey) ?? [];
      return refs.toSet();
    } catch (e) {
      AppLogger.paymentError('Failed to get processed txn refs: $e');
      return {};
    }
  }

  /// Add a transaction reference to the processed list
  static Future<void> _addProcessedTxnRef(String txnRef) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_processedTxnRefsKey) ?? [];
      if (!current.contains(txnRef)) {
        current.add(txnRef);
        // Keep only last 10 processed refs to avoid unlimited growth
        if (current.length > 10) {
          current.removeAt(0);
        }
        await prefs.setStringList(_processedTxnRefsKey, current);
        AppLogger.payment('Added processed txn ref: $txnRef');
      }
    } catch (e) {
      AppLogger.paymentError('Failed to add processed txn ref: $e');
    }
  }

  /// Khởi động listener – KHÔNG cần BuildContext
  static Future<void> start() async {
    _appLinks ??= AppLinks();

    // Cold start - process any initial deep link (including payment callbacks).
    // Duplicate transaction protection (_lastTxnRef + persisted list) prevents
    // processing the same payment twice, so it's safe to handle initial links
    // rather than ignoring them. This ensures callbacks received while the app
    // was not running are handled.
    // Call through `dynamic` to avoid static type issues with different
    // versions of the `app_links` package (some versions expose a differently
    // named API). Using dynamic lets us try at runtime while keeping analyzer
    // happy during static checks.
    Uri? initial;
    try {
      initial = await (_appLinks as dynamic).getInitialAppLink();
    } catch (_) {
      try {
        initial = await (_appLinks as dynamic).getInitialAppLinkUri();
      } catch (_) {
        initial = null;
      }
    }
    if (initial != null) {
      AppLogger.payment('Processing initial app link on cold start: $initial');
      await _handle(initial);
    }

    // Also check for any pending deeplink saved by background isolates (e.g. local
    // notification tap handled in a background isolate). If found, process it and
    // remove it from storage so it's not processed repeatedly.
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString('pending_deeplink');
      if (pending != null && pending.isNotEmpty) {
        AppLogger.payment('Found pending deeplink in prefs: $pending');
        try {
          await processUri(Uri.parse(pending));
        } catch (e) {
          AppLogger.paymentError('Failed to process pending deeplink: $e');
        }
        await prefs.remove('pending_deeplink');
        AppLogger.payment('Cleared pending deeplink from prefs');
      }
    } catch (e) {
      AppLogger.paymentError('Error checking pending deeplink: $e');
    }

    // Warm/foreground - process all deep links
    _sub ??= _appLinks!.uriLinkStream.listen(
      _handle,
      onError: (e) {
        _toast('DeepLink error: $e');
      },
    );
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static bool _match(Uri uri) =>
      uri.scheme == _scheme && uri.host == _host && uri.path == _successPath;

  static Future<void> _handle(Uri uri) async {
    AppLogger.payment('Received payment deep link: $uri');
    AppLogger.payment('Query parameters: ${uri.queryParameters}');
    AppLogger.payment('Timestamp: ${DateTime.now()}');

    if (!_match(uri)) {
      AppLogger.payment('URI does not match payment success pattern, ignoring');
      return;
    }

    // Payment flow match
    if (_match(uri)) {
      AppLogger.payment('Processing payment success deep link');
      final qp = uri.queryParameters;
      final vnpTxnRef = qp['vnp_TxnRef'] ?? qp['vnp_Txnref'];
      final vnpResp = qp['vnp_ResponseCode'];
      final vnpTxStatus = qp['vnp_TransactionStatus'];

      AppLogger.payment('VNP Transaction Ref: $vnpTxnRef');
      AppLogger.payment('VNP Response Code: $vnpResp');
      AppLogger.payment('VNP Transaction Status: $vnpTxStatus');

      // Check for duplicate transaction refs (both in-memory and persisted)
      final processedRefs = await _getProcessedTxnRefs();
      if (vnpTxnRef != null &&
          (vnpTxnRef == _lastTxnRef || processedRefs.contains(vnpTxnRef))) {
        AppLogger.payment(
          'Duplicate transaction ref detected (in-memory or persisted), ignoring: $vnpTxnRef',
        );
        return;
      }
      _lastTxnRef = vnpTxnRef;

      // Mark this txn ref as processed
      if (vnpTxnRef != null) {
        await _addProcessedTxnRef(vnpTxnRef);
      }

      // Ping BE để log return (không bắt buộc). Use ApiClient for consistent headers
      try {
        final url = Uri.parse(
          '${AppConfig.apiBaseUrl}/payments/return',
        ).replace(queryParameters: qp);
        AppLogger.payment('Pinging backend return endpoint: $url');
        final apiClient = ApiClient(tokenProvider: AuthStorage.getAccessToken);
        final path = '/payments/return${url.hasQuery ? '?${url.query}' : ''}';
        final res = await apiClient.get(path);
        // Try to decode and log any structured response from the backend
        try {
          final body = apiClient.extractDataFromResponse(res);
          AppLogger.payment(
            'Backend return ping completed: status=${res.statusCode}, body=$body',
          );
          if (body is Map<String, dynamic>) {
            final isSuccess = body['isSuccess'];
            final uiStatus = body['status'];
            final statusHint = body['statusHint'];
            AppLogger.payment(
              'Backend return payload: isSuccess=$isSuccess, status=$uiStatus, statusHint=$statusHint',
            );
          }
        } catch (e) {
          AppLogger.payment(
            'Backend return ping completed (could not parse body): status=${res.statusCode}',
          );
        }
      } catch (e) {
        AppLogger.paymentError('Backend return ping failed: $e');
      }

      if (vnpTxnRef == null) {
        AppLogger.paymentError(
          'ERROR: Missing transaction reference (vnp_TxnRef)',
        );
        _toast('Không có mã giao dịch (vnp_TxnRef).');
        return;
      }

      final token = await AuthStorage.getAccessToken() ?? '';
      if (token.isEmpty) {
        AppLogger.paymentError('ERROR: Missing access token');
        _toast(
          'Thiếu access token. Lưu trạng thái để xác nhận sau khi đăng nhập.',
        );
        // Save minimal pending info (use txnRef and orderInfo) so retry can resolve
        final orderInfo = qp['vnp_OrderInfo'] ?? '';
        await _savePendingSubscriptionConfirmationWithExtras(
          paymentId: '',
          planCode: '',
          txnRef: vnpTxnRef,
          orderInfo: orderInfo.isNotEmpty ? orderInfo : null,
        );
        return;
      }

      AppLogger.payment(
        'Access token available, proceeding with payment verification',
      );

      final paymentApi = PaymentApi(
        baseUrl: AppConfig.apiBaseUrl,
        apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );

      // Query trạng thái giao dịch (querydr)
      Map<String, dynamic>? dr;
      try {
        AppLogger.payment('Querying payment status for txn: $vnpTxnRef');
        final (:data, :headers) = await paymentApi.getPaymentStatus(
          vnpTxnRef,
          token,
          onLoading: (loading) {
            if (loading) {
              AppLogger.payment('Loading payment status...');
            }
          },
        );
        dr = data;
        AppLogger.payment('Payment status query result: $dr');
      } catch (e) {
        AppLogger.paymentError('ERROR: Payment status query failed: $e');
        _toast('Lỗi kiểm tra trạng thái: $e');
        return;
      }

      final status = (dr['status'] ?? '').toString().toLowerCase();
      final txn = (dr['vnp_TransactionStatus'] ?? '').toString();
      final isSuccess = dr['isSuccess'] == true;
      final rawPaymentId = (dr['payment_id'] ?? '').toString();

      // Fallback: if payment_id is not available, use vnpTxnRef as paymentId
      final paymentId = rawPaymentId.isEmpty ? vnpTxnRef : rawPaymentId;
      String planCode = (dr['code'] ?? dr['plan_code'] ?? '').toString();

      // If plan_code not provided by backend, extract from vnp_OrderInfo
      if (planCode.isEmpty) {
        final orderInfo = qp['vnp_OrderInfo'] ?? '';
        if (orderInfo.isNotEmpty) {
          // Format: "Lifetime premium-vision-2025" -> "premium-vision-2025"
          final parts = orderInfo.split(' ');
          if (parts.length >= 2) {
            planCode = parts.sublist(1).join(' ');
          }
        }
      }

      AppLogger.payment('Payment status evaluation:');
      AppLogger.payment('- Status: $status');
      AppLogger.payment('- VNP Transaction Status: $txn');
      AppLogger.payment('- Is Success: $isSuccess');
      AppLogger.payment('- Payment ID: $rawPaymentId');
      AppLogger.payment('- Actual Payment ID (with fallback): $paymentId');
      AppLogger.payment('- Plan Code: $planCode');

      final paid =
          status == 'paid' ||
          status == 'success' ||
          txn == '00' ||
          isSuccess ||
          (vnpResp == '00' && vnpTxStatus == '00');

      AppLogger.payment('Payment success determination: $paid');
      AppLogger.payment('- status == "paid": ${status == 'paid'}');
      AppLogger.payment('- txn == "00": ${txn == '00'}');
      AppLogger.payment('- isSuccess: $isSuccess');
      AppLogger.payment(
        '- vnpResp == "00" && vnpTxStatus == "00": ${vnpResp == '00' && vnpTxStatus == '00'}',
      );

      if (!paid) {
        AppLogger.payment('Payment not completed, showing error message');
        _toast('Giao dịch chưa hoàn tất. Mã: $vnpTxnRef');
        return;
      }

      if (paymentId.isEmpty) {
        AppLogger.paymentError('ERROR: Missing payment ID for confirmation');
        _toast('Không có payment_id để xác nhận.');
        return;
      }

      AppLogger.payment(
        'Confirming subscription with paymentId: $paymentId, planCode: $planCode',
      );

      // Confirm subscription
      final confirm = await paymentApi.createPaidSubscription(
        paymentId,
        planCode,
        token,
        onLoading: (loading) {
          if (loading) {
            AppLogger.payment('Loading subscription confirmation...');
          }
        },
      );

      AppLogger.payment('Subscription confirmation result: $confirm');
      final rawConfirm = confirm.containsKey('raw') ? confirm['raw'] : confirm;
      final bool confirmSuccess =
          (confirm['confirmed'] == true) ||
          _confirmIndicatesSuccess(rawConfirm);
      AppLogger.payment('Confirmation indicates success: $confirmSuccess');

      if (confirmSuccess) {
        AppLogger.payment('SUCCESS: Subscription confirmed successfully');
        _toast('Đăng ký thành công!');
        // Clear any pending confirmation state
        await _clearPendingSubscriptionConfirmation();

        // Best-effort: poll the subscription API/store a few times to allow
        // backend eventual-consistency. We will refresh the central
        // SubscriptionStore up to `maxAttempts` times with exponential
        // backoff until the store reports a plan code that matches the
        // expected `planCode` we derived earlier.
        final int maxAttempts = 4;
        int attempt = 0;
        bool matched = false;
        try {
          while (attempt < maxAttempts && !matched) {
            attempt += 1;
            AppLogger.payment('Attempt $attempt to refresh SubscriptionStore');
            try {
              await SubscriptionStore.instance.refresh();
            } catch (e) {
              AppLogger.paymentError('SubscriptionStore.refresh() failed: $e');
            }

            // Inspect plan data from the store to see if it reflects expected code
            final pd = SubscriptionStore.instance.planData;
            String? foundCode;
            try {
              if (pd != null) {
                // If store returned an envelope with subscriptions
                if (pd['subscriptions'] is List &&
                    (pd['subscriptions'] as List).isNotEmpty) {
                  final sub =
                      (pd['subscriptions'] as List).first
                          as Map<String, dynamic>;
                  foundCode = (sub['plan_code'] ?? sub['code'])?.toString();
                  // also check nested snapshots
                  if (foundCode == null && sub['plan_snapshot'] is Map) {
                    foundCode =
                        (sub['plan_snapshot']['code'] ??
                                sub['plan_snapshot']['plan_code'])
                            ?.toString();
                  }
                } else {
                  // pd itself may be a plan object
                  foundCode = (pd['plan_code'] ?? pd['code'])?.toString();
                }
              }
            } catch (_) {
              foundCode = null;
            }

            AppLogger.payment(
              'SubscriptionStore plan code on attempt $attempt: $foundCode (expected: $planCode)',
            );
            if (foundCode != null &&
                planCode.isNotEmpty &&
                foundCode == planCode) {
              matched = true;
              AppLogger.payment(
                'SubscriptionStore now reflects expected plan code: $foundCode',
              );
              break;
            }

            // Backoff before next attempt
            final waitMs = 300 * (1 << (attempt - 1));
            AppLogger.payment(
              'Waiting ${waitMs}ms before next subscription refresh attempt',
            );
            await Future.delayed(Duration(milliseconds: waitMs));
          }
        } catch (e) {
          AppLogger.paymentError('Error while polling subscription store: $e');
        }

        if (!matched) {
          AppLogger.payment(
            'Warning: subscription store did not reflect expected plan after $maxAttempts attempts',
          );
        }

        // Also refresh SubscriptionsProvider (used by many subscription screens)
        try {
          final ctx = NavigatorKey.navigatorKey.currentContext;
          if (ctx != null) {
            final prov = ctx.read<SubscriptionsProvider>();
            // Call refreshSubscriptions which will notify listeners
            await prov.refreshSubscriptions();
            AppLogger.payment(
              'SubscriptionsProvider.refreshSubscriptions() called after confirmation',
            );
          } else {
            AppLogger.payment(
              'No root context available to refresh SubscriptionsProvider',
            );
          }
        } catch (e) {
          AppLogger.paymentError('Failed to refresh SubscriptionsProvider: $e');
        }

        NavigatorKey.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      } else {
        AppLogger.paymentError(
          'ERROR: Subscription confirmation failed: ${confirm['message'] ?? 'Unknown error'}',
        );
        _toast(
          'Xác nhận đăng ký thất bại: ${confirm['message'] ?? 'Không rõ lỗi'}\nGói của bạn sẽ được cập nhật trong thời gian sớm nhất.',
        );

        // Save pending confirmation for later retry
        await _savePendingSubscriptionConfirmation(paymentId, planCode);

        // Even if confirmation fails, payment was successful
        // Navigate to home screen - user will see premium features when subscription is confirmed
        AppLogger.payment('Payment was successful, navigating to home screen');
        _navigateToHome();
      }

      return;
    }

    // Event deeplink: detectcare://event/{eventId}
    try {
      if (uri.scheme == _scheme && uri.host == _eventHost) {
        // path may be '/{id}' or the id may be in pathSegments
        final id = (uri.pathSegments.isNotEmpty)
            ? uri.pathSegments.last
            : uri.path.replaceFirst('/', '');
        if (id.isNotEmpty) {
          // Navigate in-app to event detail
          NavigatorKey.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)),
          );
        }
        return;
      }
    } catch (_) {}
  }

  /// Public wrapper to allow other services (e.g., FCM tap handler) to
  /// process arbitrary incoming deeplink URIs through the same handler.
  static Future<void> processUri(Uri uri) async {
    try {
      // If the URI points to notifications list, navigate there
      if (uri.scheme == _scheme && uri.host == 'notifications') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            NavigatorKey.navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          } catch (e) {
            AppLogger.paymentError('Failed to navigate to notifications: $e');
          }
        });
        return;
      }

      // Alert deeplink: detectcare://alert/{alertId} -> treat as event detail
      if (uri.scheme == _scheme && uri.host == 'alert') {
        final id = (uri.pathSegments.isNotEmpty)
            ? uri.pathSegments.last
            : uri.path.replaceFirst('/', '');
        if (id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              NavigatorKey.navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: id),
                ),
              );
            } catch (e) {
              AppLogger.paymentError(
                'Failed to navigate to alert/event $id: $e',
              );
            }
          });
        }
        return;
      }

      // Fallback: delegate to existing private handler which covers payment and event
      await _handle(uri);
    } catch (e) {
      AppLogger.paymentError('Error processing deeplink $uri: $e');
    }
  }

  // Helper to interpret backend confirmation shapes for success.
  static bool _confirmIndicatesSuccess(dynamic confirm) {
    if (confirm == null) return false;
    try {
      if (confirm is Map<String, dynamic>) {
        final status = (confirm['status'] ?? '').toString().toLowerCase();
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

  static void _toast(String msg) {
    try {
      final ctx = NavigatorKey.navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
    } catch (_) {}
    // Fallback: try to show via navigator state if available
    try {
      final nav = NavigatorKey.navigatorKey.currentState;
      final ctx = nav?.overlay?.context;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {}
  }

  // Navigation helper removed — deep link handling now navigates directly

  /// Lưu trạng thái payment thành công nhưng subscription chưa confirm
  static Future<void> _savePendingSubscriptionConfirmation(
    String paymentId,
    String planCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = {
        'paymentId': paymentId,
        'planCode': planCode,
        'txnRef': null,
        'orderInfo': null,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };
      await prefs.setString(
        'pending_subscription_confirmation',
        jsonEncode(pendingData),
      );
      AppLogger.payment(
        'Saved pending subscription confirmation: $pendingData',
      );
    } catch (e) {
      AppLogger.paymentError(
        'Failed to save pending subscription confirmation: $e',
      );
    }
  }

  /// Save pending subscription confirmation with optional txnRef/orderInfo
  static Future<void> _savePendingSubscriptionConfirmationWithExtras({
    required String paymentId,
    required String planCode,
    String? txnRef,
    String? orderInfo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = {
        'paymentId': paymentId,
        'planCode': planCode,
        'txnRef': txnRef,
        'orderInfo': orderInfo,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };
      await prefs.setString(
        'pending_subscription_confirmation',
        jsonEncode(pendingData),
      );
      AppLogger.payment(
        'Saved pending subscription confirmation (with extras): $pendingData',
      );
    } catch (e) {
      AppLogger.paymentError(
        'Failed to save pending subscription confirmation: $e',
      );
    }
  }

  /// Lấy trạng thái payment đang chờ confirm
  static Future<Map<String, dynamic>?>
  _getPendingSubscriptionConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('pending_subscription_confirmation');
      if (data != null) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        return decoded;
      }
    } catch (e) {
      AppLogger.paymentError(
        'Failed to get pending subscription confirmation: $e',
      );
    }
    return null;
  }

  /// Xóa trạng thái payment đã được xử lý
  static Future<void> _clearPendingSubscriptionConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_subscription_confirmation');
      AppLogger.payment('Cleared pending subscription confirmation');
    } catch (e) {
      AppLogger.paymentError(
        'Failed to clear pending subscription confirmation: $e',
      );
    }
  }

  /// Check and retry any pending subscription confirmations
  static Future<void> checkAndRetryPendingConfirmations() async {
    final pending = await _getPendingSubscriptionConfirmation();
    if (pending != null) {
      final paymentId = pending['paymentId'];
      final planCode = pending['planCode'];
      final timestamp = pending['timestamp'];

      // Only retry if it's within the last 24 hours
      final age = DateTime.now().difference(DateTime.parse(timestamp));
      if (age.inHours < 24) {
        AppLogger.payment(
          'Retrying pending subscription confirmation for payment: $paymentId',
        );
        await _retrySubscriptionConfirmation(paymentId, planCode);
      } else {
        // Clear old pending confirmation
        await _clearPendingSubscriptionConfirmation();
        AppLogger.payment(
          'Cleared old pending confirmation (age: ${age.inHours} hours)',
        );
      }
    }
  }

  /// Retry subscription confirmation
  static Future<void> _retrySubscriptionConfirmation(
    String paymentId,
    String planCode,
  ) async {
    try {
      // Get current user token for API call
      final token = await AuthStorage.getAccessToken() ?? '';
      if (token.isEmpty) {
        AppLogger.paymentError('No user token available for retry');
        return;
      }

      final paymentApi = PaymentApi(
        baseUrl: AppConfig.apiBaseUrl,
        apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );

      // Use mutable locals so we can resolve missing values
      var resolvedPaymentId = paymentId;
      var resolvedPlanCode = planCode;

      // If paymentId or planCode is missing, try to resolve using txnRef stored in pending
      if ((resolvedPaymentId.isEmpty || resolvedPlanCode.isEmpty)) {
        final pending = await _getPendingSubscriptionConfirmation();
        final txnRef = pending?['txnRef'] as String?;
        final orderInfo = pending?['orderInfo'] as String?;
        if (txnRef != null && txnRef.isNotEmpty) {
          try {
            final (:data, :headers) = await paymentApi.getPaymentStatus(
              txnRef,
              token,
            );
            final resolved = data;
            final rawPaymentId = (resolved['payment_id'] ?? '').toString();
            final resolvedPlan =
                (resolved['code'] ?? resolved['plan_code'] ?? '') as String? ??
                '';
            if (resolvedPaymentId.isEmpty && rawPaymentId.isNotEmpty) {
              resolvedPaymentId = rawPaymentId;
            }
            if (resolvedPlanCode.isEmpty && resolvedPlan.isNotEmpty) {
              resolvedPlanCode = resolvedPlan;
            }
            // fallback: parse orderInfo if still missing
            if (resolvedPlanCode.isEmpty &&
                orderInfo != null &&
                orderInfo.isNotEmpty) {
              final parts = orderInfo.split(' ');
              if (parts.length >= 2) {
                resolvedPlanCode = parts.sublist(1).join(' ');
              }
            }
          } catch (e) {
            AppLogger.paymentError(
              'Failed to resolve payment details from txnRef: $e',
            );
          }
        }
      }

      final confirm = await paymentApi.createPaidSubscription(
        resolvedPaymentId,
        resolvedPlanCode,
        token,
      );
      final rawConfirm = confirm.containsKey('raw') ? confirm['raw'] : confirm;
      final bool confirmSuccess =
          (confirm['confirmed'] == true) ||
          _confirmIndicatesSuccess(rawConfirm);

      if (confirmSuccess) {
        AppLogger.payment('SUCCESS: Pending subscription confirmed on retry');
        _toast('Đăng ký thành công!');
        await _clearPendingSubscriptionConfirmation();
        // Notify listeners that subscription has been updated
        await _notifySubscriptionUpdate(resolvedPlanCode);
      } else {
        AppLogger.payment(
          'Pending confirmation still failing, will retry later',
        );
      }
    } catch (e) {
      AppLogger.paymentError('Error retrying pending confirmation: $e');
    }
  }

  /// Notify subscription update to relevant screens
  static Future<void> _notifySubscriptionUpdate(String planCode) async {
    // This could trigger a refresh in subscription-related screens
    // For now, we'll just log it
    AppLogger.payment('Subscription updated to plan: $planCode');
  }

  /// Navigate to home screen after successful payment
  static void _navigateToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        NavigatorKey.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      } catch (e) {
        AppLogger.paymentError('Failed to navigate to home: $e');
      }
    });
  }
}
