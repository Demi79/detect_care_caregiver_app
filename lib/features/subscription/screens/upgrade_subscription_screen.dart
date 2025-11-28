import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/subscription/screens/payment/payment_screen.dart';
import 'package:flutter/material.dart';

import '../controllers/subscription_controller.dart';
import '../data/service_package_api.dart';
import '../models/plan.dart';
import '../models/subscription_model.dart';
import '../utils/amount_parser.dart';
import '../utils/payment_navigation_utils.dart';
import '../widgets/pricing_helpers.dart';

class UpgradeSubscriptionScreen extends StatefulWidget {
  final SubscriptionModel currentSubscription;
  final Plan currentPlan;
  final List<Plan> availablePlans;

  const UpgradeSubscriptionScreen({
    super.key,
    required this.currentSubscription,
    required this.currentPlan,
    required this.availablePlans,
  });

  @override
  State<UpgradeSubscriptionScreen> createState() =>
      _UpgradeSubscriptionScreenState();
}

class _UpgradeSubscriptionScreenState extends State<UpgradeSubscriptionScreen> {
  final SubscriptionController _controller = SubscriptionController(
    ServicePackageApi(),
  );

  Plan? selectedTargetPlan;
  bool isLoading = false;
  String? errorMessage;
  bool _navigatingToPayment = false;
  bool _processing = false;

  static const bool _kForcePaymentDebug = false;
  static const bool _kDirectToPaymentOnConfirm = false;

  @override
  void initState() {
    super.initState();
    // Default target plan: pick a different plan if available
    selectedTargetPlan = widget.availablePlans.firstWhere(
      (p) => p.code != widget.currentPlan.code,
      orElse: () => widget.availablePlans.isNotEmpty
          ? widget.availablePlans.first
          : widget.currentPlan,
    );
  }

