import 'dart:async';
import 'package:detect_care_caregiver_app/features/patient/screens/update_patient_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/patient/models/medical_info.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/core/utils/error_handler.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';

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
  bool _hasPermission = true;
  VoidCallback? _permListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final permProvider = context.read<PermissionsProvider>();
          AppLogger.i(
            '[PatientProfile] Force reloading PermissionsProvider on screen init',
          );
          permProvider.reload();
        } catch (e) {
          AppLogger.w(
            '[PatientProfile] Failed to reload PermissionsProvider: $e',
          );
        }
      }
    });
    _load();
  }

  @override
  void dispose() {
    // Remove permissions listener to avoid leaks
    try {
      final permProvider = context.read<PermissionsProvider>();
      if (_permListener != null) {
        permProvider.removeListener(_permListener!);
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final permProvider = context.read<PermissionsProvider>();
    _permListener ??= () {
      if (!mounted) return;
      final cid = _customerId;
      if (cid == null || cid.isEmpty) return;
      final nowHas = permProvider.hasPermission(cid, 'profile_view');
      if (nowHas != _hasPermission) {
        setState(() {
          _hasPermission = nowHas;
          if (!nowHas) {
            _error =
                'Bạn không có quyền xem hồ sơ bệnh nhân. Quyền "Xem hồ sơ bệnh nhân" đã bị thu hồi.';
            _data = null;
          } else {
            _error = null;
          }
        });
        if (nowHas && _data == null && !_loading) {
          _load();
        }
      }
    };
    permProvider.addListener(_permListener!);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasPermission = true;
    });
    try {
      // Resolve linked customer (patient) id from assignments if present
      String? customerId;
      bool hasAcceptedAssignment = false;

      try {
        final assignDs = AssignmentsRemoteDataSource();
        final list = await assignDs.listPending(status: 'accepted');
        if (list.isNotEmpty) {
          customerId = list.first.customerId;
          hasAcceptedAssignment = true;
        }
      } catch (_) {}

      // If no accepted assignment but embedInParent is false (standalone mode),
      // user accessed from settings and needs permission
      if (!hasAcceptedAssignment && !widget.embedInParent) {
        setState(() {
          _hasPermission = false;
          _error =
              'Bạn không có quyền xem thông tin bệnh nhân. Hãy nhờ bệnh nhân cấp quyền truy cập trong "Quyền được chia sẻ".';
        });
        return;
      }

      customerId ??= await AuthStorage.getUserId();
      if (customerId == null || customerId.isEmpty) {
        throw Exception('No customer id available');
      }

      final permProvider = Provider.of<PermissionsProvider>(
        context,
        listen: false,
      );

      AppLogger.i(
        '[PatientProfile] Force reloading permissions from API before check',
      );
      await permProvider.reload();

      final hasProfileView = permProvider.hasPermission(
        customerId,
        'profile_view',
      );

      AppLogger.d(
        '[PatientProfile] _load: customerId=$customerId, profileView=$hasProfileView',
      );
      AppLogger.d(
        '[PatientProfile] Available permissions: ${permProvider.permissions.map((p) => 'customerId=${p.customerId}, profileView=${p.profileView}').toList()}',
      );

      if (!hasProfileView) {
        setState(() {
          _hasPermission = false;
          _error =
              'Bạn không có quyền xem hồ sơ bệnh nhân. Quyền "Xem hồ sơ bệnh nhân" đã bị thu hồi.';
        });
        return;
      }

      _customerId = customerId;
      final res = await _ds.getMedicalInfo(customerId);
      setState(() {
        _data = res;
      });
    } catch (e) {
      setState(() {
        _error = formatErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePhone(String raw) {
    if (raw == null) return '';
    var s = raw.trim();
    // remove spaces, parentheses and dashes
    s = s.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // If starts with +84 -> replace with 0
    if (s.startsWith('+84')) return '0' + s.substring(3);
    // If starts with 84 (no plus) -> replace with 0
    if (s.startsWith('84') && s.length > 2) return '0' + s.substring(2);
    return s;
  }

  Future<void> _dialNumber(String raw) async {
    try {
      await attemptCall(context: context, rawPhone: raw, actionLabel: 'Gọi');
    } catch (e) {
      AppLogger.w('[PatientProfile] dial failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi khi gọi điện')));
      }
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
    // No longer rely on realtime - permissions are force-reloaded in _load()

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
                  Icon(
                    _hasPermission
                        ? Icons.cloud_off_outlined
                        : Icons.lock_outline,
                    size: 64,
                    color: _hasPermission
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasPermission
                        ? 'Không thể tải dữ liệu'
                        : 'Không có quyền truy cập',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      if (!_hasPermission) ...[
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
                    ],
                  ),
                ],
              ),
            ),
          )
        : _buildContent();

    if (widget.embedInParent) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Column(
            children: [
              _buildEmbeddedHeader('Thông tin bệnh nhân'),
              Expanded(child: bodyWidget),
            ],
          ),
        ),
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
      floatingActionButton:
          (!_loading && _data != null && !widget.embedInParent)
          ? FloatingActionButton.extended(
              onPressed: _goToEdit,
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.edit),
              label: const Text('Chỉnh sửa'),
            )
          : null,
    );
  }

  Widget _buildEmbeddedHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF007AFF),
          ),
        ),
      ),
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
            const SizedBox(height: 16),

            // Edit button when embedded in parent
            if (widget.embedInParent && !_loading && _data != null)
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _goToEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
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
          // Emergency contacts
          if (_data?.contacts != null && _data!.contacts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text(
              'Liên hệ khẩn cấp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            ..._data!.contacts.map((c) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${c.relation} • ${_normalizePhone(c.phone)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _dialNumber(c.phone),
                                  icon: const Icon(Icons.phone),
                                  color: Colors.redAccent,
                                  iconSize: 18,
                                  tooltip: 'Gọi',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              );
            }).toList(),
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
