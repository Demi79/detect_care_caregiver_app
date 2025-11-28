import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import '../data/service_package_api.dart';
import '../models/plan.dart';

class SubscriptionController {
  final ServicePackageApi api;
  SubscriptionController(this.api);

  Future<List<Plan>> fetchPlans() async {
    AppLogger.api('[SubscriptionController] fetchPlans called');
    final res = await api.fetchPlans();
    AppLogger.api(
      '[SubscriptionController] fetchPlans result count: ${res.length}',
    );
    return res;
  }

  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    AppLogger.api('[SubscriptionController] getCurrentSubscription called');
    final res = await api.getCurrentSubscription();
    AppLogger.api(
      '[SubscriptionController] getCurrentSubscription raw result: $res',
    );
    if (res == null) return null;

    // Expect res to be normalized by ServicePackageApi: {'plan': Map?|null, 'subscription': Map?|null}
    final planRaw = (res['plan'] as Map?)?.cast<String, dynamic>();
    final subscriptionRaw = (res['subscription'] as Map?)
        ?.cast<String, dynamic>();

    Plan? planObj;
    try {
      if (planRaw != null) planObj = Plan.fromJson(planRaw);
    } catch (e) {
      AppLogger.apiError('[SubscriptionController] Failed to parse plan: $e');
    }

    // Return normalized result where 'plan' is a Plan model (or null),
    // and 'plan_raw'/'subscription' keep the original maps for callers that
    // expect raw data.
    return {
      'plan': planObj,
      'plan_raw': planRaw,
      'subscription': subscriptionRaw,
    };
  }

  // Backwards-compatible alias for older callers.
  Future<Map<String, dynamic>?> getCurrentPlan() async =>
      await getCurrentSubscription();

  Future<Map<String, dynamic>?> getCurrentQuota() async {
    AppLogger.api('[SubscriptionController] getCurrentQuota called');
    final res = await api.getCurrentQuota();
    AppLogger.api('[SubscriptionController] getCurrentQuota result: $res');
    return res;
  }

  Future<Map<String, dynamic>> registerFreePlan(String planCode) async {
    AppLogger.api(
      '[SubscriptionController] registerFreePlan called: planCode=$planCode',
    );
    final res = await api.registerFreePlan(planCode);
    AppLogger.api('[SubscriptionController] registerFreePlan response: $res');
    return res;
  }

  Future<Map<String, dynamic>> upgradeSubscription(
    String subscriptionId,
    String targetPlanCode, {
    double? prorationAmount,
    bool? effectiveImmediately,
    String? idempotencyKey,
  }) async {
    AppLogger.api(
      '[SubscriptionController] upgradeSubscription called: subscriptionId=$subscriptionId targetPlan=$targetPlanCode idempotency=$idempotencyKey',
    );
    final res = await api.upgradeSubscription(
      subscriptionId: subscriptionId,
      targetPlanCode: targetPlanCode,
      prorationAmount: prorationAmount,
      effectiveImmediately: effectiveImmediately,
      idempotencyKey: idempotencyKey,
    );
    AppLogger.api(
      '[SubscriptionController] upgradeSubscription response: $res',
    );
    return res;
  }

  Future<Map<String, dynamic>> scheduleDowngrade(String targetPlanCode) async {
    return await api.scheduleDowngrade(targetPlanCode: targetPlanCode);
  }
}
