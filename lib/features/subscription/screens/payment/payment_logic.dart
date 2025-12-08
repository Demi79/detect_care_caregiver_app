import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../data/payment_api.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import '../../models/plan.dart';
import '../../stores/subscription_store.dart';

/// Controller class chứa tất cả logic xử lý payment
class PaymentController {
  final VoidCallback? _onStateChanged;

  // State variables
  bool _stopPolling = false;
  String? _lastPaymentId;
  String? _lastVnpTxnRef;
  AppLinks? _appLinks;
  StreamSubscription? _deeplinkSub;

  bool _loading = false;
  String? _loadingMessage;

  bool _awaitingExternalConfirmation = false;
  bool _statusCheckInProgress = false;
  bool _finalizingSubscription = false;
  bool _finalizeLock = false;
  String? _statusInfoMessage;
  String? _lastHandledTxnRef;
  DateTime? _lastDeepLinkAt;
  String? _sessionNonce;
  Timer? _manualCheckTimer;
  DateTime? _nextManualCheckAt;

  Plan? _activePlan;
  Function(String, String)? _onPaymentSuccess;
  Function(String)? _onPaymentError;

  static const Duration _manualCheckCooldown = Duration(seconds: 12);
  static const List<Duration> _pollBackoffSchedule = <Duration>[
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  // Coupon / discount state
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  int _discountAmount = 0;
  String? _discountLabel;
  bool _applyingCoupon = false;

  // Getters for state
  bool get isLoading => _loading;
  String? get loadingMessage => _loadingMessage;
  bool get awaitingUserReturn => _awaitingExternalConfirmation;
  bool get _canFinalize => !_finalizeLock && !_finalizingSubscription;

  void _acquireFinalizeLock() {
    _finalizeLock = true;
  }

  void _releaseFinalizeLock() {
    _finalizeLock = false;
  }

  String? get statusInfoMessage => _statusInfoMessage;

  bool _isPaymentDeepLink(Uri uri) =>
      uri.pathSegments.contains('payment') ||
      (uri.scheme == 'detectcare' && uri.host == 'payment');

  bool get canTriggerStatusCheck {
    if (_statusCheckInProgress || _finalizingSubscription) return false;
    if (_lastPaymentId == null && _lastVnpTxnRef == null) return false;
    if (_nextManualCheckAt == null) return true;
    return DateTime.now().isAfter(_nextManualCheckAt!);
  }

  Duration? get manualCheckRemaining {
    if (_nextManualCheckAt == null) return null;
    final remaining = _nextManualCheckAt!.difference(DateTime.now());
    if (remaining.isNegative) return null;
    return remaining;
  }

  TextEditingController get couponController => _couponController;
  String? get appliedCoupon => _appliedCoupon;
  int get discountAmount => _discountAmount;
  String? get discountLabel => _discountLabel;
  bool get isApplyingCoupon => _applyingCoupon;

  // Expose last transaction identifiers so UI can show/copy them
  String? get lastPaymentId => _lastPaymentId;
  String? get lastVnpTxnRef => _lastVnpTxnRef;

  PaymentController({VoidCallback? onStateChanged})
    : _onStateChanged = onStateChanged {
    _sessionNonce = DateTime.now().millisecondsSinceEpoch.toString();
    _init();
  }

  void _notify() => _onStateChanged?.call();

  void _init() {
    _appLinks = AppLinks();

    // Xử lý deep link khi app được mở bằng link (cold start)
    _appLinks!
        .getInitialLink()
        .then((initial) async {
          try {
            if (initial != null && _isPaymentDeepLink(initial)) {
              await _handlePaymentDeepLink(initial);
            }
          } catch (e) {
            AppLogger.payment('Error handling initial deep link: $e');
          }
        })
        .catchError((e) {
          AppLogger.payment('Error getting initial app link: $e');
        });

    // Lắng nghe deeplink khi đang chạy (warm)
    try {
      _deeplinkSub = _appLinks!.uriLinkStream.listen(
        (Uri? uri) async {
          try {
            if (uri == null || !_isPaymentDeepLink(uri)) return;
            await _handlePaymentDeepLink(uri);
          } catch (e) {
            AppLogger.paymentError('Error handling deep link stream: $e');
          }
        },
        onError: (e, st) =>
            AppLogger.paymentError('Deep link stream error: $e'),
      );
    } catch (e) {
      AppLogger.payment('Error setting up deep link stream: $e');
    }
  }

  void setActivePlan(Plan plan) {
    _activePlan = plan;
  }

  void setCallbacks({
    required Function(String, String) onPaymentSuccess,
    required Function(String) onPaymentError,
  }) {
    _onPaymentSuccess = onPaymentSuccess;
    _onPaymentError = onPaymentError;
  }

  void dispose() {
    _stopPolling = true;
    _nextManualCheckAt = null; // Reset cooldown
    _deeplinkSub?.cancel();
    _appLinks = null;
    _manualCheckTimer?.cancel();
    _manualCheckTimer = null;
    _onPaymentSuccess = null;
    _onPaymentError = null;
    _couponController.dispose();
    // Reset additional state
    _finalizeLock = false;
    _statusInfoMessage = null;
    _lastHandledTxnRef = null;
    _lastDeepLinkAt = null;
    _sessionNonce = null;
  }

  // Utility to detect whether a backend confirmation response indicates
  // a successful subscription confirmation. Backends may return different
  // shapes (e.g. { status: 'active' }, { success: true },
  // { subscriptions: [ { status: 'active', ... } ] }, or raw data map).
  bool _confirmIndicatesSuccess(dynamic confirm) {
    if (confirm == null) return false;
    try {
      if (confirm is Map<String, dynamic>) {
        final status = (confirm['status'] ?? '').toString().toLowerCase();

        // If the backend explicitly reports a negative/completion status,
        // treat it as not-success. This avoids cases where a cancelled/failed
        // response could be misinterpreted as successful.
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

        // Some backends return subscription list under 'subscriptions'
        final subs = confirm['subscriptions'];
        if (subs is List && subs.isNotEmpty) {
          final first = subs.first;
          if (first is Map) {
            final s = (first['status'] ?? '').toString().toLowerCase();
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
          }
        }

        // Some responses nest data under 'data'
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
        }
      }
    } catch (_) {
      // swallow parse errors and treat as not-success
    }
    return false;
  }

