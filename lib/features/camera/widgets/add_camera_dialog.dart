import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Hộp thoại thêm camera nâng cấp: UI/UX hiện đại với Material Design 3,
// dark mode support, animations, và trải nghiệm người dùng tối ưu
class AddCameraDialog extends StatefulWidget {
  final String? userId;
  final String? roomId;
  final Map<String, dynamic>? initialData; // If provided, dialog acts as Edit
  const AddCameraDialog({
    super.key,
    this.userId,
    this.roomId,
    this.initialData,
  });

  @override
  State<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<AddCameraDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '554');
  final _pathCtrl = TextEditingController(
    text: '/cam/realmonitor?channel=1&subtype=1',
  );

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _protocol = 'rtsp';
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // Prefill fields if editing
    final init = widget.initialData;
    if (init != null) {
      _nameCtrl.text = (init['camera_name'] as String?) ?? '';
      _usernameCtrl.text = (init['username'] as String?) ?? '';
      _passwordCtrl.text = (init['password'] as String?) ?? '';
      final rtsp = (init['rtsp_url'] as String?) ?? '';
      if (rtsp.isNotEmpty) {
        try {
          final uri = Uri.parse(rtsp);
          _protocol = uri.scheme;
          _ipCtrl.text = uri.host;
          _portCtrl.text = (uri.hasPort && uri.port != 0)
              ? uri.port.toString()
              : (_protocol == 'http' ? '80' : '554');
          _pathCtrl.text = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
        } catch (_) {}
      }
    }
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  // Ghép các thành phần thành URL hoàn chỉnh: <protocol>://user:pass@ip:port/path
  String get _builtUrl {
    final scheme = '$_protocol://';
    final user = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    final port = _portCtrl.text.trim().isEmpty
        ? (_protocol == 'http' ? '80' : '554')
        : _portCtrl.text.trim();
    final auth = user.isNotEmpty
        ? pass.isNotEmpty
              ? '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}@'
              : '${Uri.encodeComponent(user)}@'
        : '';
    var path = _pathCtrl.text.trim();
    if (path.isEmpty) path = '/';
    if (!path.startsWith('/')) path = '/$path';
    return '$scheme$auth$ip:$port$path';
  }

  // URL xem trước: ẩn mật khẩu nếu có
  String get _previewUrl {
    final scheme = '$_protocol://';
    final user = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    final port = _portCtrl.text.trim().isEmpty
        ? (_protocol == 'http' ? '80' : '554')
        : _portCtrl.text.trim();
    final auth = user.isNotEmpty
        ? pass.isNotEmpty
              ? '${Uri.encodeComponent(user)}:***@'
              : '${Uri.encodeComponent(user)}@'
        : '';
    var path = _pathCtrl.text.trim();
    if (path.isEmpty) path = '/';
    if (!path.startsWith('/')) path = '/$path';
    return '$scheme$auth$ip:$port$path';
  }

  // Preset đường dẫn gợi ý theo giao thức hiện tại
  List<Map<String, String>> get _pathPresets {
    if (_protocol == 'http') {
      return [
        {'label': 'HTTP - Generic', 'value': '/video'},
        {'label': 'HTTP - MJPEG', 'value': '/mjpeg'},
      ];
    }
    // RTSP presets
    return [
      {
        'label': 'RTSP - Dahua (mặc định)',
        'value': '/cam/realmonitor?channel=1&subtype=1',
      },
      {'label': 'RTSP - Hikvision (main)', 'value': '/Streaming/Channels/101'},
      {'label': 'RTSP - ONVIF Generic', 'value': '/MediaInput/h264'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header với icon và title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.videocam_outlined,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thêm Camera Mới',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Cấu hình kết nối camera IP',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form fields
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tên camera
                            _buildTextField(
                              controller: _nameCtrl,
                              label: 'Tên Camera',
                              hint: 'Ví dụ: Camera Phòng Khách',
                              icon: Icons.camera_alt,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập tên camera'
                                  : null,
                              required: true,
                            ),
                            const SizedBox(height: 16),

                            // Giao thức
                            _buildDropdownField(
                              value: _protocol,
                              label: 'Giao thức',
                              icon: Icons.settings_ethernet,
                              items: const [
                                DropdownMenuItem(
                                  value: 'rtsp',
                                  child: Text('RTSP'),
                                ),
                                DropdownMenuItem(
                                  value: 'http',
                                  child: Text('HTTP'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                final prev = _protocol;
                                final prevDefault = prev == 'http'
                                    ? '80'
                                    : '554';
                                final nextDefault = v == 'http' ? '80' : '554';
                                setState(() {
                                  _protocol = v;
                                  final current = _portCtrl.text.trim();
                                  if (current.isEmpty ||
                                      current == prevDefault) {
                                    _portCtrl.text = nextDefault;
                                  }
                                });
                                HapticFeedback.lightImpact();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Username & Password
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _usernameCtrl,
                                    label: 'Username',
                                    hint: 'Tên đăng nhập',
                                    icon: Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _passwordCtrl,
                                    label: 'Password',
                                    hint: 'Mật khẩu',
                                    icon: Icons.lock_outline,
                                    obscureText: !_showPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _showPassword = !_showPassword,
                                        );
                                        HapticFeedback.lightImpact();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // IP/Host & Port
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _ipCtrl,
                                    label: 'IP/Host',
                                    hint: '192.168.1.100',
                                    icon: Icons.router,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Vui lòng nhập IP hoặc hostname'
                                        : null,
                                    required: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _portCtrl,
                                    label: 'Port',
                                    hint: _protocol == 'http' ? '80' : '554',
                                    icon: Icons.settings_input_component,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final t = v?.trim() ?? '';
                                      if (t.isEmpty) return null;
                                      final n = int.tryParse(t);
                                      if (n == null || n < 1 || n > 65535) {
                                        return 'Port không hợp lệ';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Đường dẫn với presets
                            _buildPathField(),
                            const SizedBox(height: 16),

                            // Quick setup buttons
                            _buildQuickSetupButtons(),
                            const SizedBox(height: 16),

                            // URL Preview
                            _buildUrlPreview(theme, colorScheme),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Hủy',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  widget.initialData == null
                                      ? 'Thêm Camera'
                                      : 'Cập nhật',
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items,
      onChanged: onChanged,
      style: TextStyle(color: colorScheme.onSurface),
      dropdownColor: colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildPathField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đường dẫn Stream',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            hintText: 'Chọn mẫu đường dẫn',
            prefixIcon: Icon(Icons.link, color: colorScheme.onSurfaceVariant),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: _pathPresets
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p['value']!,
                  child: Text(p['label']!),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _pathCtrl.text = v);
            HapticFeedback.lightImpact();
          },
          style: TextStyle(color: colorScheme.onSurface),
          dropdownColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pathCtrl,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '/cam/realmonitor?channel=1&subtype=1',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSetupButtons() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thiết lập nhanh',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickButton(
              label: 'Dahua Demo',
              icon: Icons.camera,
              onPressed: () {
                setState(() {
                  _protocol = 'rtsp';
                  _usernameCtrl.text = 'admin';
                  _passwordCtrl.text = 'L2C37340';
                  _ipCtrl.text = '192.168.8.122';
                  _portCtrl.text = '554';
                  _pathCtrl.text = '/cam/realmonitor?channel=1&subtype=1';
                  if (_nameCtrl.text.trim().isEmpty) {
                    _nameCtrl.text = 'Camera Demo';
                  }
                });
                HapticFeedback.mediumImpact();
              },
            ),
            _buildQuickButton(
              label: 'Hikvision',
              icon: Icons.videocam,
              onPressed: () {
                setState(() {
                  _protocol = 'rtsp';
                  _pathCtrl.text = '/Streaming/Channels/101';
                  if (_nameCtrl.text.trim().isEmpty) {
                    _nameCtrl.text = 'Camera Hikvision';
                  }
                });
                HapticFeedback.mediumImpact();
              },
            ),
            _buildQuickButton(
              label: 'ONVIF Generic',
              icon: Icons.settings,
              onPressed: () {
                setState(() {
                  _protocol = 'rtsp';
                  _pathCtrl.text = '/MediaInput/h264';
                  if (_nameCtrl.text.trim().isEmpty) {
                    _nameCtrl.text = 'Camera ONVIF';
                  }
                });
                HapticFeedback.mediumImpact();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildUrlPreview(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'URL Preview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _usernameCtrl,
              _passwordCtrl,
              _ipCtrl,
              _portCtrl,
              _pathCtrl,
            ]),
            builder: (_, __) => Text(
              _previewUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _isLoading = true);

    // Simulate network delay for better UX
    await Future.delayed(const Duration(milliseconds: 800));

    final url = _builtUrl;
    final data = {
      'user_id': widget.userId,
      'camera_name': _nameCtrl.text.trim(),
      'camera_type': 'ip',
      'ip_address': _ipCtrl.text.trim(),
      'port': int.tryParse(_portCtrl.text.trim()) ?? 554,
      'rtsp_url': url,
      'username': _usernameCtrl.text.trim(),
      'password': _passwordCtrl.text.trim(),
      'location_in_room': '',
      'resolution': '',
      'fps': 30,
      'status': 'active',
      'is_online': true,
    };

    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.mediumImpact();
      Navigator.of(context, rootNavigator: true).pop(data);
    }
  }
}
