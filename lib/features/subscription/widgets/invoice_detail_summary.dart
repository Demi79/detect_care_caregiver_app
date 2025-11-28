import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceDetailSummary extends StatelessWidget {
  const InvoiceDetailSummary({
    super.key,
    required this.invoice,
    required this.paidText,
    required this.totalText,
  });

  final Invoice invoice;
  final String paidText;
  final String totalText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        if (narrow) {
          return Column(
            children: [
              _infoCard(title: L10nVi.paidDate, content: paidText),
              const SizedBox(height: 12),
              _infoCard(title: L10nVi.total, content: totalText),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _infoCard(title: L10nVi.paidDate, content: paidText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(title: L10nVi.total, content: totalText),
            ),
          ],
        );
      },
    );
  }

  Widget _infoCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(content),
        ],
      ),
    );
  }
}
