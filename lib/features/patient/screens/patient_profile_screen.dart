import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/features/patient/widgets/patient_header_card.dart';
import 'package:detect_care_caregiver_app/features/patient/widgets/patient_medical_history_card.dart';
import 'package:flutter/material.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(
      //     'Hồ sơ bệnh nhân',
      //     style: TextStyle(color: Colors.white),
      //   ),
      //   centerTitle: true,
      //   backgroundColor: const Color(0xFF2D8FE6), // màu xanh hệ thống
      //   elevation: 1.5,
      //   foregroundColor: Colors.white,
      //   leading: Navigator.canPop(context)
      //       ? IconButton(
      //           icon: const Icon(Icons.arrow_back, color: Colors.white),
      //           onPressed: () => Navigator.pop(context),
      //           splashRadius: 22,
      //         )
      //       : null,
      // ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: PatientHeaderCard(
                        patient: _data?.patient,
                        fallbackName: _displayName,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PatientMedicalHistoryCard(record: _data?.record),
                    // const SizedBox(height: 18),
                    // PatientHabitsCard(
                    //   habits: _data?.habits ?? [],
                    //   habitTypeLabel: _habitTypeLabel,
                    //   frequencyLabel: _frequencyLabel,
                    // ),
                    // Nếu muốn hiển thị liên hệ khẩn cấp, bỏ comment dòng dưới:
                    // const SizedBox(height: 18),
                    // PatientContactsCard(
                    //   contacts: _data?.contacts ?? [],
                    //   alertLevelLabel: (level) => _alertLevelLabel(level ?? 1),
                    //   alertLevelColor: (level) => _alertLevelColor(level ?? 1),
                    // ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildExtraSections() {
    final List<Widget> widgets = [];
    // Bệnh sử
    if (_data?.record != null) {
      widgets.addAll([
        const SizedBox(height: 24),
        Row(
          children: const [
            Icon(Icons.medical_services, color: AppTheme.activityColor),
            SizedBox(width: 8),
            Text(
              'Bệnh sử',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        if (_data!.record!.conditions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Chẩn đoán: ${_data!.record!.conditions.join(", ")}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ),
        if (_data!.record!.medications.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Thuốc đang dùng: ${_data!.record!.medications.join(", ")}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ),
        if (_data!.record!.history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tiền sử: ${_data!.record!.history.join(", ")}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ),
      ]);
    }

    // Thói quen
    widgets.addAll([
      const SizedBox(height: 24),
      Row(
        children: const [
          Icon(Icons.accessibility_new, color: AppTheme.activityColor),
          SizedBox(width: 8),
          Text(
            'Thói quen',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      if (_data?.habits.isEmpty ?? true)
        Column(
          children: [
            const SizedBox(height: 8),
            const Text('Bạn chưa thêm thói quen nào.'),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chức năng thêm thói quen chưa khả dụng.'),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: AppTheme.activityColor),
              label: const Text(
                'Thêm thói quen',
                style: TextStyle(color: AppTheme.activityColor),
              ),
            ),
          ],
        )
      else
        ..._data!.habits.map(
          (habit) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.activityColor,
              ),
              title: Text(habit.habitName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loại: ${_habitTypeLabel(habit.habitType)}'),
                  if (habit.description != null &&
                      habit.description!.isNotEmpty)
                    Text('Mô tả: ${habit.description}'),
                  if (habit.typicalTime != null &&
                      habit.typicalTime!.isNotEmpty)
                    Text('Giờ điển hình: ${habit.typicalTime}'),
                  if (habit.durationMinutes != null)
                    Text('Thời lượng: ${habit.durationMinutes} phút'),
                  Text('Tần suất: ${_frequencyLabel(habit.frequency)}'),
                  if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty)
                    Text('Các ngày: ${habit.daysOfWeek!.join(", ")}'),
                  if (habit.location != null && habit.location!.isNotEmpty)
                    Text('Địa điểm: ${habit.location}'),
                  if (habit.notes != null && habit.notes!.isNotEmpty)
                    Text('Ghi chú: ${habit.notes}'),
                  Text(
                    'Hiệu lực: ${habit.isActive ? "Đang áp dụng" : "Ngừng"}',
                  ),
                ],
              ),
            ),
          ),
        ),
    ]);

    // Liên hệ khẩn cấp
    // widgets.addAll([
    //   const SizedBox(height: 24),
    //   Row(
    //     children: const [
    //       Icon(Icons.contact_phone, color: AppTheme.activityColor),
    //       SizedBox(width: 8),
    //       Text(
    //         'Liên hệ khẩn cấp',
    //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    //       ),
    //     ],
    //   ),
    //   if (_data?.contacts.isEmpty ?? true)
    //     Column(
    //       children: [
    //         const SizedBox(height: 8),
    //         const Text('Bạn chưa thêm liên hệ nào.'),
    //         TextButton.icon(
    //           onPressed: () {
    //             // TODO: Thêm logic thêm liên hệ khẩn cấp
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               const SnackBar(
    //                 content: Text('Chức năng thêm liên hệ chưa khả dụng.'),
    //               ),
    //             );
    //           },
    //           icon: const Icon(Icons.add, color: AppTheme.activityColor),
    //           label: const Text(
    //             'Thêm liên hệ',
    //             style: TextStyle(color: AppTheme.activityColor),
    //           ),
    //         ),
    //       ],
    //     )
    //   else
    //     ..._data!.contacts.map(
    //       (contact) => Card(
    //         margin: const EdgeInsets.symmetric(vertical: 6),
    //         elevation: 2,
    //         shape: RoundedRectangleBorder(
    //           borderRadius: BorderRadius.circular(14),
    //         ),
    //         child: ListTile(
    //           leading: const Icon(Icons.person, color: AppTheme.activityColor),
    //           title: Text(contact.name),
    //           subtitle: Column(
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: [
    //               Text('Mối quan hệ: ${contact.relation}'),
    //               Text('SĐT: ${contact.phone}'),
    //               Text(
    //                 'Mức cảnh báo: ${_alertLevelLabel(contact.alertLevel ?? 1)}',
    //               ),
    //             ],
    //           ),
    //           trailing: contact.alertLevel != null
    //               ? Container(
    //                   padding: const EdgeInsets.symmetric(
    //                     horizontal: 8,
    //                     vertical: 4,
    //                   ),
    //                   decoration: BoxDecoration(
    //                     color: _alertLevelColor(contact.alertLevel ?? 1),
    //                     borderRadius: BorderRadius.circular(8),
    //                   ),
    //                   child: Text(
    //                     _alertLevelLabel(contact.alertLevel ?? 1),
    //                     style: const TextStyle(
    //                       color: Colors.white,
    //                       fontWeight: FontWeight.bold,
    //                     ),
    //                   ),
    //                 )
    //               : null,
    //         ),
    //       ),
    //     ),
    // ]);

    return widgets;
  }

  String _habitTypeLabel(String type) {
    switch (type) {
      case 'sleep':
        return 'Ngủ nghỉ';
      case 'meal':
        return 'Ăn uống';
      case 'medication':
        return 'Uống thuốc';
      case 'activity':
        return 'Vận động';
      case 'bathroom':
        return 'Vệ sinh cá nhân';
      case 'therapy':
        return 'Liệu pháp';
      case 'social':
        return 'Giao tiếp';
      default:
        return type;
    }
  }

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'daily':
        return 'Hàng ngày';
      case 'weekly':
        return 'Hàng tuần';
      case 'custom':
        return 'Tuỳ chỉnh';
      default:
        return freq;
    }
  }

  // Color _alertLevelColor(int level) {
  //   switch (level) {
  //     case 1:
  //       return Colors.blueAccent;
  //     case 2:
  //       return Colors.orangeAccent;
  //     case 3:
  //       return Colors.redAccent;
  //     default:
  //       return Colors.grey;
  //   }
  // }

  MedicalInfoResponse? _data;
  String? _displayName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = await _getUserId();
      if (userId == 'unknown') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn chưa đăng nhập. Vui lòng đăng nhập lại.'),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }
      final medicalApi = MedicalInfoRemoteDataSource();
      final medicalInfo = await medicalApi.getMedicalInfo(userId);
      final contacts = await medicalApi.listContacts(userId);
      final displayName = await _getDisplayName();
      debugPrint(
        '[PatientProfileScreen] medicalInfo: '
        '${medicalInfo.patient?.toJson()}',
      );
      debugPrint('[PatientProfileScreen] contacts: $contacts');
      setState(() {
        _data = MedicalInfoResponse(
          patient: medicalInfo.patient,
          record: medicalInfo.record,
          habits: medicalInfo.habits,
          contacts: contacts,
        );
        _displayName = displayName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getUserId() async {
    final userId = await AuthStorage.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      debugPrint(
        '[PatientProfileScreen] Không tìm thấy userId trong AuthStorage.',
      );
      return 'unknown';
    }
    return userId;
  }

  Future<String?> _getDisplayName() async {
    final userJson = await AuthStorage.getUserJson();
    if (userJson != null) {
      final name =
          userJson['fullName']?.toString() ??
          userJson['name']?.toString() ??
          userJson['displayName']?.toString();
      if (name?.isNotEmpty ?? false) return name;
    }
    return null;
  }

  Widget buildFormCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [..._buildExtraSections()],
        ),
      ),
    );
  }
}
