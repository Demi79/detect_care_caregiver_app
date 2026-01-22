import 'package:detect_care_caregiver_app/features/patient/data/medical_info_upsert_service.dart';
import 'package:flutter/material.dart';

class AddHabitDialog extends StatefulWidget {
  const AddHabitDialog({super.key});

  @override
  State<AddHabitDialog> createState() => AddHabitDialogState();
}

class AddHabitDialogState extends State<AddHabitDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _habitType;
  String? _habitName;
  String? _description;
  String? _typicalTime;
  int? _durationMinutes;
  String? _frequency;
  String? _daysOfWeek;
  String? _location;
  String? _notes;
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm thói quen'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Tên thói quen'),
                onChanged: (v) => _habitName = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nhập tên thói quen' : null,
              ),

              const SizedBox.shrink(),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Mô tả'),
                onChanged: (v) => _description = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Giờ điển hình'),
                onChanged: (v) => _typicalTime = v,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Thời lượng (phút)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _durationMinutes = int.tryParse(v),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tần suất'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Hàng ngày')),
                  DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
                  DropdownMenuItem(value: 'custom', child: Text('Tuỳ chỉnh')),
                ],
                onChanged: (v) => _frequency = v,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Các ngày (cách nhau bằng dấu phẩy)',
                ),
                onChanged: (v) => _daysOfWeek = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Địa điểm'),
                onChanged: (v) => _location = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                onChanged: (v) => _notes = v,
              ),
              SwitchListTile(
                title: const Text('Đang áp dụng'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(
                HabitItemDto(
                  habitType: _habitType ?? 'sleep',
                  habitName: _habitName,
                  description: _description,
                  typicalTime: _typicalTime,
                  durationMinutes: _durationMinutes,
                  frequency: _frequency,
                  daysOfWeek: _daysOfWeek
                      ?.split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  location: _location,
                  notes: _notes,
                  isActive: _isActive,
                ),
              );
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
