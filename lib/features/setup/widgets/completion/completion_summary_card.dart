import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/setup_flow_manager.dart';
import '../../models/setup_step.dart';

class CompletionSummaryCard extends StatelessWidget {
  const CompletionSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tóm tắt thiết lập',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<SetupFlowManager>(
            builder: (context, setupManager, child) {
              return Column(
                children: [
                  _buildSummaryItem(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Hồ sơ bệnh nhân',
                    status:
                        setupManager.isStepCompleted(
                          SetupStepType.patientProfile,
                        )
                        ? 'Đã thiết lập'
                        : 'Chưa hoàn thành',
                    isCompleted: setupManager.isStepCompleted(
                      SetupStepType.patientProfile,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryItem(
                    context: context,
                    icon: Icons.people_outline,
                    title: 'Người chăm sóc',
                    status:
                        setupManager.isStepCompleted(
                          SetupStepType.caregiverSetup,
                        )
                        ? 'Đã thiết lập'
                        : 'Chưa hoàn thành',
                    isCompleted: setupManager.isStepCompleted(
                      SetupStepType.caregiverSetup,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryItem(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                    title: 'Cài đặt hình ảnh',
                    status:
                        setupManager.isStepCompleted(
                          SetupStepType.imageSettings,
                        )
                        ? 'Đã cấu hình'
                        : 'Chưa hoàn thành',
                    isCompleted: setupManager.isStepCompleted(
                      SetupStepType.imageSettings,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryItem(
                    context: context,
                    icon: Icons.notifications_active_outlined,
                    title: 'Cài đặt thông báo',
                    status:
                        setupManager.isStepCompleted(
                          SetupStepType.alertSettings,
                        )
                        ? 'Đã cấu hình'
                        : 'Chưa hoàn thành',
                    isCompleted: setupManager.isStepCompleted(
                      SetupStepType.alertSettings,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String status,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade400,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isCompleted
                  ? const Color(0xFF1E293B)
                  : Colors.grey.shade600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
