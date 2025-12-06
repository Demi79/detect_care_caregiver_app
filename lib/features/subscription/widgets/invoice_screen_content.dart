import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_list_item.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_pagination.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_shimmer.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

class InvoiceScreenContent extends StatelessWidget {
  const InvoiceScreenContent({
    super.key,
    required this.invoices,
    required this.isLoading,
    required this.error,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
    required this.totalCount,
    required this.scrollController,
    required this.jumpController,
    required this.onPrev,
    required this.onNext,
    required this.onChangeLimit,
    required this.onJump,
    required this.onOpenFilters,
    required this.onTapInvoice,
  });

  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;
  final int page;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;
  final int? totalCount;
  final ScrollController scrollController;
  final TextEditingController jumpController;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onChangeLimit;
  final ValueChanged<int> onJump;
  final VoidCallback onOpenFilters;
  final void Function(Invoice) onTapInvoice;

  @override
  Widget build(BuildContext context) {
    final Widget content = SafeArea(
      child: isLoading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ShimmerItem(),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: 6,
            )
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => onJump(1),
                      child: const Text(L10nVi.retry),
                    ),
                  ],
                ),
              ),
            )
          : invoices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 72,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      L10nVi.noInvoices,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L10nVi.noInvoices,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => onJump(1),
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text(L10nVi.retry),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => onJump(1),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 136,
                      ),
                      itemCount: invoices.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox.shrink(),
                      itemBuilder: (context, idx) {
                        if (idx >= invoices.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : const Text(L10nVi.pullToLoadMore),
                            ),
                          );
                        }

                        final inv = invoices[idx];
                        return InvoiceListItem(
                          invoice: inv,
                          onTap: () => onTapInvoice(inv),
                        );
                      },
                    ),
                  ),

                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 32,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: InvoicePagination(
                        page: page,
                        limit: limit,
                        totalCount: totalCount,
                        isLoading: isLoading,
                        hasMore: hasMore,
                        jumpController: jumpController,
                        onPrev: onPrev,
                        onNext: onNext,
                        onChangeLimit: onChangeLimit,
                        onJump: onJump,
                        onOpenFilters: onOpenFilters,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );

    return content;
  }
}
