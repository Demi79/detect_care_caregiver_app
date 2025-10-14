import 'package:flutter/material.dart';

class ControlsBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final DateTime? lastRefreshed;
  final int total;
  final int filtered;

  const ControlsBar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.lastRefreshed,
    required this.total,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController(text: search);
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: search.length),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.transparent, width: 0),
                  ),
                  child: TextField(
                    controller: textController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.blueAccent.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      hintText: 'Tìm camera theo tên...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      suffixIcon: search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () {
                                textController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LastUpdatedBadge(lastRefreshed: lastRefreshed),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                filtered == total
                    ? 'Tổng: $total camera'
                    : 'Hiển thị $filtered / $total camera',
                key: ValueKey('$filtered/$total'),
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LastUpdatedBadge extends StatelessWidget {
  final DateTime? lastRefreshed;

  const LastUpdatedBadge({super.key, required this.lastRefreshed});

  @override
  Widget build(BuildContext context) {
    final txt = lastRefreshed == null
        ? '—'
        : '${lastRefreshed!.hour.toString().padLeft(2, '0')}:${lastRefreshed!.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.2 * 255),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.1 * 255),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: Colors.blueAccent.withValues(alpha: 0.8 * 255),
          ),
          const SizedBox(width: 8),
          Text(
            'Cập nhật: $txt',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
