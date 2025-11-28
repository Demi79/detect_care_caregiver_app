import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceDetailMetadata extends StatelessWidget {
  const InvoiceDetailMetadata({super.key, this.planName, this.description});

  final String? planName;
  final String? description;

  @override
  Widget build(BuildContext context) {
    if ((planName == null || planName!.isEmpty) &&
        (description == null || description!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (planName != null) Text('${L10nVi.plan}: ${planName!}'),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description!,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}
