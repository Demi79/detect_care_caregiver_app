import 'dart:async';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_upsert_service.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/_add_habit_dialog.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';

class HabitFormData {
  String? habitId;
  final TextEditingController habitType = TextEditingController();
  final TextEditingController habitName = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController frequency = TextEditingController();
  final TextEditingController sleepStart = TextEditingController();
  final TextEditingController sleepEnd = TextEditingController();
  final List<String> selectedDays = [];
  bool isActive = true;

  HabitFormData({this.habitId}) {
    habitType.text = 'sleep';
  }

  factory HabitFormData.fromDto(HabitItemDto dto) {
    final f = HabitFormData(habitId: dto.habitId);
    f.habitType.text = dto.habitType ?? 'sleep';
    f.habitName.text = dto.habitName ?? '';
    f.description.text = dto.description ?? '';
    f.frequency.text = dto.frequency ?? '';
    f.sleepStart.text = dto.sleepStart ?? '';
    f.sleepEnd.text = dto.sleepEnd ?? '';
    if (dto.daysOfWeek != null) f.selectedDays.addAll(dto.daysOfWeek!);
    f.isActive = dto.isActive ?? true;
    return f;
  }

  factory HabitFormData.fromHabit(Habit? h) {
    final f = HabitFormData(habitId: h?.habitId);
    f.habitType.text = 'sleep';
    if (h != null) {
      f.habitName.text = h.habitName;
      f.description.text = h.description ?? '';
      f.frequency.text = h.frequency;
      f.sleepStart.text = h.sleepStart ?? '';
      f.sleepEnd.text = h.sleepEnd ?? '';
      if (h.daysOfWeek != null) f.selectedDays.addAll(h.daysOfWeek!);
      f.isActive = h.isActive;
    }
    return f;
  }

  void dispose() {
    habitType.dispose();
    habitName.dispose();
    description.dispose();
    frequency.dispose();
    sleepStart.dispose();
    sleepEnd.dispose();
  }
}

class UpdatePatientInfoScreen extends StatefulWidget {
  final String? customerId;
  final PatientInfo? initialPatient;
  final List<Habit>? initialHabits;

  const UpdatePatientInfoScreen({
    super.key,
    this.customerId,
    this.initialPatient,
    this.initialHabits,
  });

  @override
  State<UpdatePatientInfoScreen> createState() =>
      _UpdatePatientInfoScreenState();
}

