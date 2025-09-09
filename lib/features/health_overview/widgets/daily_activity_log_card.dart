// import 'package:flutter/material.dart';
// import '../../../core/theme/app_theme.dart';
// import '../../../core/widgets/custom_card.dart';
// import '../../../core/widgets/status_badge.dart';

// class DailyActivityLogCard extends StatelessWidget {
//   const DailyActivityLogCard({Key? key}) : super(key: key);

//   final List<Map<String, dynamic>> activities = const [
//     {'date': 'June 28, 2025', 'status': 'Normal'},
//     {'date': 'June 27, 2025', 'status': 'Normal'},
//     {'date': 'June 26, 2025', 'status': 'Normal'},
//     {'date': 'June 25, 2025', 'status': 'Normal'},
//     {'date': 'June 24, 2025', 'status': 'Normal'},
//     {'date': 'June 23, 2025', 'status': 'Normal'},
//   ];

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
//                   color: AppTheme.successColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(
//                     AppTheme.borderRadiusSmall,
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.list_alt,
//                   color: AppTheme.successColor,
//                   size: 20,
//                 ),
//               ),
//               const SizedBox(width: AppTheme.spacingM),
//               Expanded(
//                 child: Text(
//                   'Daily Activity Log',
//                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                     color: AppTheme.successColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: AppTheme.spacingS),

//           Text(
//             'Detailed report for each day of the week.',
//             style: Theme.of(
//               context,
//             ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
//           ),
//           const SizedBox(height: AppTheme.spacingL),

//           // Activity List
//           ...activities
//               .map(
//                 (activity) => _buildActivityItem(
//                   context,
//                   activity['date'],
//                   activity['status'],
//                 ),
//               )
//               .toList(),
//         ],
//       ),
//     );
//   }

//   Widget _buildActivityItem(BuildContext context, String date, String status) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             date,
//             style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//               color: AppTheme.text,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           StatusBadge(status: status),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/health_overview_models.dart';

class DailyActivityLogCard extends StatelessWidget {
  final List<DailyActivity> activities;

  const DailyActivityLogCard({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Center(
            child: Text(
              'No recent activity',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Activity Log',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...activities.map(
              (activity) => _buildActivityItem(context, activity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, DailyActivity activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.date,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.statusLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: activity.statusColor),
                ),
              ],
            ),
          ),
          StatusBadge(status: activity.status),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final ActivityStatus status;

  const StatusBadge({super.key, required this.status});

  Color get _background {
    switch (status) {
      case ActivityStatus.normal:
        return Colors.green.withValues(alpha: 0.1);
      case ActivityStatus.warning:
        return Colors.orange.withValues(alpha: 0.1);
      case ActivityStatus.danger:
        return Colors.red.withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color get _textColor {
    switch (status) {
      case ActivityStatus.normal:
        return Colors.green;
      case ActivityStatus.warning:
        return Colors.orange;
      case ActivityStatus.danger:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _label {
    switch (status) {
      case ActivityStatus.normal:
        return 'Normal';
      case ActivityStatus.warning:
        return 'Warning';
      case ActivityStatus.danger:
        return 'Danger';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
