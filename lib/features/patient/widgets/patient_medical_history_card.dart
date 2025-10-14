import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';

class PatientMedicalHistoryCard extends StatelessWidget {
  final PatientRecord? record;
  const PatientMedicalHistoryCard({super.key, this.record});

  @override
  Widget build(BuildContext context) {
    if (record == null) return SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF06B6D4,
                    ).withValues(alpha: 0.12 * 255),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.medical_services,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Bệnh sử',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (record!.conditions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Chẩn đoán: ${record!.conditions.join(", ")}',
                  style: TextStyle(color: Colors.blueGrey[700], fontSize: 15),
                ),
              ),
            if (record!.medications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Thuốc đang dùng: ${record!.medications.join(", ")}',
                  style: TextStyle(color: Colors.blueGrey[700], fontSize: 15),
                ),
              ),
            if (record!.history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tiền sử: ${record!.history.join(", ")}',
                  style: TextStyle(color: Colors.blueGrey[700], fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
