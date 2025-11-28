import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class Invoice {
  final String id;
  final String userId;
  final String subscriptionId;
  final int totalAmount;
  final String currency;
  final List<Map<String, dynamic>> lineItems; // snapshot of items
  final DateTime issuedAt;
  final DateTime? paidAt;
  final String status; // issued, paid, failed
  final String? statusDisplay;
  final int? taxAmount;
  final double? taxRate;
  final String? description;
  final String? planName;
  final String? invoiceUrl;

  Invoice({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    required this.totalAmount,
    required this.currency,
    required this.lineItems,
    required this.issuedAt,
    this.paidAt,
    required this.status,
    this.statusDisplay,
    this.description,
    this.planName,
    this.invoiceUrl,
    this.taxAmount,
    this.taxRate,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse ints and doubles from various keys
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) {
        return int.tryParse(v) ?? (double.tryParse(v)?.round() ?? 0);
      }
      return 0;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (e) {
          AppLogger.w('Failed to parse date string: $v, using current time', e);
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    // Normalize possible keys from transactions or legacy invoice shapes
    final id = json['id']?.toString() ?? '';
    final userId =
        json['user_id']?.toString() ??
        json['customer_id']?.toString() ??
        ((json['subscription'] is Map &&
                json['subscription']['user_id'] != null)
            ? json['subscription']['user_id'].toString()
            : '');

    final subscriptionId =
        json['subscription_id']?.toString() ??
        ((json['subscription'] is Map && json['subscription']['id'] != null)
            ? json['subscription']['id'].toString()
            : '');

    final totalAmount = parseInt(
      json['total_amount'] ?? json['amount'] ?? json['total'],
    );
    final currency = json['currency']?.toString() ?? 'VND';

    List<Map<String, dynamic>> lineItems = [];
    try {
      final items =
          json['line_items'] ?? json['items'] ?? json['items_snapshot'];
      if (items is List) lineItems = List<Map<String, dynamic>>.from(items);
    } catch (e) {
      AppLogger.w('Failed to parse line items from invoice JSON', e);
      lineItems = [];
    }

    final issuedAt = parseDate(
      json['issued_at'] ?? json['created_at'] ?? json['createdAt'],
    );
    final paidAt = json['paid_at'] != null
        ? parseDate(json['paid_at'])
        : (json['paidAt'] != null ? parseDate(json['paidAt']) : null);
    final status = json['status']?.toString() ?? 'issued';

    final taxAmount = json['tax_amount'] != null
        ? parseInt(json['tax_amount'])
        : (json['tax'] != null ? parseInt(json['tax']) : null);
    final taxRate = json['tax_rate'] != null
        ? parseDouble(json['tax_rate'])
        : null;

    final description =
        json['description']?.toString() ?? json['desc']?.toString();
    final planName =
        json['plan_name']?.toString() ??
        json['planName']?.toString() ??
        json['plan']?.toString();
    final invoiceUrl =
        json['invoice_url']?.toString() ?? json['invoiceUrl']?.toString();
    final statusDisplay =
        json['status_display']?.toString() ?? json['statusDisplay']?.toString();

    return Invoice(
      id: id,
      userId: userId,
      subscriptionId: subscriptionId,
      totalAmount: totalAmount,
      currency: currency,
      lineItems: lineItems,
      issuedAt: issuedAt,
      paidAt: paidAt,
      status: status,
      statusDisplay: statusDisplay,
      taxAmount: taxAmount,
      taxRate: taxRate,
      description: description,
      planName: planName,
      invoiceUrl: invoiceUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_id': subscriptionId,
      'total_amount': totalAmount,
      'currency': currency,
      'line_items': lineItems,
      'issued_at': issuedAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'status': status,
      if (statusDisplay != null) 'status_display': statusDisplay,
      if (description != null) 'description': description,
      if (planName != null) 'plan_name': planName,
      if (invoiceUrl != null) 'invoice_url': invoiceUrl,
      if (taxAmount != null) 'tax_amount': taxAmount,
      if (taxRate != null) 'tax_rate': taxRate,
    };
  }
}
