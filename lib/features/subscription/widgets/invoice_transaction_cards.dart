import 'package:flutter/material.dart';

class InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const InvoiceCard({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
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
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${totalAmount.toString()} $currency'),
            if (issuedAt != null) Text('Ngày tạo: ${_formatDate(issuedAt)}'),
            if (paidAt != null) Text('Ngày thanh toán: ${_formatDate(paidAt)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isPaid = status == 'paid';
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

  String _formatDate(String dateString) {
    try {
      return DateTime.parse(dateString).toLocal().toString().split(' ')[0];
    } catch (e) {
      return dateString;
    }
  }
}

class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
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
                _buildTransactionTypeBadge(type),
              ],
            ),
            const SizedBox(height: 8),
            Text('Số tiền: ${amount.toString()} $currency'),
            Text('Loại: ${_getTransactionTypeText(type)}'),
            if (transactionDate != null)
              Text('Ngày: ${_formatDate(transactionDate)}'),
            if (status != null)
              Text('Trạng thái: ${_getTransactionStatusText(status)}'),
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
