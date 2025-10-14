import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/settings_remote_data_source.dart';
import '../../../core/models/settings.dart';
import '../../../features/auth/data/auth_storage.dart';
import '../providers/setup_flow_manager.dart';
import '../models/setup_step.dart';

class ImageSettingsSetupStep extends StatefulWidget {
  const ImageSettingsSetupStep({super.key});

  @override
  State<ImageSettingsSetupStep> createState() => _ImageSettingsSetupStepState();
}

class _ImageSettingsSetupStepState extends State<ImageSettingsSetupStep>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Settings state
  String _selectedMonitoringMode = 'Giám sát nâng cao';
  String _selectedDuration = '30 minute';
  String _selectedFrameCount = '10 frame';
  final bool _enableImageSaving = true;
  int _normalRetentionDays = 30;
  int _alertRetentionDays = 90;
  bool _isSaving = false;

  final List<String> _monitoringModes = [
    'Giám sát cơ bản',
    'Giám sát nâng cao',
    'Giám sát thông minh',
  ];

  final List<String> _durations = [
    '15 minute',
    '30 minute',
    '45 minute',
    '60 minute',
  ];

  final List<String> _frameCounts = [
    '5 frame',
    '10 frame',
    '15 frame',
    '20 frame',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildMonitoringSection(),
              const SizedBox(height: 24),
              // Image quality UI removed; handled by system/defaults
              const SizedBox(height: 24),
              _buildRetentionSection(),
              const SizedBox(height: 24),
              _buildQuickPresets(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_outlined, size: 32, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt hình ảnh',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cấu hình chất lượng và tần suất giám sát',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringSection() {
    return _buildSection(
      title: 'Tần suất giám sát',
      icon: Icons.monitor_outlined,
      children: [
        _buildDropdownOption(
          icon: Icons.speed_outlined,
          title: 'Chế độ giám sát',
          subtitle: 'Mức độ chi tiết của việc giám sát',
          value: _selectedMonitoringMode,
          items: _monitoringModes,
          onChanged: (value) {
            setState(() {
              _selectedMonitoringMode = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.schedule_outlined,
          title: 'Khoảng thời gian',
          subtitle: 'Thời gian giữa các lần chụp ảnh',
          value: _selectedDuration,
          items: _durations,
          onChanged: (value) {
            setState(() {
              _selectedDuration = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.photo_camera_outlined,
          title: 'Số khung hình',
          subtitle: 'Số lượng frame được chụp mỗi lần',
          value: _selectedFrameCount,
          items: _frameCounts,
          onChanged: (value) {
            setState(() {
              _selectedFrameCount = value!;
            });
          },
        ),
      ],
    );
  }

  // Image quality section removed - managed by device/system defaults

  Widget _buildRetentionSection() {
    return _buildSection(
      title: 'Thời gian lưu trữ',
      icon: Icons.storage_outlined,
      children: [
        _buildSliderOption(
          icon: Icons.folder_outlined,
          title: 'Hình ảnh thường (ngày)',
          subtitle: 'Thời gian lưu trữ hình ảnh bình thường',
          value: _normalRetentionDays,
          min: 7,
          max: 180,
          onChanged: (value) {
            setState(() {
              _normalRetentionDays = value.round();
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSliderOption(
          icon: Icons.warning_outlined,
          title: 'Hình ảnh cảnh báo (ngày)',
          subtitle: 'Thời gian lưu trữ hình ảnh có cảnh báo',
          value: _alertRetentionDays,
          min: 30,
          max: 365,
          onChanged: (value) {
            setState(() {
              _alertRetentionDays = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildQuickPresets() {
    return _buildSection(
      title: 'Cài đặt nhanh',
      icon: Icons.speed_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPresetButton(
                title: 'Tiết kiệm',
                subtitle: 'Chất lượng thấp, ít dung lượng',
                icon: Icons.battery_saver_outlined,
                color: const Color(0xFF10B981),
                onPressed: () => _applyPreset('economy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPresetButton(
                title: 'Cân bằng',
                subtitle: 'Cân bằng chất lượng và dung lượng',
                icon: Icons.balance_outlined,
                color: const Color(0xFF3B82F6),
                onPressed: () => _applyPreset('balanced'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPresetButton(
                title: 'Chất lượng cao',
                subtitle: 'Chất lượng tốt nhất',
                icon: Icons.high_quality_outlined,
                color: const Color(0xFF8B5CF6),
                onPressed: () => _applyPreset('premium'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPresetButton(
                title: 'Tùy chỉnh',
                subtitle: 'Cài đặt hiện tại',
                icon: Icons.tune_outlined,
                color: const Color(0xFF6B7280),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          underline: const SizedBox.shrink(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // Switch option helper removed; setup step uses simpler controls

  Widget _buildSliderOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$value ngày',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: onChanged,
          activeColor: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveImageSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.grey : const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _isSaving ? 'Đang lưu...' : 'Lưu cài đặt hình ảnh',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'economy':
          _selectedMonitoringMode = 'Giám sát cơ bản';
          _selectedDuration = '60 minute';
          _selectedFrameCount = '5 frame';
          _normalRetentionDays = 7;
          _alertRetentionDays = 30;
          break;
        case 'balanced':
          _selectedMonitoringMode = 'Giám sát nâng cao';
          _selectedDuration = '30 minute';
          _selectedFrameCount = '10 frame';
          _normalRetentionDays = 30;
          _alertRetentionDays = 90;
          break;
        case 'premium':
          _selectedMonitoringMode = 'Giám sát thông minh';
          _selectedDuration = '15 minute';
          _selectedFrameCount = '20 frame';
          _normalRetentionDays = 90;
          _alertRetentionDays = 180;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã áp dụng cài đặt $preset'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _saveImageSettings() async {
    setState(() => _isSaving = true);

    final ctx = context;

    try {
      // Get current user ID
      final userId = await AuthStorage.getUserId();
      if (userId == null) {
        throw Exception('Không thể lấy thông tin người dùng hiện tại');
      }

      // Create image settings object
      // imageQuality is controlled by system/device defaults; send default token to backend
      final imageSettings = ImageSettings(
        monitoringMode: _selectedMonitoringMode,
        duration: _selectedDuration,
        frameCount: _selectedFrameCount,
        imageQuality: 'Medium (1080p)',
        enableImageSaving: _enableImageSaving,
        normalRetentionDays: _normalRetentionDays,
        alertRetentionDays: _alertRetentionDays,
      );

      // Save to backend API
      final settingsApi = SettingsRemoteDataSource();
      await settingsApi.saveImageSettings(userId, imageSettings);

      // Also save locally for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('image_monitoring_mode', _selectedMonitoringMode);
      await prefs.setString('image_duration', _selectedDuration);
      await prefs.setString('image_frame_count', _selectedFrameCount);
      // image_quality local preference intentionally removed; device default used
      await prefs.setBool('image_saving_enabled', _enableImageSaving);
      await prefs.setInt('image_normal_retention_days', _normalRetentionDays);
      await prefs.setInt('image_alert_retention_days', _alertRetentionDays);

      // Sync settings to camera
      try {
        await settingsApi.syncSettingsToCamera(userId);
      } catch (e) {
        debugPrint('Warning: Could not sync settings to camera: $e');
        // Don't fail the whole operation if camera sync fails
      }

      final setupManager = ctx.read<SetupFlowManager>();
      setupManager.completeStep(SetupStepType.imageSettings);

      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt hình ảnh thành công'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu cài đặt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
