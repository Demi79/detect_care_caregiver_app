import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import '../constants/plan_constants.dart';
import '../controllers/subscription_controller.dart';
import '../data/service_package_api.dart';
import '../models/plan.dart';

/// Shared subscription loading logic that handles plan fetching,
/// current subscription resolution, and exposes useful bits of state
/// (plans, selected index, active subscription id, etc.) to consumers.
mixin SubscriptionLogic<T extends StatefulWidget> on State<T> {
  late final SubscriptionController _controller;

  List<Plan> _plans = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  String? _error;
  int? _selectedPlanIndex;
  String? _activeSubscriptionId;

  // Public getters for UI layers.
  List<Plan> get plans => _plans;
  Map<String, dynamic>? get subscription => _subscription;
  bool get loading => _loading;
  String? get error => _error;
  int? get selectedPlanIndex => _selectedPlanIndex;
  String? get activeSubscriptionId => _activeSubscriptionId;
  bool get hasActiveSubscription => _activeSubscriptionId != null;

  // Limited setters so states can opt-in to direct mutations when required.
  set plans(List<Plan> value) => _plans = value;
  set subscription(Map<String, dynamic>? value) => _subscription = value;
  set loading(bool value) => _loading = value;
  set error(String? value) => _error = value;
  set selectedPlanIndex(int? value) => _selectedPlanIndex = value;
  set activeSubscriptionId(String? value) => _activeSubscriptionId = value;

  SubscriptionController get subscriptionController => _controller;

  /// Override to opt-out of fetching the current plan (e.g. when the user
  /// has not signed in and no token is available).
  @protected
  Future<bool> canFetchCurrentPlan() async => true;

  @override
  void initState() {
    super.initState();
    _controller = SubscriptionController(ServicePackageApi());
  }

  /// Fetch plans + current subscription with consistent loading/error handling.
  Future<void> initializeSubscriptionData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _fetchPlans();
      if (await canFetchCurrentPlan()) {
        await _fetchCurrentSubscription();
      }
    } catch (e, s) {
      AppLogger.apiError('[SubscriptionLogic] Failed to init: $e\n$s');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Re-fetch only the plans list.
  Future<void> refreshPlans() async {
    try {
      await _fetchPlans();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
      rethrow;
    }
  }

  /// Re-fetch only the current subscription payload.
  Future<void> refreshCurrentPlan({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await _fetchCurrentSubscription();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
      rethrow;
    } finally {
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchPlans() async {
    AppLogger.api('[SubscriptionLogic] GET ${AppConfig.apiBaseUrl}/plan');
    final fetchedPlans = await _controller.fetchPlans();
    if (!mounted) return;
    setState(() {
      _plans = fetchedPlans;
    });
  }

  Future<void> _fetchCurrentSubscription() async {
    try {
      AppLogger.api(
        '[SubscriptionLogic] GET ${AppConfig.apiBaseUrl}/subscriptions/me',
      );
      final response = await _controller.getCurrentSubscription();
      AppLogger.api('[SubscriptionLogic] Current plan response: $response');

      final planObj = response?['plan'] as Plan?;
      final planRaw = (response?['plan_raw'] as Map?)?.cast<String, dynamic>();
      final subscriptionRow = (response?['subscription'] as Map?)
          ?.cast<String, dynamic>();

      _activeSubscriptionId = _extractActiveSubscriptionId(subscriptionRow);

      final resolvedPlanCode = _resolvePlanCode(
        planObj: planObj,
        planRaw: planRaw,
        subscriptionRow: subscriptionRow,
      );

      AppLogger.api(
        '[SubscriptionLogic] Resolved plan code: $resolvedPlanCode',
      );

      if (resolvedPlanCode != null) {
        _selectResolvedPlan(
          resolvedPlanCode: resolvedPlanCode,
          planRaw: planRaw,
          subscriptionRow: subscriptionRow,
        );
      } else {
        _selectFallbackFreePlan(planRaw);
      }
    } catch (e, s) {
      AppLogger.apiError(
        '[SubscriptionLogic] _fetchCurrentSubscription error: $e\n$s',
      );
    }
  }

  String? _extractActiveSubscriptionId(Map<String, dynamic>? subscriptionRow) {
    final rawId = subscriptionRow != null
        ? (subscriptionRow['subscription_id'] ?? subscriptionRow['id'])
        : null;
    return rawId?.toString();
  }

  String? _resolvePlanCode({
    Plan? planObj,
    Map<String, dynamic>? planRaw,
    Map<String, dynamic>? subscriptionRow,
  }) {
    return planObj?.code ??
        planRaw?['code']?.toString() ??
        subscriptionRow?['plan_code']?.toString() ??
        subscriptionRow?['code']?.toString();
  }

  void _selectResolvedPlan({
    required String resolvedPlanCode,
    Map<String, dynamic>? planRaw,
    Map<String, dynamic>? subscriptionRow,
  }) {
    final availablePlans = _plans.isNotEmpty
        ? _plans
        : PlanConstants.fallbackPlans;

    final idx = _resolvePlanIndex(
      availablePlans: availablePlans,
      resolvedPlanCode: resolvedPlanCode,
      planRaw: planRaw,
      subscriptionRow: subscriptionRow,
    );

    if (!mounted) return;
    setState(() {
      if (_plans.isEmpty) {
        _plans = List<Plan>.from(availablePlans);
      }
      _selectedPlanIndex = idx >= 0 ? idx : null;
      _subscription = subscriptionRow ?? planRaw ?? {'code': resolvedPlanCode};
    });

    AppLogger.api(
      '[SubscriptionLogic] Plan index resolved: $idx (code=$resolvedPlanCode)',
    );
  }

  void _selectFallbackFreePlan(Map<String, dynamic>? planRaw) {
    AppLogger.api(
      '[SubscriptionLogic] No plan code resolved. Attempting free plan auto-selection.',
    );
    final availablePlans = _plans.isNotEmpty
        ? _plans
        : PlanConstants.fallbackPlans;
    final freePlanIdx = availablePlans.indexWhere((p) => p.price == 0);
    if (freePlanIdx == -1 || !mounted) return;

    setState(() {
      if (_plans.isEmpty) {
        _plans = List<Plan>.from(availablePlans);
      }
      _selectedPlanIndex = freePlanIdx >= 0 ? freePlanIdx : null;
      _subscription = planRaw;
    });
  }

  int _resolvePlanIndex({
    required List<Plan> availablePlans,
    required String resolvedPlanCode,
    Map<String, dynamic>? planRaw,
    Map<String, dynamic>? subscriptionRow,
  }) {
    int idx = availablePlans.indexWhere((p) => p.code == resolvedPlanCode);

    if (idx != -1) return idx;

    final candidateIds = <String>{
      for (final value in [
        planRaw?['id'],
        planRaw?['plan_id'],
        subscriptionRow?['plan_id'],
        subscriptionRow?['planId'],
        subscriptionRow?['id'],
      ])
        if (value != null && value.toString().isNotEmpty) value.toString(),
    };

    if (candidateIds.isNotEmpty) {
      idx = availablePlans.indexWhere((p) => candidateIds.contains(p.code));
      if (idx != -1) return idx;
    }

    final rawPrice = _tryParseInt(
      planRaw?['price'] ?? subscriptionRow?['price'],
    );
    if (rawPrice != null) {
      idx = availablePlans.indexWhere((p) => p.price == rawPrice);
      if (idx != -1) return idx;
    }

    final rawName =
        (planRaw?['name'] ??
                subscriptionRow?['plan_name'] ??
                subscriptionRow?['name'])
            ?.toString();
    if (rawName != null && rawName.isNotEmpty) {
      final lower = rawName.toLowerCase();
      idx = availablePlans.indexWhere((p) => p.name.toLowerCase() == lower);
    }

    return idx;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Helper for screens that want to manually select a plan index.
  void selectPlan(int index) {
    if (!mounted) return;
    setState(() => _selectedPlanIndex = index);
  }

  /// Convenience method mirroring old API.
  Future<void> refreshSubscriptionData() => initializeSubscriptionData();
}
