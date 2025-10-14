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
      title: Text('Thêm thói quen'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Tên thói quen'),
                onChanged: (v) => _habitName = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nhập tên thói quen' : null,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Loại thói quen'),
                items: [
                  DropdownMenuItem(value: 'sleep', child: Text('Ngủ nghỉ')),
                  DropdownMenuItem(value: 'meal', child: Text('Ăn uống')),
                  DropdownMenuItem(
                    value: 'medication',
                    child: Text('Uống thuốc'),
                  ),
                  DropdownMenuItem(value: 'activity', child: Text('Vận động')),
                  DropdownMenuItem(
                    value: 'bathroom',
                    child: Text('Vệ sinh cá nhân'),
                  ),
                  DropdownMenuItem(value: 'therapy', child: Text('Liệu pháp')),
                  DropdownMenuItem(value: 'social', child: Text('Giao tiếp')),
                ],
                onChanged: (v) => _habitType = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Chọn loại thói quen' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Mô tả'),
                onChanged: (v) => _description = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Giờ điển hình'),
                onChanged: (v) => _typicalTime = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Thời lượng (phút)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _durationMinutes = int.tryParse(v),
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Tần suất'),
                items: [
                  DropdownMenuItem(value: 'daily', child: Text('Hàng ngày')),
                  DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
                  DropdownMenuItem(value: 'custom', child: Text('Tuỳ chỉnh')),
                ],
                onChanged: (v) => _frequency = v,
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Các ngày (cách nhau bằng dấu phẩy)',
                ),
                onChanged: (v) => _daysOfWeek = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Địa điểm'),
                onChanged: (v) => _location = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Ghi chú'),
                onChanged: (v) => _notes = v,
              ),
              SwitchListTile(
                title: Text('Đang áp dụng'),
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
          child: Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(
                HabitItemDto(
                  habitType: _habitType,
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
          child: Text('Lưu'),
        ),
      ],
    );
  }
}
