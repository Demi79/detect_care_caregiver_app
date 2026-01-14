// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/home/screens/home_screen.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/widgets/auth_gate.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';

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
      // if (accept) {
      //   try {
      //     final beforeToken = await AuthStorage.getAccessToken();
      //     final beforeUid = await AuthStorage.getUserId();
      //     print(
      //       '[PendingAssignments] BEFORE accept: token=$beforeToken userId=$beforeUid',
      //     );
      //   } catch (e) {
      //     print(
      //       '[PendingAssignments] BEFORE accept: failed to read AuthStorage: $e',
      //     );
      //   }

      //   final accepted = await _dataSource.accept(id);
      //   print('[PendingAssignments] accept returned: ${accepted.assignmentId}');

      //   // If server returned the accepted assignment already active, navigate
      //   // immediately to Home — avoid waiting for user record propagation.
      //   if (accepted.isActive) {
      //     try {
      //       AppEvents.instance.notifyEventsChanged();
      //     } catch (_) {}
      //     if (!mounted) return;
      //     Navigator.of(context).pushAndRemoveUntil(
      //       MaterialPageRoute(builder: (_) => const HomeScreen()),
      //       (route) => false,
      //     );
      //     return;
      //   }

      //   // Diagnostic: print accepted assignment details to help debug activation timing
      //   try {
      //     print(
      //       '[PendingAssignments] accepted details: status=${accepted.status} isActive=${accepted.isActive} assignedAt=${accepted.assignedAt}',
      //     );
      //   } catch (e) {
      //     print('[PendingAssignments] failed to print accepted details: $e');
      //   }

      //   try {
      //     final afterToken = await AuthStorage.getAccessToken();
      //     final afterUid = await AuthStorage.getUserId();
      //     print(
      //       '[PendingAssignments] AFTER accept: token=$afterToken userId=$afterUid',
      //     );
      //   } catch (e) {
      //     print(
      //       '[PendingAssignments] AFTER accept: failed to read AuthStorage: $e',
      //     );
      //   }

      //   final auth = context.read<AuthProvider>();

      //   bool becameAuthenticated = false;
      //   final currentUserId = context.read<AuthProvider>().currentUserId;
      //   try {
      //     for (var attempt = 0; attempt < 8; attempt++) {
      //       print('[PendingAssignments] reloadUser attempt #$attempt');
      //       try {
      //         await auth.reloadUser();
      //       } catch (e) {
      //         print('[PendingAssignments] reloadUser failed: $e');
      //       }
      //       // Diagnostic: log auth status and user assignment flag after each reload
      //       try {
      //         print(
      //           '[PendingAssignments] post-reload auth.status=${auth.status} userId=${auth.currentUserId} user.isAssigned=${auth.user?.isAssigned}',
      //         );
      //       } catch (_) {}

      //       if (auth.status == AuthStatus.authenticated) {
      //         becameAuthenticated = true;
      //         break;
      //       }
      //       // If reload didn't flip the auth flag, also query assignments
      //       // endpoint directly to see if the accepted assignment became active.
      //       try {
      //         if (currentUserId != null && currentUserId.isNotEmpty) {
      //           final assignDs = AssignmentsRemoteDataSource();
      //           // Ask for active accepted assignments specifically to detect
      //           // whether the accepted assignment has been activated on the server.
      //           final acceptedList = await assignDs.listPending(
      //             status: 'accepted',
      //             isActive: true,
      //           );

      //           // First try matching by caregiver id + active flag
      //           var mine = acceptedList.any(
      //             (a) => a.caregiverId == currentUserId && a.isActive,
      //           );

      //           // If not found, also try to match by the assignment id we just
      //           // received from the accept() call (some backends return the
      //           // assignment but without caregiver mapping until propagation).
      //           if (!mine) {
      //             mine = acceptedList.any(
      //               (a) => a.assignmentId == accepted.assignmentId,
      //             );
      //           }

      //           print(
      //             '[PendingAssignments] direct assignments check -> mineActive=$mine (count=${acceptedList.length})',
      //           );
      //           if (mine) {
      //             becameAuthenticated = true;
      //             break;
      //           }
      //         }
      //       } catch (e) {
      //         print('[PendingAssignments] assignments direct check failed: $e');
      //       }

      //       await Future.delayed(const Duration(milliseconds: 700));
      //     }
      //   } catch (e) {
      //     print('[PendingAssignments] reload loop error: $e');
      //   }

      //   try {
      //     AppEvents.instance.notifyEventsChanged();
      //   } catch (_) {}

      //   if (!mounted) return;

      //   if (becameAuthenticated) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: const Text("Yêu cầu đã được chấp nhận"),
      //         backgroundColor: Colors.green[600],
      //         behavior: SnackBarBehavior.floating,
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(12),
      //         ),
      //       ),
      //     );

      //     Navigator.of(context).pushAndRemoveUntil(
      //       MaterialPageRoute(builder: (_) => const HomeScreen()),
      //       (route) => false,
      //     );
      //   } else {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: const Text(
      //           "Yêu cầu đã được chấp nhận (đang chờ kích hoạt). Vui lòng chờ hoặc thử làm mới.",
      //         ),
      //         backgroundColor: Colors.green[600],
      //         behavior: SnackBarBehavior.floating,
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(12),
      //         ),
      //       ),
      //     );
      //     _reload();
      //   }
      // } else {
      //   try {
      //     final beforeToken = await AuthStorage.getAccessToken();
      //     final beforeUid = await AuthStorage.getUserId();
      //     print(
      //       '[PendingAssignments] BEFORE reject: token=$beforeToken userId=$beforeUid',
      //     );
      //   } catch (e) {
      //     print(
      //       '[PendingAssignments] BEFORE reject: failed to read AuthStorage: $e',
      //     );
      //   }

      //   final rejected = await _dataSource.reject(id);
      //   print('[PendingAssignments] reject returned: ${rejected.assignmentId}');

      //   try {
      //     final afterToken = await AuthStorage.getAccessToken();
      //     final afterUid = await AuthStorage.getUserId();
      //     print(
      //       '[PendingAssignments] AFTER reject: token=$afterToken userId=$afterUid',
      //     );
      //   } catch (e) {
      //     print(
      //       '[PendingAssignments] AFTER reject: failed to read AuthStorage: $e',
      //     );
      //   }
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: const Text("Yêu cầu đã bị từ chối"),
      //         backgroundColor: Colors.orange[600],
      //         behavior: SnackBarBehavior.floating,
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(12),
      //         ),
      //       ),
      //     );
      //     _reload();
      //   }
      // }
      if (accept) {
        final accepted = await _dataSource.accept(id);
        print('[PendingAssignments] accept returned: ${accepted.assignmentId}');
        print(
          '[PendingAssignments] accepted status=${accepted.status} isActive=${accepted.isActive}',
        );

        final auth = context.read<AuthProvider>();

        if (accepted.isActive || accepted.status.toLowerCase() == 'active') {
          await auth.reloadUser();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
          return;
        }

        bool becameActive = false;
        for (int attempt = 0; attempt < 6; attempt++) {
          await Future.delayed(const Duration(milliseconds: 700));
          await auth.reloadUser();
          print(
            '[PendingAssignments] reloadUser attempt #$attempt: ${auth.user?.isAssigned}',
          );
          if (auth.status == AuthStatus.authenticated ||
              auth.user?.isAssigned == true) {
            becameActive = true;
            break;
          }
        }

        if (becameActive) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Lời mời đã được chấp nhận thành công 🎉'),
              backgroundColor: Colors.green[600],
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Yêu cầu đã được chấp nhận, đang chờ kích hoạt...',
              ),
              backgroundColor: Colors.orange[600],
            ),
          );
          _reload();
        }
      }
    } catch (e, st) {
      print('[PendingAssignments] _handleAction error: $e\n$st');
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
        title: const Text(
          "Lời mời đang chờ ",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                try {
                  context.read<PermissionsProvider>().reset();
                } catch (_) {}
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
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    SizedBox(height: 12),

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
                                "Bạn hiện chưa có lời mời nào.",
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
                                label: "Tên người dùng",
                                value: a.customerUsername ?? a.customerId,
                              ),
                              _buildDetailRow(
                                icon: Icons.verified_user_outlined,
                                label: "Trạng thái",
                                value: _translateStatus(a.status),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: a.isActive
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                label: "Đang hoạt động",
                                value: a.isActive ? "Có" : "Không",
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.access_time,
                                label: "Được mời lúc",
                                value: _formatAssignedAt(a.assignedAt),
                              ),
                              if (a.notes != null && a.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: Icons.note_outlined,
                                  label: "Ghi chú",
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
                                          "Từ chối",
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
                                          "Chấp nhận",
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

  String _formatAssignedAt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final MM = dt.month.toString().padLeft(2, '0');
      final yy = dt.year % 100;
      final yyS = yy.toString().padLeft(2, '0');
      return '$hh:$mm $dd/$MM/$yyS';
    } catch (_) {
      return iso;
    }
  }

  String _translateStatus(String? status) {
    if (status == null || status.isEmpty) return '';
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
        return 'Đang chờ';
      case 'accepted':
        return 'Đã chấp nhận';
      case 'rejected':
      case 'declined':
        return 'Đã từ chối';
      case 'active':
        return 'Đang hoạt động';
      case 'inactive':
        return 'Không hoạt động';
      default:
        // fallback to BackendEnums mapping for danger/warning/normal
        return BackendEnums.statusToVietnamese(status);
    }
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
