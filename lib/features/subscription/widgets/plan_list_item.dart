import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../widgets/plan_card.dart';
import '../widgets/pricing_helpers.dart';

class PlanListItem extends StatelessWidget {
  final Plan plan;
  final int index;
  final int? selectedPlanIndex;
  final Map<String, dynamic>? subscription;
  final int selectedTerm;
  final List<Plan> allPlans;
  final Future<void> Function(Plan plan, int index) onSelectPlan;
  final Future<void> Function(Plan plan) onUpgradePlan;

  const PlanListItem({
    super.key,
    required this.plan,
    required this.index,
    required this.selectedPlanIndex,
    required this.subscription,
    required this.selectedTerm,
    required this.allPlans,
    required this.onSelectPlan,
    required this.onUpgradePlan,
  });

  @override
  Widget build(BuildContext context) {
    // `isSelected` chỉ là trạng thái tạm thời của UI khi user click vào card.
    // Không coi `isSelected` là "gói đang dùng".
    final bool isSelected = selectedPlanIndex == index;

    // Lấy mã plan hiện tại từ subscription (nếu backend trả subscription)
    // Ưu tiên: subscription['plan_code'] -> subscription['code'] -> subscription['plans']['code']
    String? currentCode;
    if (subscription != null) {
      final plansObj = subscription?['plans'];
      final plansCode = (plansObj is Map) ? plansObj['code'] : null;
      currentCode =
          (subscription?['plan_code'] ?? subscription?['code'] ?? plansCode)
              ?.toString();
    }

    // Tìm Plan object tương ứng với currentCode trong allPlans. Nếu không có,
    // fallback sang selectedPlanIndex (chỉ để hiển thị selection tạm thời).
    Plan? currentPlan;
    if (currentCode != null) {
      try {
        currentPlan = allPlans.firstWhere((p) => p.code == currentCode);
      } catch (_) {
        currentPlan = null;
      }
    } else if (selectedPlanIndex != null &&
        selectedPlanIndex! >= 0 &&
        selectedPlanIndex! < allPlans.length) {
      currentPlan = allPlans[selectedPlanIndex!];
    }

    // Tính các quota/thuộc tính hiển thị; chỉ áp dụng extras nếu đây là plan đang dùng thực tế.
    int cameraQuota = plan.cameraQuota;
    int caregiverSeats = plan.caregiverSeats;
    int sites = plan.sites;
    String storageSize = plan.storageSize;

    final bool isCurrentPlan = currentCode != null && currentCode == plan.code;
    if (subscription != null && isCurrentPlan) {
      // Nếu subscription chứa các khóa extras, cộng vào các quota hiển thị
      cameraQuota += (subscription?['extra_camera_quota'] ?? 0) as int;
      caregiverSeats += (subscription?['extra_caregiver_seats'] ?? 0) as int;
      sites += (subscription?['extra_sites'] ?? 0) as int;

      if ((subscription?['extra_storage_gb'] ?? 0) > 0) {
        final extraGb = (subscription?['extra_storage_gb'] ?? 0) as int;
        final match = RegExp(r'^(\d+)GB').firstMatch(storageSize);
        if (match != null) {
          final baseGb = int.tryParse(match.group(1) ?? '') ?? 0;
          storageSize = '${baseGb + extraGb}GB';
        }
      }
    }

    // So sánh chi phí để xác định nâng cấp/hạ cấp
    bool isUpgrade = false;
    bool isDowngrade = false;
    if (currentPlan != null) {
      isUpgrade =
          effectiveMonthly(plan, selectedTerm) >
          effectiveMonthly(currentPlan, selectedTerm);
      isDowngrade =
          effectiveMonthly(plan, selectedTerm) <
          effectiveMonthly(currentPlan, selectedTerm);
    }

    // Quyết định label và trạng thái nút dựa trên plan thực tế (isCurrentPlan)
    String buttonText;
    bool buttonEnabled;
    if (isCurrentPlan) {
      buttonText = 'Đang sử dụng';
      buttonEnabled = false;
    } else if (isUpgrade) {
      buttonText = 'Nâng cấp gói';
      buttonEnabled = true;
    } else if (isDowngrade) {
      buttonText = 'Không thể hạ cấp';
      buttonEnabled = false;
    } else {
      buttonText = 'Chọn gói này';
      buttonEnabled = true;
    }

    final priceToShow = effectiveMonthly(plan, selectedTerm);
    final savingText = savingTextFor(plan, selectedTerm);
    final deltaText = deltaTextFor(
      plan,
      currentPlan,
      priceToShow,
      selectedTerm,
    );

    return PlanCard(
      plan: plan,
      isSelected: isSelected,
      isUpgrade: isUpgrade,
      isDowngrade: isDowngrade,
      cameraQuota: cameraQuota,
      caregiverSeats: caregiverSeats,
      sites: sites,
      storageSize: storageSize,
      buttonText: buttonText,
      buttonEnabled: buttonEnabled,
      price: priceToShow,
      savingText: savingText,
      deltaText: deltaText,
      onPressed: buttonEnabled
          ? () async {
              if (isUpgrade && priceToShow > 0) {
                await onUpgradePlan(plan);
              } else {
                await onSelectPlan(plan, index);
              }
            }
          : null,
    );
  }
}
