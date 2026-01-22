import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/core/utils/error_handler.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/plan_constants.dart';
import '../mixins/subscription_logic_mixin.dart';
import '../models/plan.dart';
import '../providers/subscriptions_provider.dart';
import '../stores/subscription_store.dart';
import '../widgets/error_message_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/plan_list_item.dart';
import '../utils/amount_parser.dart';
import '../utils/payment_navigation_utils.dart';
import 'payment/payment_screen.dart';

class SelectSubscriptionScreen extends StatefulWidget {
  final Map<String, dynamic>? preloadedSubscription;
  const SelectSubscriptionScreen({super.key, this.preloadedSubscription});

  @override
  State<SelectSubscriptionScreen> createState() =>
      _SelectSubscriptionScreenState();
}

class _SelectSubscriptionScreenState extends State<SelectSubscriptionScreen>
    with SubscriptionLogic<SelectSubscriptionScreen> {
  // Billing term selection: 1 (monthly), 6, 12 (months prepaid)
  final int _selectedTerm = 1;
  bool _processingUpgrade = false;
  bool _navigatingToPayment = false;
  static const bool _kForcePaymentDebug = false;

  final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  @override
  void initState() {
    super.initState();
    if (widget.preloadedSubscription != null) {
      subscription = widget.preloadedSubscription;
      loading = false;
      // Nếu có plan_code, chọn luôn gói từ fallback plans
      final planCode = subscription?['code'];
      if (planCode != null) {
        final idx = PlanConstants.fallbackPlans.indexWhere(
          (p) => p.code == planCode,
        );
        if (idx != -1) {
          selectedPlanIndex = idx;
          plans = List<Plan>.from(
            PlanConstants.fallbackPlans,
          ); // Copy để sử dụng
        }
      }
    } else {
      // Khi không có preloadedSubscription, khởi tạo màn hình
      // (gọi API lấy subscription thực từ server). Không giữ state cũ
      // của `selectedPlanIndex` hay `subscription` để tránh hiển thị nhầm.
      _initScreen();
    }
  }

  Future<void> _initScreen() async {
    await initializeSubscriptionData();
  }

  @override
  Future<bool> canFetchCurrentPlan() async {
    final token = await AuthStorage.getAccessToken();
    return token != null;
  }

  void _showUpgradePaymentNotice({
    String? serverMessage,
    int? totalPayable,
    int? prorationAmount,
    int? fallbackAmount,
  }) {
    if (!mounted) return;
    final shouldUseServerMessage =
        serverMessage != null &&
        serverMessage.trim().isNotEmpty &&
        messageSuggestsPayment(serverMessage);
    final amount = totalPayable ?? prorationAmount ?? fallbackAmount;
    final text = shouldUseServerMessage
        ? serverMessage.trim()
        : (amount != null && amount > 0)
        ? 'Bạn sẽ thanh toán thêm ${_vnd.format(amount)} cho phần chênh lệch của kỳ hiện tại.'
        : 'Bạn sẽ thanh toán thêm phần chênh lệch cho kỳ hiện tại.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Determine whether the prepare/upgrade response requires opening a
  // payment UI. Collects many possible keys used by various backends and
  // returns true if there's an amount, a transaction, a redirect URL, or
  // an explicit flag that indicates payment is required.
  bool _shouldOpenPayment(Map<String, dynamic> r) {
    try {
      final messageText = (r['message'] ?? r['note'] ?? r['description'])
          ?.toString();
      final messageAmount = paymentAmountFromText(messageText);

      final hasAmount =
          (parseAmountFlexible(
                    r['amountDue'] ?? r['amount_due'] ?? r['amount'],
                  ) ??
                  0) >
              0 ||
          (parseAmountFlexible(
                    r['proration_amount'] ?? r['proration'] ?? r['prorate'],
                  ) ??
                  0) >
              0 ||
          (messageAmount ?? 0) > 0;
      final hasTx =
          (r['transactionId'] ??
              r['transaction_id'] ??
              r['txId'] ??
              r['payment_id']) !=
          null;
      final urls = [
        r['payment_url'],
        r['paymentUrl'],
        r['checkout_url'],
        r['checkoutUrl'],
        r['redirect_url'],
        r['redirectUrl'],
        r['payment_intent'],
        r['paymentIntent'],
        r['payment_code'],
        r['paymentCode'],
      ].whereType<String>();
      final flags = <bool>[];
      for (final key in [
        'requires_payment',
        'payment_required',
        'need_payment',
        'requiresPayment',
        'paymentRequired',
        'needPayment',
      ]) {
        if (flagIndicatesPayment(r[key])) {
          flags.add(true);
        }
      }
      for (final key in ['status', 'payment_status', 'state']) {
        final statusValue = r[key]?.toString();
        if (statusIndicatesPayment(statusValue)) {
          flags.add(true);
          break;
        }
      }
      final nextAction =
          (r['next_action'] ?? r['nextAction'] ?? r['nextActionRequired'])
              ?.toString()
              .toLowerCase();
      if (nextAction != null &&
          (nextAction.contains('redirect') || nextAction.contains('payment'))) {
        flags.add(true);
      }
      if (messageSuggestsPayment(messageText)) {
        flags.add(true);
      }

      return hasAmount || hasTx || urls.isNotEmpty || flags.any((b) => b);
    } catch (_) {
      return false;
    }
  }

  Future<void> _onSelectPlan(Plan plan, int index) async {
    setState(() {
      selectedPlanIndex = index;
    });
    AppLogger.api(
      '[SelectPlan] Đã chọn gói: code=${plan.code}, price=${plan.price}, index=$index',
    );
    final token = await AuthStorage.getAccessToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy access token')),
        );
      }
      return;
    }
    try {
      if (plan.price == 0) {
        AppLogger.api('[API] POST ${AppConfig.apiBaseUrl}/subscriptions');
        AppLogger.api('[SelectPlan] Đăng ký gói miễn phí: code=${plan.code}');
        final response = await subscriptionController.registerFreePlan(
          plan.code,
        );
        AppLogger.api('[SelectPlan] Phản hồi API RegisterFreePlan: $response');
        if (response['status'] == 'active' || response['is_trial'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đăng ký thành công: $plan.name')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đăng ký thất bại: ${response['message'] ?? 'Lỗi không xác định'}',
                ),
              ),
            );
          }
        }
      } else {
        AppLogger.api(
          '[SelectPlan] Điều hướng đến PaymentScreen với gói: code=${plan.code}, price=${plan.price}',
        );
        if (!mounted) return;
        if (_navigatingToPayment && !_kForcePaymentDebug) return;
        if (_navigatingToPayment && _kForcePaymentDebug) {
          AppLogger.api(
            '[UpgradePlan][DEBUG] Buộc điều hướng mặc dù _navigatingToPayment=true',
          );
        }
        _navigatingToPayment = true;
        AppLogger.api(
          '[UpgradePlan] Đẩy PaymentScreen (mua mới) -> plan=${plan.code}, price=${plan.price}',
        );
        try {
          final paymentResult = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PaymentScreen(plan: plan, selectedTerm: _selectedTerm),
            ),
          );

          // If payment was successful, refresh the subscription data
          if (paymentResult == true) {
            await refreshCurrentPlan();
          }
        } finally {
          _navigatingToPayment = false;
        }
      }
    } catch (e) {
      AppLogger.apiError('[SelectPlan] Lỗi RegisterFreePlan: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đăng ký: $e')));
      }
    }
  }

  Future<void> _onUpgradePlan(Plan plan) async {
    if (_processingUpgrade) return;
    final currentCode = (subscription?['code'] ?? subscription?['plan_code'])
        ?.toString();
    if (currentCode != null && currentCode == plan.code) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đang ở đúng gói này')),
        );
      }
      return;
    }

    setState(() => _processingUpgrade = true);

    try {
      AppLogger.api(
        '[UpgradePlan] Nhấn nâng cấp gói: code=${plan.code}, price=${plan.price}',
      );

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Xác nhận nâng cấp'),
          content: Text(
            'Bạn có chắc chắn muốn nâng cấp lên gói "${plan.name}" với giá ${_vnd.format(plan.price)}/tháng?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      AppLogger.api(
        '[UpgradePlan] Đã xác nhận nâng cấp. Chuẩn bị nâng cấp trên server nếu có subscription, nếu không thì khởi tạo thanh toán cho gói đầy đủ.',
      );

      String? subscriptionId = activeSubscriptionId;
      if (subscriptionId == null) {
        try {
          subscriptionId = await subscriptionController.api
              .getActiveSubscriptionId();
        } catch (e) {
          AppLogger.apiError('[UpgradePlan] Lỗi getActiveSubscriptionId: $e');
        }
      }

      AppLogger.api(
        '[UpgradePlan] subscriptionId=$subscriptionId, subscription.status=${subscription?['status']}, subscription.plan_code=${subscription?['plan_code']}',
      );

      // Log current subscription state for debugging navigation decisions
      AppLogger.api(
        '[SelectSubscription] status=${subscription?['status']} plan=${subscription?['plan_code']} endsAt=${subscription?['current_period_end']} subscriptionId=$subscriptionId',
      );

      if (subscriptionId != null) {
        try {
          final idemp =
              'upgrade-$subscriptionId-${DateTime.now().millisecondsSinceEpoch}';
          final result = await subscriptionController.upgradeSubscription(
            subscriptionId,
            plan.code,
            idempotencyKey: idemp,
          );
          AppLogger.api('[UpgradePlan] Chuẩn bị nâng cấp kết quả: $result');

          final isError =
              (result['status'] == 'error') || (result['success'] == false);
          if (isError) {
            AppLogger.api(
              '[UpgradePlan] Nâng cấp chính thất bại, thử fallback',
            );
            final alt = await subscriptionController.api.upgradePlanFallback(
              planCode: plan.code,
            );
            AppLogger.api('[UpgradePlan] Kết quả nâng cấp fallback: $alt');
            if ((alt['status'] == 'error') || (alt['success'] == false)) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(alt['message'] ?? 'Nâng cấp thất bại')),
              );
            } else {
              AppLogger.api(
                '[UpgradePlan] Kết quả chuẩn bị fallback (raw): $alt',
              );
              final rAlt = alt['data'] ?? alt;
              AppLogger.api(
                '[UpgradePlan] Phân tích kết quả chuẩn bị fallback -> $rAlt',
              );

              final int? prorationAmountAlt = parseAmountFlexible(
                rAlt['proration_amount'] ??
                    rAlt['proration'] ??
                    rAlt['prorate'],
              );
              final int? taxAmountAlt = parseAmountFlexible(
                rAlt['tax_amount'] ?? rAlt['tax'],
              );
              final int? feeAmountAlt = parseAmountFlexible(
                rAlt['fee_amount'] ?? rAlt['fee'],
              );
              final int? totalPayableAlt = parseAmountFlexible(
                rAlt['total_payable'] ??
                    rAlt['total'] ??
                    rAlt['amount_due'] ??
                    rAlt['amount'] ??
                    rAlt['amountDue'],
              );

              final txAlt =
                  rAlt['transactionId'] ??
                  rAlt['transaction_id'] ??
                  rAlt['txId'] ??
                  rAlt['payment_id'];
              final bool hasPaymentUrlAlt =
                  (rAlt['payment_url'] ?? rAlt['paymentUrl']) != null;
              final String? messageTextAlt =
                  (rAlt['message'] ?? rAlt['note'] ?? rAlt['description'])
                      ?.toString();
              final int? messageAmountAlt = paymentAmountFromText(
                messageTextAlt,
              );

              AppLogger.api(
                '[UpgradePlan] Phân tích fallback -> totalPayable=$totalPayableAlt, proration=$prorationAmountAlt, tax=$taxAmountAlt, fee=$feeAmountAlt, tx=$txAlt, hasPaymentUrl=$hasPaymentUrlAlt',
              );

              final bool needsPaymentAlt = _shouldOpenPayment(rAlt);
              final bool hasAmountAlt =
                  (totalPayableAlt != null && totalPayableAlt > 0) ||
                  (prorationAmountAlt != null && prorationAmountAlt > 0);
              final bool hasTxAlt = txAlt != null;
              final bool forceOpenAlt =
                  !needsPaymentAlt && (hasAmountAlt || hasTxAlt);

              final bool shouldNavigateAlt = _shouldNavigateToPayment(
                rAlt,
                totalPayable: totalPayableAlt,
                prorationAmount: prorationAmountAlt,
                tx: txAlt,
              );

              if (!mounted) return;
              if (shouldNavigateAlt) {
                if (!mounted) return;
                AppLogger.api(
                  '[UpgradePlan] Fallback sẽ mở thanh toán: needsPayment=$needsPaymentAlt hasTx=$hasTxAlt hasAmount=$hasAmountAlt forceOpen=$forceOpenAlt',
                );

                _showUpgradePaymentNotice(
                  serverMessage: messageTextAlt ?? rAlt['message']?.toString(),
                  totalPayable: totalPayableAlt,
                  prorationAmount: prorationAmountAlt,
                  fallbackAmount: messageAmountAlt,
                );

                AppLogger.api(
                  '[UpgradePlan] Điều hướng PaymentScreen (fallback): totalPayable=$totalPayableAlt, proration=$prorationAmountAlt, tx=$txAlt',
                );

                _navigatingToPayment = false;

                await _goToPayment(
                  plan: plan,
                  selectedTerm: _selectedTerm,
                  overrideAmount:
                      totalPayableAlt ?? prorationAmountAlt ?? messageAmountAlt,
                  linkedTransactionId: txAlt?.toString(),
                  billingType: 'upgrade',
                );

                return;
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(rAlt['message'] ?? 'Nâng cấp thành công!'),
                  ),
                );
                await refreshCurrentPlan();
              }
            }
          } else {
            AppLogger.api(
              '[UpgradePlan] Kết quả chuẩn bị nâng cấp (raw): $result',
            );
            final r = result['data'] ?? result;
            AppLogger.api('[UpgradePlan] Phân tích kết quả chuẩn bị -> $r');

            final int? prorationAmount = parseAmountFlexible(
              r['proration_amount'] ?? r['proration'] ?? r['prorate'],
            );
            final int? taxAmount = parseAmountFlexible(
              r['tax_amount'] ?? r['tax'],
            );
            final int? feeAmount = parseAmountFlexible(
              r['fee_amount'] ?? r['fee'],
            );
            final int? totalPayable = parseAmountFlexible(
              r['total_payable'] ??
                  r['total'] ??
                  r['amount_due'] ??
                  r['amount'] ??
                  r['amountDue'],
            );

            final tx =
                r['transactionId'] ??
                r['transaction_id'] ??
                r['txId'] ??
                r['payment_id'];
            final bool hasPaymentUrl =
                (r['payment_url'] ?? r['paymentUrl']) != null;
            final String? messageText =
                (r['message'] ?? r['note'] ?? r['description'])?.toString();
            final int? messageAmount = paymentAmountFromText(messageText);

            AppLogger.api(
              '[UpgradePlan] Phân tích kết quả chuẩn bị -> totalPayable=$totalPayable, proration=$prorationAmount, tax=$taxAmount, fee=$feeAmount, tx=$tx, hasPaymentUrl=$hasPaymentUrl, raw=$r',
            );

            final bool needsPayment = _shouldOpenPayment(r);

            final bool hasAmount =
                (totalPayable != null && totalPayable > 0) ||
                (prorationAmount != null && prorationAmount > 0) ||
                (messageAmount != null && messageAmount > 0);
            final bool hasTx = tx != null;
            final bool forceOpen = !needsPayment && (hasAmount || hasTx);

            AppLogger.api(
              '[UpgradePlan][QUYẾT ĐỊNH] needsPayment=$needsPayment hasAmount=$hasAmount totalPayable=$totalPayable proration=$prorationAmount hasTx=$hasTx tx=$tx forceOpen=$forceOpen keys=${r.keys.toList()}',
            );
            final bool shouldNavigate = _shouldNavigateToPayment(
              r,
              totalPayable: totalPayable,
              prorationAmount: prorationAmount,
              tx: tx,
            );

            AppLogger.api(
              '[UpgradePlan] shouldNavigate=$shouldNavigate, needsPayment=$needsPayment, forceOpen=$forceOpen',
            );

            if (!mounted) return;
            if (shouldNavigate) {
              final bool isForced = forceOpen && !needsPayment;

              if (isForced) {
                AppLogger.api(
                  '[UpgradePlan] forceOpen=true (select screen) needsPayment=$needsPayment hasTx=$hasTx hasAmount=$hasAmount -> buộc mở màn hình thanh toán',
                );
                _navigatingToPayment = false;

                _showUpgradePaymentNotice(
                  serverMessage: messageText,
                  totalPayable: totalPayable,
                  prorationAmount: prorationAmount,
                  fallbackAmount: messageAmount,
                );

                final paymentUrl =
                    (r['payment_url'] ??
                            r['paymentUrl'] ??
                            r['checkout_url'] ??
                            r['checkoutUrl'] ??
                            r['redirect_url'] ??
                            r['redirectUrl'] ??
                            r['payment_intent'] ??
                            r['paymentIntent'])
                        ?.toString();

                AppLogger.api(
                  '[UpgradePlan] Điều hướng PaymentScreen (select screen - buộc): totalPayable=$totalPayable, proration=$prorationAmount, tx=$tx, url=$paymentUrl',
                );
              } else {
                // needsPayment path
                _showUpgradePaymentNotice(
                  serverMessage: messageText,
                  totalPayable: totalPayable,
                  prorationAmount: prorationAmount,
                  fallbackAmount: messageAmount,
                );

                if (mounted) setState(() => _processingUpgrade = false);

                final paymentUrl =
                    (result['payment_url'] ??
                            result['paymentUrl'] ??
                            result['checkout_url'] ??
                            result['checkoutUrl'] ??
                            result['redirect_url'] ??
                            result['redirectUrl'] ??
                            result['payment_intent'] ??
                            result['paymentIntent'] ??
                            result['payment_code'] ??
                            result['paymentCode'])
                        ?.toString();
                AppLogger.api(
                  '[UpgradePlan] Điều hướng PaymentScreen: totalPayable=$totalPayable, proration=$prorationAmount, tx=$tx, url=$paymentUrl',
                );
              }

              await _goToPayment(
                plan: plan,
                selectedTerm: _selectedTerm,
                overrideAmount:
                    totalPayable ?? prorationAmount ?? messageAmount,
                linkedTransactionId: tx?.toString(),
                billingType: 'upgrade',
              );

              return;
            } else {
              AppLogger.api(
                '[UpgradePlan] Không đáp ứng điều kiện mở màn hình thanh toán. result=$result',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Nâng cấp thành công!'),
                ),
              );
              await refreshCurrentPlan();
            }
          }
        } catch (e) {
          AppLogger.apiError('[UpgradePlan] Lỗi prepare/upgrade: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi khi chuẩn bị nâng cấp: $e')),
            );
          }
        }
      } else {
        AppLogger.api(
          '[UpgradePlan] Không tìm thấy subscriptionId, chuyển đến thanh toán cho mua mới',
        );
        if (!mounted) return;
        final token = await AuthStorage.getAccessToken();
        final oldPlanCode = subscription?['code'];

        await _goToPayment(
          plan: plan,
          selectedTerm: _selectedTerm,
          overrideAmount: plan.price,
          billingType: 'purchase',
        );
        if (token != null) {
          final newPlanCode = subscription?['code'];
          if (oldPlanCode != null &&
              newPlanCode != null &&
              oldPlanCode != newPlanCode) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nâng cấp gói thành công!')),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _processingUpgrade = false);
    }
  }

  Future<void> _goToPayment({
    required Plan plan,
    required int selectedTerm,
    int? overrideAmount,
    String? linkedTransactionId,
    String billingType = 'upgrade',
    String? paymentUrl,
  }) async {
    if (!mounted) {
      AppLogger.api(
        '[UpgradePlan] _goToPayment bị hủy: widget không được mount',
      );
      return;
    }
    if (_navigatingToPayment && !_kForcePaymentDebug) {
      AppLogger.api(
        '[UpgradePlan] _goToPayment bị hủy: _navigatingToPayment đã là true',
      );
      if (mounted) setState(() => _processingUpgrade = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }
    if (_navigatingToPayment && _kForcePaymentDebug) {
      AppLogger.api('[UpgradePlan][DEBUG] ghi đè guard _navigatingToPayment');
    }
    _navigatingToPayment = true;

    try {
      if (mounted) setState(() => _processingUpgrade = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      AppLogger.api(
        '[UpgradePlan] Điều hướng PaymentScreen: overrideAmount=$overrideAmount, tx=$linkedTransactionId, url=$paymentUrl',
      );

      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'payment-upgrade'),
          builder: (_) => PaymentScreen(
            plan: plan,
            selectedTerm: selectedTerm,
            overrideAmount: overrideAmount,
            linkedTransactionId: linkedTransactionId,
            billingType: billingType,
          ),
        ),
      );

      if (ok == true) {
        await refreshCurrentPlan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không mở được màn thanh toán: $e')),
        );
      }
    } finally {
      _navigatingToPayment = false;
    }
  }

  bool _shouldNavigateToPayment(
    Map<String, dynamic> r, {
    int? totalPayable,
    int? prorationAmount,
    dynamic tx,
  }) {
    final bool needs = _shouldOpenPayment(r);
    final int total =
        totalPayable ??
        (parseAmountFlexible(
              r['total_payable'] ??
                  r['total'] ??
                  r['amount_due'] ??
                  r['amount'] ??
                  r['amountDue'],
            ) ??
            0);
    final int pror =
        prorationAmount ??
        (parseAmountFlexible(
              r['proration_amount'] ?? r['proration'] ?? r['prorate'],
            ) ??
            0);
    final dynamic txVal =
        tx ??
        r['transactionId'] ??
        r['transaction_id'] ??
        r['txId'] ??
        r['payment_id'];
    final bool forceOpen = !needs && (total > 0 || pror > 0 || txVal != null);

    AppLogger.api(
      '[UpgradePlan][QUYẾT ĐỊNH] needsPayment=$needs '
      'hasAmount=${(total > 0) || (pror > 0)} totalPayable=$total proration=$pror '
      'hasTx=${txVal != null} tx=$txVal forceOpen=$forceOpen keys=${r.keys.toList()}',
    );

    return needs || forceOpen;
  }

  void _handleStoreUpdates(BuildContext context) {
    try {
      final store = context.watch<SubscriptionStore>();
      final storePlan = store.planData;
      // Only proceed when storePlan exists and is different from current subscription
      if (storePlan != null && storePlan != subscription) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Try to extract the actual subscription object from different shapes
          // NOTE: store.planData có thể có nhiều dạng tuỳ backend:
          //  - Envelope: { subscriptions: [ { subscription... } ] }
          //  - Object chứa key 'subscription'
          //  - Hoặc chính là object subscription/plans
          // Mục tiêu của đoạn code sau là: luôn tìm ra đối tượng subscription
          // thực tế (chứa plan_code, status, current_period_end, ...)
          // và GÁN `subscription = sub` (không gán nhầm inner 'plan' thành subscription).
          Map<String, dynamic>?
          sub; // the subscription object (contains plan_code, status, etc.)

          try {
            if (storePlan['subscriptions'] is List) {
              final subscriptions = storePlan['subscriptions'] as List;
              if (subscriptions.isNotEmpty) {
                // subscription element should be the full subscription, not the inner 'plans'
                final firstSub = subscriptions[0];
                if (firstSub is Map<String, dynamic>) {
                  sub = firstSub;
                }
              }
            } else {
              // Some backends may expose subscription directly under 'subscription' or the root
              final maybeSubscription = storePlan['subscription'];
              if (maybeSubscription is Map<String, dynamic>) {
                sub = maybeSubscription;
              } else if ((storePlan['plan_code'] ?? storePlan['code']) !=
                  null) {
                // storePlan itself may already be the subscription object
                sub = storePlan;
              }
            }
          } catch (_) {
            sub = null;
          }

          if (sub != null) {
            // Xác định mã plan hiện tại (currentCode) từ subscription thực
            // ưu tiên 'plan_code', fallback về 'code'.
            final String? currentCode = (sub['plan_code'] ?? sub['code'])
                ?.toString();

            // availablePlans: nếu đã load sẵn plans thì dùng, nếu chưa thì dùng fallback
            final availablePlans = plans.isNotEmpty
                ? plans
                : PlanConstants.fallbackPlans;
            final idx = currentCode != null
                ? availablePlans.indexWhere((p) => p.code == currentCode)
                : -1;

            setState(() {
              if (plans.isEmpty) plans = List<Plan>.from(availablePlans);
              // Chỉ cập nhật selectedPlanIndex khi tìm thấy plan tương ứng
              // Tránh dùng selectedPlanIndex như là nguồn chân lý cho plan hiện tại.
              if (idx != -1) {
                selectedPlanIndex = idx;
              }
              // Gán subscription = sub (đối tượng subscription thực từ BE)
              // Không gán inner `plan` vào `subscription` vì sẽ làm nhầm lẫn
              // giữa plan và subscription (đã gây lỗi trước đây).
              subscription = sub;
            });
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _handleStoreUpdates(context);
    try {
      final prov = context.watch<SubscriptionsProvider>();
      if (loading && !prov.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => loading = false);
        });
      }
    } catch (_) {}

    return Scaffold(
      body: Stack(
        children: [
          if (error != null)
            ErrorMessageWidget(error: error)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: plans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (ctx, i) {
                        return PlanListItem(
                          plan: plans[i],
                          index: i,
                          selectedPlanIndex: selectedPlanIndex,
                          subscription: subscription,
                          selectedTerm: _selectedTerm,
                          allPlans: plans,
                          onSelectPlan: _onSelectPlan,
                          onUpgradePlan: _onUpgradePlan,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (loading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withAlpha(220),
                child: const Center(
                  child: LoadingWidget(
                    message: 'Đang tải dữ liệu gói dịch vụ...',
                  ),
                ),
              ),
            ),
          if (_processingUpgrade)
            Positioned.fill(
              child: Container(
                color: Colors.white.withAlpha(200),
                alignment: Alignment.center,
                child: const LoadingWidget(message: 'Đang xử lý nâng cấp...'),
              ),
            ),
        ],
      ),
    );
  }
} // class