  // Kiểm tra bằng chứng cuối cùng trong payload xác nhận để đảm bảo
  // backend thực sự đã hoàn tất đăng ký/thanh toán. Tránh trường hợp
  // payload mơ hồ khiến client hiểu nhầm là thành công.
  bool _hasFinalizationEvidence(dynamic payload) {
    try {
      if (payload == null) return false;
      if (payload is Map<String, dynamic>) {
        if (payload.containsKey('paid_at') || payload.containsKey('paidAt')) {
          return true;
        }
        if (payload.containsKey('invoice') ||
            payload.containsKey('invoice_url') ||
            payload.containsKey('invoiceUrl')) {
          return true;
        }
        if (payload.containsKey('subscription') &&
            payload['subscription'] is Map) {
          final sub = payload['subscription'] as Map<String, dynamic>;
          if (sub['id'] != null || sub['status'] != null) return true;
        }
        if (payload.containsKey('subscription_id') ||
            payload.containsKey('subscriptionId') ||
            payload.containsKey('id')) {
          return true;
        }
        final nested = payload['data'];
        if (nested is Map) return _hasFinalizationEvidence(nested);
      }
      if (payload is List && payload.isNotEmpty) {
        return _hasFinalizationEvidence(payload.first);
      }
    } catch (_) {}
    return false;
  }

  // Setters for state
  void updateLoading(bool loading, [String? message]) {
    _loading = loading;
    _loadingMessage = message;
    _notify();
  }

  void updateCouponState({
    bool? applying,
    int? discountAmount,
    String? discountLabel,
    String? appliedCoupon,
  }) {
    if (applying != null) _applyingCoupon = applying;
    if (discountAmount != null) _discountAmount = discountAmount;
    if (discountLabel != null) _discountLabel = discountLabel;
    if (appliedCoupon != null) _appliedCoupon = appliedCoupon;
    _notify();
  }

  void _setStatusInfoMessage(String? message) {
    // Avoid double messages in UI
    if (_statusInfoMessage == message) return;
    _statusInfoMessage = message;
    _notify();
  }

