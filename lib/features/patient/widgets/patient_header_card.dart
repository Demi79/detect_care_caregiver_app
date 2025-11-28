import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/update_patient_info_screen.dart';
import 'package:detect_care_caregiver_app/core/utils/date_utils.dart';
import 'package:flutter/material.dart';

class _Palette {
  // Blue palette khớp screenshot
  static const primary = Color(0xFF2D8FE6); // Deep blue (icon)
  static const primaryLight = Color(0xFF69ACED); // Mid blue
}

class PatientHeaderCard extends StatelessWidget {
  final PatientInfo? patient;
  final String? fallbackName;
  const PatientHeaderCard({super.key, this.patient, this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final hasName = (patient?.name.isNotEmpty ?? false);
    final displayName = hasName
        ? patient!.name
        : (fallbackName?.isNotEmpty ?? false)
        ? fallbackName!
        : 'Chưa có tên';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.06 * 255).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: _Palette.primaryLight.withAlpha((0.18 * 255).toInt()),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFF8FAFC),
                child: Icon(Icons.person, size: 48, color: _Palette.primary),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Chức năng cập nhật ảnh đại diện chưa khả dụng.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _Palette.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _Palette.primary.withAlpha(
                              (0.35 * 255).toInt(),
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (patient?.dob.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ngày sinh: ${AppDateUtils.formatDobForDisplay(patient!.dob)}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }
}