class _UpdatePatientInfoScreenState extends State<UpdatePatientInfoScreen> {
  List<HabitFormData> _habits = [];
  bool _saving = false;
  bool _hideSave = false;
  bool _dirty = false;
  bool _hasPermission = true;
  VoidCallback? _permListener;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPatient;
    _habits = (widget.initialHabits ?? [])
        .map((h) => HabitFormData.fromHabit(h))
        .toList();
    for (final h in _habits) {
      _attachListeners(h);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  void _attachListeners(HabitFormData h) {
    h.habitName.addListener(_markDirty);
    h.description.addListener(_markDirty);
    h.frequency.addListener(_markDirty);
    h.sleepStart.addListener(_markDirty);
    h.sleepEnd.addListener(_markDirty);
  }

  @override
  void dispose() {
    try {
      final permProvider = context.read<PermissionsProvider>();
      if (_permListener != null) {
        permProvider.removeListener(_permListener!);
      }
    } catch (_) {}
    for (final h in _habits) {
      h.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final permProvider = context.read<PermissionsProvider>();
    _permListener ??= () {
      if (!mounted) return;
      final cid = widget.customerId;
      if (cid == null || cid.isEmpty) return;
      final nowHas = permProvider.hasPermission(cid, 'profile_view');
      if (nowHas != _hasPermission) {
        setState(() {
          _hasPermission = nowHas;
        });
        if (!nowHas && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền xem hồ sơ đã bị thu hồi'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
          Navigator.pop(context);
        }
      }
    };
    permProvider.addListener(_permListener!);
  }

  void _addHabit() {
    if (_hasSleep()) {
      _showSnackBar('Đã có thói quen "Ngủ", không thể thêm.', isError: true);
      return;
    }
    setState(() => _habits.add(HabitFormData()));
    _attachListeners(_habits.last);
    _markDirty();
  }

  bool _hasSleep() {
    try {
      final fromForms = _habits.any(
        (e) => e.habitType.text.trim().toLowerCase() == 'sleep',
      );
      final fromInitial = (widget.initialHabits ?? []).any(
        (h) => (h.habitType ?? '').trim().toLowerCase() == 'sleep',
      );
      return fromForms || fromInitial;
    } catch (_) {
      return _habits.any(
        (e) => e.habitType.text.trim().toLowerCase() == 'sleep',
      );
    }
  }

  Future<void> _removeHabit(int index) async {
    final habit = _habits[index];
    if (habit.habitId != null && habit.habitId!.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xoá'),
          content: const Text('Bạn có chắc muốn xoá thói quen này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xoá'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final cid = widget.customerId;
      if (cid == null || cid.isEmpty) {
        _showSnackBar(
          'Không tìm thấy customerId, không thể xoá.',
          isError: true,
        );
        return;
      }

      setState(() => _hideSave = true);
      final service = MedicalInfoUpsertService('');
      final ok = await service.deleteHabit(cid, habit.habitId!);
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _hideSave = false);
        _showSnackBar('Xoá thói quen thất bại, thử lại.', isError: true);
      }
    } else {
      setState(() {
        _habits[index].dispose();
        _habits.removeAt(index);
      });
      _markDirty();
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'Chọn thời gian',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = MedicalInfoUpsertService('');

      List<HabitItemDto>? habitsDto;
      if (_habits.isNotEmpty) {
        final list = <HabitItemDto>[];
        for (final h in _habits) {
          list.add(
            HabitItemDto(
              habitId: h.habitId,
              habitType: 'sleep',
              habitName: h.habitName.text,
              description: (h.description.text.isNotEmpty)
                  ? h.description.text
                  : null,
              sleepStart: (h.sleepStart.text.isNotEmpty)
                  ? h.sleepStart.text
                  : null,
              sleepEnd: (h.sleepEnd.text.isNotEmpty) ? h.sleepEnd.text : null,
              frequency: h.frequency.text,
              isActive: h.isActive,
              daysOfWeek: (h.selectedDays.isNotEmpty) ? h.selectedDays : null,
            ),
          );
        }
        habitsDto = list;
      } else if ((widget.initialHabits ?? []).isNotEmpty) {
        habitsDto = <HabitItemDto>[];
      }

      final dto = MedicalInfoUpsertDto(patient: null, habits: habitsDto);
      final cid = widget.customerId;
      if (cid == null || cid.isEmpty) {
        _showSnackBar(
          'Không tìm thấy customerId, không thể cập nhật thói quen',
          isError: true,
        );
        return;
      }

      AppLogger.d('[UpdatePatient] update payload: ${dto.toJson()}');
      final ok = await service.updateMedicalInfo(cid, dto);
      if (!mounted) return;
      if (ok) {
        _showSnackBar('Cập nhật thành công!', isError: false);
        Navigator.pop(context, true);
      } else {
        _showSnackBar('Cập nhật thất bại, thử lại.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerId = widget.customerId;

    if (customerId != null && customerId.isNotEmpty) {
      final permProvider = context.read<PermissionsProvider>();
      _hasPermission = permProvider.hasPermission(customerId, 'profile_view');
      AppLogger.d(
        '[UpdatePatient] customerId=$customerId, profileView=$_hasPermission',
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          centerTitle: true,
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
            'Cập nhật hồ sơ',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có quyền truy cập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quyền "Xem hồ sơ bệnh nhân" đã bị thu hồi. Vui lòng nhờ bệnh nhân cấp lại quyền.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Quay lại'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CaregiverSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.key),
                      label: const Text('Yêu cầu quyền'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        centerTitle: true,
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
          'Cập nhật hồ sơ',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [_buildHabitsSection(), const SizedBox(height: 100)],
            ),
          ),
          if (_dirty && !_hideSave) _buildBottomSaveBar(),
        ],
      ),
    );
  }

  Widget _buildHabitsSection() {
    final hasSleep = _hasSleep();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Thói quen sinh hoạt',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Builder(
              builder: (_) {
                final hasSleep = _hasSleep();
                AppLogger.d(
                  '[UpdatePatient] hasSleep=$hasSleep, _habits.len=${_habits.length}, initialHabits.len=${(widget.initialHabits ?? []).length}',
                );
                if (hasSleep) return const SizedBox.shrink();
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addHabit,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Thêm',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_habits.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bedtime_outlined,
                    size: 48,
                    color: const Color(0xFF8B5CF6).withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có thói quen nào',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasSleep
                      ? 'Đã có thói quen ngủ. Bạn có thể chỉnh sửa ở trên.'
                      : 'Nhấn "Thêm" để tạo thói quen mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...List.generate(
            _habits.length,
            (i) => Padding(
              padding: EdgeInsets.only(
                bottom: i == _habits.length - 1 ? 0 : 16,
              ),
              child: _buildHabitForm(i),
            ),
          ),
      ],
    );
  }