  Future<void> _onConfirmUpgrade() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      errorMessage = null;
    });

    final plan = selectedTargetPlan ?? widget.currentPlan;

    try {
      AppLogger.api('[UpgradePlan] Upgrade plan pressed: code=${plan.code}');

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận nâng cấp'),
          content: Text(
            'Bạn có chắc chắn muốn nâng cấp lên gói "${plan.name}"?',
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

      String? subscriptionId = widget.currentSubscription.id.isNotEmpty
          ? widget.currentSubscription.id
          : null;
      if (subscriptionId == null) {
        try {
          subscriptionId = await _controller.api.getActiveSubscriptionId();
        } catch (e) {
          AppLogger.apiError('[UpgradePlan] getActiveSubscriptionId error: $e');
        }
      }

      if (subscriptionId != null) {
        final idemp =
            'upgrade-$subscriptionId-${DateTime.now().millisecondsSinceEpoch}';
        final result = await _controller.upgradeSubscription(
          subscriptionId,
          plan.code,
          idempotencyKey: idemp,
        );
        AppLogger.api('[UpgradePlan] Prepare upgrade result: $result');

        final isError =
            (result['status'] == 'error') || (result['success'] == false);
        if (isError) {
          AppLogger.api(
            '[UpgradePlan] Primary upgrade failed, attempting fallback',
          );
          final alt = await _controller.api.upgradePlanFallback(
            planCode: plan.code,
          );
          AppLogger.api('[UpgradePlan] Fallback upgrade result: $alt');
          if ((alt['status'] == 'error') || (alt['success'] == false)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(alt['message'] ?? 'Nâng cấp thất bại')),
            );
            return;
          } else {
            final rAlt = alt['data'] ?? alt;
            await _handlePrepareResult(rAlt, plan);
            return;
          }
        } else {
          final r = result['data'] ?? result;
          await _handlePrepareResult(r, plan);
          return;
        }
      } else {
        // No active subscription -> purchase flow
        await _goToPayment(
          plan: plan,
          selectedTerm: 1,
          overrideAmount: plan.price,
          billingType: 'purchase',
        );
        return;
      }
    } catch (e) {
      AppLogger.apiError('[UpgradePlan] prepare/upgrade error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chuẩn bị nâng cấp: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _handlePrepareResult(Map<String, dynamic> r, Plan plan) async {
    final int? prorationAmount = parseAmountFlexible(
      r['proration_amount'] ?? r['proration'] ?? r['prorate'],
    );
    final int? taxAmount = parseAmountFlexible(r['tax_amount'] ?? r['tax']);
    final int? feeAmount = parseAmountFlexible(r['fee_amount'] ?? r['fee']);
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
    final bool hasPaymentUrl = (r['payment_url'] ?? r['paymentUrl']) != null;
    final String? messageText = (r['message'] ?? r['note'] ?? r['description'])
        ?.toString();
    final int? messageAmount = paymentAmountFromText(messageText);

    AppLogger.api(
      '[UpgradePlan] Parsed prepare result -> totalPayable=$totalPayable, proration=$prorationAmount, tax=$taxAmount, fee=$feeAmount, tx=$tx, hasPaymentUrl=$hasPaymentUrl, raw=$r',
    );

    final bool needsPayment = shouldOpenPayment(r);

    final bool hasAmount =
        (totalPayable != null && totalPayable > 0) ||
        (prorationAmount != null && prorationAmount > 0) ||
        (messageAmount != null && messageAmount > 0);
    final bool hasTx = tx != null;
    final bool forceOpen = !needsPayment && (hasAmount || hasTx);

    AppLogger.api(
      '[UpgradePlan][DECIDE] needsPayment=$needsPayment hasAmount=$hasAmount totalPayable=$totalPayable proration=$prorationAmount hasTx=$hasTx tx=$tx forceOpen=$forceOpen keys=${r.keys.toList()}',
    );

    final bool shouldNavigate = shouldNavigateToPayment(
      r,
      totalPayable: totalPayable,
      prorationAmount: prorationAmount,
      tx: tx,
    );

    if (!mounted) return;
    if (shouldNavigate) {
      final bool isForced = forceOpen && !needsPayment;

      if (isForced) {
        AppLogger.api(
          '[UpgradePlan] forceOpen=true (upgrade screen) -> forcing payment screen',
        );
        _navigatingToPayment = false;
        _showUpgradePaymentNotice(
          serverMessage: messageText ?? r['message']?.toString(),
          totalPayable: totalPayable,
          prorationAmount: prorationAmount,
          fallbackAmount: messageAmount,
        );
        AppLogger.api(
          '[UpgradePlan] Navigate PaymentScreen (upgrade screen - forced): totalPayable=$totalPayable, proration=$prorationAmount, tax=$taxAmount, fee=$feeAmount, tx=$tx',
        );
      } else {
        // needsPayment path
        if (_kDirectToPaymentOnConfirm) {
          AppLogger.api(
            '[UpgradePlan] Direct-to-payment shortcut enabled (upgrade screen). Navigating now.',
          );
          await _goToPayment(
            plan: plan,
            selectedTerm: 1,
            overrideAmount: totalPayable ?? prorationAmount,
            linkedTransactionId: tx?.toString(),
            billingType: 'upgrade',
          );
          return;
        }

        if (!mounted) return;
        _showUpgradePaymentNotice(
          serverMessage: messageText,
          totalPayable: totalPayable,
          prorationAmount: prorationAmount,
          fallbackAmount: messageAmount,
        );
        AppLogger.api(
          '[UpgradePlan] Navigate PaymentScreen (upgrade screen): totalPayable=$totalPayable, proration=$prorationAmount, tax=$taxAmount, fee=$feeAmount, tx=$tx',
        );
      }

      await _goToPayment(
        plan: plan,
        selectedTerm: 1,
        overrideAmount: totalPayable ?? prorationAmount ?? messageAmount,
        linkedTransactionId: tx?.toString(),
        billingType: 'upgrade',
      );
      return;
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message'] ?? 'Nâng cấp thành công!')),
      );
      Navigator.pop(context, {'refresh': true});
    }
  }

  void _showUpgradePaymentNotice({
    String? serverMessage,
    int? totalPayable,
    int? prorationAmount,
    int? fallbackAmount,
  }) {
    if (!mounted) return;
    final trimmed = serverMessage?.trim();
    final shouldUseServerMessage =
        trimmed != null &&
        trimmed.isNotEmpty &&
        messageSuggestsPayment(trimmed);
    final amount = totalPayable ?? prorationAmount ?? fallbackAmount;
    final text = shouldUseServerMessage
        ? trimmed
        : (amount != null && amount > 0)
        ? 'Bạn sẽ thanh toán thêm ${formatVND(amount)} cho phần chênh lệch của kỳ hiện tại.'
        : 'Bạn sẽ thanh toán thêm phần chênh lệch cho kỳ hiện tại.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      AppLogger.api('[UpgradePlan] _goToPayment aborted: widget not mounted');
      return;
    }
    if (_navigatingToPayment && !_kForcePaymentDebug) {
      AppLogger.api(
        '[UpgradePlan] _goToPayment aborted: _navigatingToPayment already true',
      );
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }
    if (_navigatingToPayment && _kForcePaymentDebug) {
      AppLogger.api(
        '[UpgradePlan][DEBUG] overriding _navigatingToPayment guard (upgrade screen)',
      );
    }
    _navigatingToPayment = true;

    try {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      AppLogger.api(
        '[UpgradePlan] _goToPayment: overrideAmount=$overrideAmount, tx=$linkedTransactionId, url=$paymentUrl',
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

      if (ok == true && mounted) {
        Navigator.pop(context, {'refresh': true});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được màn thanh toán: $e')),
      );
    } finally {
      _navigatingToPayment = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nâng cấp gói')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gói hiện tại: ${widget.currentPlan.name} (${formatVND(widget.currentPlan.price)}/tháng)',
            ),
            const SizedBox(height: 12),
            DropdownButton<Plan>(
              value: selectedTargetPlan,
              isExpanded: true,
              items: widget.availablePlans
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p.name} - ${formatVND(p.price)}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selectedTargetPlan = v),
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            ElevatedButton(
              onPressed: _processing ? null : _onConfirmUpgrade,
              child: _processing
                  ? const CircularProgressIndicator()
                  : const Text('Xác nhận nâng cấp'),
            ),
          ],
        ),
      ),
    );
  }
}
