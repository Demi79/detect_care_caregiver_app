import 'package:flutter/material.dart';

import '../models/plan.dart';

class PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isSelected;
  final bool isUpgrade;
  final bool isDowngrade;
  final int cameraQuota;
  final int caregiverSeats;
  final int sites;
  final String storageSize;
  final String buttonText;
  final bool buttonEnabled;
  final int price;
  final String savingText;
  final String deltaText;
  final VoidCallback? onPressed;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.isUpgrade,
    required this.isDowngrade,
    required this.cameraQuota,
    required this.caregiverSeats,
    required this.sites,
    required this.storageSize,
    required this.buttonText,
    required this.buttonEnabled,
    required this.price,
    required this.savingText,
    required this.deltaText,
    required this.onPressed,
  });

  static String formatVND(int amount) {
    final s = amount.toString();
    final chars = s.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      if ((i + 1) % 3 == 0 && i != chars.length - 1) out.add('.');
    }
    return '${out.reversed.join()}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: plan.isRecommended ? 10 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: plan.isRecommended
              ? const Color(0xFF1E88E5).withValues(alpha: 102)
              : Colors.grey.withValues(alpha: 77),
          width: 2,
        ),
      ),
      color: plan.isRecommended ? const Color(0xFFE3F2FD) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: plan.isRecommended
                          ? const Color(0xFF1E88E5)
                          : Colors.black,
                    ),
                  ),
                ),
                if (plan.isRecommended)
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 1.5),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: const Color(0xFF1E88E5).withValues(alpha: 77),
                      //     blurRadius: 4,
                      //     offset: const Offset(0, 2),
                      //   ),
                      // ],
                    ),
                    child: const Text(
                      'Khuyên dùng',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price == 0 ? 'Miễn phí' : '${PlanCard.formatVND(price)}/tháng',
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (savingText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  savingText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (deltaText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  deltaText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            ...[
              'Hỗ trợ tối đa $cameraQuota camera giám sát',
              'Lưu trữ dữ liệu lên đến ${plan.retentionDays} ngày',
              'Quản lý $caregiverSeats tài khoản caregiver',
              'Áp dụng cho $sites địa điểm khác nhau',
              'Dung lượng lưu trữ: $storageSize',
              'Nhận cập nhật phần mềm định kỳ mỗi ${plan.majorUpdatesMonths} tháng',
            ].map(
              (f) => Row(
                children: [
                  const Icon(Icons.check, color: Color(0xFF1E88E5), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(f, style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !buttonEnabled
                      ? Colors.grey.shade400
                      : (plan.isRecommended
                            ? const Color(0xFF1E88E5)
                            : const Color(0xFF2196F3)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: !buttonEnabled
                          ? Colors.transparent
                          : (plan.isRecommended
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFF2196F3)),
                      width: 1.5,
                    ),
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
