import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';

class PatientContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String Function(int?) alertLevelLabel;
  final Color Function(int?) alertLevelColor;
  const PatientContactsCard({
    super.key,
    required this.contacts,
    required this.alertLevelLabel,
    required this.alertLevelColor,
  });

  @override
  Widget build(BuildContext context) {
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
                    Icons.contact_phone,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Liên hệ khẩn cấp',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Bạn chưa thêm liên hệ nào.',
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 15),
                ),
              ),
            ...contacts.map(
              (contact) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Color(0xFF06B6D4),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            contact.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mối quan hệ: ${contact.relation}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'SĐT: ${contact.phone}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Mức cảnh báo: ${alertLevelLabel(contact.alertLevel)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: alertLevelColor(contact.alertLevel),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alertLevelLabel(contact.alertLevel),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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
