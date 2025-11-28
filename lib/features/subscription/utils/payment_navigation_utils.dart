import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import 'amount_parser.dart';

bool flagIndicatesPayment(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    const truthy = {
      'true',
      '1',
      'yes',
      'y',
      'required',
      'requires_payment',
      'require_payment',
      'need_payment',
      'needs_payment',
      'pending',
      'pending_payment',
      'awaiting_payment',
      'payment_pending',
      'pending_proration',
      'pending_proration_payment',
      'requires_action',
      'requires_payment_method',
    };
    if (truthy.contains(normalized)) return true;
    final mentionsPayment =
        normalized.contains('payment') ||
        normalized.contains('pay') ||
        normalized.contains('thanh toán') ||
        normalized.contains('thanh toan');
    final negated =
        normalized.contains('không') ||
        normalized.contains('khong') ||
        normalized.contains('no ');
    return mentionsPayment && !negated;
  }
  return false;
}

bool statusIndicatesPayment(String? status) {
  if (status == null) return false;
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  const paymentStatuses = {
    'requires_payment',
    'pending_payment',
    'awaiting_payment',
    'payment_pending',
    'pending_proration_payment',
    'pending_proration',
    'requires_action',
    'requires_payment_method',
    'pending_invoice',
    'awaiting_proration',
  };
  if (paymentStatuses.contains(normalized)) return true;
  final mentionsPayment =
      normalized.contains('payment') ||
      normalized.contains('thanh toán') ||
      normalized.contains('thanh toan');
  final negated =
      normalized.contains('no_payment') ||
      normalized.contains('không') ||
      normalized.contains('khong');
  return mentionsPayment && !negated;
}

bool messageSuggestsPayment(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  final hasKeyword =
      normalized.contains('thanh toán') ||
      normalized.contains('thanh toan') ||
      normalized.contains('payment') ||
      normalized.contains('pay');
  if (!hasKeyword) return false;
  final negated =
      normalized.contains('không cần') ||
      normalized.contains('khong can') ||
      normalized.contains('không phải') ||
      normalized.contains('khong phai') ||
      normalized.contains('không phải thanh toán') ||
      normalized.contains('khong phai thanh toan') ||
      normalized.contains('không cần thanh toán') ||
      normalized.contains('khong can thanh toan') ||
      normalized.contains('no additional payment') ||
      normalized.contains('no need to pay') ||
      normalized.contains('no payment required');
  return !negated;
}

int? paymentAmountFromText(String? message) {
  if (!messageSuggestsPayment(message)) return null;
  return parseAmountFlexible(message);
}

bool shouldOpenPayment(Map<String, dynamic> r) {
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

bool shouldNavigateToPayment(
  Map<String, dynamic> r, {
  int? totalPayable,
  int? prorationAmount,
  dynamic tx,
}) {
  final bool needs = shouldOpenPayment(r);
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
    '[UpgradePlan][DECIDE] needsPayment=$needs '
    'hasAmount=${(total > 0) || (pror > 0)} totalPayable=$total proration=$pror '
    'hasTx=${txVal != null} tx=$txVal forceOpen=$forceOpen keys=${r.keys.toList()}',
  );

  return needs || forceOpen;
}
