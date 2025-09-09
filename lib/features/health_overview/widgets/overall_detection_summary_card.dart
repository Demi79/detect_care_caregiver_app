// import 'package:flutter/material.dart';
// import '../../../core/theme/app_theme.dart';
// import '../../../core/widgets/custom_card.dart';
// import '../../../core/widgets/progress_indicator_widget.dart';

// class OverallDetectionSummaryCard extends StatelessWidget {
//   const OverallDetectionSummaryCard({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return CustomCard(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(AppTheme.spacingS),
//                 decoration: BoxDecoration(
//                   color: AppTheme.primaryBlue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(
//                     AppTheme.borderRadiusSmall,
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.analytics,
//                   color: AppTheme.primaryBlue,
//                   size: 20,
//                 ),
//               ),
//               const SizedBox(width: AppTheme.spacingM),
//               Expanded(
//                 child: Text(
//                   'Overall Detection Summary',
//                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                     color: AppTheme.primaryBlue,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: AppTheme.spacingS),

//           Text(
//             'Key insights for patient activity over the selected period.',
//             style: Theme.of(
//               context,
//             ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
//           ),
//           const SizedBox(height: AppTheme.spacingL),

//           // Reporting Period Section
//           _buildInfoSection(
//             context,
//             'Reporting Period',
//             'June 22, 2025 - June 28, 2025',
//             Icons.calendar_today,
//           ),
//           const SizedBox(height: AppTheme.spacingL),

//           // Incident Detection Sessions
//           _buildInfoSection(
//             context,
//             'Incident Detection Sessions',
//             '5',
//             Icons.security,
//           ),
//           const SizedBox(height: AppTheme.spacingL),

//           // Progress Section
//           Row(
//             children: [
//               Icon(Icons.trending_up, color: AppTheme.successColor, size: 20),
//               const SizedBox(width: AppTheme.spacingS),
//               Expanded(
//                 child: Text(
//                   'Progress Compared to Last Week',
//                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                     color: AppTheme.text,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: AppTheme.spacingM),

//           // Progress Indicator
//           ProgressIndicatorWidget(
//             percentage: 12,
//             color: AppTheme.successColor,
//             label: '+12%',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoSection(
//     BuildContext context,
//     String title,
//     String value,
//     IconData icon,
//   ) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, size: 16, color: AppTheme.textSecondary),
//             const SizedBox(width: AppTheme.spacingS),
//             Expanded(
//               child: Text(
//                 title,
//                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   color: AppTheme.textSecondary,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: AppTheme.spacingS),
//         Text(
//           value,
//           style: Theme.of(context).textTheme.titleMedium?.copyWith(
//             color: AppTheme.text,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/health_overview_models.dart';

class OverallDetectionSummaryCard extends StatelessWidget {
  final OverallDetectionSummary data;
  const OverallDetectionSummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data.progressStatus;
    final statusColor = status == 'Improved'
        ? AppTheme.successColor
        : status == 'Declined'
        ? AppTheme.dangerColor
        : AppTheme.textSecondary;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusSmall,
                  ),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  'Overall Detection Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Key insights for patient activity over the selected period.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            context,
            'Total Detection Sessions',
            data.totalDetectionSessions.toString(),
            Icons.history_toggle_off,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Icon(
                status == 'Improved'
                    ? Icons.trending_up
                    : status == 'Declined'
                    ? Icons.trending_down
                    : Icons.horizontal_rule,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'Status Compared to Last Week',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme
                        .text, // ensure AppTheme.text exists; otherwise use a primary text color
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusSmall,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppTheme.textSecondary,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppTheme.text,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(child: Text(title, style: titleStyle)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(value, style: valueStyle),
      ],
    );
  }
}
