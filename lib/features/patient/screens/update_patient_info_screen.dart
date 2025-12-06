import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_upsert_service.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';

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

  @override
  void initState() {
    super.initState();
    final p = widget.initialPatient;
    _habits = (widget.initialHabits ?? [])
        .map((h) => HabitFormData.fromHabit(h))
        .toList();
  }

  void _addHabit() => setState(() => _habits.add(HabitFormData()));

  void _removeHabit(int index) {
    setState(() {
      _habits[index].dispose();
      _habits.removeAt(index);
    });
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
      // Personal info updates are not allowed here — only update habits.

      List<HabitItemDto>? habitsDto;
      if (_habits.isNotEmpty) {
        habitsDto = _habits.map((h) {
          return HabitItemDto(
            habitType: h.habitType.text,
            habitName: h.habitName.text,
            description: h.description.text.isNotEmpty
                ? h.description.text
                : null,
            sleepStart: h.sleepStart.text.isNotEmpty ? h.sleepStart.text : null,
            sleepEnd: h.sleepEnd.text.isNotEmpty ? h.sleepEnd.text : null,
            frequency: h.frequency.text,
            isActive: h.isActive,
            daysOfWeek: h.selectedDays.isNotEmpty ? h.selectedDays : null,
          );
        }).toList();
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHabitsSection(),
          const SizedBox(height: 24),
          _buildSaveButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHabitsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thói quen sinh hoạt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Material(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _addHabit,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_habits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có thói quen nào',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(
              _habits.length,
              (i) => Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                child: _buildHabitForm(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHabitForm(int index) {
    final h = _habits[index];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Thói quen ${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
                iconSize: 22,
                onPressed: () => _removeHabit(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            value: h.habitType.text.isEmpty ? null : h.habitType.text,
            items: [
              'sleep',
              'meal',
              'medication',
              'activity',
              'bathroom',
              'therapy',
              'social',
            ],
            label: 'Loại thói quen',
            icon: Icons.category_outlined,
            onChanged: (val) => setState(() => h.habitType.text = val ?? ''),
            mapper: BackendEnums.habitTypeToVietnamese,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: h.habitName,
            label: 'Tên thói quen',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: h.description,
            label: 'Mô tả (tuỳ chọn)',
            icon: Icons.notes_outlined,
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            value: h.frequency.text.isEmpty ? null : h.frequency.text,
            items: ['daily', 'weekly', 'custom'],
            label: 'Tần suất',
            icon: Icons.repeat,
            onChanged: (val) => setState(() => h.frequency.text = val ?? ''),
            mapper: BackendEnums.frequencyToVietnamese,
          ),
          if (h.frequency.text == 'custom') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BackendEnums.daysOfWeekVi.entries.map((e) {
                final selected = h.selectedDays.contains(e.key);
                return FilterChip(
                  label: Text(
                    e.value,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      v
                          ? h.selectedDays.add(e.key)
                          : h.selectedDays.remove(e.key);
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF3B82F6),
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
          ],
          if (h.habitType.text == 'sleep') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Color(0xFF3B82F6),
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
                  const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => h.isActive = !h.isActive),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: h.isActive,
                      onChanged: (val) =>
                          setState(() => h.isActive = val ?? true),
                      activeColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Đang hoạt động',
                    style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
                  ),
                ],
              ),
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
    IconData? suffix,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        suffixIcon: suffix != null
            ? Icon(suffix, size: 20, color: const Color(0xFF94A3B8))
            : null,
        filled: true,
        fillColor: Colors.white,
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
          vertical: 14,
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
          .map((e) => DropdownMenuItem(value: e, child: Text(mapper(e))))
          .toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
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
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Lưu thay đổi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class HabitFormData {
  final TextEditingController habitName;
  final TextEditingController habitType;
  final TextEditingController description;
  final TextEditingController frequency;
  final TextEditingController sleepStart;
  final TextEditingController sleepEnd;
  bool isActive;
  List<String> selectedDays;

  HabitFormData({
    String? name,
    String? type,
    String? desc,
    String? freq,
    String? start,
    String? end,
    this.isActive = true,
    List<String>? days,
  }) : habitName = TextEditingController(text: name ?? ''),
       habitType = TextEditingController(text: type ?? ''),
       description = TextEditingController(text: desc ?? ''),
       frequency = TextEditingController(text: freq ?? 'daily'),
       sleepStart = TextEditingController(text: start ?? ''),
       sleepEnd = TextEditingController(text: end ?? ''),
       selectedDays = days ?? [];

  factory HabitFormData.fromHabit(Habit h) {
    return HabitFormData(
      name: h.habitName,
      type: h.habitType,
      desc: h.description,
      freq: h.frequency,
      start: h.sleepStart,
      end: h.sleepEnd,
      isActive: h.isActive,
      days: h.daysOfWeek ?? [],
    );
  }

  void dispose() {
    habitName.dispose();
    habitType.dispose();
    description.dispose();
    frequency.dispose();
    sleepStart.dispose();
    sleepEnd.dispose();
  }
}
