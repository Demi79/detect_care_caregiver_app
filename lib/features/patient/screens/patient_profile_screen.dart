import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController(); // yyyy-MM-dd
  String _gender = 'Nam';
  final _addressController = TextEditingController();
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  bool _loading = false;
  MedicalInfoResponse? _data;
  String? _avatarPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUserId;
    if (uid == null || uid.isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      final ds = MedicalInfoRemoteDataSource();
      final res = await ds.getMedicalInfo(uid);
      setState(() {
        _data = res;
        _nameController.text = res.patient?.name ?? '';
        _dobController.text = res.patient?.dob ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(_dobController.text) ?? DateTime(now.year - 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}'
          '-${picked.month.toString().padLeft(2, '0')}'
          '-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = context.read<AuthProvider>().currentUserId;
    if (uid == null || uid.isEmpty) return;
    setState(() {
      _saving = true;
    });
    try {
      final ds = MedicalInfoRemoteDataSource();
      final updated = await ds.upsertMedicalInfo(
        uid,
        patient: PatientInfo(
          id: uid,
          name: _nameController.text.trim(),
          dob: _dobController.text.trim().isEmpty
              ? null
              : _dobController.text.trim(),
        ),
      );
      setState(() => _data = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ bệnh nhân')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu hồ sơ: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text('Hồ sơ bệnh nhân'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 28, top: 14),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 22,
                ),
              )
            : null,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4), Color(0xFFB2F5EA)],
          ),
        ),
        child: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 38,
                      ),
                      child: Column(
                        children: [
                          // Header Card
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: _buildHeaderCard(),
                          ),
                          const SizedBox(height: 38),
                          // Form Card
                          _buildFormCard(context),
                        ],
                      ),
                    ),
                  ),
            if (_saving)
              Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.only(top: 66, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  splashColor: Colors.blue.withValues(alpha: 0.2),
                  onTap: () async {
                    // TODO: Implement image picker
                    setState(() {
                      _avatarPath = 'assets/avatar_demo.png';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2E7BF0),
                      backgroundImage: _avatarPath != null
                          ? AssetImage(_avatarPath!)
                          : null,
                      child: _avatarPath == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Chọn ảnh',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.camera_alt, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Hồ sơ bệnh nhân',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quản lý thông tin bệnh nhân, lịch theo dõi và tiền sử sức khỏe trong hệ thống Vision AI.',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '“Sức khỏe là tài sản quý giá nhất của mỗi người.”',
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Color(0xFF0E7490),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF2E7BF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF2E7BF0), width: 2),
                ),
                errorStyle: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                helperText: 'Nhập đầy đủ họ tên bệnh nhân',
                helperStyle: TextStyle(color: Color(0xFF64748B)),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _dobController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Ngày sinh (yyyy-MM-dd)',
                prefixIcon: const Icon(Icons.cake_outlined),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF2E7BF0), width: 2),
                ),
                errorStyle: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                helperText: 'Định dạng: yyyy-MM-dd (ví dụ: 1990-01-01)',
                helperStyle: const TextStyle(color: Color(0xFF64748B)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _pickDob,
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Vui lòng nhập ngày sinh'
                  : null,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Giới tính',
                prefixIcon: Icon(Icons.wc_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF2E7BF0), width: 2),
                ),
                helperText: 'Chọn giới tính phù hợp',
                helperStyle: TextStyle(color: Color(0xFF64748B)),
              ),
              items: const [
                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'Nam'),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF2E7BF0), width: 2),
                ),
                helperText: 'Nhập địa chỉ nơi ở hiện tại',
                helperStyle: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quiet hours (lịch theo dõi):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_round),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _quietStart ?? TimeOfDay(hour: 22, minute: 0),
                      );
                      if (picked != null) setState(() => _quietStart = picked);
                    },
                    label: Text(
                      _quietStart == null
                          ? 'Giờ bắt đầu'
                          : _quietStart!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _quietEnd ?? TimeOfDay(hour: 6, minute: 0),
                      );
                      if (picked != null) setState(() => _quietEnd = picked);
                    },
                    label: Text(
                      _quietEnd == null
                          ? 'Giờ kết thúc'
                          : _quietEnd!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            if (_quietStart != null && _quietEnd != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Khung giờ theo dõi: ${_quietStart!.format(context)} - ${_quietEnd!.format(context)}',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                      ).copyWith(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.pressed)) {
                                return const Color(
                                  0xFF06B6D4,
                                ).withValues(alpha: 0.7);
                              }
                              if (states.contains(WidgetState.hovered)) {
                                return const Color(
                                  0xFF2E7BF0,
                                ).withValues(alpha: 0.7);
                              }
                              return null;
                            }),
                      ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save, color: Color(0xFF06B6D4)),
                  label: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4)],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'Lưu hồ sơ',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_data?.record != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFB2F5EA).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF06B6D4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 22,
                      color: Color(0xFF06B6D4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tiền sử: ${(_data!.record!.history).join(', ')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Color(0xFF0E7490),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
