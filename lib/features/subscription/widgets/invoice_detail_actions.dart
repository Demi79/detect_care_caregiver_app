import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceDetailActions extends StatelessWidget {
  const InvoiceDetailActions({
    super.key,
    required this.busy,
    required this.onDownload,
    required this.onShare,
  });

  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Tải PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: busy ? null : onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text(L10nVi.share),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
