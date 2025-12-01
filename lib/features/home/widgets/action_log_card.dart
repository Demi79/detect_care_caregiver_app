import 'dart:convert' as convert;
import 'package:detect_care_caregiver_app/core/services/direct_caller.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_service.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/events/screens/propose_screen.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/ui/overlay_toast.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/backend_enums.dart' as be;
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';

class _ElevatedCard extends StatelessWidget {
  final Widget child;
  const _ElevatedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ActionLogCard extends StatelessWidget {
  final LogEntry data;
  final void Function(String newStatus, {bool? confirmed})? onUpdated;

  const ActionLogCard({super.key, required this.data, this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final String status = data.status;
    final Color statusColor = AppTheme.getStatusColor(status);
    final Color typeColor = _eventTypeColor(data.eventType);
    final IconData eventIcon = _getEventIcon(data.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  typeColor.withValues(alpha: 0.08),
                  typeColor.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusChip(status, statusColor),

                          // Lifecycle badge may be long; allow it to wrap to next run.
                          if ((data.lifecycleState ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                be.BackendEnums.lifecycleStateToVietnamese(
                                  data.lifecycleState,
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),

                    /// Nút gọi khẩn cấp
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.call, color: Colors.red),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          String? phoneToCall;

                          try {
                            final userId = await AuthStorage.getUserId();
                            if (userId != null && userId.isNotEmpty) {
                              final contacts =
                                  await EmergencyContactsRemoteDataSource()
                                      .list(userId);

                              final p1 = contacts
                                  .where(
                                    (c) =>
                                        (c.alertLevel == 1) &&
                                        c.phone.trim().isNotEmpty,
                                  )
                                  .toList();

                              if (p1.isNotEmpty) {
                                phoneToCall = p1.first.phone.trim();
                              } else {
                                final any = contacts.firstWhere(
                                  (c) => c.phone.trim().isNotEmpty,
                                  orElse: () => EmergencyContactDto(
                                    id: '',
                                    name: '',
                                    relation: '',
                                    phone: '',
                                    alertLevel: 1,
                                  ),
                                );
                                if (any.phone.trim().isNotEmpty) {
                                  phoneToCall = any.phone.trim();
                                }
                              }
                            }
                          } catch (e) {
                            print('[ActionLogCard] load contacts error: $e');
                          }

                          phoneToCall =
                              (phoneToCall == null || phoneToCall.isEmpty)
                              ? '112'
                              : phoneToCall;

                          String normalized = phoneToCall.replaceAll(
                            RegExp(r'[\s\-\(\)]'),
                            '',
                          );
                          if (normalized.startsWith('+84')) {
                            normalized = '0${normalized.substring(3)}';
                          } else if (normalized.startsWith('84')) {
                            normalized = '0${normalized.substring(2)}';
                          }

                          try {
                            final status = await Permission.phone.request();
                            if (status.isGranted) {
                              final success = await DirectCaller.call(
                                normalized,
                              );
                              if (!success) {
                                await launchUrl(Uri.parse('tel:$normalized'));
                              }
                            } else if (status.isPermanentlyDenied) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Quyền gọi điện bị từ chối vĩnh viễn. Vui lòng bật quyền trong cài đặt.',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Cài đặt',
                                    onPressed: () => openAppSettings(),
                                  ),
                                ),
                              );
                              await launchUrl(Uri.parse('tel:$normalized'));
                            } else {
                              await launchUrl(Uri.parse('tel:$normalized'));
                            }
                          } catch (e) {
                            try {
                              await launchUrl(Uri.parse('tel:$normalized'));
                            } catch (_) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi khi gọi: $e'),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lỗi khi gọi: $e'),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(eventIcon, size: 24, color: typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overflow: TextOverflow.ellipsis,
                            data.eventDescription?.trim().isNotEmpty == true
                                ? data.eventDescription!.trim()
                                : _titleFromType(data.eventType),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _eventTypeChip(
                            be.BackendEnums.eventTypeToVietnamese(
                              data.eventType,
                            ),
                            typeColor,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(data.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetails(context),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Xem chi tiết'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      foregroundColor: statusColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            be.BackendEnums.statusToVietnamese(status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTypeChip(String eventType, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        eventType.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _factCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          if (fullWidth)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'fall':
        return Icons.warning_amber_outlined;
      case 'abnormal_behavior':
        return Icons.psychology_outlined;
      case 'visitor_detected':
        return Icons.person_outline;
      case 'seizure':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade600;
    if (confidence >= 0.6) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  String _percent(double v) {
    final p = (v * 100).clamp(0, 100).toStringAsFixed(1);
    return '$p%';
  }

  String _shortId(String id) {
    if (id.isEmpty) return '-';
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final hh = two(local.hour);
    final mm = two(local.minute);
    final dd = two(local.day);
    final MM = two(local.month);
    final yy = (local.year % 100).toString().padLeft(2, '0');
    return '$hh:$mm $dd/$MM/$yy';
  }

  String _titleFromType(String t) {
    switch (t.toLowerCase()) {
      case 'fall':
        return 'Phát hiện ngã';
      case 'abnormal_behavior':
        return 'Phát hiện hành vi bất thường';
      case 'visitor_detected':
        return 'Phát hiện khách';
      case 'seizure':
        return 'Phát hiện co giật';
      default:
        return be.BackendEnums.eventTypeToVietnamese(t);
    }
  }

  Color _eventTypeColor(String t) {
    switch (t.toLowerCase()) {
      case 'fall':
        return const Color(0xFFE53E3E);
      case 'abnormal_behavior':
        return const Color(0xFFD53F8C);
      case 'visitor_detected':
        return const Color(0xFFFF8C00);
      case 'seizure':
        return const Color(0xFF805AD5);
      default:
        return const Color(0xFF3182CE);
    }
  }

  void _showDetails(BuildContext context) async {
    try {
      debugPrint(
        '[ActionLogCard DEBUG] Opening details for event: ${data.eventId}',
      );
      debugPrint('[ActionLogCard DEBUG] data.toString(): ${data.toString()}');

      final found = <String, dynamic>{};

      void scanMap(Map? m, String prefix) {
        if (m == null || m.isEmpty) return;
        for (final k in m.keys) {
          final lk = k.toString().toLowerCase();
          if (lk.contains('image') ||
              lk.contains('media') ||
              lk.contains('photo') ||
              lk.contains('file') ||
              lk.contains('url')) {
            found['$prefix.$k'] = m[k];
          }
        }
      }

      scanMap(data.detectionData, 'detectionData');
      scanMap(data.contextData, 'contextData');
      scanMap(data.aiAnalysisResult, 'aiAnalysisResult');
      if (data.boundingBoxes.isNotEmpty) {
        found['boundingBoxes'] = data.boundingBoxes;
      }

      if (found.isNotEmpty) {
        print('[ActionLogCard DEBUG] candidate image fields found:');
        found.forEach((k, v) => print('  - $k: ${v.toString()}'));
      } else {
        print(
          '[ActionLogCard DEBUG] no obvious image fields found in data maps',
        );
      }
    } catch (e, st) {
      print('[ActionLogCard DEBUG] error while inspecting data: $e');
      print('$st');
    }

    final Color statusColor = AppTheme.getStatusColor(data.status);
    final Color typeColor = _eventTypeColor(data.eventType);

    final sub = AppEvents.instance.eventsChanged.listen((_) {
      try {
        Navigator.of(context, rootNavigator: true).maybePop();
      } catch (_) {}
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withValues(
                            alpha: 0.08,
                            red: typeColor.r * 255.0,
                            green: typeColor.g * 255.0,
                            blue: typeColor.b * 255.0,
                          ),
                          typeColor.withValues(
                            alpha: 0.03,
                            red: typeColor.r * 255.0,
                            green: typeColor.g * 255.0,
                            blue: typeColor.b * 255.0,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(
                              alpha: 0.1,
                              red: typeColor.r * 255.0,
                              green: typeColor.g * 255.0,
                              blue: typeColor.b * 255.0,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _getEventIcon(data.eventType),
                            color: typeColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overflow: TextOverflow.ellipsis,
                                data.eventDescription?.trim().isNotEmpty == true
                                    ? data.eventDescription!.trim()
                                    : _titleFromType(data.eventType),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Show event type on its own line, then status + lifecycle
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _eventTypeChip(
                                    be.BackendEnums.eventTypeToVietnamese(
                                      data.eventType,
                                    ),
                                    typeColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _statusChip(data.status, statusColor),
                                      if ((data.lifecycleState ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Tooltip(
                                          message:
                                              be.BackendEnums.lifecycleStateToVietnamese(
                                                data.lifecycleState,
                                              ),
                                          child: _lifecycleChip(
                                            data.lifecycleState,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                              red: Colors.white.r * 255.0,
                              green: Colors.white.g * 255.0,
                              blue: Colors.white.b * 255.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              try {
                                Navigator.of(context).pop();
                              } catch (_) {}
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProposeScreen(logEntry: data),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Đề xuất sửa đổi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final eventLog = EventLog(
                                eventId: data.eventId,
                                eventType: data.eventType,
                                detectedAt: data.detectedAt,
                                eventDescription: data.eventDescription,
                                confidenceScore: data.confidenceScore,
                                status: data.status,
                                detectionData: data.detectionData,
                                aiAnalysisResult: data.aiAnalysisResult,
                                contextData: data.contextData,
                                boundingBoxes: data.boundingBoxes,
                                confirmStatus: data.confirmStatus,
                                createdAt: data.createdAt,
                                cameraId: data.cameraId,
                              );
                              _showImagesModal(context, eventLog);
                            },
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('Xem ảnh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.grey.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Chi tiết sự kiện'),
                          const SizedBox(height: 12),
                          _detailCard([
                            //   _kvRow(
                            //     'Trạng thái xử lý',
                            //     _be.BackendEnums.confirmStatusToVietnamese(
                            //       data.confirmStatus,
                            //     ),
                            //     data.confirmStatus
                            //         ? Colors.green.shade600
                            //         : Colors.grey.shade600,
                            //     data.confirmStatus
                            //         ? Icons.check_circle
                            //         : Icons.radio_button_unchecked,
                            //   ),
                            // Lifecycle state on its own row, above the status row
                            if ((data.lifecycleState ?? '')
                                .toString()
                                .isNotEmpty)
                              _kvRow(
                                'Hiện tại sự kiện',
                                be.BackendEnums.lifecycleStateToVietnamese(
                                  _normalizeLifecycle(data.lifecycleState),
                                ),
                                Colors.grey.shade600,
                                Icons.event_available,
                              ),
                            _kvRow(
                              'Trạng thái',
                              be.BackendEnums.statusToVietnamese(data.status),
                              statusColor,
                              Icons.flag_outlined,
                            ),

                            _kvRow(
                              'Sự kiện',
                              be.BackendEnums.eventTypeToVietnamese(
                                data.eventType,
                              ),
                              typeColor,
                              Icons.category_outlined,
                            ),
                            _kvRow(
                              'Mô tả',
                              data.eventDescription?.trim().isNotEmpty == true
                                  ? data.eventDescription!.trim()
                                  : '-',
                              typeColor,
                              Icons.category_outlined,
                            ),
                            // _kvRow(
                            //   'Độ tin cậy',
                            //   _percent(data.confidenceScore),
                            //   _getConfidenceColor(data.confidenceScore),
                            //   Icons.analytics_outlined,
                            // ),
                            _kvRow(
                              'Mã sự kiện',
                              _shortId(data.eventId),
                              Colors.grey.shade600,
                              Icons.fingerprint_outlined,
                            ),
                            // _kvRow(
                            //   'Thời gian phát hiện',
                            //   _formatDateTime(data.detectedAt),
                            //   Colors.grey.shade600,
                            //   Icons.access_time_outlined,
                            // ),
                            _kvRow(
                              'Thời gian tạo',
                              _formatDateTime(data.createdAt),
                              Colors.grey.shade600,
                              Icons.access_time_outlined,
                            ),
                            // if (data.createdAt != null)
                            //   _kvRow(
                            //     'Thời gian tạo',
                            //     _formatDateTime(data.createdAt),
                            //     Colors.grey.shade600,
                            //     Icons.schedule_outlined,
                            //   ),
                          ]),

                          Builder(
                            builder: (ctx) {
                              final eventForImages = EventLog(
                                eventId: data.eventId,
                                eventType: data.eventType,
                                detectedAt: data.detectedAt,
                                eventDescription: data.eventDescription,
                                confidenceScore: data.confidenceScore,
                                status: data.status,
                                detectionData: data.detectionData,
                                aiAnalysisResult: data.aiAnalysisResult,
                                contextData: data.contextData,
                                boundingBoxes: data.boundingBoxes,
                                confirmStatus: data.confirmStatus,
                                createdAt: data.createdAt,
                                cameraId: data.cameraId,
                              );

                              return FutureBuilder<List<String>>(
                                future: loadEventImageUrls(eventForImages),
                                builder: (context, snap) {
                                  if (snap.connectionState !=
                                      ConnectionState.done) {
                                    return const SizedBox();
                                  }
                                  if (snap.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Text(
                                        'Lỗi tải ảnh: ${snap.error}',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                    );
                                  }
                                  final urls = snap.data ?? const [];
                                  if (urls.isEmpty) {
                                    return const SizedBox();
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 24),
                                      _sectionTitle('Ảnh sự kiện'),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 220,
                                        child: GridView.builder(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                                childAspectRatio: 1.3,
                                              ),
                                          itemCount: urls.length,
                                          itemBuilder: (context, index) {
                                            final url = urls[index];
                                            return GestureDetector(
                                              onTap: () => _showFullImage(
                                                context,
                                                url,
                                                index,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: Image.network(
                                                          url,
                                                          fit: BoxFit.cover,
                                                          loadingBuilder:
                                                              (
                                                                c,
                                                                w,
                                                                progress,
                                                              ) => progress == null
                                                              ? w
                                                              : const Center(
                                                                  child:
                                                                      CircularProgressIndicator(),
                                                                ),
                                                          errorBuilder:
                                                              (
                                                                c,
                                                                err,
                                                                st,
                                                              ) => Container(
                                                                color: Colors
                                                                    .grey
                                                                    .shade100,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image_outlined,
                                                                  size: 32,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade400,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 6,
                                                        left: 6,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.45,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'Ảnh ${index + 1}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),

                          // if (data.contextData.isNotEmpty) ...[
                          //   const SizedBox(height: 24),
                          //   _sectionTitle('Dữ liệu ngữ cảnh'),
                          //   const SizedBox(height: 12),
                          //   _jsonPreview(data.contextData),
                          // ],
                          // if (data.aiAnalysisResult.isNotEmpty) ...[
                          //   const SizedBox(height: 24),
                          //   _sectionTitle('Kết quả phân tích AI'),
                          //   const SizedBox(height: 12),
                          //   _jsonPreview(data.aiAnalysisResult),
                          // ],

                          // if (data.detectionData.isNotEmpty) ...[
                          //   const SizedBox(height: 24),
                          //   _sectionTitle('Dữ liệu phát hiện'),
                          //   const SizedBox(height: 12),
                          //   _jsonPreview(data.detectionData),
                          // ],

                          // const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Alarm control buttons (activate / cancel)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Xác nhận'),
                                  content: const Text(
                                    'Bạn có muốn kích hoạt báo động cho sự kiện này không?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dCtx).pop(false),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dCtx).pop(true),
                                      child: const Text('Xác nhận'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              try {
                                final userId =
                                    await AuthStorage.getUserId() ?? '';
                                final ds = AlarmRemoteDataSource();
                                final ok = await ds.setAlarm(
                                  eventId: data.eventId,
                                  userId: userId,
                                  cameraId: data.cameraId,
                                  enabled: true,
                                );

                                if (ok) {
                                  try {
                                    await EventsRemoteDataSource()
                                        .updateEventLifecycle(
                                          eventId: data.eventId,
                                          lifecycleState: 'ALARM_ACTIVATED',
                                        );
                                  } catch (_) {}

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Đã kích hoạt báo động',
                                      ),
                                      backgroundColor: Colors.green.shade600,
                                    ),
                                  );

                                  try {
                                    AppEvents.instance.notifyEventsChanged();
                                  } catch (_) {}
                                  if (onUpdated != null) onUpdated!('alarm');
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Kích hoạt báo động thất bại',
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                    ),
                                  );
                                }
                              } catch (e) {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Lỗi khi kích hoạt báo động: $e',
                                    ),
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                            ),
                            label: const Text('Kích hoạt báo động'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Xác nhận'),
                                  content: const Text(
                                    'Bạn có muốn dừng báo động cho sự kiện này không?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dCtx).pop(false),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dCtx).pop(true),
                                      child: const Text('Xác nhận'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              try {
                                final userId =
                                    await AuthStorage.getUserId() ?? '';
                                final ds = AlarmRemoteDataSource();
                                final ok = await ds.cancelAlarm(
                                  eventId: data.eventId,
                                  userId: userId,
                                  cameraId: data.cameraId,
                                );

                                if (ok) {
                                  try {
                                    await EventsRemoteDataSource().cancelEvent(
                                      eventId: data.eventId,
                                    );
                                  } catch (_) {}

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Đã dừng báo động'),
                                      backgroundColor: Colors.green.shade600,
                                    ),
                                  );

                                  try {
                                    AppEvents.instance.notifyEventsChanged();
                                  } catch (_) {}
                                  if (onUpdated != null)
                                    onUpdated!('cancel_alarm');
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Dừng báo động thất bại',
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                    ),
                                  );
                                }
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi dừng báo động: $e'),
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.notifications_off_outlined,
                              size: 18,
                            ),
                            label: const Text('Dừng báo động'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // // Confirm toggle
                  // Padding(
                  //   padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  //   child: StatefulBuilder(
                  //     builder: (ctx, setState) {
                  //       bool confirmed = (data.confirmStatus as bool?) ?? false;
                  //       final initiallyConfirmed = data.confirmStatus == true;

                  //       Future<void> toggleConfirm(bool value) async {
                  //         if (initiallyConfirmed) return;

                  //         if (!value) {
                  //           return;
                  //         }

                  //         setState(() => confirmed = true);
                  //         final messenger = ScaffoldMessenger.of(ctx);
                  //         try {
                  //           final ds = EventsRemoteDataSource();
                  //           await ds.confirmEvent(
                  //             eventId: data.eventId,
                  //             confirmStatusBool: true,
                  //           );

                  //           messenger.showSnackBar(
                  //             SnackBar(
                  //               content: const Text(
                  //                 'Đã đánh dấu sự kiện là đã xử lý',
                  //               ),
                  //               backgroundColor: Colors.green.shade600,
                  //               behavior: SnackBarBehavior.floating,
                  //               duration: const Duration(seconds: 2),
                  //             ),
                  //           );

                  //           if (onUpdated != null) {
                  //             onUpdated!('confirm', confirmed: true);
                  //           }
                  //           try {
                  //             AppEvents.instance.notifyEventsChanged();
                  //           } catch (_) {}
                  //         } catch (e) {
                  //           setState(() => confirmed = false);
                  //           messenger.showSnackBar(
                  //             SnackBar(
                  //               content: Text(
                  //                 'Xử lý thất bại: ${e.toString()}',
                  //               ),
                  //               backgroundColor: Colors.red.shade600,
                  //               behavior: SnackBarBehavior.floating,
                  //               duration: const Duration(seconds: 3),
                  //             ),
                  //           );
                  //         }
                  //       }

                  //       return Container(
                  //         padding: const EdgeInsets.symmetric(vertical: 8),
                  //         child: SwitchListTile(
                  //           value: confirmed,
                  //           onChanged: initiallyConfirmed
                  //               ? null
                  //               : (v) async => await toggleConfirm(v),
                  //           title: Text(
                  //             'Đánh dấu đã xử lý',
                  //             style: TextStyle(
                  //               fontWeight: FontWeight.w700,
                  //               color: Colors.grey.shade800,
                  //             ),
                  //           ),
                  //           subtitle: Text(
                  //             initiallyConfirmed
                  //                 ? 'Xác nhận bạn đã xử lý sự kiện này'
                  //                 : 'Xác nhận bạn đã xử lý sự kiện này',
                  //             style: TextStyle(color: Colors.grey.shade600),
                  //           ),
                  //           activeColor: Colors.green.shade600,
                  //           activeTrackColor: Colors.green.shade200,
                  //           inactiveTrackColor: Colors.grey.shade300,
                  //           contentPadding: EdgeInsets.zero,
                  //         ),
                  //       );
                  //     },
                  //   ),
                  // ),
                ],
              ),
            );
          },
        );
      },
    );

    // Cancel the subscription when the sheet is closed.
    try {
      await sub.cancel();
    } catch (_) {}
  }

  String _normalizeLifecycle(String? s) {
    if (s == null) return '';
    final trimmed = s.toString().trim();
    if (trimmed.isEmpty) return '';

    // Split on common separators first and take the primary token.
    final parts = trimmed
        .split(RegExp(r'[_\-\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    String token = parts.isNotEmpty ? parts.first : trimmed;

    // If token is camelCase / PascalCase, extract the leading word.
    final camelMatches = RegExp(
      r'([A-Z]?[a-z]+|[A-Z]+(?![a-z]))',
    ).allMatches(token);
    if (camelMatches.isNotEmpty) {
      token = camelMatches.first.group(0) ?? token;
    }

    final low = token.toLowerCase();
    return low.isNotEmpty
        ? (low[0].toUpperCase() + (low.length > 1 ? low.substring(1) : ''))
        : '';
  }

  Widget _lifecycleChip(String? lifecycle) {
    final norm = _normalizeLifecycle(lifecycle);
    if (norm.isEmpty) return const SizedBox.shrink();
    final label = be.BackendEnums.lifecycleStateToVietnamese(norm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.caregiverPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // Widget _confirmChip(bool confirmed) {
  //   final Color c = confirmed ? Colors.green.shade600 : Colors.red.shade500;
  //   // final String label = _be.BackendEnums.confirmStatusToVietnamese(confirmed);
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //     decoration: BoxDecoration(
  //       color: c.withValues(alpha: 0.18),
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: c.withValues(alpha: 0.45)),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(
  //           confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
  //           size: 14,
  //           color: c,
  //         ),
  //         const SizedBox(width: 6),
  //         // Text(
  //         //   label,
  //         //   style: TextStyle(
  //         //     color: c,
  //         //     fontSize: 11,
  //         //     fontWeight: FontWeight.w700,
  //         //     letterSpacing: 0.5,
  //         //   ),
  //         // ),
  //       ],
  //     ),
  //   );
  // }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _kvRow(String key, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jsonPreview(Map<String, dynamic> json) {
    final jsonString = convert.JsonEncoder.withIndent('  ').convert(json);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        jsonString,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white,
          height: 1.5,
        ),
      ),
    );
  }

  void _showProposeModal(BuildContext pageContext) {
    final allStatusOptions = ['danger', 'warning', 'normal'];
    final statusLabels = {
      'danger': 'Nguy hiểm',
      'warning': 'Cảnh báo',
      'normal': 'Bình thường',
    };

    final allEventTypes = [
      'fall',
      'abnormal_behavior',
      'emergency',
      'normal_activity',
      'sleep',
    ];

    final availableEventTypes = allEventTypes
        .where((t) => t != data.eventType)
        .toList();

    final currentLower = data.status.toLowerCase();
    final statusOptions = allStatusOptions
        .where((s) => s != currentLower)
        .toList();

    String? selectedStatus;
    String? selectedEventType;
    String note = '';

    showDialog(
      context: pageContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(dialogCtx).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: Colors.blue.shade600,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Đề xuất thay đổi sự kiện',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Trạng thái hiện tại: ${be.BackendEnums.statusToVietnamese(data.status)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getStatusColor(data.status),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ElevatedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn trạng thái đề xuất:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: statusOptions.map((status) {
                              final isSelected = selectedStatus == status;
                              final label = statusLabels[status]!;

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedStatus = status),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade50
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade300,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Loại hiện tại: ${be.BackendEnums.eventTypeToVietnamese(data.eventType)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ElevatedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn loại sự kiện đề xuất:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: availableEventTypes.map((type) {
                              final label =
                                  be.BackendEnums.eventTypeToVietnamese(type);
                              final isSelected = selectedEventType == type;

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedEventType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade50
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade300,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _ElevatedCard(
                      child: TextField(
                        onChanged: (v) => note = v,
                        // Dismiss keyboard when tapping outside the TextField (Flutter 3.3+)
                        onTapOutside: (_) => FocusScope.of(dialogCtx).unfocus(),
                        maxLines: 4,
                        maxLength: 240,
                        decoration: InputDecoration(
                          labelText: 'Lý do đề xuất (bắt buộc)',
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          counterText: '',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Gửi đề xuất'),
                            onPressed: () {
                              if (selectedStatus == null &&
                                  selectedEventType == null) {
                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng chọn trạng thái hoặc loại sự kiện',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (note.trim().isEmpty) {
                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng nhập lý do đề xuất',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(dialogCtx).pop();
                              _confirmPropose(
                                pageContext,
                                selectedStatus ?? data.status,
                                note,
                                eventType: selectedEventType,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmPropose(
    BuildContext ctx,
    String newStatus,
    String note, {
    String? eventType,
  }) {
    showDialog(
      context: ctx,
      builder: (confirmCtx) => AlertDialog(
        title: const Text('Xác nhận gửi đề xuất'),
        content: Text(
          'Bạn có chắc muốn gửi đề xuất thay đổi trạng thái / loại sự kiện này?\n'
          'Khách hàng sẽ xem xét và phê duyệt sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(confirmCtx).pop();
              await _performPropose(ctx, newStatus, note, eventType: eventType);
            },
            child: const Text('Gửi đề xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _performPropose(
    BuildContext ctx,
    String newStatus,
    String note, {
    String? eventType,
  }) async {
    final messenger = ScaffoldMessenger.of(ctx);
    final repo = EventRepository(EventService.withDefaultClient());

    try {
      final ds = EventsRemoteDataSource();

      // pending_until mặc định 48h sau thời điểm tạo (nếu có)
      final pendingUntil = data.createdAt != null
          ? data.createdAt!.add(const Duration(hours: 48))
          : DateTime.now().add(const Duration(hours: 48));

      await repo.proposeEvent(
        eventId: data.eventId,
        proposedStatus: newStatus,
        proposedEventType: eventType,
        reason: note,
        pendingUntil: pendingUntil,
      );
      try {
        final currentNorm = _normalizeLifecycle(
          data.lifecycleState,
        ).toUpperCase();
        if (currentNorm == 'NOTIFIED' || currentNorm == '') {
          try {
            await ds.updateEventLifecycle(
              eventId: data.eventId,
              lifecycleState: 'ACKNOWLEDGED',
            );
          } catch (e) {
            try {
              print(
                '[ActionLogCard] Failed to update lifecycle to ACKNOWLEDGED: $e',
              );
            } catch (_) {}
          }
        }
      } catch (_) {}

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã gửi đề xuất thay đổi thành công'),
          backgroundColor: Colors.green.shade600,
        ),
      );

      try {
        showOverlayToast('Đã gửi đề xuất thành công');
      } catch (_) {}

      try {
        AppEvents.instance.notifyEventsChanged();
      } catch (_) {}
    } catch (e) {
      final cleaned = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gửi đề xuất thất bại: $cleaned'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _showImagesModal(BuildContext pageContext, EventLog event) {
    print('\n🖼️ Loading images for event ${event.eventId}...');
    final future = loadEventImageUrls(event).then((urls) {
      print('📸 Found ${urls.length} images:');
      for (var url in urls) {
        print('   - $url');
      }
      return urls;
    });

    showDialog(
      context: pageContext,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(pageContext).size.width * 0.9,
          height: MediaQuery.of(pageContext).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hình ảnh',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),

                  //  Nút đóng dialog
                  IconButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),

                  //  Nút xem camera
                  IconButton(
                    onPressed: () {
                      Navigator.of(dialogCtx, rootNavigator: true).pop();
                      Future.delayed(const Duration(milliseconds: 250), () {
                        _openCameraForEvent(pageContext, event);
                      });
                    },
                    icon: const Icon(Icons.videocam_outlined),
                    tooltip: 'Xem camera',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              //  Grid hiển thị hình ảnh
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Lỗi tải ảnh: ${snap.error}',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      );
                    }

                    final urls = snap.data ?? const [];
                    if (urls.isEmpty) {
                      return _emptyImages();
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                          ),
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final url = urls[index];
                        return GestureDetector(
                          onTap: () => _showFullImage(context, url, index),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (c, w, progress) =>
                                          progress == null
                                          ? w
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                      errorBuilder: (c, err, st) => Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 32,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Color.fromRGBO(0, 0, 0, 0.7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        'Ảnh ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(
                                          255,
                                          255,
                                          255,
                                          0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.zoom_in,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyImages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Không có ảnh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có ảnh được ghi lại cho sự kiện này.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, w, p) =>
                      p == null ? w : const CircularProgressIndicator(),
                  errorBuilder: (c, e, s) => Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.black),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Ảnh ${index + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Camera button for full image
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng dùng nút "Xem camera" trong cửa sổ ảnh để mở camera.',
                          ),
                        ),
                      );
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.videocam, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCameraForEvent(BuildContext context, EventLog event) async {
    final messenger = ScaffoldMessenger.of(context);
    print('[DEBUG] event.cameraId = ${event.cameraId}');
    print(
      '[DEBUG] detectionData.camera_id = ${event.detectionData['camera_id']}',
    );
    print('[DEBUG] contextData.camera_id = ${event.contextData['camera_id']}');

    String? cameraId =
        event.cameraId ??
        event.detectionData['camera_id']?.toString() ??
        event.contextData['camera_id']?.toString();

    if (cameraId == null) {
      print('[INFO] CameraId not found — fetching event detail...');
      try {
        final detail = await EventsRemoteDataSource().getEventById(
          eventId: event.eventId,
        );

        if (detail['camera_id'] != null) {
          cameraId = detail['camera_id'].toString();
          print('[✅] Found camera_id from top-level: $cameraId');
        } else if (detail['cameras'] is Map &&
            detail['cameras']['camera_id'] != null) {
          cameraId = detail['cameras']['camera_id'].toString();
          print('[✅] Found camera_id from cameras object: $cameraId');
        } else if (detail['snapshots'] is Map &&
            detail['snapshots']['camera_id'] != null) {
          cameraId = detail['snapshots']['camera_id'].toString();
          print('[✅] Found camera_id from snapshots: $cameraId');
        } else {
          print('[⚠️] No camera_id found in event detail.');
        }
      } catch (e) {
        print('[❌] Error fetching event detail: $e');
      }
    }

    if (cameraId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy camera cho sự kiện này.')),
      );
      return;
    }

    print('[INFO] Final cameraId to open: $cameraId');

    try {
      final userId = await AuthStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không xác thực được người dùng.')),
        );
        return;
      }

      final cameraService = CameraService();
      final cameras = await cameraService.loadCameras();

      final matched = cameras.firstWhere(
        (cam) => cam.id == cameraId,
        orElse: () => cameras.first,
      );

      final cameraUrl = matched.url;
      if (cameraUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera không có URL hợp lệ.')),
        );
        return;
      }

      print('🎬 Opening LiveCameraScreen with url=$cameraUrl');
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveCameraScreen(initialUrl: cameraUrl),
        ),
      );
    } catch (e) {
      print('[❌] Failed to load camera list: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể tải danh sách camera.')),
      );
    }
  }
}
