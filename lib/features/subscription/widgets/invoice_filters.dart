import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

/// Shows the invoice filters & sorting modal.
///
/// The callbacks are used to notify the caller about changes. The modal
/// itself does not mutate external state — it calls the provided callbacks
/// when the user picks values.
Future<void> showInvoiceFiltersModal({
  required BuildContext context,
  required String sort,
  required String status,
  required String source,
  required int limit,
  required TextEditingController jumpController,
  required ValueChanged<String> onSortChanged,
  required ValueChanged<String> onStatusChanged,
  required ValueChanged<String> onSourceChanged,
  required ValueChanged<int> onLimitChanged,
  required void Function(int page) onJumpToPage,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
        child: Wrap(
          runSpacing: 16,
          children: [
            const Text(
              L10nVi.filterSortTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                const Text('${L10nVi.status}: '),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'paid',
                      label: Text(L10nVi.statusPaid),
                    ),
                  ],
                  selected: {status},
                  onSelectionChanged: (s) => onStatusChanged(s.first),
                ),
              ],
            ),
            Row(
              children: [
                const Text('${L10nVi.source}: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: source,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text(L10nVi.all)),
                    DropdownMenuItem(value: 'vnpay', child: Text(L10nVi.vnpay)),
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text(L10nVi.manual),
                    ),
                  ],
                  onChanged: (v) => onSourceChanged(v ?? 'all'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('${L10nVi.sort}: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: sort,
                  items: const [
                    DropdownMenuItem(
                      value: 'date_desc',
                      child: Text(L10nVi.newest),
                    ),
                    DropdownMenuItem(
                      value: 'date_asc',
                      child: Text(L10nVi.oldest),
                    ),
                    DropdownMenuItem(
                      value: 'amount_desc',
                      child: Text(L10nVi.amountDesc),
                    ),
                    DropdownMenuItem(
                      value: 'amount_asc',
                      child: Text(L10nVi.amountAsc),
                    ),
                  ],
                  onChanged: (v) => onSortChanged(v ?? 'date_desc'),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  L10nVi.itemsPerPage,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                DropdownButton<int>(
                  value: limit,
                  items: const [10, 20, 50]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    onLimitChanged(val);
                    Navigator.of(ctx).pop();
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: jumpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: L10nVi.jumpToPage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final text = jumpController.text.trim();
                    if (text.isEmpty) return;
                    final p = int.tryParse(text);
                    if (p == null || p < 1) return;
                    Navigator.of(ctx).pop();
                    onJumpToPage(p);
                    HapticFeedback.lightImpact();
                  },
                  child: const Text(L10nVi.go),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
