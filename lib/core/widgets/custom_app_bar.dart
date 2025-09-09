import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    this.leading,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 2,

      leading: leading,

      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
      centerTitle: true,

      actions:
          actions ??
          [
            IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.primaryBlue),
              tooltip: 'Đăng xuất',
              onPressed: () {
                context.read<AuthProvider>().logout();
              },
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppTheme.primaryBlue),
              ),
            ),
          ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
