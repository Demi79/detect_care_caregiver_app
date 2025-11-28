import 'package:flutter/material.dart';

typedef OnPackageSelected = void Function(int id);

class PackageItem extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool isSelected;
  final bool isUpgrade;
  final OnPackageSelected onSelected;

  const PackageItem({
    super.key,
    required this.pkg,
    required this.isSelected,
    required this.isUpgrade,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    pkg['name'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Đã chọn',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  pkg['price'] != null ? '${pkg['price']}' : '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            leading: Radio<int>(
              value: pkg['id'],
              groupValue: isSelected ? pkg['id'] : null,
              onChanged: (_) => onSelected(pkg['id']),
            ),
            onTap: () => onSelected(pkg['id']),
          ),
          if (isUpgrade)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: const [
                  Icon(Icons.upgrade, color: Colors.orange, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Nâng cấp gói dịch vụ',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
