import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceListItem extends StatelessWidget {
  const InvoiceListItem({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final issued = dateFormat.format(invoice.issuedAt.toLocal());

    String statusLabel(String status) {
      // prefer explicit display text from API when available
      if (invoice.statusDisplay != null && invoice.statusDisplay!.isNotEmpty) {
        return invoice.statusDisplay!;
      }
      switch (status.toLowerCase()) {
        case 'paid':
        case 'success':
          return L10nVi.statusPaid;
        case 'failed':
        case 'error':
          return L10nVi.statusFailed;
        default:
          return status[0].toUpperCase() + status.substring(1);
      }
    }

    Color statusColor(String s) {
      final st = s.toLowerCase();
      if (st.contains('paid') ||
          st.contains('success') ||
          st.contains('đã thanh toán')) {
        return Colors.green;
      }
      if (st.contains('failed') ||
          st.contains('error') ||
          st.contains('thất bại')) {
        return Colors.red;
      }
      return Colors.orange;
    }

    IconData statusIcon(String s) {
      final st = s.toLowerCase();
      if (st.contains('paid') ||
          st.contains('success') ||
          st.contains('đã thanh toán')) {
        return Icons.check_circle;
      }
      if (st.contains('failed') ||
          st.contains('error') ||
          st.contains('thất bại')) {
        return Icons.error;
      }
      return Icons.receipt;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50.withAlpha((0.3 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.02 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200.withAlpha((0.5 * 255).round()),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: statusColor(
            statusLabel(invoice.status),
          ).withAlpha((0.1 * 255).round()),
          highlightColor: statusColor(
            statusLabel(invoice.status),
          ).withAlpha((0.05 * 255).round()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        statusColor(
                          statusLabel(invoice.status),
                        ).withAlpha((0.15 * 255).round()),
                        statusColor(
                          statusLabel(invoice.status),
                        ).withAlpha((0.08 * 255).round()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: statusColor(
                        statusLabel(invoice.status),
                      ).withAlpha((0.2 * 255).round()),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    statusIcon(statusLabel(invoice.status)),
                    color: statusColor(statusLabel(invoice.status)),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nVi.invoiceDisplayTitle(invoice.id),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${L10nVi.issuedDate}: $issued',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (invoice.planName != null &&
                          invoice.planName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${L10nVi.plan}: ${invoice.planName}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(invoice.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor(
                            statusLabel(invoice.status),
                          ).withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor(
                              statusLabel(invoice.status),
                            ).withAlpha((0.3 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusLabel(invoice.status),
                          style: TextStyle(
                            color: statusColor(statusLabel(invoice.status)),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
