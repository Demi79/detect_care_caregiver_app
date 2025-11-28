import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

// Reusable pagination widget extracted from InvoicesScreen.
class InvoicePagination extends StatelessWidget {
  const InvoicePagination({
    super.key,
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.isLoading,
    required this.hasMore,
    required this.jumpController,
    required this.onPrev,
    required this.onNext,
    required this.onChangeLimit,
    required this.onJump,
    required this.onOpenFilters,
  });

  final int page;
  final int limit;
  final int? totalCount;
  final bool isLoading;
  final bool hasMore;
  final TextEditingController jumpController;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onChangeLimit;
  final ValueChanged<int> onJump;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: page > 1 && !isLoading ? onPrev : null,
                      child: Text(L10nVi.previous),
                    ),
                    TextButton(
                      onPressed: hasMore && !isLoading ? onNext : null,
                      child: Text(L10nVi.next),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (totalCount != null)
                      Text(
                        '${L10nVi.page} $page/${((totalCount! + limit - 1) ~/ limit)}',
                      )
                    else
                      Text('${L10nVi.page} $page'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: onOpenFilters,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: page > 1 && !isLoading ? onPrev : null,
                child: Text(L10nVi.previous),
              ),

              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, innerConstraints) {
                    if (innerConstraints.maxWidth < 420) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (totalCount != null)
                            Text(
                              '${L10nVi.page} $page/${((totalCount! + limit - 1) ~/ limit)}',
                            )
                          else
                            Text('${L10nVi.page} $page'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: onOpenFilters,
                          ),
                        ],
                      );
                    }

                    return Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: DropdownButton<int>(
                              value: limit,
                              items: const [10, 20, 50]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text('$v'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isLoading
                                  ? null
                                  : (val) {
                                      if (val != null) onChangeLimit(val);
                                    },
                              underline: const SizedBox.shrink(),
                              style: TextStyle(color: Colors.grey.shade800),
                            ),
                          ),

                          if (totalCount != null)
                            Text(
                              '${L10nVi.page} $page/${((totalCount! + limit - 1) ~/ limit)}',
                            )
                          else
                            Text('${L10nVi.page} $page'),

                          SizedBox(
                            width: 72,
                            height: 32,
                            child: TextField(
                              controller: jumpController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                hintText: 'Số',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),

                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      final text = jumpController.text.trim();
                                      if (text.isEmpty) return;
                                      final p = int.tryParse(text);
                                      if (p == null || p < 1) return;
                                      final maxPage = totalCount != null
                                          ? ((totalCount! + limit - 1) ~/ limit)
                                          : p;
                                      final target = p > maxPage ? maxPage : p;
                                      onJump(target);
                                    },
                              child: const Text('Đi'),
                            ),
                          ),

                          if (isLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              TextButton(
                onPressed: hasMore && !isLoading ? onNext : null,
                child: Text(L10nVi.next),
              ),
            ],
          ),
        );
      },
    );
  }
}
