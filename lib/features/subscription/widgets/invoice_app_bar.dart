import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InvoiceAppBar({
    super.key,
    required this.totalCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final int? totalCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            L10nVi.title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            totalCount != null ? L10nVi.totalInvoices(totalCount!) : ' ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: L10nVi.retry,
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh_outlined),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
