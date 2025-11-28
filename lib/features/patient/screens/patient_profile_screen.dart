import 'package:detect_care_caregiver_app/features/patient/screens/update_patient_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class PatientProfileScreen extends StatefulWidget {
  final bool embedInParent;

  const PatientProfileScreen({super.key, this.embedInParent = false});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _ds = MedicalInfoRemoteDataSource();
  MedicalInfoResponse? _data;
  bool _loading = true;
  String? _error;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Resolve linked customer (patient) id from assignments if present
      String? customerId;
      try {
        final assignDs = AssignmentsRemoteDataSource();
        final list = await assignDs.listPending(status: 'accepted');
        if (list.isNotEmpty) customerId = list.first.customerId;
      } catch (_) {}
      customerId ??= await AuthStorage.getUserId();
      if (customerId == null || customerId.isEmpty) {
        throw Exception('No customer id available');
      }

      _customerId = customerId;
      final res = await _ds.getMedicalInfo(customerId);
      setState(() {
        _data = res;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDobVi(String? dob) {
    if (dob == null || dob.isEmpty) return '—';
    try {
      final d = DateTime.parse(dob);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return dob;
    }
  }

  Future<void> _goToEdit() async {
    if (_data == null) return;
    final cid = _customerId;
    if (cid == null || cid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy customerId')),
        );
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UpdatePatientInfoScreen(
          customerId: cid,
          initialPatient: _data!.patient,
          initialHabits: _data!.habits,
        ),
      ),
    );

    if (result == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đã cập nhật hồ sơ thành công'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget bodyWidget = _loading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi tải dữ liệu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : _buildContent();

    if (widget.embedInParent) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(child: bodyWidget),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
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
          'Thông tin bệnh nhân',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: bodyWidget,
      floatingActionButton: (!_loading && _data != null)
          ? FloatingActionButton.extended(
              onPressed: _goToEdit,
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.edit),
              label: const Text('Chỉnh sửa'),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final patient = _data?.patient;
    final habits = _data?.habits ?? [];

    return RefreshIndicator(
      color: const Color(0xFF3B82F6),
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin bệnh nhân Card
            _buildPatientInfoCard(patient),
            const SizedBox(height: 16),

            // Thói quen sinh hoạt Card
            _buildHabitsCard(habits),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard(PatientInfo? patient) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thông tin cơ bản',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.badge_outlined, 'Họ tên', patient?.name ?? '—'),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.cake_outlined,
            'Ngày sinh',
            _formatDobVi(patient?.dob),
          ),
          if (patient?.allergies?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.warning_amber_outlined,
              'Dị ứng',
              patient!.allergies!.join(', '),
            ),
          ],
          if (patient?.chronicDiseases?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.local_hospital_outlined,
              'Bệnh mãn tính',
              patient!.chronicDiseases!.join(', '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHabitsCard(List<Habit> habits) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bedtime,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thói quen sinh hoạt',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (habits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.mood_bad_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có thói quen nào',
                      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...habits.asMap().entries.map((entry) {
              final index = entry.key;
              final h = entry.value;
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  _buildHabitItem(h),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHabitItem(Habit h) {
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
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  BackendEnums.habitTypeToVietnamese(h.habitType),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (h.isActive)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            h.habitName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          if (h.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              h.description!,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Builder(
                builder: (_) {
                  if (h.frequency == 'custom' &&
                      (h.daysOfWeek?.isNotEmpty == true)) {
                    final names = h.daysOfWeek!
                        .map((d) => BackendEnums.daysOfWeekVi[d] ?? d)
                        .toList();
                    return Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List<Widget>.generate(names.length, (i) {
                          final text = i < names.length - 1
                              ? '${names[i]},'
                              : names[i];
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          );
                        }),
                      ),
                    );
                  }
                  return Text(
                    BackendEnums.frequencyToVietnamese(h.frequency),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  );
                },
              ),
            ],
          ),
          if (h.sleepStart != null && h.sleepEnd != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Giấc ngủ: ${h.sleepStart} - ${h.sleepEnd}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (h.location?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  h.location!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
