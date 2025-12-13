import 'package:detect_care_caregiver_app/features/activity_logs/screens/activity_logs_screen.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/sleep_checkin_screen.dart';
import 'package:detect_care_caregiver_app/features/profile/screens/profile_screen.dart';
import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/features/patient/screens/patient_profile_screen.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';

import '../widgets/settings_card.dart';
import '../widgets/settings_divider.dart';
import '../widgets/settings_item.dart';

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

                    _buildSectionTitle('TÀI KHOẢN'),
                    const SizedBox(height: 12),
                    _accountSection(),

                    const SizedBox(height: 24),

                    _buildSectionTitle('CÀI ĐẶT CẢNH BÁO'),
                    const SizedBox(height: 12),
                    _alertSettingsSection(context),
                    const SizedBox(height: 24),

                    _buildSectionTitle('CÀI ĐẶT KHÁC'),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF007AFF),
            ),
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
          color: const Color(0xFF007AFF),
          fontWeight: FontWeight.w600,
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
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
        title: 'Quyền được chia sẻ',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
          );
        },
      ),
      const Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
        // child: Text(
        //   '⚠️ Một số quyền được thiết lập bởi Customer và không thể chỉnh sửa (theo chuẩn y tế).',
        //   style: TextStyle(
        //     color: Colors.redAccent,
        //     fontSize: 13,
        //     fontWeight: FontWeight.w500,
        //   ),
        // ),
      ),
      // const SettingsDivider(),
      // SettingsItem(
      //   icon: Icons.local_activity_outlined,
      //   title: 'Quản lý nhật ký hoạt động',
      //   onTap: () {
      //     Navigator.of(
      //       context,
      //     ).push(MaterialPageRoute(builder: (_) => const ActivityLogsScreen()));
      //   },
      // ),
      const SettingsDivider(),
    ],
  );

  Widget _otherSettingsSection() => SettingsCard(
    children: [
      // SettingsSwitchItem(
      //   icon: Icons.dark_mode_outlined,
      //   title: 'Chế độ ban đêm',
      //   value: Provider.of<ThemeProvider>(context).isDark,
      //   onChanged: (v) async {
      //     final tp = Provider.of<ThemeProvider>(context, listen: false);
      //     await tp.setDark(v);
      //   },
      // ),
      // const SettingsDivider(),
      const SettingsDivider(),
      SettingsItem(
        icon: Icons.bedtime_outlined,
        title: 'Giờ ngủ',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SleepCheckinScreen())),
      ),

      // const SettingsDivider(),
      // SettingsItem(
      //   icon: Icons.event_busy,
      //   title: 'Danh sách sự kiện đã hủy',
      //   onTap: () async {
      //     showDialog(
      //       context: context,
      //       barrierDismissible: false,
      //       builder: (_) => const Center(child: CircularProgressIndicator()),
      //     );

      //     try {
      //       final repo = EventRepository(
      //         EventService(
      //           ApiClient(tokenProvider: AuthStorage.getAccessToken),
      //         ),
      //       );
      //       final events = await repo.getEvents(
      //         page: 1,
      //         limit: 200,
      //         lifecycleState: 'CANCELED',
      //       );
      //       try {
      //         print(
      //           '[Settings] fetched CANCELED events count=${events.length}',
      //         );
      //         for (final ev in events) {
      //           try {
      //             print(
      //               '[Settings] event id=${ev.eventId} status=${ev.status} detectedAt=${ev.detectedAt} createdAt=${ev.createdAt} confirm=${ev.confirmStatus} confirmationState=${ev.confirmationState}',
      //             );
      //             print('[Settings] event full map=${ev.toMapString()}');
      //           } catch (e) {
      //             print('[Settings] error printing event details: $e');
      //           }
      //         }
      //       } catch (e) {
      //         print('[Settings] error printing fetched events: $e');
      //       }
      //       if (mounted) Navigator.of(context).pop();
      //       if (!mounted) return;
      //       Navigator.of(context).push(
      //         MaterialPageRoute(
      //           builder: (_) => CancelEventLogScreen(
      //             logs: events,
      //             selectedDayRange: HomeFilters.defaultDayRange,
      //             selectedStatus: HomeFilters.defaultStatus,
      //             selectedPeriod: HomeFilters.defaultPeriod,
      //             onRefresh: () {},
      //             onStatusChanged: (_) {},
      //             onDayRangeChanged: (_) {},
      //             onPeriodChanged: (_) {},
      //           ),
      //         ),
      //       );
      //     } catch (e) {
      //       if (mounted) Navigator.of(context).pop();
      //       if (mounted) {
      //         ScaffoldMessenger.of(context).showSnackBar(
      //           SnackBar(content: Text('Lỗi tải danh sách đã hủy: $e')),
      //         );
      //       }
      //     }
      //   },
      // ),
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
