import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceDetailHeader extends StatelessWidget {
  const InvoiceDetailHeader({
    super.key,
    required this.invoice,
    required this.issued,
    required this.paid,
    required this.statusLabel,
    required this.chipColor,
    required this.onCopy,
  });

  final Invoice invoice;
  final String issued;
  final String paid;
  final String statusLabel;
  final Color chipColor;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(
              label: Text(
                statusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              backgroundColor: chipColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${L10nVi.issuedDate}: $issued',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              tooltip: L10nVi.copiedInvoiceId,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${L10nVi.paidDate}: $paid',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
