class SubscriptionModel {
  final String id;
  final String accountId;
  final String planCode;
  final String planVersion;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final String renewalMode; // auto, manual
  final int camerasUsed;
  final int sitesUsed;
  final int seatsUsed;
  final double storageUsedGb;
  final bool cancelAtPeriodEnd;
  final Map<String, dynamic>? nextPlanChange;
  final String? paymentMethodId;
  final String invoicingMode; // prepaid, postpaid
  final Map<String, dynamic>? meta;
  final String country;
  final String currency;
  final String planName;
  final DateTime? nextBillingAt;
  final String? paymentMethod;

  SubscriptionModel({
    required this.id,
    required this.accountId,
    required this.planCode,
    required this.planVersion,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.renewalMode,
    this.camerasUsed = 0,
    this.sitesUsed = 0,
    this.seatsUsed = 0,
    this.storageUsedGb = 0.0,
    this.cancelAtPeriodEnd = false,
    this.nextPlanChange,
    this.paymentMethodId,
    required this.invoicingMode,
    this.meta,
    required this.country,
    required this.currency,
    required this.planName,
    this.nextBillingAt,
    this.paymentMethod,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }

    return SubscriptionModel(
      id: json['id']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? '',
      planCode:
          json['plan_code']?.toString() ??
          json['code']?.toString() ??
          json['plan']?.toString() ??
          '',
      planVersion: json['plan_version']?.toString() ?? '',
      planName:
          json['plan_name']?.toString() ??
          json['plan_display']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'active',
      currentPeriodStart:
          parseDate(json['current_period_start']?.toString()) ?? DateTime.now(),
      currentPeriodEnd:
          parseDate(json['current_period_end']?.toString()) ?? DateTime.now(),
      renewalMode: json['renewal_mode']?.toString() ?? 'auto',
      camerasUsed: json['cameras_used'] ?? 0,
      sitesUsed: json['sites_used'] ?? 0,
      seatsUsed: json['seats_used'] ?? 0,
      storageUsedGb: (json['storage_used_gb'] as num?)?.toDouble() ?? 0.0,
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
      nextPlanChange: json['next_plan_change'] as Map<String, dynamic>?,
      paymentMethodId: json['payment_method_id']?.toString(),
      invoicingMode: json['invoicing_mode']?.toString() ?? 'prepaid',
      meta: json['meta'] as Map<String, dynamic>?,
      country: json['country']?.toString() ?? 'Vietnam',
      currency: json['currency']?.toString() ?? 'VND',
      nextBillingAt: parseDate(json['next_billing_at']?.toString()),
      paymentMethod: json['payment_method']?.toString(),
    );
  }
}
