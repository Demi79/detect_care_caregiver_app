import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class UserMenuButton extends StatelessWidget {
  const UserMenuButton({
    super.key,
    required this.userName,
    required this.onProfile,
    required this.onLogout,
  });

  final String userName;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
        child: const Icon(Icons.person, color: AppTheme.primaryBlue),
      ),
      onSelected: (value) {
        if (value == 'profile') {
          onProfile();
        } else if (value == 'logout') {
          onLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'username',
          enabled: false,
          child: Text(userName),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Text('Hồ sơ cá nhân'),
        ),
        const PopupMenuItem<String>(value: 'logout', child: Text('Đăng xuất')),
      ],
    );
  }
}
