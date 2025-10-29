import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const SectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
        ),
        if (onViewAll != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Xem chi tiết'),
            ),
          ),
        ],
      ],
    );
  }
}
