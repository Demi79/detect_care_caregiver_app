import 'package:flutter/material.dart';

/// A compact panel used by the notification screen to search and filter the list.
class NotificationFilterPanel extends StatelessWidget {
  const NotificationFilterPanel({
    super.key,
    required this.searchController,
    required this.filterOptions,
    required this.statusOptions,
    required this.selectedFilterValue,
    required this.selectedStatusValue,
    required this.onSearchChanged,
    required this.onFilterSelected,
    required this.onStatusSelected,
  });

  final TextEditingController searchController;
  final List<Map<String, dynamic>> filterOptions;
  final List<Map<String, dynamic>> statusOptions;
  final String? selectedFilterValue;
  final String? selectedStatusValue;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onFilterSelected;
  final ValueChanged<String?> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildChipRow(
          options: filterOptions,
          selectedValue: selectedFilterValue,
          onSelected: onFilterSelected,
        ),
        _buildChipRow(
          options: statusOptions,
          selectedValue: selectedStatusValue,
          onSelected: onStatusSelected,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm thông báo...',
            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
            prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildChipRow({
    required List<Map<String, dynamic>> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return Container(
      color: Colors.white,
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final value = option['value'] ?? option['type'];
          final isSelected = selectedValue == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                option['label'],
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              backgroundColor: const Color(0xFFF1F5F9),
              selectedColor: const Color(0xFF3B82F6),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFE2E8F0),
              ),
              onSelected: (selected) =>
                  onSelected(selected ? value : null),
            ),
          );
        },
      ),
    );
  }
}
