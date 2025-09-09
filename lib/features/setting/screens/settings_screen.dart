import 'package:detect_care_caregiver_app/features/activity_logs/screens/activity_logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/patient/screens/patient_profile_screen.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';

import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_divider.dart';
import '../widgets/settings_item.dart';
import '../widgets/settings_switch_item.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    _buildSectionTitle('ACCOUNT'),
                    const SizedBox(height: 12),
                    _accountSection(),

                    const SizedBox(height: 24),

                    _buildSectionTitle('ALERT SETTINGS'),
                    const SizedBox(height: 12),
                    _alertSettingsSection(context),

                    const SizedBox(height: 24),

                    _buildSectionTitle('OTHER SETTINGS'),
                    const SizedBox(height: 12),
                    _otherSettingsSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'Cài đặt',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _accountSection() => SettingsCard(
    children: [
      SettingsItem(
        icon: Icons.person_outline,
        title: 'Hồ sơ cá nhân',
        onTap: () {},
      ),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.medical_information_outlined,
        title: 'Hồ sơ bệnh nhân',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PatientProfileScreen())),
      ),
    ],
  );

  Widget _alertSettingsSection(BuildContext context) => SettingsCard(
    children: [
      SettingsItem(
        icon: Icons.warning_outlined,
        title: 'Thiết lập của bạn',
        onTap: () {
          final auth = context.read<AuthProvider>();
          final caregiverId = auth.currentUserId ?? '';
          final caregiverDisplay =
              auth.user?.fullName ?? auth.user?.phone ?? 'Caregiver';

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CaregiverSettingsScreen(
                caregiverId: caregiverId,
                caregiverDisplay: caregiverDisplay,
                customerId:
                    '', // để trống -> màn hình tự resolve phần tử đầu tiên
              ),
            ),
          );
        },
      ),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.local_activity_outlined,
        title: 'Quản lý nhật ký hoạt',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ActivityLogsScreen()));
        },
      ),
      const SettingsDivider(),
    ],
  );

  Widget _otherSettingsSection() => SettingsCard(
    children: [
      SettingsSwitchItem(
        icon: Icons.dark_mode_outlined,
        title: 'Chế độ ban đêm',
        value: isDarkMode,
        onChanged: (v) => setState(() => isDarkMode = v),
      ),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.security_outlined,
        title: 'Bảo mật',
        onTap: () {},
        trailing: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.language_outlined,
        title: 'Riêng tư',
        onTap: () {},
        trailing: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.help_outline,
        title: 'Trợ giúp & Hỗ trợ',
        onTap: () {},
      ),
      const SettingsDivider(),
      SettingsItem(icon: Icons.star_outline, title: 'Đánh giá', onTap: () {}),
    ],
  );
}
