import 'package:flutter/material.dart';

// Hộp thoại thêm camera: cho phép nhập username/password, IP/Host, Port (mặc định 554),
// và đường dẫn. Ứng dụng sẽ tự tạo URL RTSP hoàn chỉnh từ các phần đã nhập.
class AddCameraDialog extends StatefulWidget {
  final String? userId;
  final String? roomId;
  const AddCameraDialog({super.key, this.userId, this.roomId});
  @override
  State<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<AddCameraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '554');
  final _pathCtrl = TextEditingController(
    text: '/cam/realmonitor?channel=1&subtype=1',
  );
  String _protocol = 'rtsp';

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
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  // Tên camera (bắt buộc)
  @override
  Widget build(BuildContext context) {
    final previewStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]);

    // Username / Password (tùy chọn)
    return AlertDialog(
      title: const Text('Thêm camera'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
              ),
              const SizedBox(height: 12),
              // Chọn giao thức (rtsp/http)
              DropdownButtonFormField<String>(
                value: _protocol,
                decoration: const InputDecoration(labelText: 'Giao thức'),
                items: const [
                  DropdownMenuItem(value: 'rtsp', child: Text('rtsp')),
                  DropdownMenuItem(value: 'http', child: Text('http')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final prev = _protocol;
                  final prevDefault = prev == 'http' ? '80' : '554';
                  final nextDefault = v == 'http' ? '80' : '554';
                  setState(() {
                    _protocol = v;
                    final current = _portCtrl.text.trim();
                    if (current.isEmpty || current == prevDefault) {
                      _portCtrl.text = nextDefault; // tự động đổi port mặc định
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setSBState) {
                        return TextFormField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Username (tùy chọn)',
                            suffixIcon: _usernameCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _usernameCtrl.clear();
                                      setSBState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setSBState(() {}),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setSBState) {
                        return TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password (tùy chọn)',
                            suffixIcon: _passwordCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _passwordCtrl.clear();
                                      setSBState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setSBState(() {}),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IP/Host',
                        hintText: '192.168.1.100 hoặc mycamera.local',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nhập IP/Host'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        hintText: _protocol == 'http' ? '80' : '554',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null; // default 554
                        final n = int.tryParse(t);
                        if (n == null || n < 1 || n > 65535) {
                          return 'Port không hợp lệ';
                        }
                        // Xem trước URL để kiểm tra nhanh trước khi lưu
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Chọn mẫu đường dẫn theo giao thức
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Chọn mẫu đường dẫn',
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
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Dán mẫu Dahua (đủ thông tin)'),
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
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Đường dẫn (tùy chọn)',
                  hintText: '/cam/realmonitor?channel=1&subtype=1',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('URL xem trước', style: previewStyle),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
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
                          _previewUrl, // Ẩn mật khẩu trong URL xem trước
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
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
            Navigator.pop(context, data);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
