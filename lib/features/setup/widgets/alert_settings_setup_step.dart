import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/settings_remote_data_source.dart';
import '../../../core/models/settings.dart';
import '../../../features/auth/data/auth_storage.dart';
import '../providers/setup_flow_manager.dart';
import '../models/setup_step.dart';

class AlertSettingsSetupStep extends StatefulWidget {
  const AlertSettingsSetupStep({super.key});

  @override
  State<AlertSettingsSetupStep> createState() => _AlertSettingsSetupStepState();
}

class _AlertSettingsSetupStepState extends State<AlertSettingsSetupStep>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Notification settings state
  bool _masterNotifications = true;
  bool _appNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;
  bool _callNotifications = false;
  bool _deviceAlerts = false;

  // Emergency contacts
  final List<Map<String, dynamic>> _emergencyContacts = [];
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _selectedContactRelation = 'Người thân';
  bool _isSaving = false;

  final List<String> _contactRelations = [
    'Người thân',
    'Bác sĩ',
    'Y tá',
    'Hàng xóm',
    'Bạn bè',
    'Khác',
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
    _contactNameController.dispose();
    _contactPhoneController.dispose();
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
              _buildMasterSwitch(),
              const SizedBox(height: 24),
              _buildNotificationChannels(),
              const SizedBox(height: 24),
              _buildEmergencyContacts(),
              const SizedBox(height: 24),
              _buildQuickActions(),
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
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            size: 32,
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt thông báo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thiết lập cách thức nhận cảnh báo khẩn cấp',
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

  Widget _buildMasterSwitch() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _masterNotifications
              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
              : Colors.grey.shade300,
          width: _masterNotifications ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _masterNotifications
                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
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
              gradient: _masterNotifications
                  ? const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    )
                  : null,
              color: _masterNotifications ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _masterNotifications
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _masterNotifications ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bật/Tắt tất cả thông báo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _masterNotifications
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Điều khiển toàn bộ hệ thống thông báo',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _masterNotifications,
            onChanged: (value) {
              setState(() {
                _masterNotifications = value;
                if (!value) {
                  _appNotifications = false;
                  _emailNotifications = false;
                  _smsNotifications = false;
                  _callNotifications = false;
                  _deviceAlerts = false;
                }
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationChannels() {
    return _buildSection(
      title: 'Kênh thông báo',
      icon: Icons.send_outlined,
      children: [
        AnimatedOpacity(
          opacity: _masterNotifications ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              _buildNotificationOption(
                icon: Icons.phone_android,
                title: 'Thông báo qua app',
                subtitle: 'Push notification trực tiếp từ ứng dụng',
                value: _appNotifications && _masterNotifications,
                color: const Color(0xFF2E7BF0),
                enabled: _masterNotifications,
                onChanged: _masterNotifications
                    ? (value) => setState(() => _appNotifications = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildNotificationOption(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: 'Gửi thông báo qua email đã đăng ký',
                value: _emailNotifications && _masterNotifications,
                color: const Color(0xFF10B981),
                enabled: _masterNotifications,
                onChanged: _masterNotifications
                    ? (value) => setState(() => _emailNotifications = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildNotificationOption(
                icon: Icons.sms_outlined,
                title: 'SMS',
                subtitle: 'Gửi tin nhắn đến số điện thoại',
                value: _smsNotifications && _masterNotifications,
                color: const Color(0xFFF59E0B),
                enabled: _masterNotifications,
                onChanged: _masterNotifications
                    ? (value) => setState(() => _smsNotifications = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildNotificationOption(
                icon: Icons.phone_outlined,
                title: 'Cuộc gọi khẩn cấp',
                subtitle: 'Gọi điện khi có cảnh báo nghiêm trọng',
                value: _callNotifications && _masterNotifications,
                color: const Color(0xFFEF4444),
                enabled: _masterNotifications,
                onChanged: _masterNotifications
                    ? (value) => setState(() => _callNotifications = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildNotificationOption(
                icon: Icons.watch,
                title: 'Thiết bị đeo',
                subtitle: 'Rung và phát âm thanh trên thiết bị',
                value: _deviceAlerts && _masterNotifications,
                color: const Color(0xFF8B5CF6),
                enabled: _masterNotifications,
                onChanged: _masterNotifications
                    ? (value) => setState(() => _deviceAlerts = value)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContacts() {
    return _buildSection(
      title: 'Danh bạ khẩn cấp',
      icon: Icons.contact_emergency_outlined,
      children: [
        Text(
          'Thêm danh sách người liên hệ khi có tình huống khẩn cấp',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        _buildAddContactForm(),
        const SizedBox(height: 16),
        if (_emergencyContacts.isEmpty)
          _buildEmptyContactsState()
        else
          ..._emergencyContacts.map((contact) => _buildContactCard(contact)),
      ],
    );
  }

  Widget _buildAddContactForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contactNameController,
                  decoration: InputDecoration(
                    labelText: 'Họ tên',
                    hintText: 'Nhập họ tên',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    hintText: 'Nhập SĐT',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedContactRelation,
                  onChanged: (value) =>
                      setState(() => _selectedContactRelation = value!),
                  items: _contactRelations.map((relation) {
                    return DropdownMenuItem(
                      value: relation,
                      child: Text(relation),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Mối quan hệ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _canAddContact() ? _addEmergencyContact : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return _buildSection(
      title: 'Thao tác nhanh',
      icon: Icons.flash_on_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.notifications_active,
                title: 'Bật tất cả',
                color: const Color(0xFF10B981),
                onPressed: () {
                  setState(() {
                    _masterNotifications = true;
                    _appNotifications = true;
                    _emailNotifications = true;
                    _smsNotifications = true;
                    _callNotifications = true;
                    _deviceAlerts = true;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.notifications_off,
                title: 'Tắt tất cả',
                color: const Color(0xFFEF4444),
                onPressed: () {
                  setState(() {
                    _masterNotifications = false;
                    _appNotifications = false;
                    _emailNotifications = false;
                    _smsNotifications = false;
                    _callNotifications = false;
                    _deviceAlerts = false;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.emergency,
                title: 'Chỉ khẩn cấp',
                color: const Color(0xFFF59E0B),
                onPressed: () {
                  setState(() {
                    _masterNotifications = true;
                    _appNotifications = true;
                    _emailNotifications = false;
                    _smsNotifications = true;
                    _callNotifications = true;
                    _deviceAlerts = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.tune,
                title: 'Tùy chỉnh',
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
              Icon(icon, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (title == 'Kênh thông báo')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_getActiveNotificationsCount()}/5 đang bật',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
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

  Widget _buildNotificationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required bool enabled,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value && enabled
            ? color.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value && enabled
              ? color.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value && enabled
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value && enabled ? color : Colors.grey.shade600,
              size: 20,
            ),
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
                    color: enabled
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: color),
        ],
      ),
    );
  }

  Widget _buildEmptyContactsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.contacts_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Chưa có liên hệ khẩn cấp',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            radius: 16,
            child: const Icon(Icons.person, color: Color(0xFFF59E0B), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${contact['phone']} • ${contact['relation']}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeEmergencyContact(contact),
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
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
        onPressed: _isSaving ? null : _saveAlertSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.grey : const Color(0xFFF59E0B),
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
          _isSaving ? 'Đang lưu...' : 'Lưu cài đặt thông báo',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  bool _canAddContact() {
    return _contactNameController.text.trim().isNotEmpty &&
        _contactPhoneController.text.trim().isNotEmpty;
  }

  void _addEmergencyContact() {
    if (!_canAddContact()) return;

    final contact = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _contactNameController.text.trim(),
      'phone': _contactPhoneController.text.trim(),
      'relation': _selectedContactRelation,
    };

    setState(() {
      _emergencyContacts.add(contact);
      _contactNameController.clear();
      _contactPhoneController.clear();
      _selectedContactRelation = 'Người thân';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm liên hệ khẩn cấp'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _removeEmergencyContact(Map<String, dynamic> contact) {
    setState(() {
      _emergencyContacts.remove(contact);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa liên hệ khẩn cấp'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  int _getActiveNotificationsCount() {
    int count = 0;
    if (_appNotifications && _masterNotifications) count++;
    if (_emailNotifications && _masterNotifications) count++;
    if (_smsNotifications && _masterNotifications) count++;
    if (_callNotifications && _masterNotifications) count++;
    if (_deviceAlerts && _masterNotifications) count++;
    return count;
  }

  void _saveAlertSettings() async {
    setState(() => _isSaving = true);
    final ctx = context;

    try {
      // Get current user ID
      final userId = await AuthStorage.getUserId();
      if (userId == null) {
        throw Exception('Không thể lấy thông tin người dùng hiện tại');
      }

      // Create alert settings object
      final alertSettings = AlertSettings(
        masterNotifications: _masterNotifications,
        appNotifications: _appNotifications,
        emailNotifications: _emailNotifications,
        smsNotifications: _smsNotifications,
        callNotifications: _callNotifications,
        deviceAlerts: _deviceAlerts,
      );

      // Save to backend API
      final settingsApi = SettingsRemoteDataSource();
      await settingsApi.saveAlertSettings(userId, alertSettings);

      // Also save locally for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alert_master_notifications', _masterNotifications);
      await prefs.setBool('alert_app_notifications', _appNotifications);
      await prefs.setBool('alert_email_notifications', _emailNotifications);
      await prefs.setBool('alert_sms_notifications', _smsNotifications);
      await prefs.setBool('alert_call_notifications', _callNotifications);
      await prefs.setBool('alert_device_alerts', _deviceAlerts);

      // Save emergency contacts locally (as JSON string for now)
      final contactsJson = _emergencyContacts
          .map(
            (contact) => {
              'name': contact['name'],
              'phone': contact['phone'],
              'relation': contact['relation'],
            },
          )
          .toList();
      await prefs.setStringList(
        'emergency_contacts',
        contactsJson.map((c) => c.toString()).toList(),
      );

      final setupManager = ctx.read<SetupFlowManager>();
      setupManager.completeStep(SetupStepType.alertSettings);

      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt thông báo thành công'),
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
