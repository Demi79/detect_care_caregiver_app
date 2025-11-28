import 'package:flutter/material.dart';

class PaymentHistoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> billingHistory;
  final Future<void> Function() onRefresh;

  const PaymentHistoryTab({
    super.key,
    required this.invoices,
    required this.billingHistory,
    required this.onRefresh,
  });

  @override
  State<PaymentHistoryTab> createState() => _PaymentHistoryTabState();
}

class _PaymentHistoryTabState extends State<PaymentHistoryTab> {
  // Constants for invoice statuses
  static const String _invoiceStatusPaid = 'paid';

  List<Map<String, dynamic>> get _combinedHistory {
    final combinedHistory = [
      ...widget.invoices.map(
        (invoice) => {
          ...invoice,
          'type': 'invoice',
          'date': invoice['issued_at'] ?? invoice['created_at'],
        },
      ),
      ...widget.billingHistory.map(
        (transaction) => {
          ...transaction,
          'type': 'transaction',
          'date': transaction['transaction_date'] ?? transaction['created_at'],
        },
      ),
    ];

    // Sort by date (most recent first)
    combinedHistory.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return DateTime.parse(dateB).compareTo(DateTime.parse(dateA));
    });

    return combinedHistory;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: _combinedHistory.isEmpty
          ? const Center(child: Text('Chưa có lịch sử thanh toán'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _combinedHistory.length,
              itemBuilder: (context, index) {
                final item = _combinedHistory[index];
                return item['type'] == 'invoice'
                    ? _buildInvoiceCard(item)
                    : _buildTransactionCard(item);
              },
            ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hóa đơn #${invoice['id'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${totalAmount.toString()} $currency'),
            if (issuedAt != null)
              Text('Ngày phát hành: ${_formatDate(issuedAt)}'),
            if (paidAt != null) Text('Ngày thanh toán: ${_formatDate(paidAt)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isPaid = status == _invoiceStatusPaid;
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

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Giao dịch #${transaction['id'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildTransactionTypeBadge(type),
              ],
            ),
            const SizedBox(height: 8),
            Text('Số tiền: ${amount.toString()} $currency'),
            Text('Trạng thái: ${_getTransactionStatusText(status)}'),
            if (transactionDate != null)
              Text('Ngày: ${_formatDate(transactionDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeBadge(String type) {
    final color = _getTransactionTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getTransactionTypeText(type),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Color _getTransactionTypeColor(String type) {
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

  String _getTransactionTypeText(String type) {
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

  String _getTransactionStatusText(String status) {
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

  String _formatDate(String dateString) {
    try {
      return DateTime.parse(dateString).toLocal().toString().split(' ')[0];
    } catch (e) {
      return dateString;
    }
  }
}
