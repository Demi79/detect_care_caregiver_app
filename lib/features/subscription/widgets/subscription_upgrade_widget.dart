import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/payment_endpoint_adapter.dart';
import '../../auth/data/auth_storage.dart';

enum UpgradeState {
  idle,
  preparing,
  requiresAction,
  awaitingReturn,
  pendingConfirmation,
  success,
  failure,
}

class SubscriptionUpgradeWidget extends StatefulWidget {
  final String subscriptionId;
  final String planCode;
  final List<String> billingCycles; // e.g. ['monthly','yearly']
  final PaymentEndpointAdapter? adapter;

  const SubscriptionUpgradeWidget({
    super.key,
    required this.subscriptionId,
    required this.planCode,
    this.billingCycles = const ['monthly'],
    this.adapter,
  });

  @override
  State<SubscriptionUpgradeWidget> createState() =>
      _SubscriptionUpgradeWidgetState();
}

class _SubscriptionUpgradeWidgetState extends State<SubscriptionUpgradeWidget> {
  late final PaymentEndpointAdapter adapter;
  String? selectedCycle;
  UpgradeState state = UpgradeState.idle;
  Map<String, dynamic>? prepareData;
  Map<String, dynamic>? paymentData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    adapter = widget.adapter ?? PaymentEndpointAdapter(baseUrl: '');
    selectedCycle = widget.billingCycles.isNotEmpty
        ? widget.billingCycles.first
        : null;
  }

  Future<void> _prepare() async {
    setState(() {
      state = UpgradeState.preparing;
      errorMessage = null;
    });

    final idemp = '${DateTime.now().millisecondsSinceEpoch}-${_shortRandom()}';
    final token = await AuthStorage.getAccessToken();

    final resp = await adapter.prepareUpgrade(
      subscriptionId: widget.subscriptionId,
      planCode: widget.planCode,
      billingCycle: selectedCycle,
      token: token,
      idempotencyKey: idemp,
    );

    if (resp['success'] == true && resp['data'] != null) {
      setState(() {
        prepareData = Map<String, dynamic>.from(resp['data']);
      });

      final status = prepareData?['status']?.toString();
      final amountDue =
          prepareData?['amountDue'] ?? prepareData?['amount'] ?? 0;
      if ((amountDue == 0 || amountDue == '0') &&
          (status == null || status == 'success')) {
        // free upgrade
        setState(() => state = UpgradeState.success);
        // Caller should refresh subscription; we leave that to parent
        return;
      }

      if (status == 'requires_action' || amountDue != 0) {
        setState(() => state = UpgradeState.requiresAction);
        return;
      }

      setState(() {
        state = UpgradeState.failure;
        errorMessage = 'Unexpected prepare response';
      });
    } else {
      setState(() {
        state = UpgradeState.failure;
        errorMessage = resp['error']?.toString() ?? 'Prepare failed';
      });
    }
  }

  Future<void> _createPaymentAndRedirect() async {
    setState(() {
      state = UpgradeState.awaitingReturn;
      errorMessage = null;
    });

    final idemp = '${DateTime.now().millisecondsSinceEpoch}-${_shortRandom()}';
    final token = await AuthStorage.getAccessToken();

    final resp = await adapter.createVnPayPayment(
      planCode: widget.planCode,
      billingCycle: selectedCycle,
      description: 'Upgrade ${widget.planCode} ${selectedCycle ?? ''}',
      token: token,
      idempotencyKey: idemp,
    );

    if (resp['success'] == true && resp['data'] != null) {
      paymentData = Map<String, dynamic>.from(resp['data']);
      final url = paymentData?['payment_url']?.toString();
      final paymentId =
          paymentData?['payment_id']?.toString() ??
          paymentData?['vnpTxnRef']?.toString();

      if (url != null) {
        // open external browser or webview
        await _openUrl(url);
      }

      // move to pendingConfirmation so UI shows 'Đang xử lý'
      setState(() => state = UpgradeState.pendingConfirmation);

      // Start polling in background but allow user to press manual check
      if (paymentId != null) {
        _pollAndHandle(paymentId);
      }
    } else {
      setState(() {
        state = UpgradeState.failure;
        errorMessage = resp['error']?.toString() ?? 'Create payment failed';
      });
    }
  }

  Future<void> _pollAndHandle(String paymentId) async {
    final token = await AuthStorage.getAccessToken();
    final resp = await adapter.pollPaymentStatus(
      paymentId: paymentId,
      token: token,
    );
    if (resp['success'] == true) {
      setState(() => state = UpgradeState.success);
    } else {
      setState(() {
        state = UpgradeState.pendingConfirmation;
        errorMessage = resp['message'] ?? resp['error']?.toString();
      });
    }
  }

  int _shortRandom() =>
      DateTime.now().millisecond + (DateTime.now().second << 8);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      setState(() {
        errorMessage = 'Unable to open payment URL';
      });
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildBody() {
    switch (state) {
      case UpgradeState.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.billingCycles.isNotEmpty)
              DropdownButton<String>(
                value: selectedCycle,
                items: widget.billingCycles
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCycle = v),
              ),
            ElevatedButton(onPressed: _prepare, child: const Text('Nâng cấp')),
          ],
        );

      case UpgradeState.preparing:
        return const Center(child: CircularProgressIndicator());

      case UpgradeState.requiresAction:
        final amount =
            prepareData?['amountDue'] ?? prepareData?['amount'] ?? '—';
        final desc = prepareData?['description'] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số tiền phải trả: $amount VND'),
            if (desc != null) Text(desc.toString()),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createPaymentAndRedirect,
              child: const Text('Thanh toán'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => state = UpgradeState.idle),
              child: const Text('Hủy'),
            ),
          ],
        );

      case UpgradeState.awaitingReturn:
      case UpgradeState.pendingConfirmation:
        final paymentId =
            paymentData?['payment_id'] ?? paymentData?['vnpTxnRef'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đang xử lý thanh toán...'),
            if (paymentId != null) Text('Giao dịch: $paymentId'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (paymentId != null) _pollAndHandle(paymentId.toString());
              },
              child: const Text('Kiểm tra trạng thái'),
            ),
          ],
        );

      case UpgradeState.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            const Text('Nâng cấp thành công'),
            ElevatedButton(
              onPressed: () {
                // allow retry or parent refresh
                setState(() => state = UpgradeState.idle);
              },
              child: const Text('Đóng'),
            ),
          ],
        );

      case UpgradeState.failure:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(errorMessage ?? 'Lỗi khi nâng cấp'),
            ElevatedButton(
              onPressed: () => setState(() => state = UpgradeState.idle),
              child: const Text('Thử lại'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
    );
  }
}
