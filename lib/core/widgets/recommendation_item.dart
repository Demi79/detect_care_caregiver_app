// import 'package:flutter/material.dart';
// import '../theme/app_theme.dart';

// class RecommendationItem extends StatelessWidget {
//   final String title;
//   final IconData icon;

//   const RecommendationItem({Key? key, required this.title, required this.icon})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(AppTheme.spacingS),
//             decoration: BoxDecoration(
//               color: AppTheme.primaryBlue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
//             ),
//             child: Icon(icon, color: AppTheme.primaryBlue, size: 16),
//           ),
//           const SizedBox(width: AppTheme.spacingM),
//           Expanded(
//             child: Text(
//               title,
//               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 color: AppTheme.text,
//                 height: 1.4,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecommendationItem extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final int priority;

  const RecommendationItem({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    String priorityLabel;
    if (priority == 1) {
      priorityColor = AppTheme.dangerColor;
      priorityLabel = 'High';
    } else if (priority == 2) {
      priorityColor = AppTheme.warningColor;
      priorityLabel = 'Medium';
    } else {
      priorityColor = AppTheme.successColor;
      priorityLabel = 'Low';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (description != null && description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Text(
              priorityLabel,
              style: TextStyle(
                color: priorityColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
