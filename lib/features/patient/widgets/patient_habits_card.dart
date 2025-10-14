import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';

class PatientHabitsCard extends StatelessWidget {
  final List<Habit> habits;
  final String Function(String) habitTypeLabel;
  final String Function(String) frequencyLabel;
  const PatientHabitsCard({
    super.key,
    required this.habits,
    required this.habitTypeLabel,
    required this.frequencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF06B6D4,
                    ).withAlpha((0.12 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: const Icon(
                    Icons.accessibility_new,
                    color: Color(0xFF06B6D4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Thói quen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Bạn chưa thêm thói quen nào.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                    ),
                  ],
                ),
              ),
            ...habits.map(
              (habit) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF06B6D4),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            habit.habitName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Loại: ${habitTypeLabel(habit.habitType)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (habit.description != null &&
                          habit.description!.isNotEmpty)
                        Text(
                          'Mô tả: ${habit.description}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (habit.typicalTime != null &&
                          habit.typicalTime!.isNotEmpty)
                        Text(
                          'Giờ điển hình: ${habit.typicalTime}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (habit.durationMinutes != null)
                        Text(
                          'Thời lượng: ${habit.durationMinutes} phút',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      Text(
                        'Tần suất: ${frequencyLabel(habit.frequency)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (habit.daysOfWeek != null &&
                          habit.daysOfWeek!.isNotEmpty)
                        Text(
                          'Các ngày: ${habit.daysOfWeek!.join(", ")}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (habit.location != null && habit.location!.isNotEmpty)
                        Text(
                          'Địa điểm: ${habit.location}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (habit.notes != null && habit.notes!.isNotEmpty)
                        Text(
                          'Ghi chú: ${habit.notes}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      Text(
                        'Hiệu lực: ${habit.isActive ? "Đang áp dụng" : "Ngừng"}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
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
