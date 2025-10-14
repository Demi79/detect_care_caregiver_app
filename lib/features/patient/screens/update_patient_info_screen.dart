import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_upsert_service.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdatePatientInfoScreen extends StatefulWidget {
  final PatientInfo? patient;
  final bool readOnly;
  const UpdatePatientInfoScreen({
    super.key,
    this.patient,
    this.readOnly = false,
  });

  @override
  State<UpdatePatientInfoScreen> createState() =>
      _UpdatePatientInfoScreenState();
}

class _UpdatePatientInfoScreenState extends State<UpdatePatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  // Sleep settings
  TimeOfDay? _bedtime;
  TimeOfDay? _wakeTime;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  // reminder days (0=Mon .. 6=Sun)
  Set<int> _reminderDays = {};
  final List<HabitItemDto> _habits = [];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameController = TextEditingController(text: p?.name ?? '');
    _dobController = TextEditingController(text: p?.dob ?? '');
    _loadSleepPrefs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (widget.readOnly) return;
    if (_formKey.currentState?.validate() ?? false) {
      final userId = await AuthStorage.getUserId() ?? '';
      final service = MedicalInfoUpsertService(AppConfig.apiBaseUrl);
      final dto = MedicalInfoUpsertDto(
        patient: PatientUpsertDto(
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          dob: _dobController.text.trim().isEmpty
              ? null
              : _dobController.text.trim(),
        ),
        habits: _habits,
        customerId: userId,
      );
      // persist sleep settings locally (and optionally send to backend if supported)
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_bedtime != null) {
          prefs.setString(
            'sleep_bedtime',
            '${_bedtime!.hour}:${_bedtime!.minute}',
          );
        }
        if (_wakeTime != null) {
          prefs.setString(
            'sleep_waketime',
            '${_wakeTime!.hour}:${_wakeTime!.minute}',
          );
        }
        prefs.setBool('sleep_reminder_enabled', _reminderEnabled);
        if (_reminderTime != null) {
          prefs.setString(
            'sleep_reminder_time',
            '${_reminderTime!.hour}:${_reminderTime!.minute}',
          );
        }
        prefs.setStringList(
          'sleep_reminder_days',
          _reminderDays.map((d) => d.toString()).toList(),
        );
      } catch (_) {}

      final success = await service.updateMedicalInfo(userId, dto);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
        if (!mounted) return;
        Navigator.of(context).pop(dto);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thất bại!')));
      }
    }
  }

  Future<void> _loadSleepPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bed = prefs.getString('sleep_bedtime');
      final wake = prefs.getString('sleep_waketime');
      final remEnabled = prefs.getBool('sleep_reminder_enabled') ?? false;
      final remTime = prefs.getString('sleep_reminder_time');
      final days = prefs.getStringList('sleep_reminder_days') ?? [];
      if (bed != null && bed.contains(':')) {
        final parts = bed.split(':');
        _bedtime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (wake != null && wake.contains(':')) {
        final parts = wake.split(':');
        _wakeTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _reminderEnabled = remEnabled;
      if (remTime != null && remTime.contains(':')) {
        final parts = remTime.split(':');
        _reminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _reminderDays = days.map((s) => int.tryParse(s) ?? 0).toSet();
      setState(() {});
    } catch (_) {}
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay(hour: 22, minute: 0),
    );
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Hồ sơ bệnh nhân',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFFF8FAFC),
                  elevation: 7,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: const Color(0xFF1E88E5)),
                            const SizedBox(width: 10),
                            const Text(
                              'Thông tin cá nhân',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ tên',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                          enabled: !widget.readOnly,
                          validator: (v) => widget.readOnly
                              ? null
                              : (v == null || v.isEmpty
                                    ? 'Vui lòng nhập họ tên'
                                    : null),
                        ),
                        const SizedBox(height: 12),
                        AbsorbPointer(
                          absorbing: widget.readOnly,
                          child: GestureDetector(
                            onTap: widget.readOnly
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _dobController.text.isNotEmpty
                                          ? DateTime.tryParse(
                                                  _dobController.text,
                                                ) ??
                                                DateTime(2000, 1, 1)
                                          : DateTime(2000, 1, 1),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime.now(),
                                      helpText: 'Chọn ngày sinh',
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _dobController.text = picked
                                            .toIso8601String()
                                            .substring(0, 10);
                                      });
                                    }
                                  },
                            child: TextFormField(
                              controller: _dobController,
                              decoration: const InputDecoration(
                                labelText: 'Ngày sinh',
                                prefixIcon: Icon(
                                  Icons.cake_outlined,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                              enabled: !widget.readOnly,
                              validator: (v) => widget.readOnly
                                  ? null
                                  : (v == null || v.isEmpty
                                        ? 'Vui lòng chọn ngày sinh'
                                        : null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sleep settings card (replaces medical info)
                Card(
                  color: const Color(0xFFF8FAFC),
                  elevation: 7,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bedtime, color: Color(0xFF1E88E5)),
                            SizedBox(width: 10),
                            Text(
                              'Giờ ngủ & Nhắc ngủ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.nightlight_round,
                            color: Color(0xFF1E88E5),
                          ),
                          title: const Text('Thời gian đi ngủ (Bedtime)'),
                          subtitle: Text(
                            _bedtime != null
                                ? _bedtime!.format(context)
                                : 'Chưa đặt',
                          ),
                          trailing: TextButton(
                            onPressed: widget.readOnly
                                ? null
                                : () async {
                                    final t = await _pickTime(_bedtime);
                                    if (t != null) setState(() => _bedtime = t);
                                  },
                            child: const Text('Chọn'),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.wb_sunny,
                            color: Color(0xFF1E88E5),
                          ),
                          title: const Text('Thời gian thức dậy (Wake time)'),
                          subtitle: Text(
                            _wakeTime != null
                                ? _wakeTime!.format(context)
                                : 'Chưa đặt',
                          ),
                          trailing: TextButton(
                            onPressed: widget.readOnly
                                ? null
                                : () async {
                                    final t = await _pickTime(_wakeTime);
                                    if (t != null)
                                      setState(() => _wakeTime = t);
                                  },
                            child: const Text('Chọn'),
                          ),
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Bật nhắc ngủ'),
                          value: _reminderEnabled,
                          onChanged: widget.readOnly
                              ? null
                              : (v) => setState(() => _reminderEnabled = v),
                          secondary: const Icon(
                            Icons.alarm,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        if (_reminderEnabled) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.schedule,
                              color: Color(0xFF1E88E5),
                            ),
                            title: const Text('Thời gian nhắc'),
                            subtitle: Text(
                              _reminderTime != null
                                  ? _reminderTime!.format(context)
                                  : 'Chưa đặt',
                            ),
                            trailing: TextButton(
                              onPressed: widget.readOnly
                                  ? null
                                  : () async {
                                      final t = await _pickTime(_reminderTime);
                                      if (t != null) {
                                        setState(() => _reminderTime = t);
                                      }
                                    },
                              child: const Text('Chọn'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: List.generate(7, (i) {
                              final names = [
                                'T2',
                                'T3',
                                'T4',
                                'T5',
                                'T6',
                                'T7',
                                'CN',
                              ];
                              final selected = _reminderDays.contains(i);
                              return FilterChip(
                                label: Text(names[i]),
                                selected: selected,
                                onSelected: widget.readOnly
                                    ? null
                                    : (v) {
                                        setState(() {
                                          if (v) {
                                            _reminderDays.add(i);
                                          } else {
                                            _reminderDays.remove(i);
                                          }
                                        });
                                      },
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!widget.readOnly)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 22),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: AppTheme.selectedTextColor,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _submit,
                      label: const Text(
                        'Lưu thông tin',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