  void _startManualCheckCooldown([Duration duration = _manualCheckCooldown]) {
    _manualCheckTimer?.cancel();
    _manualCheckTimer = null;
    _nextManualCheckAt = DateTime.now().add(duration);
    _notify();
    _manualCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextManualCheckAt == null) {
        timer.cancel();
        _manualCheckTimer = null;
        return;
      }
      if (DateTime.now().isAfter(_nextManualCheckAt!)) {
        _nextManualCheckAt = null;
        timer.cancel();
        _manualCheckTimer = null;
      }
      _notify();
    });
  }

  void stopPolling() {
    AppLogger.payment('User requested to stop polling');
    AppLogger.payment('Setting _stopPolling to true');
    _stopPolling = true;
    _awaitingExternalConfirmation = false;
    _manualCheckTimer?.cancel();
    _manualCheckTimer = null;
    _nextManualCheckAt = null;
    updateLoading(false);
    _setStatusInfoMessage(null);
  }

  Future<void> _handleAuthError(BuildContext context) async {
    AppLogger.payment(
      'Handling auth error - clearing token and redirecting to login',
    );

    // Clear stored authentication data
    await AuthStorage.clear();

    // Show error message and redirect to login
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _handlePaymentDeepLink(Uri uri) async {
    // Prevent deep link burst within 1-2s
    final now = DateTime.now();
    if (_lastDeepLinkAt != null &&
        now.difference(_lastDeepLinkAt!).inMilliseconds < 1500) {
      AppLogger.payment('Deep link burst ignored (within 1.5s)');
      return;
    }
    _lastDeepLinkAt = now;

    // Tighten deep link conditions: must be payment deep link and have vnp_ parameters
    if (!_isPaymentDeepLink(uri) ||
        !uri.queryParameters.containsKey('vnp_TxnRef')) {
      AppLogger.payment(
        'Invalid deep link: not a payment deep link or missing vnp_TxnRef',
      );
      return;
    }

    final p = uri.queryParameters;
    final txnRef = p['vnp_TxnRef'];

    // Dedupe: ignore if we've already handled this transaction
    if (txnRef != null && txnRef == _lastHandledTxnRef) {
      AppLogger.payment('Duplicate deep link ignored: $txnRef');
      return;
    }
    if (txnRef != null) _lastHandledTxnRef = txnRef;

    _lastVnpTxnRef = p['vnp_TxnRef'] ?? _lastVnpTxnRef;

    updateLoading(true, 'Đang xác thực giao dịch...');
    await _verifyVnpReturnRaw(uri.query);

    final ok = p['vnp_ResponseCode'] == '00';
    final paid = p['vnp_TransactionStatus'] == '00';

    // If backend/gateway returned a non-success response code, treat as
    // cancelled/failed immediately rather than proceeding to confirm.
    if (!ok) {
      AppLogger.payment(
        'Payment response code indicates failure/cancel: ${p['vnp_ResponseCode']}',
      );
      _awaitingExternalConfirmation = false;
      _statusCheckInProgress = false;
      _manualCheckTimer?.cancel();
      _manualCheckTimer = null;
      _nextManualCheckAt = null;
      final msg =
          'Giao dịch bị hủy hoặc thất bại (mã: ${p['vnp_ResponseCode'] ?? 'unknown'})';
      updateLoading(false, msg);
      _setStatusInfoMessage(msg);
      _onPaymentError?.call(msg);
      return;
    }

    // Handle deep links without vnp_TransactionStatus - trigger manual check
    if (ok && p['vnp_TransactionStatus'] == null) {
      AppLogger.payment(
        'Deep link missing vnp_TransactionStatus, triggering manual check',
      );
      _manualCheckTimer?.cancel();
      _manualCheckTimer = null;
      _nextManualCheckAt = null;
      if (_awaitingExternalConfirmation && !_statusCheckInProgress) {
        await triggerManualStatusCheck(
          onSuccess: _onPaymentSuccess ?? (_, __) {},
          onError: _onPaymentError ?? (_) {},
          triggeredByDeepLink: true,
        );
      }
      return;
    }

    // Nếu VNPay trả về thành công hoàn tất => bỏ qua poll, confirm luôn
    if (ok && paid) {
      _stopPolling = true;
      _awaitingExternalConfirmation = false;
      _statusCheckInProgress = false;
      // Clean cooldown/timer when deep link succeeds
      _manualCheckTimer?.cancel();
      _manualCheckTimer = null;
      _nextManualCheckAt = null;

      if (!_canFinalize) {
        AppLogger.payment(
          'Finalize already in progress, skipping deep link handling',
        );
        return;
      }

      _acquireFinalizeLock();
      try {
        final token = await AuthStorage.getAccessToken() ?? '';
        final ref = _lastPaymentId ?? _lastVnpTxnRef ?? p['vnp_TxnRef'];
        if (ref != null && token.isNotEmpty && _activePlan != null) {
          final paymentApi = PaymentApi(
            baseUrl: AppConfig.apiBaseUrl,
            apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
          );
          updateLoading(true, 'Đang xác nhận đăng ký gói...');
          final idempotencyKey = 'confirm::$ref';
          final confirm = await paymentApi.createPaidSubscription(
            ref,
            _activePlan!.code,
            token,
            idempotencyKey: idempotencyKey,
          );
          AppLogger.payment('Subscription confirmation raw response: $confirm');
          final raw = confirm.containsKey('raw') ? confirm['raw'] : confirm;
          final bool confirmed =
              (confirm['confirmed'] == true) || _confirmIndicatesSuccess(raw);
          if (confirmed) {
            // Force refetch subscription before pop
            await Future.delayed(const Duration(milliseconds: 200));
            try {
              // Refresh central subscription store so all listeners update.
              // This will call the /subscriptions/me endpoint internally.
              await SubscriptionStore.instance.refresh();
            } catch (_) {}
            _onPaymentSuccess?.call(
              'Đăng ký thành công: ${_activePlan!.name}',
              'success',
            );
          } else {
            _onPaymentError?.call(
              'Đăng ký thất bại: ${confirm['message'] ?? 'Lỗi không xác định'}',
            );
          }
        }
      } finally {
        _releaseFinalizeLock();
      }
      return;
    }

    // Nếu chưa paid, trigger polling automatically when returning via deep link
    if (_awaitingExternalConfirmation && !_statusCheckInProgress) {
      AppLogger.payment(
        'User returned via deep link, triggering automatic status check',
      );
      await triggerManualStatusCheck(
        onSuccess: _onPaymentSuccess ?? (_, __) {},
        onError: _onPaymentError ?? (_) {},
      );
    } else {
      // Just update UI state
      _awaitingExternalConfirmation = false;
      updateLoading(
        false,
        'Giao dịch đã được xác thực. Bạn có thể kiểm tra trạng thái thủ công.',
      );
      _onStateChanged?.call();
    }
  }

  Future<void> processDeepLink(Uri uri) async {
    final params = Map<String, String>.from(uri.queryParameters);
    // Đảm bảo truyền vnp_TxnRef nếu có
    if (!params.containsKey('vnp_TxnRef') &&
        uri.queryParameters['vnp_TxnRef'] != null) {
      params['vnp_TxnRef'] = uri.queryParameters['vnp_TxnRef']!;
    }
    final normalized = Uri(queryParameters: params).query;
    await _verifyVnpReturnRaw(normalized);
  }

  Future<void> _verifyVnpReturnRaw(String rawQuery) async {
    final apiClient = ApiClient(tokenProvider: AuthStorage.getAccessToken);
    AppLogger.payment('_verifyVnpReturnRaw called at: ${DateTime.now()}');
    AppLogger.payment('rawQuery: $rawQuery');
    try {
      // Use POST to avoid gateway re-encoding issues
      final res = await apiClient
          .post('payments/return', body: {'rawQuery': rawQuery})
          .timeout(const Duration(seconds: 8));
      AppLogger.payment('Verify return (raw) -> ${res.statusCode}');

      // Try to decode structured response and log helpful fields
      try {
        final body = apiClient.extractDataFromResponse(res);
        AppLogger.payment('Verify return response body: $body');
        if (body is Map<String, dynamic>) {
          final isSuccess = body['isSuccess'];
          final uiStatus = body['status'];
          final statusHint = body['statusHint'];
          AppLogger.payment(
            'Return payload: isSuccess=$isSuccess, status=$uiStatus, statusHint=$statusHint',
          );
        }
      } catch (e) {
        AppLogger.payment('Verify return: could not parse response body');
      }

      // If backend returned 404, try alternate base (some deployments mount the
      // API at root vs /api). The public return endpoint doesn't require auth,
      // so we'll try an unauthenticated request to the toggled base.
      if (res.statusCode == 404) {
        try {
          var altBase = AppConfig.apiBaseUrl;
          if (altBase.endsWith('/api')) {
            altBase = altBase.substring(0, altBase.length - 4);
          } else {
            altBase = '$altBase/api';
          }
          // normalize trailing slash
          if (altBase.endsWith('/')) {
            altBase = altBase.substring(0, altBase.length - 1);
          }

          final altUri = Uri.parse('$altBase/payments/return');
          AppLogger.payment(
            'Primary return endpoint 404 — trying alternate URL: $altUri',
          );

          final altRes = await http
              .post(
                altUri,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'rawQuery': rawQuery}),
              )
              .timeout(const Duration(seconds: 8));
          AppLogger.payment(
            'Alternate verify return (raw) -> ${altRes.statusCode}',
          );

          if (altRes.statusCode == 200) return;

          // Last resort: try GET with the raw query appended (some backends
          // expose a GET handler for /payments/return)
          final getUri = Uri.parse('$altBase/payments/return?$rawQuery');
          AppLogger.payment('Trying GET fallback to: $getUri');
          final getRes = await http
              .get(getUri)
              .timeout(const Duration(seconds: 8));
          AppLogger.payment(
            'GET fallback verify return -> ${getRes.statusCode}',
          );
        } catch (e) {
          AppLogger.paymentError('Alternate return attempts failed: $e');
        }
      }
    } catch (e) {
      AppLogger.paymentError('Verify return raw timeout/error: $e');
      // Don't block the flow - IPN will handle verification later
    }
  }

  Future<void> startPaymentFlow(
    Plan plan, {
    required Function(String, String) onSuccess,
    required Function(String) onError,
    required BuildContext context,
    int? amountOverride,
    String? linkedTransactionId,
    String? billingType,
  }) async {
    _stopPolling = false;
    _statusCheckInProgress = false;
    _awaitingExternalConfirmation = false;
    _setStatusInfoMessage(null);

    _activePlan = plan;
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;

    updateLoading(true, 'Đang tạo yêu cầu thanh toán...');
    AppLogger.payment('[PAYMENT] Local time: ${DateTime.now()}');
    AppLogger.payment('[PAYMENT] UTC time: ${DateTime.now().toUtc()}');

    try {
      final token = await AuthStorage.getAccessToken() ?? '';
      AppLogger.payment(
        'Retrieved token: ${token.isNotEmpty ? 'Present (${token.length} chars)' : 'Empty'}',
      );

      if (token.isEmpty) {
        updateLoading(false);
        onError('Không tìm thấy access token');
        return;
      }

      final paymentApi = PaymentApi(
        baseUrl: AppConfig.apiBaseUrl,
        apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );

      // 1) Create payment
      final amountToCharge = amountOverride ?? plan.price;
      AppLogger.payment(
        'Creating payment for plan: ${plan.code}, amount: $amountToCharge',
      );
      final userId = await AuthStorage.getUserId();
      final idempotencyKey =
          linkedTransactionId ??
          'create::${userId ?? 'unknown'}::${plan.code}::$_sessionNonce';
      final created = await paymentApi.createPayment(
        plan.code,
        amountToCharge,
        token,
        userId: userId,
        idempotencyKey: idempotencyKey,
        billingType: billingType,
        onLoading: (loading) {
          if (loading) {
            updateLoading(true, 'Đang tạo yêu cầu thanh toán...');
          }
        },
      );
      AppLogger.payment('Payment creation response: $created');

      // If adapter returned an error shape, surface message to UI
      // Detect adapter/backend error shapes and surface their message
      if (created['status'] == 'error' ||
          created['success'] == false ||
          created.containsKey('error')) {
        final errMsg =
            (created['message'] ??
                    created['error'] ??
                    'Không thể tạo yêu cầu thanh toán')
                .toString();
        AppLogger.payment('Payment creation failed: $errMsg');
        updateLoading(false);
        onError(errMsg);
        return;
      }

      // Additional diagnostic info
      try {
        AppLogger.payment('Created keys: ${created.keys.toList()}');
      } catch (_) {}

      final paymentUrl = created['paymentUrl'] as String?;
      _lastPaymentId =
          (created['paymentId'] ?? created['payment_id']) as String?;

      // Backend sometimes doesn't return vnp_TxnRef as a top-level field.
      // Parse it from the paymentUrl if necessary so FE can track txnRef for
      // status checks and dedupe when receiving deep links.
      _lastVnpTxnRef = created['vnp_TxnRef'] as String?;
      if ((paymentUrl ?? '').isNotEmpty) {
        try {
          final parsed = Uri.parse(paymentUrl!);
          final qp = parsed.queryParameters;
          final txnRefFromUrl =
              qp['vnp_TxnRef'] ?? qp['vnp_txn_ref'] ?? qp['vnpTxnRef'];
          if ((txnRefFromUrl ?? '').isNotEmpty) {
            _lastVnpTxnRef ??= txnRefFromUrl;
          }
          final paymentIdFromUrl =
              qp['paymentId'] ?? qp['payment_id'] ?? qp['txnId'];
          if ((paymentIdFromUrl ?? '').isNotEmpty) {
            _lastPaymentId ??= paymentIdFromUrl;
          }
        } catch (e) {
          AppLogger.payment(
            'Không thể phân tích paymentUrl để lấy mã giao dịch VNPay: $e',
          );
        }
      }

      AppLogger.payment('Payment URL: $paymentUrl');
      AppLogger.payment('Payment ID: $_lastPaymentId');
      AppLogger.payment('VNP TxnRef: $_lastVnpTxnRef');

      // Check if payment creation failed due to auth issues
      if (paymentUrl == null && created['status'] == 'error') {
        AppLogger.payment(
          'Payment creation failed, checking for auth issues...',
        );

        // If it's an auth error, suggest user to re-login
        if (created['code'] == 'UNAUTHORIZED' ||
            created['message']?.toString().contains('Unauthorized') == true ||
            created['message']?.toString().contains('token') == true) {
          AppLogger.paymentError('Auth error detected, handling...');
          if (context.mounted) {
            await _handleAuthError(context);
          }
          return;
        }
      }

      // Không poll trạng thái ngay sau khi tạo payment nữa

      if (paymentUrl == null ||
          (_lastPaymentId == null && _lastVnpTxnRef == null)) {
        updateLoading(false);
        onError('Không thể tạo yêu cầu thanh toán');
        return;
      }

      updateLoading(true, 'Đang chuyển hướng đến trang thanh toán...');

      /*
      // Debug: show dialog with full checkout URL and Copy button so
      // developers can paste it into desktop browser to debug signature issues.
      // Only show in debug builds (kDebugMode).
      try {
        if (kDebugMode && context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Debug: Checkout URL'),
              content: SingleChildScrollView(child: SelectableText(paymentUrl)),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: paymentUrl));
                    } catch (_) {}
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Copy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        }
      } catch (_) {}
      */

      // 2) Launch VNPay (external)
      // Log the raw paymentUrl and the parsed Uri.toString() so we can
      // compare exactly what FE sends to the external browser vs what
      // backend logged when generating the URL.
      try {
        AppLogger.payment('Launching (raw string): $paymentUrl');
        // Use launchUrlString to send the raw string to the platform without
        // an intermediate re-encode that might alter percent-encoding.
        AppLogger.payment(
          'Launching (uri.toString()): ${Uri.parse(paymentUrl).toString()}',
        );
        final launchResult = await launchUrlString(
          paymentUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!launchResult) {
          updateLoading(false);
          onError('Không thể mở trình duyệt để thanh toán');
          return;
        }
      } catch (e) {
        // If parsing or launching fails, surface the error to UI and logs
        AppLogger.paymentError('Error launching payment URL: $e');
        updateLoading(false);
        onError('Lỗi khi mở trang thanh toán: $e');
        return;
      }

      _awaitingExternalConfirmation = true;
      _statusCheckInProgress = false;
      _setStatusInfoMessage(
        'Khi hoàn tất thanh toán trên VNPay, quay lại ứng dụng và nhấn "Tôi đã thanh toán" để kiểm tra trạng thái.',
      );
      _startManualCheckCooldown(const Duration(seconds: 10));
      updateLoading(false);
    } catch (e) {
      AppLogger.paymentError('[PAYMENT] Flow error: $e');
      onError('Lỗi thanh toán: $e');
    } finally {
      if (!_statusCheckInProgress && !_finalizingSubscription) {
        updateLoading(false);
      }
    }
  }

  Future<
    ({bool success, bool throttled, String? message, Duration? retryAfter})
  >
  _pollStatusUntilPaid({
    required String txnRefOrPaymentId,
    required String token,
    required Function(String) onError,
  }) async {
    AppLogger.payment('Starting payment status polling with staged backoff');
    AppLogger.payment('Transaction/Payment ID: $txnRefOrPaymentId');

    final paymentApi = PaymentApi(
      baseUrl: AppConfig.apiBaseUrl,
      apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );
    final totalAttempts = _pollBackoffSchedule.length;

    for (int attempt = 0; attempt < totalAttempts; attempt++) {
      if (_stopPolling) {
        AppLogger.payment('Polling stopped by user request');
        return (
          success: false,
          throttled: false,
          message: null,
          retryAfter: null,
        );
      }

      final wait = _pollBackoffSchedule[attempt];
      if (wait > Duration.zero) {
        AppLogger.payment(
          'Waiting ${wait.inSeconds}s before attempt ${attempt + 1}',
        );
        await Future.delayed(wait);
        if (_stopPolling) {
          return (
            success: false,
            throttled: false,
            message: null,
            retryAfter: null,
          );
        }
      }

      final label =
          'Đang kiểm tra trạng thái thanh toán... (${attempt + 1}/$totalAttempts)';
      updateLoading(true, label);

      try {
        final (:data, :headers) = await paymentApi.getPaymentStatus(
          txnRefOrPaymentId,
          token,
          maxRetries: 1,
          onLoading: (loading) {
            if (loading) updateLoading(true, label);
          },
        );
        final res = data;
        AppLogger.payment('Poll attempt ${attempt + 1} result: $res');

        // Check for Retry-After header if BE sets it
        final retryAfterHeader =
            headers['retry-after'] ?? headers['Retry-After'];
        if (retryAfterHeader != null) {
          final retryAfterSeconds = int.tryParse(retryAfterHeader);
          if (retryAfterSeconds != null && retryAfterSeconds > 0) {
            final waitDuration = Duration(seconds: retryAfterSeconds);
            AppLogger.payment(
              'BE requested retry-after: ${waitDuration.inSeconds}s',
            );
            return (
              success: false,
              throttled: true,
              message:
                  'VNPay yêu cầu đợi ${waitDuration.inSeconds} giây trước khi kiểm tra lại.',
              retryAfter: waitDuration,
            );
          }
        }

        final status = (res['status'] ?? '').toString().toLowerCase();
        final txn = (res['vnp_TransactionStatus'] ?? '').toString();
        final nestedPaid = (res['transaction'] is Map)
            ? ((res['transaction']['status'] ?? '').toString().toUpperCase() ==
                  'PAID')
            : false;

        final isSuccess = res['isSuccess'] == true;
        if (status == 'paid' ||
            txn == '00' ||
            isSuccess ||
            (status == 'success' && nestedPaid)) {
          AppLogger.payment('Payment confirmed as successful');
          return (
            success: true,
            throttled: false,
            message: null,
            retryAfter: null,
          );
        }

        if (status == 'failed' || status == 'canceled') {
          final desc = (res['statusDesc'] ?? 'Giao dịch thất bại hoặc bị hủy.')
              .toString();
          updateLoading(false);
          _setStatusInfoMessage(desc);
          return (
            success: false,
            throttled: false,
            message: desc,
            retryAfter: null,
          );
        }

        final code = (res['code'] ?? '').toString();
        final message = (res['message'] ?? '').toString().toLowerCase();

        if (code == '404' || message.contains('not found')) {
          const msg = 'Không tìm thấy giao dịch. Vui lòng thử lại.';
          updateLoading(false);
          _setStatusInfoMessage(msg);
          return (
            success: false,
            throttled: false,
            message: msg,
            retryAfter: null,
          );
        }

        if (code == '429' ||
            status == 'throttled' ||
            message.contains('duplicate request')) {
          final waitMsRaw = res['nextInMs'];
          final waitMs = waitMsRaw is int
              ? waitMsRaw
              : int.tryParse(waitMsRaw?.toString() ?? '') ?? 10000;
          final waitDuration = Duration(milliseconds: waitMs);
          final waitSeconds = (waitMs / 1000).ceil();
          final msg =
              'VNPay yêu cầu đợi thêm khoảng $waitSeconds giây trước khi kiểm tra lại.';
          return (
            success: false,
            throttled: true,
            message: msg,
            retryAfter: waitDuration,
          );
        }
      } catch (e) {
        AppLogger.paymentError('Poll error: $e');
      }
    }

    const msg =
        'Không xác định được trạng thái giao dịch. Vui lòng thử lại sau ít phút.';
    return (success: false, throttled: false, message: msg, retryAfter: null);
  }

  Future<void> _finalizeSubscription({
    required String reference,
    required String token,
    required Plan plan,
    required Function(String, String) onSuccess,
    required Function(String) onError,
  }) async {
    if (!_canFinalize) {
      AppLogger.payment('Finalize already in progress, skipping');
      return;
    }

    _acquireFinalizeLock();
    _finalizingSubscription = true;
    updateLoading(true, 'Đang xác nhận đăng ký gói...');

    try {
      final paymentApi = PaymentApi(
        baseUrl: AppConfig.apiBaseUrl,
        apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      final idempotencyKey = 'confirm::$reference';
      final confirm = await paymentApi.createPaidSubscription(
        reference,
        plan.code,
        token,
        idempotencyKey: idempotencyKey,
        onLoading: (loading) {
          if (loading) {
            updateLoading(true, 'Đang xác nhận đăng ký gói...');
          }
        },
      );
      AppLogger.payment('Subscription confirmation raw response: $confirm');
      final raw = confirm.containsKey('raw') ? confirm['raw'] : confirm;
      final bool confirmed =
          (confirm['confirmed'] == true) || _confirmIndicatesSuccess(raw);

      if (confirmed) {
        // Double-check there is concrete finalization evidence to avoid
        // treating ambiguous confirms as success. If missing, surface an
        // error to the user and do not call onSuccess.
        if (!_hasFinalizationEvidence(raw)) {
          final msg =
              confirm['message']?.toString() ??
              'Xác nhận không rõ ràng từ máy chủ. Vui lòng kiểm tra lại.';
          AppLogger.payment(
            'Finalize skipped: missing finalization evidence in confirm payload',
          );
          updateLoading(false, msg);
          _setStatusInfoMessage(msg);
          onError(msg);
          _startManualCheckCooldown();
          return;
        }
        try {
          // Refresh central subscription store instead of doing ad-hoc GET.
          await SubscriptionStore.instance.refresh();
        } catch (_) {}

        _awaitingExternalConfirmation = false;
        _statusCheckInProgress = false;
        _stopPolling = true;
        _nextManualCheckAt = null; // Clear cooldown
        _manualCheckTimer?.cancel(); // Cancel timer when finalizing
        _manualCheckTimer = null;
        updateLoading(false);
        _setStatusInfoMessage(null);
        onSuccess('Đăng ký thành công: ${plan.name}', 'success');
      } else {
        final message =
            confirm['message']?.toString() ?? 'Đăng ký subscription thất bại';
        updateLoading(false, message);
        _setStatusInfoMessage(message);
        onError(message);
        _startManualCheckCooldown();
      }
    } catch (e) {
      AppLogger.paymentError('Finalize subscription error: $e');
      final msg = 'Lỗi xác nhận đăng ký: $e';
      updateLoading(false, msg);
      _setStatusInfoMessage(msg);
      onError(msg);
      _startManualCheckCooldown();
    } finally {
      _finalizingSubscription = false;
      _releaseFinalizeLock();
    }
  }

  Future<void> triggerManualStatusCheck({
    required Function(String, String) onSuccess,
    required Function(String) onError,
    Plan? planOverride,
    bool triggeredByDeepLink = false,
  }) async {
    if (_statusCheckInProgress || _finalizingSubscription) {
      AppLogger.payment('Status check already in progress, skipping');
      return;
    }

    final plan = planOverride ?? _activePlan;
    if (plan == null) {
      onError('Không xác định được gói dịch vụ.');
      return;
    }

    if (!triggeredByDeepLink && !canTriggerStatusCheck) {
      final remaining = manualCheckRemaining;
      if (remaining != null) {
        _setStatusInfoMessage(
          'Bạn có thể kiểm tra lại sau ${remaining.inSeconds} giây.',
        );
      }
      return;
    }

    final reference = _lastPaymentId ?? _lastVnpTxnRef;
    if (reference == null) {
      onError('Không tìm thấy mã giao dịch để kiểm tra.');
      return;
    }

    final token = await AuthStorage.getAccessToken() ?? '';
    if (token.isEmpty) {
      updateLoading(false);
      onError('Không tìm thấy access token');
      return;
    }

    _statusCheckInProgress = true;
    _stopPolling = false;
    _setStatusInfoMessage(null);
    updateLoading(true, 'Đang kiểm tra trạng thái thanh toán...');

    final poll = await _pollStatusUntilPaid(
      txnRefOrPaymentId: reference,
      token: token,
      onError: onError,
    );

    _statusCheckInProgress = false;

    if (poll.success && !_stopPolling) {
      await _finalizeSubscription(
        reference: reference,
        token: token,
        plan: plan,
        onSuccess: onSuccess,
        onError: onError,
      );
      return;
    }

    updateLoading(false);

    if (poll.throttled) {
      if (poll.message != null) {
        _setStatusInfoMessage(poll.message);
      }
      if (poll.retryAfter != null) {
        _startManualCheckCooldown(poll.retryAfter!);
      } else if (!triggeredByDeepLink) {
        _startManualCheckCooldown();
      }
      return;
    }

    if (!triggeredByDeepLink) {
      _startManualCheckCooldown();
    }

    if (poll.message != null) {
      _setStatusInfoMessage(poll.message);
      onError(poll.message!);
    } else {
      _setStatusInfoMessage(
        'Chưa nhận được xác nhận. Hãy thử kiểm tra lại sau ít phút.',
      );
    }
  }

  Future<void> applyCoupon(
    Plan plan,
    int term,
    int subtotal, {
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    updateCouponState(applying: true, discountAmount: 0, discountLabel: null);

    await Future.delayed(const Duration(milliseconds: 350));

    // Local coupon examples (replace with API call later)
    // WELCOME10 -> 10% off up to 200k
    // TRY50K -> 50k off one-time
    if (code.toUpperCase() == 'WELCOME10') {
      final discount = (subtotal * 0.1).round();
      updateCouponState(
        discountAmount: discount > 200000 ? 200000 : discount,
        discountLabel: '10% (tối đa 200k)',
        appliedCoupon: code.toUpperCase(),
      );
    } else if (code.toUpperCase() == 'TRY50K') {
      updateCouponState(
        discountAmount: 50000,
        discountLabel: '50k off',
        appliedCoupon: code.toUpperCase(),
      );
    } else {
      updateCouponState(
        discountAmount: 0,
        discountLabel: null,
        appliedCoupon: null,
      );
    }

    updateCouponState(applying: false);

    if (_appliedCoupon == null) {
      onError('Mã khuyến mãi không hợp lệ');
    } else {
      onSuccess('Áp dụng mã: $_appliedCoupon');
    }
  }
}
