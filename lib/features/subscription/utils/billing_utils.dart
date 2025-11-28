import 'package:flutter/material.dart';

/// Utility class for billing-related UI components and formatting
class BillingUtils {
  // Constants for invoice statuses
  static const String invoiceStatusPaid = 'paid';

  /// Builds an invoice card widget
  static Widget buildInvoiceCard(Map<String, dynamic> invoice) {
    final totalAmount = invoice['total_amount'] ?? 0;
    final currency = invoice['currency'] ?? 'VND';
    final status = invoice['status'] ?? 'unknown';
    final issuedAt = invoice['issued_at'];
    final paidAt = invoice['paid_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hóa đơn #${invoice['id']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${totalAmount.toString()} $currency'),
            if (issuedAt != null) Text('Ngày tạo: ${formatDate(issuedAt)}'),
            if (paidAt != null) Text('Ngày thanh toán: ${formatDate(paidAt)}'),
          ],
        ),
      ),
    );
  }

  /// Builds a status badge widget for invoices
  static Widget buildStatusBadge(String status) {
    final isPaid = status == invoiceStatusPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  /// Builds a transaction card widget
  static Widget buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] ?? 0;
    final currency = transaction['currency'] ?? 'VND';
    final type = transaction['transaction_type'] ?? 'unknown';
    final status = transaction['status'] ?? 'unknown';
    final transactionDate =
        transaction['transaction_date'] ?? transaction['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giao dịch #${transaction['id']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                buildTransactionTypeBadge(type),
              ],
            ),
            const SizedBox(height: 8),
            Text('Số tiền: ${amount.toString()} $currency'),
            Text('Loại: ${getTransactionTypeText(type)}'),
            if (transactionDate != null)
              Text('Ngày: ${formatDate(transactionDate)}'),
            if (status != null)
              Text('Trạng thái: ${getTransactionStatusText(status)}'),
          ],
        ),
      ),
    );
  }

  /// Builds a transaction type badge widget
  static Widget buildTransactionTypeBadge(String type) {
    final color = getTransactionTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        getTransactionTypeText(type),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  /// Gets the color for a transaction type
  static Color getTransactionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'charge':
        return Colors.green;
      case 'refund':
        return Colors.blue;
      case 'adjustment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Gets the display text for a transaction type
  static String getTransactionTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return 'Thanh toán';
      case 'charge':
        return 'Phí';
      case 'refund':
        return 'Hoàn tiền';
      case 'adjustment':
        return 'Điều chỉnh';
      default:
        return type;
    }
  }

  /// Gets the display text for a transaction status
  static String getTransactionStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return 'Hoàn thành';
      case 'pending':
        return 'Đang xử lý';
      case 'failed':
        return 'Thất bại';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  /// Formats a date string to a readable format
  static String formatDate(String dateString) {
    try {
      return DateTime.parse(dateString).toLocal().toString().split(' ')[0];
    } catch (e) {
      return dateString;
    }
  }
}
