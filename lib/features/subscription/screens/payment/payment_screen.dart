import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:flutter/material.dart';

import '../../models/plan.dart';
import '../../widgets/pricing_helpers.dart';
import 'payment_logic.dart';
import 'payment_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final Plan plan;
  final int selectedTerm;
  final int? overrideAmount;
  final String? linkedTransactionId;
  final String? billingType;
  const PaymentScreen({
    super.key,
    required this.plan,
    this.selectedTerm = 1,
    this.overrideAmount,
    this.linkedTransactionId,
    this.billingType,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final PaymentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaymentController(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _controller.setActivePlan(widget.plan);
    AppLogger.payment(
      '[PAYMENT][INIT] PaymentScreen init -> plan=${widget.plan.name}, term=${widget.selectedTerm}, override=${widget.overrideAmount}, tx=${widget.linkedTransactionId}, billing=${widget.billingType}',
    );
    _controller.setCallbacks(
      onPaymentSuccess: (message, type) {
        if (!mounted) return;
        // Show a success dialog that the user can dismiss
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đăng ký thành công'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      },
      onPaymentError: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final term = widget.selectedTerm;
    final unitPrice = effectiveMonthly(plan, term);
    final saving = savingTextFor(plan, term);
    final subtotal =
        unitPrice * (term == 1 ? 1 : term); // if prepaid, show total for term
    final vat = (subtotal * 0.1).round();
    final total = subtotal + vat;
    final bool useOverride = widget.overrideAmount != null;
    final int payableTotal = useOverride ? widget.overrideAmount! : total;

    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () {
              AppLogger.payment(
                '[PAYMENT][BACK] User pressed back button from payment screen',
              );
              AppLogger.payment(
                '[PAYMENT][BACK] Plan: ${widget.plan.name}, Term: ${widget.selectedTerm}',
              );
              AppLogger.payment('[PAYMENT][BACK] Timestamp: ${DateTime.now()}');
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),

        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),

        title: const Text(
          'Thanh toán gói dịch vụ',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),

        // iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PlanSummary(
                              plan: plan,
                              billingType: widget.billingType,
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Tóm tắt đơn hàng',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!useOverride) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(child: Text('Giá đơn vị')),
                                  Flexible(child: Text(formatVND(unitPrice))),
                                ],
                              ),
                              if (saving.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(child: Text('Tiết kiệm')),
                                    Flexible(child: Text(saving)),
                                  ],
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(child: Text('Số tháng')),
                                  Flexible(child: Text('$term')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(child: Text('Tạm tính')),
                                  Flexible(child: Text(formatVND(subtotal))),
                                ],
                              ),
                              if (_controller.discountAmount > 0)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Giảm giá${_controller.discountLabel != null ? ' (${_controller.discountLabel})' : ''}',
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '-${formatVND(_controller.discountAmount)}',
                                      ),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(child: Text('VAT (10%)')),
                                  Flexible(child: Text(formatVND(vat))),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Tổng cộng',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      formatVND(total),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Số tiền phải trả',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      formatVND(payableTotal),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Đã bao gồm điều chỉnh nâng cấp / thuế (nếu có)',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Preserve coupon UI commented-out block in case it's reenabled later.
                    // The scrollable area allows the card and additional content to
                    // be fully visible without forcing the action buttons off-screen.
                  ],
                ),
              ),
            ),

            // Bottom actions: extracted to reusable widget
            SafeArea(
              top: false,
              child: PaymentBottomActions(
                isLoading: _controller.isLoading,
                loadingMessage: _controller.loadingMessage,
                onCancel: () {
                  if (!mounted) return;
                  _controller.stopPolling();
                  _controller.updateLoading(false);
                },
                awaitingUserReturn: _controller.awaitingUserReturn,
                statusInfoMessage: _controller.statusInfoMessage,
                canTriggerStatusCheck: _controller.canTriggerStatusCheck,
                manualCheckRemaining: _controller.manualCheckRemaining,
                onTriggerManualPressed: () => _controller.triggerManualStatusCheck(
                  onSuccess: (message, type) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                    // Return `true` so caller (SelectSubscriptionScreen) knows
                    // the payment/subscription succeeded and can refresh.
                    Navigator.pop(context, true);
                  },
                  onError: (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  },
                ),
                onBackPressed: () => Navigator.pop(context),
                primaryIsLoading: _controller.isLoading,
                onPrimaryPressed: () => _controller.startPaymentFlow(
                  widget.plan,
                  onSuccess: (message, type) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                    // Return true to indicate success to the caller so it can
                    // refresh subscription/plan state.
                    Navigator.pop(context, true);
                  },
                  onError: (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  },
                  context: context,
                  amountOverride: widget.overrideAmount,
                  linkedTransactionId: widget.linkedTransactionId,
                  billingType: widget.billingType,
                ),
                lastPaymentId: _controller.lastPaymentId,
                lastVnpTxnRef: _controller.lastVnpTxnRef,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
