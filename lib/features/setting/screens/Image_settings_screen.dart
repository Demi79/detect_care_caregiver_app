// ignore_for_file: file_names
import 'package:detect_care_caregiver_app/features/setting/data/image_settings_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/setting/providers/image_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageSettingsScreen extends StatefulWidget {
  const ImageSettingsScreen({super.key});

  @override
  State<ImageSettingsScreen> createState() => _ImageSettingsScreenState();
}

class _ImageSettingsScreenState extends State<ImageSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Settings state
  String _selectedMonitoringMode = 'Giám sát nâng cao';
  String _selectedDuration = '30 minute';
  String _selectedFrameCount = '10 frame';
  bool _enableImageSaving = true;
  String _selectedImageQuality = 'Medium (1080p)';
  int _normalRetentionDays = 30;
  int _alertRetentionDays = 90;

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

  final List<String> _imageQualities = [
    'Low (720p)',
    'Medium (1080p)',
    'High (4K)',
  ];
  String _mapQuality(String? value) {
    switch (value) {
      case "low_720p":
        return "Low (720p)";
      case "medium_1080p":
        return "Medium (1080p)";
      case "high_4k":
        return "High (4K)";
      default:
        return "Medium (1080p)"; // default
    }
  }

  String _mapMode(String? value) {
    switch (value) {
      case "basic":
        return "Giám sát cơ bản";
      case "advanced":
        return "Giám sát nâng cao";
      case "smart":
        return "Giám sát thông minh";
      default:
        return "Giám sát nâng cao"; // default
    }
  }

  // Map ngược lại từ label UI -> value API
  String _reverseQuality(String label) {
    switch (label) {
      case "Low (720p)":
        return "low_720p";
      case "Medium (1080p)":
        return "medium_1080p";
      case "High (4K)":
        return "high_4k";
      default:
        return "medium_1080p";
    }
  }

  String _reverseMode(String label) {
    switch (label) {
      case "Giám sát cơ bản":
        return "basic";
      case "Giám sát nâng cao":
        return "advanced";
      case "Giám sát thông minh":
        return "smart";
      default:
        return "advanced";
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Load settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ImageSettingsProvider>(
        context,
        listen: false,
      );
      provider.loadSettings().then((_) {
        final settings = provider.settings;

        setState(() {
          final autoSave = settings.firstWhere(
            (s) => s.key == "image.auto_save",
            orElse: () =>
                ImageSetting(id: '', key: '', value: '', isEnabled: true),
          );
          _enableImageSaving = autoSave.isEnabled;

          final quality = settings.firstWhere(
            (s) => s.key == "image.quality",
            orElse: () => ImageSetting(
              id: '',
              key: '',
              value: 'medium_1080p',
              isEnabled: true,
            ),
          );
          _selectedImageQuality = _mapQuality(quality.value);

          final normalRetention = settings.firstWhere(
            (s) => s.key == "image.retention.normal_days",
            orElse: () =>
                ImageSetting(id: '', key: '', value: '30', isEnabled: true),
          );
          _normalRetentionDays =
              int.tryParse(normalRetention.value ?? "30") ?? 30;

          final alertRetention = settings.firstWhere(
            (s) => s.key == "image.retention.alert_days",
            orElse: () =>
                ImageSetting(id: '', key: '', value: '90', isEnabled: true),
          );
          _alertRetentionDays =
              int.tryParse(alertRetention.value ?? "90") ?? 90;

          final frameCount = settings.firstWhere(
            (s) => s.key == "monitor.frame_count",
            orElse: () =>
                ImageSetting(id: '', key: '', value: '10', isEnabled: true),
          );
          _selectedFrameCount = "${frameCount.value ?? "10"} frame";

          final duration = settings.firstWhere(
            (s) => s.key == "monitor.interval_minutes",
            orElse: () =>
                ImageSetting(id: '', key: '', value: '30', isEnabled: true),
          );
          _selectedDuration = "${duration.value ?? "30"} minute";

          final mode = settings.firstWhere(
            (s) => s.key == "monitor.mode",
            orElse: () => ImageSetting(
              id: '',
              key: '',
              value: 'advanced',
              isEnabled: true,
            ),
          );
          _selectedMonitoringMode = _mapMode(mode.value);
        });
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Image Settings',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildMonitoringFrequencySection(),
                const SizedBox(height: 28),
                _buildImageManagementSection(),
                const SizedBox(height: 32),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.05),
            const Color(0xFF059669).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cài đặt hình ảnh',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Cấu hình chất lượng và lưu trữ hình ảnh giám sát',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tần suất giám sát',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7BF0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2E7BF0).withValues(alpha: 0.2),
                ),
              ),
              child: const Text(
                'Advanced',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7BF0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.monitor,
          title: 'Chế độ giám sát',
          subtitle: 'Lựa chọn mức độ giám sát phù hợp',
          value: _selectedMonitoringMode,
          items: _monitoringModes,
          color: const Color(0xFF2E7BF0),
          onChanged: (value) {
            setState(() {
              _selectedMonitoringMode = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.schedule,
          title: 'Khoảng thời gian',
          subtitle: 'Tần suất chụp ảnh giám sát',
          value: _selectedDuration,
          items: _durations,
          color: const Color(0xFFF59E0B),
          onChanged: (value) {
            setState(() {
              _selectedDuration = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.photo_camera,
          title: 'Số khung hình',
          subtitle: 'Số lượng frame được chụp mỗi lần',
          value: _selectedFrameCount,
          items: _frameCounts,
          color: const Color(0xFF8B5CF6),
          onChanged: (value) {
            setState(() {
              _selectedFrameCount = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildImageManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quản lý hình ảnh',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchOption(
          icon: Icons.save,
          title: 'Lưu hình ảnh tự động',
          subtitle: 'Tự động lưu hình ảnh khi phát hiện sự kiện',
          value: _enableImageSaving,
          color: const Color(0xFF10B981),
          onChanged: (value) {
            setState(() {
              _enableImageSaving = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownOption(
          icon: Icons.high_quality,
          title: 'Chất lượng hình ảnh',
          subtitle: 'Độ phân giải và chất lượng ảnh',
          value: _selectedImageQuality,
          items: _imageQualities,
          color: const Color(0xFFEF4444),
          onChanged: (value) {
            setState(() {
              _selectedImageQuality = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSliderOption(
          icon: Icons.access_time,
          title: 'Thời gian lưu ảnh thường (ngày)',
          subtitle: 'Thời gian lưu trữ hình ảnh bình thường',
          value: _normalRetentionDays,
          min: 7,
          max: 180,
          color: const Color(0xFF06B6D4),
          onChanged: (value) {
            setState(() {
              _normalRetentionDays = value.round();
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSliderOption(
          icon: Icons.warning,
          title: 'Thời gian lưu ảnh cảnh báo (ngày)',
          subtitle: 'Thời gian lưu trữ hình ảnh có cảnh báo',
          value: _alertRetentionDays,
          min: 30,
          max: 365,
          color: const Color(0xFFEF4444),
          onChanged: (value) {
            setState(() {
              _alertRetentionDays = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                onChanged: onChanged,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                icon: Icon(Icons.keyboard_arrow_down, color: color),
                isExpanded: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: value ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: value
                ? color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: value
                  ? color.withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? color.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              color: value ? color : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: value
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFFD1D5DB),
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? color
                  : const Color(0xFFF3F4F6),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '$value ngày',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ 5,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thao tác nhanh',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.restore,
                label: 'Reset mặc định',
                color: const Color(0xFF6B7280),
                onPressed: () {
                  setState(() {
                    _selectedMonitoringMode = 'Giám sát nâng cao';
                    _selectedDuration = '30 minute';
                    _selectedFrameCount = '10 frame';
                    _enableImageSaving = true;
                    _selectedImageQuality = 'Medium (1080p)';
                    _normalRetentionDays = 30;
                    _alertRetentionDays = 90;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.settings_backup_restore,
                label: 'Tối ưu hóa',
                color: const Color(0xFF2E7BF0),
                onPressed: () {
                  setState(() {
                    _selectedMonitoringMode = 'Giám sát thông minh';
                    _selectedDuration = '15 minute';
                    _selectedFrameCount = '15 frame';
                    _enableImageSaving = true;
                    _selectedImageQuality = 'High (4K)';
                    _normalRetentionDays = 60;
                    _alertRetentionDays = 180;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, color: color, size: 18),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final provider = context.read<ImageSettingsProvider>();
          await provider.toggleSetting("image.auto_save", _enableImageSaving);
          await provider.updateSetting(
            "image.quality",
            _reverseQuality(_selectedImageQuality),
          );
          await provider.updateSetting(
            "image.retention.normal_days",
            _normalRetentionDays.toString(),
          );
          await provider.updateSetting(
            "image.retention.alert_days",
            _alertRetentionDays.toString(),
          );
          await provider.updateSetting(
            "monitor.frame_count",
            _selectedFrameCount.split(" ").first,
          );
          await provider.updateSetting(
            "monitor.interval_minutes",
            _selectedDuration.split(" ").first,
          );
          await provider.updateSetting(
            "monitor.mode",
            _reverseMode(_selectedMonitoringMode),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Đã lưu cài đặt thành công',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.save, color: Colors.white, size: 20),
        label: const Text(
          'Lưu cài đặt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
