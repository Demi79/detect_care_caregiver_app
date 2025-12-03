import 'dart:async';
import 'dart:convert';

import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/assignments_constants.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/assignment_list_item.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/confirm_assignment_sheet.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/edit_permissions_sheet.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/search_results_list.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/caregivers/data/caregivers_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/utils/caregiver_resolver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentsScreen extends StatefulWidget {
  final bool embedInParent;

  const AssignmentsScreen({super.key, this.embedInParent = false});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsLifecycleObserver extends WidgetsBindingObserver {
  final FutureOr<void> Function() onResume;
  _AssignmentsLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      try {
        onResume();
      } catch (_) {
        // ignore callback errors here
      }
    }
  }
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  bool _syncing = false;

  late final WidgetsBindingObserver _lifecycleObserver;
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _debounce;
  bool _loading = false;

  List<User> _searchResults = const [];
  List<Assignment> _assignments = const [];

  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();

    _lifecycleObserver = _AssignmentsLifecycleObserver(
      onResume: () async {
        await _maybeAutoSync();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAssignments().then((_) async {
        await _maybeAutoSync();
      });
    });
  }

  void _showEditPermissionsSheet(Assignment a, int index) async {
    final ctx = context;

    Assignment assignmentForEdit = a;

    try {
      if (a.caregiverId.isNotEmpty && a.customerId.isNotEmpty) {
        final spDs = SharedPermissionsRemoteDataSource();
        final cp = await spDs.getPermission(
          customerId: a.customerId,
          caregiverId: a.caregiverId,
        );
        if (cp != null) {
          final serverMap = <String, dynamic>{};
          final pj = cp.toJson();
          pj.forEach((k, v) => serverMap[k] = v);

          assignmentForEdit = Assignment(
            assignmentId: a.assignmentId,
            caregiverId: a.caregiverId,
            customerId: a.customerId,
            isActive: a.isActive,
            assignedAt: a.assignedAt,
            unassignedAt: a.unassignedAt,
            notes: a.notes,
            assignmentType: a.assignmentType,
            status: a.status,
            createdAt: a.createdAt,
            updatedAt: a.updatedAt,
            caregiverName: a.caregiverName,
            caregiverPhone: a.caregiverPhone,
            caregiverEmail: a.caregiverEmail,
            caregiverSpecialization: a.caregiverSpecialization,
            customerName: a.customerName,
            sharedPermissions: serverMap,
          );
        }
      }
    } catch (e, st) {
      AppLogger.apiError(
        '[Assignments] Failed to fetch server permission',
        e,
        st,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'assignment_shared_permissions_${a.assignmentId}';
      final s = prefs.getString(key);
      if (s != null && s.isNotEmpty) {
        final decoded = json.decode(s) as Map<String, dynamic>;
        final map = <String, dynamic>{};
        decoded.forEach((k, v) {
          map[k.toString()] = v;
        });

        final merged = <String, dynamic>{};
        if (assignmentForEdit.sharedPermissions != null) {
          merged.addAll(assignmentForEdit.sharedPermissions!);
        }
        merged.addAll(map);

        assignmentForEdit = Assignment(
          assignmentId: assignmentForEdit.assignmentId,
          caregiverId: assignmentForEdit.caregiverId,
          customerId: assignmentForEdit.customerId,
          isActive: assignmentForEdit.isActive,
          assignedAt: assignmentForEdit.assignedAt,
          unassignedAt: assignmentForEdit.unassignedAt,
          notes: assignmentForEdit.notes,
          assignmentType: assignmentForEdit.assignmentType,
          status: assignmentForEdit.status,
          createdAt: assignmentForEdit.createdAt,
          updatedAt: assignmentForEdit.updatedAt,
          caregiverName: assignmentForEdit.caregiverName,
          caregiverPhone: assignmentForEdit.caregiverPhone,
          caregiverEmail: assignmentForEdit.caregiverEmail,
          caregiverSpecialization: assignmentForEdit.caregiverSpecialization,
          customerName: assignmentForEdit.customerName,
          sharedPermissions: merged,
        );
      }
    } catch (_) {
      // ignore prefs errors
    }

    final result = await showModalBottomSheet<SharedPermissions?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          EditPermissionsSheet(assignment: assignmentForEdit, index: index),
    );

    if (result != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'assignment_shared_permissions_${a.assignmentId}';
        final payload = json.encode({
          'stream_view': result.streamView,
          'alert_read': result.alertRead,
          'alert_ack': result.alertAck,
          'log_access_days': result.logAccessDays,
          'report_access_days': result.reportAccessDays,
          'notification_channel': result.notificationChannel,
          'profile_view': result.profileView,
        });
        AppLogger.i(
          '[Assignments] Persisting local permissions (persist-first) -> key=$key payload=${payload.length}chars',
        );
        await prefs.setString(key, payload);
      } catch (e, st) {
        AppLogger.apiError(
          '[Assignments] Failed to persist local permissions (persist-first)',
          e,
          st,
        );
      }

      try {
        final customerId = ctx.read<AuthProvider>().currentUserId;
        if (customerId != null && customerId.isNotEmpty) {
          final ds = SharedPermissionsRemoteDataSource();

          final name = a.caregiverName ?? '';
          final phone = a.caregiverPhone ?? '';

          final caregiversDs = CaregiversRemoteDataSource();

          if (a.caregiverId.isNotEmpty) {
            final caregiverId = a.caregiverId;
            final caregiverUsername = a.caregiverEmail ?? '';
            final caregiverPhone = a.caregiverPhone ?? '';
            final caregiverFullName = a.caregiverName ?? '';

            final serverResult = await ds.updatePermissions(
              customerId: customerId,
              caregiverId: caregiverId,
              caregiverUsername: caregiverUsername,
              caregiverPhone: caregiverPhone,
              caregiverFullName: caregiverFullName,
              permissions: result,
            );

            final newAssignment = Assignment(
              assignmentId: a.assignmentId,
              caregiverId: caregiverId,
              customerId: a.customerId,
              isActive: a.isActive,
              assignedAt: a.assignedAt,
              unassignedAt: a.unassignedAt,
              notes: a.notes,
              assignmentType: a.assignmentType,
              status: a.status,
              createdAt: a.createdAt,
              updatedAt: a.updatedAt,
              caregiverName: () {
                final cand = serverResult.caregiverFullName.toString();
                final existing = a.caregiverName ?? '';
                final looksLikeUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\$',
                ).hasMatch(cand);
                if (cand.trim().isEmpty) {
                  return existing.isNotEmpty ? existing : (a.caregiverId);
                }
                if (looksLikeUuid && existing.trim().isNotEmpty) {
                  return existing;
                }
                return cand;
              }(),
              caregiverPhone: serverResult.caregiverPhone,
              caregiverEmail: a.caregiverEmail,
              caregiverSpecialization: a.caregiverSpecialization,
              customerName: a.customerName,
              sharedPermissions: {
                'stream_view': serverResult.permissions.streamView,
                'alert_read': serverResult.permissions.alertRead,
                'alert_ack': serverResult.permissions.alertAck,
                'profile_view': serverResult.permissions.profileView,
              },
            );

            if (!mounted) return;
            setState(() {
              final list = _assignments.toList();
              list[index] = newAssignment;
              _assignments = list;
            });

            try {
              final prefs = await SharedPreferences.getInstance();
              final key = 'assignment_shared_permissions_${a.assignmentId}';
              if (prefs.containsKey(key)) {
                await prefs.remove(key);
                AppLogger.i(
                  '[Assignments] Removed local staged permissions after server success -> $key',
                );
              }
            } catch (e, st) {
              AppLogger.apiError(
                '[Assignments] Failed to remove local staged permissions after server success',
                e,
                st,
              );
            }

            _showSuccessSnackBar('Đã cập nhật quyền chia sẻ (server)', ctx);
            return;
          }

          final resolver = await resolveCaregiver(
            name: name,
            phone: phone,
            search: (q) => caregiversDs.search(keyword: q),
          );
          if (resolver.candidates != null && resolver.candidates!.isNotEmpty) {
            final pick = await showDialog<User?>(
              context: ctx,
              builder: (dctx) {
                return SimpleDialog(
                  title: const Text('Chọn người chăm sóc phù hợp'),
                  children: resolver.candidates!
                      .map(
                        (u) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(dctx, u),
                          child: ListTile(
                            title: Text(
                              u.fullName.isNotEmpty ? u.fullName : u.username,
                            ),
                            subtitle: Text(
                              u.phone.isNotEmpty ? u.phone : u.email,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            );

            if (pick != null) {
              print(
                '[Assignments] updatePermissions payload (manual pick): ${json.encode({
                  'customerId': customerId,
                  'caregiverId': pick.id,
                  'caregiverUsername': pick.username,
                  'caregiverPhone': pick.phone.isNotEmpty ? pick.phone : phone,
                  'caregiverFullName': pick.fullName.isNotEmpty ? pick.fullName : pick.username,
                  'permissions': {'stream_view': result.streamView, 'alert_read': result.alertRead, 'alert_ack': result.alertAck, 'log_access_days': result.logAccessDays, 'report_access_days': result.reportAccessDays, 'notification_channel': result.notificationChannel, 'profile_view': result.profileView},
                })}',
              );
              final serverResult = await ds.updatePermissions(
                customerId: customerId,
                caregiverId: pick.id,
                caregiverUsername: pick.username,
                caregiverPhone: pick.phone.isNotEmpty ? pick.phone : phone,
                caregiverFullName: pick.fullName.isNotEmpty
                    ? pick.fullName
                    : pick.username,
                permissions: result,
              );

              final newAssignment = Assignment(
                assignmentId: a.assignmentId,
                caregiverId: pick.id,
                customerId: a.customerId,
                isActive: a.isActive,
                assignedAt: a.assignedAt,
                unassignedAt: a.unassignedAt,
                notes: a.notes,
                assignmentType: a.assignmentType,
                status: a.status,
                createdAt: a.createdAt,
                updatedAt: a.updatedAt,
                caregiverName: () {
                  final cand = serverResult.caregiverFullName.toString();
                  final existing = a.caregiverName ?? '';
                  final looksLikeUuid = RegExp(
                    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\$',
                  ).hasMatch(cand);
                  if (cand.trim().isEmpty) {
                    return existing.isNotEmpty ? existing : (a.caregiverId);
                  }
                  if (looksLikeUuid && existing.trim().isNotEmpty) {
                    return existing;
                  }
                  return cand;
                }(),
                caregiverPhone: serverResult.caregiverPhone,
                caregiverEmail: a.caregiverEmail,
                caregiverSpecialization: a.caregiverSpecialization,
                customerName: a.customerName,
                sharedPermissions: {
                  'stream_view': serverResult.permissions.streamView,
                  'alert_read': serverResult.permissions.alertRead,
                  'alert_ack': serverResult.permissions.alertAck,
                  'profile_view': serverResult.permissions.profileView,
                },
              );

              if (!mounted) return;
              setState(() {
                final list = _assignments.toList();
                list[index] = newAssignment;
                _assignments = list;
              });
              try {
                final prefs = await SharedPreferences.getInstance();
                final key = 'assignment_shared_permissions_${a.assignmentId}';
                if (prefs.containsKey(key)) {
                  await prefs.remove(key);
                  AppLogger.i(
                    '[Assignments] Removed local staged permissions after server success -> $key',
                  );
                }
              } catch (e, st) {
                AppLogger.apiError(
                  '[Assignments] Failed to remove local staged permissions after server success',
                  e,
                  st,
                );
              }

              _showSuccessSnackBar('Đã cập nhật quyền chia sẻ (server)', ctx);
              return;
            }
          } else if (resolver.resolved != null) {
            final r = resolver.resolved!;
            print(
              '[Assignments] updatePermissions payload (resolved): ${json.encode({
                'customerId': customerId,
                'caregiverId': r.caregiverId,
                'caregiverUsername': r.caregiverUsername,
                'caregiverPhone': r.caregiverPhone ?? '',
                'caregiverFullName': r.caregiverFullName,
                'permissions': {'stream_view': result.streamView, 'alert_read': result.alertRead, 'alert_ack': result.alertAck, 'log_access_days': result.logAccessDays, 'report_access_days': result.reportAccessDays, 'notification_channel': result.notificationChannel, 'profile_view': result.profileView},
              })}',
            );
            final serverResult = await ds.updatePermissions(
              customerId: customerId,
              caregiverId: r.caregiverId,
              caregiverUsername: r.caregiverUsername,
              caregiverPhone: r.caregiverPhone ?? '',
              caregiverFullName: r.caregiverFullName,
              permissions: result,
            );

            final newAssignment = Assignment(
              assignmentId: a.assignmentId,
              caregiverId: r.caregiverId,
              customerId: a.customerId,
              isActive: a.isActive,
              assignedAt: a.assignedAt,
              unassignedAt: a.unassignedAt,
              notes: a.notes,
              assignmentType: a.assignmentType,
              status: a.status,
              createdAt: a.createdAt,
              updatedAt: a.updatedAt,
              caregiverName: () {
                final cand = serverResult.caregiverFullName.toString();
                final existing = a.caregiverName ?? '';
                final looksLikeUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\$',
                ).hasMatch(cand);
                if (cand.trim().isEmpty) {
                  return existing.isNotEmpty ? existing : (a.caregiverId);
                }
                if (looksLikeUuid && existing.trim().isNotEmpty) {
                  return existing;
                }
                return cand;
              }(),
              caregiverPhone: serverResult.caregiverPhone,
              caregiverEmail: a.caregiverEmail,
              caregiverSpecialization: a.caregiverSpecialization,
              customerName: a.customerName,
              sharedPermissions: {
                'stream_view': serverResult.permissions.streamView,
                'alert_read': serverResult.permissions.alertRead,
                'alert_ack': serverResult.permissions.alertAck,
                'profile_view': serverResult.permissions.profileView,
              },
            );

            if (!mounted) return;
            setState(() {
              final list = _assignments.toList();
              list[index] = newAssignment;
              _assignments = list;
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              final key = 'assignment_shared_permissions_${a.assignmentId}';
              if (prefs.containsKey(key)) {
                await prefs.remove(key);
                AppLogger.i(
                  '[Assignments] Removed local staged permissions after server success -> $key',
                );
              }
            } catch (e, st) {
              AppLogger.apiError(
                '[Assignments] Failed to remove local staged permissions after server success',
                e,
                st,
              );
            }

            _showSuccessSnackBar('Đã cập nhật quyền chia sẻ (server)', ctx);
            return;
          }
        }
      } catch (e) {
        // to update UI
      }

      final newAssignment = Assignment(
        assignmentId: a.assignmentId,
        caregiverId: a.caregiverId,
        customerId: a.customerId,
        isActive: a.isActive,
        assignedAt: a.assignedAt,
        unassignedAt: a.unassignedAt,
        notes: a.notes,
        assignmentType: a.assignmentType,
        status: a.status,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        caregiverName: a.caregiverName,
        caregiverPhone: a.caregiverPhone,
        caregiverEmail: a.caregiverEmail,
        caregiverSpecialization: a.caregiverSpecialization,
        customerName: a.customerName,
        sharedPermissions: {
          'stream_view': result.streamView,
          'alert_read': result.alertRead,
          'alert_ack': result.alertAck,
          'profile_view': result.profileView,
        },
      );

      if (!mounted) return;
      setState(() {
        final list = _assignments.toList();
        list[index] = newAssignment;
        _assignments = list;
      });

      _showSuccessSnackBar('Đã cập nhật quyền chia sẻ (local)', ctx);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _notesController.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _maybeAutoSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _syncLocalSharedPermissions(promptOnAmbiguous: false);
    } catch (e) {
      print('[Assignments] Auto-sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyLocalSharedPermissions();
    });
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
    print('\n🔍 Searching caregivers with keyword: "$keyword"');
    try {
      final ds = CaregiversRemoteDataSource();
      final list = await ds.search(keyword: keyword);
      print('✅ Found ${list.length} caregivers:');
      for (var cg in list) {
        print('   - ID: ${cg.id}, Phone: ${cg.phone}');
      }
      if (!mounted) return;
      setState(() => _searchResults = list);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi tìm người chăm sóc: $e');
    }
  }

  Future<void> _applyLocalSharedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final updated = _assignments.map((a) {
        final key = 'assignment_shared_permissions_${a.assignmentId}';
        final s = prefs.getString(key);
        if (s == null || s.isEmpty) return a;
        try {
          final decoded = json.decode(s) as Map<String, dynamic>;
          final map = <String, bool>{};
          decoded.forEach((k, v) {
            map[k.toString()] = (v == true || v == '1' || v == 'true');
          });

          return Assignment(
            assignmentId: a.assignmentId,
            caregiverId: a.caregiverId,
            customerId: a.customerId,
            isActive: a.isActive,
            assignedAt: a.assignedAt,
            unassignedAt: a.unassignedAt,
            notes: a.notes,
            assignmentType: a.assignmentType,
            status: a.status,
            createdAt: a.createdAt,
            updatedAt: a.updatedAt,
            caregiverName: a.caregiverName,
            caregiverPhone: a.caregiverPhone,
            caregiverEmail: a.caregiverEmail,
            caregiverSpecialization: a.caregiverSpecialization,
            customerName: a.customerName,
            sharedPermissions: map,
          );
        } catch (_) {
          return a;
        }
      }).toList();

      if (!mounted) return;
      setState(() => _assignments = updated);
    } catch (_) {
      // Ignore errors on rehydrate; nothing fatal.
    }
  }

  void _showErrorSnackBar(String message, [BuildContext? ctx]) {
    final c = ctx ?? context;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(c);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _showSuccessSnackBar(String message, [BuildContext? ctx]) {
    final c = ctx ?? context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(c);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AssignmentsConstants.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  Future<void> _refreshAssignments() async {
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!).inSeconds < 2) {
      print(
        '[Assignments] Recent refresh detected (<2s) — applying local overlay only',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        final applied = <Assignment>[];
        for (final a in _assignments) {
          final key = 'assignment_shared_permissions_${a.assignmentId}';
          final s = prefs.getString(key);
          if (s != null && s.isNotEmpty) {
            try {
              final decoded = json.decode(s) as Map<String, dynamic>;
              final map = <String, bool>{};
              decoded.forEach((k, v) {
                map[k.toString()] = (v == true || v == '1' || v == 'true');
              });
              applied.add(
                Assignment(
                  assignmentId: a.assignmentId,
                  caregiverId: a.caregiverId,
                  customerId: a.customerId,
                  isActive: a.isActive,
                  assignedAt: a.assignedAt,
                  unassignedAt: a.unassignedAt,
                  notes: a.notes,
                  assignmentType: a.assignmentType,
                  status: a.status,
                  createdAt: a.createdAt,
                  updatedAt: a.updatedAt,
                  caregiverName: a.caregiverName,
                  caregiverPhone: a.caregiverPhone,
                  caregiverEmail: a.caregiverEmail,
                  caregiverSpecialization: a.caregiverSpecialization,
                  customerName: a.customerName,
                  sharedPermissions: map,
                ),
              );
              continue;
            } catch (_) {
              applied.add(a);
              continue;
            }
          }
          applied.add(a);
        }
        if (!mounted) return;
        setState(() => _assignments = applied);
      } catch (_) {}
      return;
    }
    _lastRefreshAt = now;
    setState(() => _loading = true);
    try {
      final ds = AssignmentsRemoteDataSource();

      List<Assignment> list;
      try {
        list = await ds.listInvitations();
      } catch (e) {
        print(
          '[Assignments] listInvitations() failed: $e — attempting listByCustomer fallback',
        );
        final customerId = context.read<AuthProvider>().currentUserId;
        if (customerId == null || customerId.isEmpty) rethrow;
        list = await ds.listByCustomer(
          customerId: customerId,
          activeOnly: false,
        );
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final applied = <Assignment>[];
        for (final a in list) {
          final key = 'assignment_shared_permissions_${a.assignmentId}';
          final s = prefs.getString(key);
          if (s != null && s.isNotEmpty) {
            try {
              print(
                '[Assignments] Applying local permissions for ${a.assignmentId}',
              );
              final decoded = json.decode(s) as Map<String, dynamic>;
              final map = <String, bool>{};
              decoded.forEach((k, v) {
                map[k.toString()] = (v == true || v == '1' || v == 'true');
              });
              applied.add(
                Assignment(
                  assignmentId: a.assignmentId,
                  caregiverId: a.caregiverId,
                  customerId: a.customerId,
                  isActive: a.isActive,
                  assignedAt: a.assignedAt,
                  unassignedAt: a.unassignedAt,
                  notes: a.notes,
                  assignmentType: a.assignmentType,
                  status: a.status,
                  createdAt: a.createdAt,
                  updatedAt: a.updatedAt,
                  caregiverName: a.caregiverName,
                  caregiverPhone: a.caregiverPhone,
                  caregiverEmail: a.caregiverEmail,
                  caregiverSpecialization: a.caregiverSpecialization,
                  customerName: a.customerName,
                  sharedPermissions: map,
                ),
              );
              continue;
            } catch (e) {
              print(
                '[Assignments] Failed to parse local permissions for ${a.assignmentId}: $e',
              );
              applied.add(a);
              continue;
            }
          }
          applied.add(a);
        }
        if (!mounted) return;
        setState(() => _assignments = applied);
      } catch (e) {
        print('[Assignments] Error applying local permissions: $e');
      }
      print('✅ Found ${list.length} assignments:');
      for (var a in list) {
        print('   - AssignID: ${a.assignmentId}');
        print('     CaregiverID: ${a.caregiverId}');
        print('     Active: ${a.isActive}');
        print('     Assigned: ${a.assignedAt}');
      }
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi tải danh sách người chăm sóc đã gán: $e');
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
        if (a.caregiverId.isEmpty || a.customerId.isEmpty) {
          _showErrorSnackBar(
            'Không có đủ thông tin để hủy gán (thiếu caregiver/customer id)',
          );
          return;
        }

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
      _showSuccessSnackBar('Đã hủy gán người chăm sóc');
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
    final ctx = context;
    final customerId = ctx.read<AuthProvider>().currentUserId;
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
      _showSuccessSnackBar('Đã gán người chăm sóc cho bạn thành công');
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
      backgroundColor: AssignmentsConstants.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ConfirmAssignmentSheet(
        caregiver: caregiver,
        notesController: _notesController,
      ),
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

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: AssignmentsConstants.primaryBlue,
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
                    hintText:
                        'Nhập tên người dùng, email, họ tên người chăm sóc...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AssignmentsConstants.primaryBlue,
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
                'Gõ đúng thông tin để thấy người chăm sóc tương ứng. Chạm vào để xác nhận gán.',
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_searchResults.isNotEmpty)
                          SearchResultsList(
                            searchResults: _searchResults,
                            onAssign: _confirmAndAssign,
                          ),
                        _buildAssignmentsSection(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedInParent) {
      return Container(
        color: AssignmentsConstants.backgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AssignmentsConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gán người chăm sóc',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AssignmentsConstants.primaryBlue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'sync') {
                await _syncLocalSharedPermissions(promptOnAmbiguous: true);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'sync',
                child: Text('Đồng bộ chỉnh sửa'),
              ),
            ],
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildAssignmentsSection() {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AssignmentsConstants.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_ind,
                  color: AssignmentsConstants.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Người chăm sóc được mời (${_assignments.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AssignmentsConstants.darkBlue,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildAssignmentsBody(),
        ],
      ),
    );
  }

  Widget _buildAssignmentsBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: AssignmentsConstants.primaryBlue,
          ),
        ),
      );
    }

    if (_assignments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_late_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có người chăm sóc nào được gán',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy tìm kiếm và gán người chăm sóc phù hợp',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _assignments.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) {
        final a = _assignments[i];
        return AssignmentListItem(
          assignment: a,
          index: i,
          onEditPermissions: _showEditPermissionsSheet,
          onUnassign: _unassign,
        );
      },
    );
  }

  Future<void> _syncLocalSharedPermissions({
    bool promptOnAmbiguous = false,
  }) async {
    final ctx = context;
    final customerId = ctx.read<AuthProvider>().currentUserId;
    if (customerId == null || customerId.isEmpty) {
      _showErrorSnackBar('Không xác định được customer hiện tại', ctx);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('assignment_shared_permissions_'))
        .toList();
    AppLogger.i(
      '[Assignments] Local shared-permissions keys found=${keys.length}: ${keys.join(', ')}',
    );
    if (keys.isEmpty) {
      AppLogger.i('[Assignments] No local permission edits to sync');

      if (promptOnAmbiguous) {
        _showSuccessSnackBar('Không có chỉnh sửa quyền cần đồng bộ', ctx);
      }
      return;
    }

    try {
      for (final k in keys) {
        final s = prefs.getString(k);
        final present = s != null;
        final len = s?.length ?? 0;
        final preview = (s != null && s.length > 200)
            ? '${s.substring(0, 200)}...'
            : (s ?? 'null');
        AppLogger.i(
          '[Assignments] Local key detail -> $k present=$present length=$len preview=$preview',
        );
      }
    } catch (e, st) {
      AppLogger.apiError(
        '[Assignments] Failed to dump local shared-permissions keys',
        e,
        st,
      );
    }

    int successCount = 0;
    int skipped = 0;
    int failed = 0;

    final ds = SharedPermissionsRemoteDataSource();
    final caregiversDs = CaregiversRemoteDataSource();

    for (final key in keys) {
      try {
        final assignmentId = key.replaceFirst(
          'assignment_shared_permissions_',
          '',
        );

        // find assignment in memory
        final idx = _assignments.indexWhere(
          (a) => a.assignmentId == assignmentId,
        );
        Assignment? a;
        if (idx >= 0) a = _assignments[idx];

        // if not found, skip this item - avoid extra network call here
        if (a == null) {
          skipped++;
          continue;
        }

        final s = prefs.getString(key);
        if (s == null || s.isEmpty) {
          skipped++;
          continue;
        }

        final decoded = json.decode(s) as Map<String, dynamic>;
        final perms = SharedPermissions.fromJson(decoded);

        String caregiverId = a.caregiverId;
        String caregiverUsername = a.caregiverEmail ?? '';
        String caregiverPhone = a.caregiverPhone ?? '';
        String caregiverFullName = a.caregiverName ?? '';

        if (caregiverId.isEmpty) {
          final resolver = await resolveCaregiver(
            name: caregiverFullName,
            phone: caregiverPhone,
            search: (q) => caregiversDs.search(keyword: q),
          );

          if (resolver.candidates != null && resolver.candidates!.isNotEmpty) {
            if (!promptOnAmbiguous) {
              skipped++;
              continue;
            }

            final pick = await showDialog<User?>(
              context: ctx,
              builder: (dctx) {
                return SimpleDialog(
                  title: const Text('Chọn người chăm sóc phù hợp'),
                  children: resolver.candidates!
                      .map(
                        (u) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(dctx, u),
                          child: ListTile(
                            title: Text(
                              u.fullName.isNotEmpty ? u.fullName : u.username,
                            ),
                            subtitle: Text(
                              u.phone.isNotEmpty ? u.phone : u.email,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            );

            if (pick == null) {
              skipped++;
              continue;
            }

            caregiverId = pick.id;
            caregiverUsername = pick.username;
            caregiverPhone = pick.phone;
            caregiverFullName = pick.fullName.isNotEmpty
                ? pick.fullName
                : pick.username;
          } else if (resolver.resolved != null) {
            caregiverId = resolver.resolved!.caregiverId;
            caregiverUsername = resolver.resolved!.caregiverUsername;
            caregiverPhone = resolver.resolved!.caregiverPhone ?? '';
            caregiverFullName = resolver.resolved!.caregiverFullName;
          } else {
            skipped++;
            continue;
          }
        }

        print(
          '[Assignments] updatePermissions payload (sync): ${json.encode({'customerId': customerId, 'caregiverId': caregiverId, 'caregiverUsername': caregiverUsername, 'caregiverPhone': caregiverPhone, 'caregiverFullName': caregiverFullName, 'permissions': perms.toJson()})}',
        );
        final serverResult = await ds.updatePermissions(
          customerId: customerId,
          caregiverId: caregiverId,
          caregiverUsername: caregiverUsername,
          caregiverPhone: caregiverPhone,
          caregiverFullName: caregiverFullName,
          permissions: perms,
        );

        await prefs.remove(key);
        AppLogger.i('[Assignments] Synced and removed local key: $key');
        successCount++;

        final newAssignment = Assignment(
          assignmentId: a.assignmentId,
          caregiverId: caregiverId,
          customerId: a.customerId,
          isActive: a.isActive,
          assignedAt: a.assignedAt,
          unassignedAt: a.unassignedAt,
          notes: a.notes,
          assignmentType: a.assignmentType,
          status: a.status,
          createdAt: a.createdAt,
          updatedAt: a.updatedAt,
          caregiverName: serverResult.caregiverFullName,
          caregiverPhone: serverResult.caregiverPhone,
          caregiverEmail: a.caregiverEmail,
          caregiverSpecialization: a.caregiverSpecialization,
          customerName: a.customerName,
          sharedPermissions: {
            'stream_view': serverResult.permissions.streamView,
            'alert_read': serverResult.permissions.alertRead,
            'alert_ack': serverResult.permissions.alertAck,
            'profile_view': serverResult.permissions.profileView,
          },
        );

        if (!mounted) return;
        setState(() {
          final list = _assignments.toList();
          final pos = list.indexWhere((x) => x.assignmentId == a!.assignmentId);
          if (pos >= 0) list[pos] = newAssignment;
          _assignments = list;
        });
      } catch (e) {
        failed++;
      }
    }

    final msgs = <String>[];
    if (successCount > 0) msgs.add('Đã đồng bộ $successCount chỉnh sửa');
    if (skipped > 0) msgs.add('Bỏ qua $skipped mục');
    if (failed > 0) msgs.add('Thất bại $failed mục');
    if (msgs.isNotEmpty) _showSuccessSnackBar(msgs.join(' — '), ctx);
  }
}
