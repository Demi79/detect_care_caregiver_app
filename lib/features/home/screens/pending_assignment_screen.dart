import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/home/screens/home_screen.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/widgets/auth_gate.dart';

class PendingAssignmentsScreen extends StatefulWidget {
  const PendingAssignmentsScreen({super.key});

  @override
  State<PendingAssignmentsScreen> createState() =>
      _PendingAssignmentsScreenState();
}

class _PendingAssignmentsScreenState extends State<PendingAssignmentsScreen> {
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _lightBlue = Color(0xFFE3F2FD);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _backgroundColor = Colors.white;

  late final AssignmentsRemoteDataSource _dataSource;
  late Future<List<Assignment>> _futureAssignments;

  @override
  void initState() {
    super.initState();
    _dataSource = AssignmentsRemoteDataSource();
    _futureAssignments = _dataSource.listPending(status: 'pending');
  }

  Future<void> _reload() async {
    setState(() {
      _futureAssignments = _dataSource.listPending(status: 'pending');
    });
  }

  Future<void> _handleAction(String id, bool accept) async {
    try {
      if (accept) {
        await _dataSource.accept(id);

        final auth = context.read<AuthProvider>();
        await auth.reloadUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Assignment đã được accept"),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        await _dataSource.reject(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Assignment đã bị reject"),
              backgroundColor: Colors.orange[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          _reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi: $e"),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        title: const Text("Yêu cầu đang chờ xử lý"),
        centerTitle: true,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Container(
                    //   width: double.infinity,
                    //   padding: const EdgeInsets.all(16),
                    //   decoration: BoxDecoration(
                    //     color: _lightBlue,
                    //     borderRadius: BorderRadius.circular(12),
                    //     // boxShadow: [
                    //     //   BoxShadow(
                    //     //     color: Colors.black.withOpacity(0.05),
                    //     //     blurRadius: 8,
                    //     //     offset: const Offset(0, 4),
                    //     //   ),
                    //     // ],
                    //   ),
                    // child: Row(
                    //   children: [
                    //     Container(
                    //       padding: const EdgeInsets.all(6),
                    //       decoration: BoxDecoration(
                    //         color: _accentBlue,
                    //         borderRadius: BorderRadius.circular(12),
                    //       ),
                    //       child: const Icon(
                    //         Icons.assignment_outlined,
                    //         color: Colors.white,
                    //         size: 24,
                    //       ),
                    //     ),
                    //     const SizedBox(width: 16),

                    //     // const Expanded(
                    //     //   child: Column(
                    //     //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     //     children: [
                    //     //       Text(
                    //     //         'Yêu cầu đang chờ xử lý',
                    //     //         style: TextStyle(
                    //     //           fontWeight: FontWeight.bold,
                    //     //           fontSize: 18,
                    //     //           color: _darkBlue,
                    //     //         ),
                    //     //         overflow: TextOverflow.ellipsis,
                    //     //       ),
                    //     //       SizedBox(height: 4),
                    //     //       Text(
                    //     //         'Chấp nhận để bắt đầu chăm sóc, hoặc từ chối nếu không phù hợp.',
                    //     //         style: TextStyle(
                    //     //           color: Color.fromRGBO(0, 0, 0, 0.7),
                    //     //           fontSize: 14,
                    //     //         ),
                    //     //       ),
                    //     //     ],
                    //     //   ),
                    //     // ),
                    //   ],
                    // ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  // foregroundColor: Colors.white,
                  // backgroundColor: _darkBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tải lại', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),

          // Nội dung chính
          Expanded(
            child: FutureBuilder<List<Assignment>>(
              future: _futureAssignments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _primaryBlue,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Lỗi: ${snapshot.error}",
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    color: _primaryBlue,
                    backgroundColor: Colors.white,
                    child: ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Bạn hiện chưa có yêu cầu đang chờ xử lý.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Text(
                              //   "Kéo xuống để làm mới hoặc nhấn nút Reload.",
                              //   style: TextStyle(
                              //     fontSize: 14,
                              //     color: Colors.grey.shade600,
                              //   ),
                              //   textAlign: TextAlign.center,
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  color: _primaryBlue,
                  backgroundColor: Colors.white,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: data.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = data[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF64748B).withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _lightBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Khách hàng: ${a.customerName ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _darkBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Details
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.people_outline,
                                label: "Username",
                                value: a.customerUsername ?? a.customerId,
                              ),
                              _buildDetailRow(
                                icon: Icons.verified_user_outlined,
                                label: "Status",
                                value: a.status ?? '',
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: a.isActive
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                label: "Active",
                                value: a.isActive ? "Yes" : "No",
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.access_time,
                                label: "Assigned at",
                                value: a.assignedAt,
                              ),
                              if (a.notes != null && a.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: Icons.note_outlined,
                                  label: "Notes",
                                  value: a.notes!,
                                ),
                              ],
                              const SizedBox(height: 20),

                              // Actions
                              if (a.status == "pending")
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _handleAction(
                                          a.assignmentId,
                                          false,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFFEF4444),
                                          ),
                                          foregroundColor: const Color(
                                            0xFFEF4444,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text(
                                          "Reject",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            _handleAction(a.assignmentId, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text(
                                          "Accept",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