  Widget _buildHabitForm(int index) {
    final h = _habits[index];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Thói quen ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _removeHabit(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Form fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    BackendEnums.habitTypeToVietnamese(
                      h.habitType.text.isNotEmpty ? h.habitType.text : 'sleep',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: h.habitName,
                  label: 'Tên thói quen',
                  icon: Icons.label_outline,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: h.description,
                  label: 'Mô tả (tuỳ chọn)',
                  icon: Icons.notes_outlined,
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  value: h.frequency.text.isEmpty ? null : h.frequency.text,
                  items: ['daily', 'weekly', 'custom'],
                  label: 'Tần suất',
                  icon: Icons.repeat,
                  onChanged: (val) =>
                      setState(() => h.frequency.text = val ?? ''),
                  mapper: BackendEnums.frequencyToVietnamese,
                ),
                if (h.frequency.text == 'custom') ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BackendEnums.daysOfWeekVi.entries.map((e) {
                      final selected = h.selectedDays.contains(e.key);
                      return FilterChip(
                        label: Text(
                          e.value,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            v
                                ? h.selectedDays.add(e.key)
                                : h.selectedDays.remove(e.key);
                          });
                          _markDirty();
                        },
                        backgroundColor: const Color(0xFFF8FAFC),
                        selectedColor: const Color(0xFF3B82F6),
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (h.habitType.text == 'sleep') ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Khung giờ ngủ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: h.sleepStart,
                                label: 'Bắt đầu',
                                icon: Icons.nightlight_round,
                                readOnly: true,
                                onTap: () => _pickTime(h.sleepStart),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: h.sleepEnd,
                                label: 'Kết thúc',
                                icon: Icons.wb_sunny_outlined,
                                readOnly: true,
                                onTap: () => _pickTime(h.sleepEnd),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // const SizedBox(height: 16),
                // Material(
                //   color: Colors.transparent,
                //   child: InkWell(
                //     onTap: () => setState(() => h.isActive = !h.isActive),
                //     borderRadius: BorderRadius.circular(8),
                //     child: Padding(
                //       padding: const EdgeInsets.symmetric(vertical: 8),
                //       child: Row(
                //         children: [
                //           SizedBox(
                //             width: 24,
                //             height: 24,
                //             child: Checkbox(
                //               value: h.isActive,
                //               onChanged: (val) => setState(() {
                //                 h.isActive = val ?? true;
                //                 _markDirty();
                //               }),
                //               activeColor: const Color(0xFF10B981),
                //               shape: RoundedRectangleBorder(
                //                 borderRadius: BorderRadius.circular(5),
                //               ),
                //             ),
                //           ),
                //           const SizedBox(width: 10),
                //           const Text(
                //             'Đang hoạt động',
                //             style: TextStyle(
                //               fontSize: 15,
                //               color: Color(0xFF475569),
                //               fontWeight: FontWeight.w500,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
    required String Function(String) mapper,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                mapper(e),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF94A3B8),
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _habits.any(
                            (h) =>
                                h.habitId == null ||
                                (h.habitId?.isEmpty ?? true),
                          )
                          ? 'Tạo'
                          : 'Lưu thay đổi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
