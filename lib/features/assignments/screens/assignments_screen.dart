import 'dart:async';

import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/caregivers/data/caregivers_remote_data_source.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _debounce;
  bool _loading = false;

  List<User> _searchResults = const [];
  List<Assignment> _assignments = const [];

  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAssignments();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        setState(() => _searchResults = const []);
        return;
      }
      _searchCaregivers(q);
    });
  }

  Future<void> _searchCaregivers(String keyword) async {
    debugPrint('\n🔍 Searching caregivers with keyword: "$keyword"');
    try {
      final ds = CaregiversRemoteDataSource();
      final list = await ds.search(keyword: keyword);
      debugPrint('✅ Found ${list.length} caregivers:');
      for (var cg in list) {
        debugPrint('   - ID: ${cg.id}, Phone: ${cg.phone}');
      }
      if (!mounted) return;
      setState(() => _searchResults = list);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi tìm caregiver: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _refreshAssignments() async {
    final customerId = context.read<AuthProvider>().currentUserId;
    debugPrint('\n📋 Refreshing assignments for customer: $customerId');
    if (customerId == null || customerId.isEmpty) {
      _showErrorSnackBar('Không xác định được customer hiện tại');
      return;
    }
    setState(() => _loading = true);
    try {
      final ds = AssignmentsRemoteDataSource();
      final list = await ds.listByCustomer(
        customerId: customerId,
        activeOnly: false,
      );
      debugPrint('✅ Found ${list.length} assignments:');
      for (var a in list) {
        debugPrint('   - AssignID: ${a.assignmentId}');
        debugPrint('     CaregiverID: ${a.caregiverId}');
        debugPrint('     Active: ${a.isActive}');
        debugPrint('     Assigned: ${a.assignedAt}');
      }
      if (!mounted) return;
      setState(() => _assignments = list);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi tải danh sách caregiver đã gán: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unassign(Assignment a) async {
    setState(() => _loading = true);
    try {
      final ds = AssignmentsRemoteDataSource();

      // B1: ưu tiên xóa theo ID
      bool done = false;
      if (a.assignmentId.isNotEmpty) {
        try {
          await ds.deleteById(a.assignmentId);
          done = true;
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (!(msg.contains('404') || msg.contains('not found'))) rethrow;
        }
      }

      // B2: fallback xóa theo cặp nếu cần
      if (!done) {
        final n = await ds.deleteByPair(
          caregiverId: a.caregiverId,
          customerId: a.customerId,
        );
        if (n <= 0) {
          _showErrorSnackBar('Không có assignment nào để hủy');
          return;
        }
      }

      if (!mounted) return;
      _showSuccessSnackBar('Đã hủy gán caregiver');
      await _refreshAssignments();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi hủy gán: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- phần _assignCaregiver: thêm refresh sau khi gán ----
  Future<void> _assignCaregiver({
    required String caregiverId,
    String? notes,
  }) async {
    final customerId = context.read<AuthProvider>().currentUserId;
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (customerId == null || customerId.isEmpty) {
      _showErrorSnackBar('Không xác định được customer hiện tại');
      return;
    }
    if (!uuidRe.hasMatch(caregiverId)) {
      _showErrorSnackBar("ID caregiver không hợp lệ: '$caregiverId'");
      return;
    }

    setState(() => _loading = true);
    try {
      final ds = AssignmentsRemoteDataSource();
      await ds.create(
        caregiverId: caregiverId,
        customerId: customerId,
        notes: notes,
      );
      if (!mounted) return;
      _showSuccessSnackBar('Đã gán caregiver cho bạn thành công');
      setState(() {
        _searchController.clear();
        _searchResults = const [];
      });
      await _refreshAssignments();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi gán: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndAssign(User caregiver) async {
    _notesController.clear();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                height: 4,
                width: 48,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caregiver.fullName.isNotEmpty
                                ? caregiver.fullName
                                : (caregiver.username.isNotEmpty
                                      ? caregiver.username
                                      : caregiver.id),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _darkBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caregiver.email.isNotEmpty
                                ? caregiver.email
                                : (caregiver.role.isNotEmpty
                                      ? caregiver.role
                                      : ''),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Notes input
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  hintText: 'Ví dụ: Ca trực tối / Chăm sóc hàng ngày...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Huỷ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text(
                        'Xác nhận gán',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;
    await _assignCaregiver(
      caregiverId: caregiver.id,
      notes: _notesController.text.trim(),
    );
  }

  // Future<void> _assignCaregiver({
  //   required String caregiverId,
  //   String? notes,
  // }) async {
  //   final customerId = context.read<AuthProvider>().currentUserId;

  //   final uuidRe = RegExp(
  //     r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  //   );

  //   if (customerId == null || customerId.isEmpty) {
  //     _showErrorSnackBar('Không xác định được customer hiện tại');
  //     return;
  //   }
  //   if (!uuidRe.hasMatch(caregiverId)) {
  //     _showErrorSnackBar("ID caregiver không hợp lệ: '$caregiverId'");
  //     return;
  //   }

  //   setState(() => _loading = true);
  //   try {
  //     final ds = AssignmentsRemoteDataSource();
  //     await ds.create(
  //       caregiverId: caregiverId,
  //       customerId: customerId,
  //       notes: notes,
  //     );
  //     if (!mounted) return;
  //     _showSuccessSnackBar('Đã gán caregiver cho bạn thành công');
  //     setState(() {
  //       _searchController.clear();
  //       _searchResults = const [];
  //     });
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showErrorSnackBar('Lỗi gán: $e');
  //   } finally {
  //     if (mounted) setState(() => _loading = false);
  //   }
  // }

  // ...existing code...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gán Caregiver',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header section with search
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Nhập username, email, họ tên caregiver...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _primaryBlue,
                        size: 24,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _onSearchChanged(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gõ đúng thông tin để thấy caregiver tương ứng. Chạm vào để xác nhận gán.',
                  style: TextStyle(
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search results
                  if (_searchResults.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _lightBlue,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: _primaryBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kết quả tìm kiếm (${_searchResults.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _darkBlue,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (_, i) {
                              final u = _searchResults[i];
                              final title = u.fullName.isNotEmpty
                                  ? u.fullName
                                  : (u.username.isNotEmpty ? u.username : u.id);
                              final subtitle = [
                                if (u.email.isNotEmpty) u.email,
                                if (u.role.isNotEmpty) 'Role: ${u.role}',
                              ].join(' • ');

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accentBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _lightBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: _primaryBlue,
                                  ),
                                ),
                                onTap: () => _confirmAndAssign(u),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Current assignments
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _lightBlue,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assignment_ind,
                                  color: _primaryBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Caregiver được gán (${_assignments.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _darkBlue,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: _primaryBlue,
                                    ),
                                  )
                                : _assignments.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assignment_late_outlined,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Chưa có caregiver nào được gán',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Hãy tìm kiếm và gán caregiver phù hợp',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: _assignments.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    itemBuilder: (_, i) {
                                      final a = _assignments[i];
                                      final active = a
                                          .isActive; // Chỉ dùng is_active từ API

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _accentBlue,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          'Caregiver: ${a.caregiverId}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Assigned: ${_formatIso(a.assignedAt)}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (a.unassignedAt != null &&
                                                a.unassignedAt!.isNotEmpty)
                                              Text(
                                                'Unassigned: ${_formatIso(a.unassignedAt)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            Text(
                                              active
                                                  ? 'Status: Active'
                                                  : 'Status: Inactive',
                                              style: TextStyle(
                                                color: active
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: active
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.link_off,
                                                ),
                                                tooltip: 'Hủy gán',
                                                onPressed: () => _unassign(a),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
