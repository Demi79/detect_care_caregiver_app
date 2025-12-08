import 'dart:convert';

import 'package:detect_care_caregiver_app/core/analytics/analytics.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/service_package/services/service_package_api.dart';
import 'package:detect_care_caregiver_app/features/subscription/controllers/subscription_controller.dart'
    as sub_ctrl;
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart'
    as sub_api;
import 'package:detect_care_caregiver_app/features/subscription/models/subscription_model.dart';
import 'package:detect_care_caregiver_app/features/subscription/providers/subscriptions_provider.dart';
import 'package:detect_care_caregiver_app/features/subscription/stores/subscription_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin that provides subscription management functionality
mixin SubscriptionManagementMixin<T extends StatefulWidget> on State<T> {
  final ServicePackageApi _servicePackageApi = ServicePackageApi();
  List<Map<String, dynamic>> _availablePlans = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _billingHistory = [];
  Map<String, dynamic>? _planUsage;
  Map<String, dynamic>? _pendingConfirmation;
  bool _hidePendingBanner = false;

  // Getters
  List<Map<String, dynamic>> get availablePlans => _availablePlans;
  List<Map<String, dynamic>> get invoices => _invoices;
  List<Map<String, dynamic>> get billingHistory => _billingHistory;
  Map<String, dynamic>? get planUsage => _planUsage;
  Map<String, dynamic>? get pendingConfirmation => _pendingConfirmation;
  bool get hidePendingBanner => _hidePendingBanner;

  // Setters
  set availablePlans(List<Map<String, dynamic>> value) =>
      _availablePlans = value;
  set invoices(List<Map<String, dynamic>> value) => _invoices = value;
  set billingHistory(List<Map<String, dynamic>> value) =>
      _billingHistory = value;
  set planUsage(Map<String, dynamic>? value) => _planUsage = value;
  set pendingConfirmation(Map<String, dynamic>? value) =>
      _pendingConfirmation = value;
  set hidePendingBanner(bool value) => _hidePendingBanner = value;

  Future<void> loadInitialData() async {
    final prov = context.read<SubscriptionsProvider>();
    try {
      await prov.fetchMySubscriptions();
    } catch (e) {
      AppLogger.apiError('fetchMySubscriptions: $e');
    }
    try {
      await loadAvailablePlans();
    } catch (e) {
      AppLogger.apiError('loadAvailablePlans: $e');
    }
    try {
      await loadInvoices();
    } catch (e) {
      AppLogger.apiError('loadInvoices: $e');
    }
    try {
      await loadBillingHistory();
    } catch (e) {
      AppLogger.apiError('loadBillingHistory: $e');
    }
    try {
      await loadPlanUsage();
    } catch (e) {
      AppLogger.apiError('loadPlanUsage: $e');
    }
    try {
      await checkPendingConfirmation();
    } catch (e) {
      AppLogger.apiError('checkPendingConfirmation: $e');
    }
  }

  Future<void> checkPendingConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('pending_subscription_confirmation');
      final hidden = prefs.getBool('pending_banner_hidden') ?? false;
      if (data != null) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _pendingConfirmation = decoded;
          _hidePendingBanner = hidden;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _pendingConfirmation = null;
        });
      }
    } catch (e) {
      AppLogger.apiError('Failed to read pending confirmation: $e');
    }
  }

  Future<void> loadAvailablePlans() async {
    try {
      _availablePlans = await _servicePackageApi.fetchPackages();
      _safeSetState();
    } catch (e) {
      AppLogger.apiError('Error loading available plans: $e');
    }
  }

  Future<void> loadInvoices() async {
    final prov = context.read<SubscriptionsProvider>();
    try {
      _invoices = await prov.fetchInvoices();
    } catch (e) {
      AppLogger.apiError('loadInvoices failed: $e');
      _invoices = [];
    }
    _safeSetState();
  }

  Future<void> loadBillingHistory() async {
    final prov = context.read<SubscriptionsProvider>();
    try {
      _billingHistory = await prov.fetchBillingHistory();
    } catch (e) {
      AppLogger.apiError('loadBillingHistory failed: $e');
      _billingHistory = [];
    }
    _safeSetState();
  }

  Future<void> dismissPendingBanner() async {
    _hidePendingBanner = true;
    _safeSetState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_banner_hidden', true);
    } catch (_) {}
  }

  Future<void> loadPlanUsage() async {
    final prov = context.read<SubscriptionsProvider>();
    _planUsage = await prov.fetchPlanUsage();
    // Debug log the received data
    AppLogger.api('Plan usage loaded: $_planUsage');
    _safeSetState();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> showPlanDetails(BuildContext context, String planCode) async {
    final prov = context.read<SubscriptionsProvider>();
    final planDetails = await prov.fetchPlanDetails(planCode);

    if (planDetails != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(planDetails['name'] ?? 'Chi tiết gói'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildPlanDetailsContent(planDetails),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  List<Widget> _buildPlanDetailsContent(Map<String, dynamic> planDetails) {
    final widgets = <Widget>[];

    if (planDetails['description'] != null) {
      widgets.add(Text('Mô tả: ${planDetails['description']}'));
      widgets.add(const SizedBox(height: 8));
    }

    widgets.addAll([
      Text(
        'Giá: ${planDetails['price'] ?? 0} ${planDetails['currency'] ?? 'VND'}',
      ),
      Text('Chu kỳ: ${planDetails['interval'] ?? 'month'}'),
      const SizedBox(height: 8),
      const Text('Giới hạn:', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('• Camera tối đa: ${planDetails['camera_limit'] ?? 'N/A'}'),
    ]);

    if (planDetails['permissions'] != null) {
      final permissions = planDetails['permissions'];
      widgets.addAll([
        Text('• Số camera: ${permissions['max_cameras'] ?? 'N/A'}'),
        Text('• Số người dùng: ${permissions['max_users'] ?? 'N/A'}'),
        Text('• Lưu trữ (ngày): ${permissions['storage_days'] ?? 'N/A'}'),
      ]);
    }

    if (planDetails['features'] != null) {
      widgets.addAll([
        const SizedBox(height: 8),
        const Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._buildFeaturesList(planDetails['features']),
      ]);
    }

    return widgets;
  }

  List<Widget> _buildFeaturesList(List<dynamic>? features) {
    return features?.map((feature) => Text('• $feature')).toList() ?? [];
  }

  Future<void> showUpgradeDialog(
    BuildContext context,
    SubscriptionModel subscription,
    SubscriptionsProvider prov,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nâng cấp gói dịch vụ'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plan selection logic would go here
              Text('Chọn gói nâng cấp:'),
              // ... existing upgrade dialog content
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Nâng cấp'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleUpgradeWithProration(
    String subscriptionId,
    String newPlanCode,
    Map<String, dynamic>? prorationInfo,
    BuildContext context,
  ) async {
    final prov = context.read<SubscriptionsProvider>();
    final result = await prov.upgradeSubscriptionWithProration(
      subscriptionId,
      newPlanCode,
    );

    if (context.mounted) {
      final success = result['success'] as bool? ?? false;
      showSnackBar(
        context,
        success
            ? 'Gói đã được nâng cấp'
            : 'Nâng cấp gói thất bại: ${result['error'] ?? ''}',
      );
    }
  }

  Future<void> showCancelSubscriptionModal(
    BuildContext context,
    SubscriptionModel subscription,
    SubscriptionsProvider prov,
  ) async {
    final effectiveDate = subscription.currentPeriodEnd.toLocal();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy đăng ký — hạ về Basic vào cuối chu kỳ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn có chắc chắn muốn hủy đăng ký? Gói sẽ hạ về Basic vào ngày ${effectiveDate.toString().split(' ')[0]}.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn sẽ mất quyền truy cập vào các tính năng nâng cao.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform cancel action
    final ok = await prov.cancelSubscription(subscription.id);
    if (!context.mounted) return;

    if (ok) {
      // Refresh central store and show undo snackbar
      try {
        SubscriptionStore.instance.refresh();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã hủy gói dịch vụ thành công'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              // Implement undo logic if needed
            },
          ),
        ),
      );
    } else {
      showSnackBar(context, 'Hủy gói thất bại');
    }
  }

  Future<void> showChangePlanModal(
    BuildContext context,
    SubscriptionModel subscription,
    SubscriptionsProvider prov,
  ) async {
    // Fetch current plan details to compute downgrade candidates
    final currentPlan = await prov.fetchPlanDetails(subscription.planCode);
    final candidates = _availablePlans.where((p) {
      try {
        final curPrice = (currentPlan?['price'] as num?)?.toDouble() ?? 0.0;
        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
        return price < curPrice;
      } catch (_) {
        return false;
      }
    }).toList();

    if (candidates.isEmpty) {
      if (context.mounted) {
        showSnackBar(context, 'Không có gói thấp hơn để hạ cấp');
      }
      return;
    }

    String? selectedPlanCode;
    bool applyAtPeriodEnd = true;

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thay đổi gói dịch vụ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chọn gói mới:'),
                const SizedBox(height: 16),
                ...candidates.map(
                  (plan) => RadioListTile<String>(
                    title: Text(plan['name'] ?? 'Gói ${plan['code']}'),
                    subtitle: Text('${plan['price'] ?? 0}₫'),
                    value: plan['code'].toString(),
                    groupValue: selectedPlanCode,
                    onChanged: (value) {
                      setState(() => selectedPlanCode = value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    'Áp dụng ngay khi kết thúc chu kỳ hiện tại',
                  ),
                  value: applyAtPeriodEnd,
                  onChanged: (value) {
                    setState(() => applyAtPeriodEnd = value ?? true);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: selectedPlanCode != null
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Thay đổi'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedPlanCode == null) return;

    // Analytics: user confirmed change plan choice
    try {
      Analytics.logEvent('change_plan_chosen', {
        'subscription_id': subscription.id,
        'target_plan': selectedPlanCode,
        'apply_at_period_end': applyAtPeriodEnd,
      });
    } catch (_) {}

    // Perform action depending on selected timing
    bool ok = false;
    String message = 'Đã thực hiện thay đổi gói';

    if (applyAtPeriodEnd) {
      // Use schedule downgrade endpoint on subscription-side ServicePackageApi via controller
      final controller = sub_ctrl.SubscriptionController(
        sub_api.ServicePackageApi(),
      );
      final res = await controller.scheduleDowngrade(selectedPlanCode!);
      if (res['status'] != 'error') {
        ok = true;
        message = res['message'] ?? 'Lên lịch hạ cấp thành công';
        try {
          await checkPendingConfirmation();
        } catch (_) {}
      } else {
        ok = false;
        message = res['message'] ?? 'Lên lịch hạ cấp thất bại';
      }
    } else {
      ok = await prov.downgradeSubscription(subscription.id, selectedPlanCode!);
      message = ok ? 'Đã hạ cấp ngay' : 'Hạ cấp thất bại';
      if (ok) {
        try {
          SubscriptionStore.instance.refresh();
        } catch (_) {}
      }
    }

    if (!context.mounted) return;

    if (ok) {
      try {
        SubscriptionStore.instance.refresh();
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      showSnackBar(context, message);
    }
  }

  Future<void> handleSubscriptionAction(
    BuildContext context,
    Future<bool> Function() action,
    String failureMessage,
    String successMessage,
  ) async {
    final ok = await action();
    if (context.mounted) {
      showSnackBar(context, ok ? successMessage : failureMessage);
    }
  }
}
