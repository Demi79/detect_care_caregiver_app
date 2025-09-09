// lib/widgets/settings_divider.dart

import 'package:flutter/material.dart';

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
