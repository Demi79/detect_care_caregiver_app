import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceDetailLineItems extends StatelessWidget {
  const InvoiceDetailLineItems({
    super.key,
    required this.lineItems,
    required this.formatCurrency,
  });

  final List<dynamic> lineItems;
  final String Function(dynamic) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10nVi.details,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lineItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final li = Map<String, dynamic>.from(lineItems[i]);
            final name = (li['name'] ?? li['title'] ?? '-').toString();
            final qty = li['quantity'] ?? li['qty'] ?? 1;
            final unitPrice =
                li['unit_price'] ?? li['unitPrice'] ?? li['price'] ?? 0;
            final total =
                li['total'] ??
                li['amount'] ??
                (unitPrice is num ? unitPrice * (qty is num ? qty : 1) : 0);
            final desc = li['description'] ?? li['desc'] ?? '';

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.03 * 255).round()),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatCurrency(total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${L10nVi.qty}: ${qty.toString()}'),
                      const SizedBox(width: 16),
                      Text('${L10nVi.unitPrice}: ${formatCurrency(unitPrice)}'),
                    ],
                  ),
                  if (desc.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${L10nVi.description}: $desc',
                      style: TextStyle(color: Colors.grey.shade600),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
