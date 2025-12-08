import 'package:detect_care_caregiver_app/core/models/notification.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/features/notification/utils/notification_translator.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationModel notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen>
    with SingleTickerProviderStateMixin {
  final NotificationApiService _apiService = NotificationApiService();
  bool _loading = false;
  List<String> _imageUrls = [];
  bool _imagesLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _ensureImageUrlsLoaded();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatFullDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  Future<void> _markAsRead() async {
    setState(() => _loading = true);
    try {
      await _apiService.markAsRead(widget.notification.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã đánh dấu là đã đọc'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Lỗi: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureImageUrlsLoaded() async {
    if (_imagesLoading || _imageUrls.isNotEmpty) return;
    _imagesLoading = true;
    try {
      final imgs = _findImageUrlsFromMetadata();
      if (imgs.isNotEmpty) {
        if (mounted) setState(() => _imageUrls = imgs);
        return;
      }

      final m = widget.notification.metadata ?? {};
      final ids = <String>[];
      void addIfString(dynamic v) {
        if (v is String && v.isNotEmpty) ids.add(v);
        if (v is List) {
          for (final e in v) {
            if (e is String && e.isNotEmpty) ids.add(e);
          }
        }
      }

      addIfString(m['snapshot_id']);
      addIfString(m['snapshotId']);
      addIfString(m['snapshot_ids']);
      addIfString(m['snapshotIds']);
      addIfString(m['snapshots']);

      final snaps = m['snapshots'] ?? m['snapshot'];
      final collected = <String>[];
      if (snaps != null) {
        if (snaps is Map) {
          if (snaps['files'] is List) {
            for (final f in (snaps['files'] as List)) {
              if (f is Map) {
                final u = (f['cloud_url'] ?? f['url'])?.toString();
                if (u != null && u.isNotEmpty) collected.add(u);
              }
            }
          } else {
            final u = (snaps['cloud_url'] ?? snaps['url'])?.toString();
            if (u != null && u.isNotEmpty) collected.add(u);
          }
        } else if (snaps is List) {
          for (final s in snaps) {
            if (s is Map) {
              if (s['files'] is List) {
                for (final f in (s['files'] as List)) {
                  if (f is Map) {
                    final u = (f['cloud_url'] ?? f['url'])?.toString();
                    if (u != null && u.isNotEmpty) collected.add(u);
                  }
                }
              } else {
                final u = (s['cloud_url'] ?? s['url'])?.toString();
                if (u != null && u.isNotEmpty) collected.add(u);
              }
            }
          }
        }
      }

      if (collected.isNotEmpty) {
        if (mounted) setState(() => _imageUrls = collected);
        return;
      }

      if (ids.isNotEmpty) {
        final sup = SupabaseService();
        final found = <String>[];
        for (final id in ids.toSet()) {
          try {
            final url = await sup.fetchSnapshotImageUrl(id);
            if (url != null && url.isNotEmpty) found.add(url);
          } catch (_) {}
        }
        if (found.isNotEmpty) {
          if (mounted) setState(() => _imageUrls = found);
          return;
        }
      }

      String? eventId;
      final cand = [
        m['event_id'],
        m['eventId'],
        m['id'],
        widget.notification.actionUrl,
      ];
      for (final c in cand) {
        if (c is String && c.isNotEmpty) {
          eventId = c;
          break;
        }
      }
      if (eventId == null) {
        final a = widget.notification.actionUrl;
        if (a != null && a.contains('event=')) {
          final uri = Uri.tryParse(a);
          if (uri != null) {
            eventId = uri.queryParameters['event'] ?? uri.queryParameters['id'];
          }
        }
      }

      if (eventId != null && eventId.isNotEmpty) {
        try {
          final ds = EventsRemoteDataSource();
          final detail = await ds.getEventById(eventId: eventId);
          final urls = <String>[];
          final sv = detail['snapshot_url'] ?? detail['snapshotUrl'];
          if (sv is String && sv.isNotEmpty) urls.add(sv);
          final snaps2 = detail['snapshots'] ?? detail['snapshot'];
          if (snaps2 != null) {
            if (snaps2 is Map) {
              if (snaps2.containsKey('files') && snaps2['files'] is List) {
                for (final f in (snaps2['files'] as List)) {
                  if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                    urls.add((f['cloud_url'] ?? f['url']).toString());
                  }
                }
              } else if ((snaps2['cloud_url'] ?? snaps2['url']) != null) {
                urls.add((snaps2['cloud_url'] ?? snaps2['url']).toString());
              }
            } else if (snaps2 is List) {
              for (final s in snaps2) {
                if (s is Map) {
                  if (s.containsKey('files') && s['files'] is List) {
                    for (final f in (s['files'] as List)) {
                      if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                        urls.add((f['cloud_url'] ?? f['url']).toString());
                      }
                    }
                  } else if ((s['cloud_url'] ?? s['url']) != null) {
                    urls.add((s['cloud_url'] ?? s['url']).toString());
                  }
                }
              }
            }
          }
          if (urls.isNotEmpty) {
            if (mounted) setState(() => _imageUrls = urls.toSet().toList());
          }
        } catch (_) {}
      }
    } finally {
      _imagesLoading = false;
    }
  }

  Future<void> _openCamera() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final m = widget.notification.metadata ?? {};
      String? cameraId =
          (m['camera_id'] ?? m['cameraId'] ?? m['camera'] ?? m['device_id'])
              ?.toString();

      if (cameraId == null || cameraId.isEmpty) {
        String? eventId;
        final a = widget.notification.actionUrl;
        if (a != null) {
          final uri = Uri.tryParse(a);
          if (uri != null) {
            eventId = uri.queryParameters['event'] ?? uri.queryParameters['id'];
          }
        }
        final cand = [m['event_id'], m['eventId'], m['id']];
        for (final c in cand) {
          if (c is String && c.isNotEmpty) {
            eventId ??= c;
            break;
          }
        }

        if (eventId != null && eventId.isNotEmpty) {
          try {
            final ds = EventsRemoteDataSource();
            final detail = await ds.getEventById(eventId: eventId);
            if (detail['camera_id'] != null) {
              cameraId = detail['camera_id'].toString();
            } else if (detail['cameras'] is Map &&
                detail['cameras']['camera_id'] != null) {
              cameraId = detail['cameras']['camera_id'].toString();
            } else if (detail['snapshots'] is Map &&
                detail['snapshots']['camera_id'] != null) {
              cameraId = detail['snapshots']['camera_id'].toString();
            }
          } catch (_) {}
        }
      }

      if (cameraId == null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Không tìm thấy camera liên quan'),
              ],
            ),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      String? customerId;
      try {
        final assignmentsDs = AssignmentsRemoteDataSource();
        final assignments = await assignmentsDs.listPending();
        final active = assignments
            .where((a) => a.isActive && a.status.toLowerCase() == 'accepted')
            .toList();
        if (active.isNotEmpty) customerId = active.first.customerId;
      } catch (_) {}

      customerId ??= await AuthStorage.getUserId();
      if (customerId == null || customerId.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Không thể xác định người dùng để lấy danh sách camera.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      final api = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      final response = await api.getCamerasByUser(userId: customerId);
      if (response['data'] is! List) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Không thể tải danh sách camera.'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      final cameras = (response['data'] as List)
          .map((e) => CameraEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final matched = cameras.firstWhere(
        (cam) => cam.id == cameraId,
        orElse: () => cameras.first,
      );
      final cameraUrl = matched.url;
      if (cameraUrl.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Camera không có URL hợp lệ.'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveCameraScreen(initialUrl: cameraUrl),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Không thể mở camera.'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Text('Xác nhận xóa'),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn xóa thông báo này? Hành động này không thể hoàn tác.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _apiService.deleteNotification(widget.notification.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã xóa thông báo'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Lỗi xóa: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _findImageUrlsFromMetadata() {
    final m = widget.notification.metadata ?? {};
    final results = <String>[];

    final listKeys = ['images', 'imageList', 'snapshots', 'snapshotList'];
    for (final k in listKeys) {
      final v = m[k];
      if (v is Iterable) {
        for (final item in v) {
          final s = item?.toString() ?? '';
          if (s.isNotEmpty) results.add(s);
        }
        if (results.isNotEmpty) return results;
      }
    }

    final singleKeys = [
      'snapshotPath',
      'snapshot',
      'image',
      'imageUrl',
      'preview',
      'snapshot_url',
      'stream_snapshot',
    ];
    for (final k in singleKeys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      if (s.contains(',')) {
        for (final part in s.split(',')) {
          final t = part.trim();
          if (t.isNotEmpty) results.add(t);
        }
      } else {
        results.add(s);
      }
      if (results.isNotEmpty) return results;
    }

    return results;
  }

  String? _findStreamUrlFromMetadata() {
    final m = widget.notification.metadata ?? {};
    final candidates = [
      'streamUrl',
      'stream_url',
      'rtsp',
      'url',
      'cameraUrl',
      'camera_url',
    ];
    for (final k in candidates) {
      final val = m[k];
      if (val == null) continue;
      final s = val.toString();
      if (s.isEmpty) continue;
      return s;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Đã làm mới thông báo'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final typeVN = BackendEnums.businessTypeToVietnamese(n.businessType);

    // Determine status
    String? statusKey = n.metadata?['status']?.toString().toLowerCase();
    if (statusKey == null || statusKey.isEmpty) {
      final pr = n.priority ?? 0;
      if (pr >= 8) {
        statusKey = 'danger';
      } else if (pr >= 4) {
        statusKey = 'warning';
      } else {
        statusKey = 'normal';
      }
    }
    final statusVN = NotificationTranslator.status(statusKey);
    final statusColor = NotificationTranslator.statusColor(statusKey);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
          'Chi tiết thông báo',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (!n.isRead)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.mark_email_read, size: 22),
                color: const Color(0xFF3B82F6),
                tooltip: 'Đánh dấu đã đọc',
                onPressed: _loading ? null : _markAsRead,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            offset: const Offset(0, 48),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    const Text('Làm mới'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    SizedBox(width: 12),
                    Text('Xóa', style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'refresh') _load();
              if (val == 'delete') _delete();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge & Priority Indicator
              // Container(
              //   padding: const EdgeInsets.all(20),
              //   decoration: BoxDecoration(
              //     gradient: LinearGradient(
              //       colors: [
              //         statusColor.withOpacity(0.1),
              //         statusColor.withOpacity(0.05),
              //       ],
              //       begin: Alignment.topLeft,
              //       end: Alignment.bottomRight,
              //     ),
              //     borderRadius: BorderRadius.circular(16),
              //     border: Border.all(
              //       color: statusColor.withOpacity(0.2),
              //       width: 1.5,
              //     ),
              //   ),
              //   child: Row(
              //     children: [
              //       Container(
              //         padding: const EdgeInsets.all(12),
              //         decoration: BoxDecoration(
              //           color: statusColor.withOpacity(0.15),
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         child: Icon(
              //           statusKey == 'danger'
              //               ? Icons.warning_rounded
              //               : statusKey == 'warning'
              //               ? Icons.error_outline
              //               : Icons.notifications_active,
              //           color: statusColor,
              //           size: 28,
              //         ),
              //       ),
              //       const SizedBox(width: 16),
              //       Expanded(
              //         child: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //               statusVN,
              //               style: TextStyle(
              //                 fontSize: 18,
              //                 fontWeight: FontWeight.w700,
              //                 color: statusColor,
              //               ),
              //             ),
              //             const SizedBox(height: 4),
              //             Text(
              //               typeVN,
              //               style: TextStyle(
              //                 fontSize: 14,
              //                 color: Colors.grey.shade600,
              //                 fontWeight: FontWeight.w500,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //       if (!n.isRead)
              //         Container(
              //           width: 12,
              //           height: 12,
              //           decoration: BoxDecoration(
              //             color: const Color(0xFF3B82F6),
              //             shape: BoxShape.circle,
              //             boxShadow: [
              //               BoxShadow(
              //                 color: const Color(0xFF3B82F6).withOpacity(0.4),
              //                 blurRadius: 8,
              //                 spreadRadius: 2,
              //               ),
              //             ],
              //           ),
              //         ),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 20),

              // Main Content Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      n.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timestamp
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(n.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          ' • ${_formatFullDate(n.createdAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 16),

                    // Message
                    Text(
                      n.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF374151),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image Gallery
                    if (_imagesLoading)
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    else if (_imageUrls.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.photo_library,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hình ảnh (${_imageUrls.length})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageUrls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (ctx, i) {
                                final img = _imageUrls[i];
                                return GestureDetector(
                                  onTap: () {
                                    final controller = PageController(
                                      initialPage: i,
                                    );
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black87,
                                      builder: (_) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: const EdgeInsets.all(16),
                                        child: Stack(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              height: 600,
                                              child: PageView.builder(
                                                controller: controller,
                                                itemCount: _imageUrls.length,
                                                itemBuilder: (_, idx) {
                                                  final src = _imageUrls[idx];
                                                  return ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: InteractiveViewer(
                                                      child:
                                                          src.startsWith('http')
                                                          ? Image.network(
                                                              src,
                                                              fit: BoxFit
                                                                  .contain,
                                                            )
                                                          : Image.file(
                                                              File(src),
                                                              fit: BoxFit
                                                                  .contain,
                                                            ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Positioned(
                                              top: 16,
                                              right: 16,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                style: IconButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.black45,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: 'image_$i',
                                    child: Container(
                                      width: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: img.startsWith('http')
                                            ? Image.network(
                                                img,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            size: 48,
                                                            color: Colors
                                                                .grey
                                                                .shade400,
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Text(
                                                            'Không tải được',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade500,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                loadingBuilder: (_, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    color: Colors.grey.shade50,
                                                    child: Center(
                                                      child: CircularProgressIndicator(
                                                        value:
                                                            progress.expectedTotalBytes !=
                                                                null
                                                            ? progress.cumulativeBytesLoaded /
                                                                  progress
                                                                      .expectedTotalBytes!
                                                            : null,
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Image.file(
                                                File(img),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thao tác nhanh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.phone, size: 20),
                            label: const Text(
                              'Gọi khẩn cấp',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: _loading
                                ? null
                                : () =>
                                      EmergencyCallHelper.initiateEmergencyCall(
                                        context,
                                      ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (ctx) {
                              final stream = _findStreamUrlFromMetadata();
                              return OutlinedButton.icon(
                                icon: const Icon(Icons.videocam, size: 20),
                                label: const Text(
                                  'Mở camera',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF3B82F6),
                                  side: const BorderSide(
                                    color: Color(0xFF3B82F6),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : () async {
                                        if (stream != null &&
                                            stream.isNotEmpty) {
                                          if (!context.mounted) return;
                                          Navigator.of(ctx).push(
                                            MaterialPageRoute(
                                              builder: (_) => LiveCameraScreen(
                                                initialUrl: stream,
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await _openCamera();
                                      },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
