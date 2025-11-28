import '../models/plan.dart';

String formatVND(int amount) {
  final s = amount.abs().toString();
  final chars = s.split('').reversed.toList();
  final out = <String>[];
  for (int i = 0; i < chars.length; i++) {
    out.add(chars[i]);
    if ((i + 1) % 3 == 0 && i != chars.length - 1) out.add('.');
  }
  final result = out.reversed.join();
  return '${(amount < 0 ? '-' : '')}$resultđ';
}

int effectiveMonthly(Plan p, int selectedTerm) {
  if (selectedTerm == 6) {
    if (p.code == 'pro') return 564300;
    if (p.code == 'premium') return 1134300;
    return p.price;
  } else if (selectedTerm == 12) {
    if (p.code == 'pro') return 990000;
    if (p.code == 'premium') return 1990000;
    return p.price;
  }
  return p.price;
}

String savingTextFor(Plan p, int selectedTerm) {
  if (selectedTerm == 6) {
    if (p.code == 'pro') {
      final saving = 99000 * 6 - 564300;
      return 'Tiết kiệm ${formatVND(saving)} (-5%)';
    }
    if (p.code == 'premium') {
      final saving = 199000 * 6 - 1134300;
      return 'Tiết kiệm ${formatVND(saving)} (-5%)';
    }
  } else if (selectedTerm == 12) {
    if (p.code == 'pro') {
      final saving = 99000 * 12 - 990000;
      return 'Tiết kiệm ${formatVND(saving)} (~2 tháng miễn phí)';
    }
    if (p.code == 'premium') {
      final saving = 199000 * 12 - 1990000;
      return 'Tiết kiệm ${formatVND(saving)} (~2 tháng miễn phí)';
    }
  }
  return '';
}

String deltaTextFor(
  Plan p,
  Plan? currentPlan,
  int priceToShow,
  int selectedTerm,
) {
  // Deprecated: UI must not self-calculate proration. Server is the single
  // source of truth for proration/total payable amounts. Return empty so
  // the UI won't show an estimated value that may differ from server.
  return '';
}

// Tính toán prorated cost cho upgrade
Map<String, dynamic> calculateProratedUpgrade({
  required Plan currentPlan,
  required Plan targetPlan,
  required DateTime subscriptionEnd,
  required int periodDays, // giả sử 30 cho monthly
}) {
  final now = DateTime.now();
  final remainingDays = subscriptionEnd.difference(now).inDays;
  if (remainingDays <= 0) {
    return {
      'totalToPay': targetPlan.price,
      'credit': 0,
      'charge': targetPlan.price,
      'remainingDays': 0,
    };
  }

  final currentDaily = currentPlan.price / periodDays;
  final targetDaily = targetPlan.price / periodDays;

  final remainingValue = (currentDaily * remainingDays).round();
  final newCost = (targetDaily * remainingDays).round();
  final difference = newCost - remainingValue;

  return {
    'totalToPay': difference > 0 ? difference : 0,
    'credit': remainingValue,
    'charge': newCost,
    'remainingDays': remainingDays,
  };
}

// Tạo line items cho invoice
List<Map<String, dynamic>> createUpgradeLineItems({
  required Plan currentPlan,
  required Plan targetPlan,
  required int credit,
  required int charge,
  required int totalToPay,
}) {
  return [
    {
      'description':
          'Giá gói hiện tại (đã trả) — snapshot: ${formatVND(currentPlan.price)}',
      'type': 'credit',
      'amount': -credit,
    },
    {
      'description':
          'Chi phí nâng cấp (phần còn lại) — snapshot: ${formatVND(targetPlan.price)}',
      'type': 'charge',
      'amount': charge,
    },
    {
      'description': 'Tổng phải trả ngay',
      'type': 'total',
      'amount': totalToPay,
    },
  ];
}
