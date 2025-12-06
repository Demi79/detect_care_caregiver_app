import 'dart:convert' as convert;
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/events/screens/propose_screen.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/home/constants/types.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_context.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import '../../../core/utils/backend_enums.dart' as be;

import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';

import 'package:detect_care_caregiver_app/features/home/widgets/action_log_card_image_viewer_helper.dart';

import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/main.dart';

import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';

part 'action_log_card_update_modal.dart';
part 'action_log_card_images.dart';
part 'action_log_card_helpers.dart';

const Duration _kEventUpdateWindow = Duration(days: 2);

enum _NotificationSeverity { danger, warning, normal, info }

class _SeverityActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final String? subtitle;
  final bool enabled;

  _SeverityActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.subtitle,
    this.enabled = true,
  });
}

class _ElevatedCard extends StatelessWidget {
  final Widget child;
  const _ElevatedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      constraints: const BoxConstraints(minWidth: double.infinity),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
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
    try {
      print(
        '[ActionLogCard.build] event=${data.eventId} detectedAt=${data.detectedAt} createdAt=${data.createdAt}',
      );
    } catch (_) {}
    final String status = data.status;
    final Color statusColor = AppTheme.getStatusColor(status);
    final Color typeColor = _eventTypeColor(data.eventType);
    final IconData eventIcon = _getEventIcon(data.eventType);
    final _NotificationSeverity severity = _severityFromStatus(status);
    final Color borderColor = _cardBorderColor(severity);

    // return Container(
    //   margin: const EdgeInsets.only(bottom: 16),
    //   decoration: BoxDecoration(
    //     color: Colors.white,
    //     borderRadius: BorderRadius.circular(16),
    //     border: Border.all(color: Colors.grey.shade200, width: 1),
    //     boxShadow: [
    //       BoxShadow(
    //         color: const Color.fromRGBO(0, 0, 0, 0.04),
    //         blurRadius: 12,
    //         offset: const Offset(0, 3),
    //         spreadRadius: 0,
    //       ),
    //     ],
    //   ),
    //   child: Column(
    //     children: [
    //       Container(
    //         padding: const EdgeInsets.all(16),
    //         decoration: BoxDecoration(
    //           gradient: LinearGradient(
    //             colors: [
    //               typeColor.withValues(alpha: 0.08),
    //               typeColor.withValues(alpha: 0.03),
    //             ],
    //             begin: Alignment.topLeft,
    //             end: Alignment.bottomRight,
    //           ),
    //           borderRadius: const BorderRadius.only(
    //             topLeft: Radius.circular(16),
    //             topRight: Radius.circular(16),
    //           ),
    //         ),
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Row(
    //               // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //               mainAxisAlignment: MainAxisAlignment.start,

    //               crossAxisAlignment: CrossAxisAlignment.start,

    //               children: [
    //                 _statusChip(status, statusColor),
    //                 const SizedBox(width: 8),
    //                 if ((data.lifecycleState ?? '').toString().isNotEmpty)
    //                   Container(
    //                     padding: const EdgeInsets.symmetric(
    //                       horizontal: 10,
    //                       vertical: 6,
    //                     ),
    //                     decoration: BoxDecoration(
    //                       color: Colors.grey.shade200,
    //                       borderRadius: BorderRadius.circular(18),
    //                     ),
    //                     child: Text(
    //                       be.BackendEnums.lifecycleStateToVietnamese(
    //                         onPressed: () async {
    //                           final messenger = ScaffoldMessenger.of(context);
    //                           try {
    //                             // Attempt to call the user's primary emergency contact.
    //                             // Fallback to 115 when no contact is available.
    //                             String? phoneToCall;
    //                             try {
    //                               final userId = await AuthStorage.getUserId();
    //                               if (userId != null && userId.isNotEmpty) {
    //                                 final contacts = await EmergencyContactsRemoteDataSource().list(userId);
    //                                 // Prefer priority 1 contacts with a phone number
    //                                 final p1 = contacts.where((c) => (c.alertLevel == 1) && c.phone.trim().isNotEmpty).toList();
    //                                 if (p1.isNotEmpty) {
    //                                   phoneToCall = p1.first.phone.trim();
    //                                 } else {
    //                                   final any = contacts.firstWhere(
    //                                     (c) => c.phone.trim().isNotEmpty,
    //                                     orElse: () => EmergencyContactDto(id: '', name: '', relation: '', phone: '', alertLevel: 1),
    //                                   );
    //                                   if (any.phone.trim().isNotEmpty) phoneToCall = any.phone.trim();
    //                                 }
    //                               }
    //                             } catch (e) {
    //                               // If fetching contacts fails, fall back to 115.
    //                               print('[ActionLogCard] failed to load emergency contacts: $e');
    //                             }

    //                             phoneToCall = (phoneToCall == null || phoneToCall.isEmpty) ? '115' : phoneToCall;

    //                             // Normalize phone number and prefer opening system dialer
    //                             String normalized = phoneToCall.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    //                             if (normalized.startsWith('+84')) {
    //                               normalized = '0${normalized.substring(3)}';
    //                             } else if (normalized.startsWith('84')) {
    //                               normalized = '0${normalized.substring(2)}';
    //                             }

    //                             final Uri tel = Uri(scheme: 'tel', path: normalized);
    //                             final launched = await launchUrl(tel, mode: LaunchMode.externalApplication);
    //                             if (!launched) {
    //                               messenger.showSnackBar(
    //                                 SnackBar(
    //                                   content: const Text('Không thể thực hiện cuộc gọi'),
    //                                   backgroundColor: Colors.red.shade600,
    //                                   behavior: SnackBarBehavior.floating,
    //                                 ),
    //                               );
    //                             }
    //                           } catch (e) {
    //                             messenger.showSnackBar(
    //                               SnackBar(
    //                                 content: Text('Lỗi khi gọi: $e'),
    //                                 backgroundColor: Colors.red.shade600,
    //                                 behavior: SnackBarBehavior.floating,
    //                               ),
    //                             );
    //                           }
    //             //   label: 'ID sự kiện',
    //             //   value: _shortId(data.eventId),
    //             //   color: Colors.blue.shade600,
    //             //   fullWidth: true,
    //             // ),
    //             // const SizedBox(height: 12),
    //             // _factCard(
    //             //   icon: Icons.schedule_outlined,
    //             //   label: 'Ngày phát hiện',
    //             //   value: _formatDateTime(data.createdAt),
    //             //   color: Colors.grey.shade600,
    //             //   fullWidth: true,
    //             // ),

    //             // if (data.detectedAt != null) ...[
    //             //   const SizedBox(height: 12),
    //             //   _factCard(
    //             //     icon: Icons.schedule_outlined,
    //             //     label: 'Ngày phát hiện',
    //             //     value: _formatDateTime(data.detectedAt),
    //             //     color: Colors.grey.shade600,
    //             //     fullWidth: true,
    //             //   ),
    //             // ],
    //             const SizedBox(height: 16),

    //             SizedBox(
    //               width: double.infinity,
    //               child: ElevatedButton.icon(
    //                 onPressed: () => _showDetails(context),
    //                 icon: const Icon(Icons.visibility_outlined, size: 18),
    //                 label: const Text('Xem chi tiết'),
    //                 style: ElevatedButton.styleFrom(
    //                   backgroundColor: statusColor.withValues(alpha: 0.1),
    //                   foregroundColor: statusColor,
    //                   elevation: 0,
    //                   padding: const EdgeInsets.symmetric(vertical: 12),
    //                   shape: RoundedRectangleBorder(
    //                     borderRadius: BorderRadius.circular(12),
    //                     side: BorderSide(
    //                       color: statusColor.withValues(alpha: 0.3),
    //                     ),
    //                   ),
    //                 ),
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     ],
    //   ),
    // );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleCardTap(context, severity),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 12,
                offset: Offset(0, 3),
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
                              if ((data.lifecycleState ?? '')
                                  .toString()
                                  .isNotEmpty)
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

                        const SizedBox(width: 8),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // if (_hasSeverityActions(severity))
                            //   _buildSeverityCTA(context, severity)
                            // else
                            //   _buildSeverityIndicator(severity),
                            // const SizedBox(height: 8),
                            if (!_isUpdateWindowExpired)
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.call, color: Colors.red),
                                onPressed: () =>
                                    _initiateEmergencyCall(context),
                              ),
                          ],
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
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, _NotificationSeverity severity) {
    // if (_hasSeverityActions(severity)) {
    //   _showSeverityActionSheet(context, severity);
    // } else {
    //   _showDetails(context);
    // }
    _showDetails(context);
  }

  // Widget _buildSeverityCTA(
  //   BuildContext context,
  //   _NotificationSeverity severity,
  // ) {
  //   final color = _severityColor(severity);
  //   return ElevatedButton.icon(
  //     onPressed: () => _showSeverityActionSheet(context, severity),
  //     icon: Icon(_severityActionIcon(severity), size: 16),
  //     label: Text(
  //       _severityActionLabel(severity),
  //       style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  //     ),
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: color.withValues(alpha: 0.15),
  //       foregroundColor: color,
  //       elevation: 0,
  //       minimumSize: const Size(0, 34),
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  //     ),
  //   );
  // }

  Widget _buildSeverityIndicator(_NotificationSeverity severity) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_severityIndicatorIcon(severity), size: 18, color: color),
    );
  }

  Future<void> _showSeverityActionSheet(
    BuildContext context,
    _NotificationSeverity severity,
  ) async {
    final eventTitle = data.eventDescription?.trim().isNotEmpty == true
        ? data.eventDescription!.trim()
        : _titleFromType(data.eventType);
    final eventForActions = _buildEventLogForImages();
    final actions = _severityActionItems(context, severity, eventForActions);
    if (actions.isEmpty) {
      _showDetails(context);
      return;
    }

    final severityColor = _severityColor(severity);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _severityLabel(severity),
                                style: TextStyle(
                                  color: severityColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                eventTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(modalCtx).pop(),
                              icon: const Icon(Icons.close),
                              splashRadius: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn hành động phù hợp để xử lý ngay lập tức.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...actions.map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSeverityActionTile(action, modalCtx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeverityActionTile(
    _SeverityActionItem action,
    BuildContext modalCtx,
  ) {
    return ListTile(
      enabled: action.enabled,
      onTap: action.enabled
          ? () {
              try {
                Navigator.of(modalCtx).pop();
              } catch (_) {}
              action.onPressed();
            }
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Icon(
        action.icon,
        size: 22,
        color: action.color ?? Colors.grey.shade800,
      ),
      title: Text(
        action.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: action.enabled ? Colors.black87 : Colors.grey.shade500,
        ),
      ),
      subtitle: action.subtitle != null
          ? Text(
              action.subtitle!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_outlined,
        size: 18,
        color: action.enabled ? Colors.grey.shade500 : Colors.grey.shade400,
      ),
    );
  }

  List<_SeverityActionItem> _severityActionItems(
    BuildContext context,
    _NotificationSeverity severity,
    EventLog eventForActions,
  ) {
    final manager = callActionManager(context);
    final bool canEmergency = manager.allowedActions.contains(
      CallAction.emergency,
    );
    final bool canCaregiver = manager.allowedActions.contains(
      CallAction.caregiver,
    );

    final shouldShowEmergency =
        canEmergency &&
        !_isLifecycleCanceled &&
        !_isLifecycleResolved &&
        !_hasBeenHandled &&
        !_isUpdateWindowExpired;
    if (severity == _NotificationSeverity.danger) {
      return [
        if (shouldShowEmergency)
          _SeverityActionItem(
            icon: Icons.call,
            label: 'Gọi khẩn cấp',
            color: AppTheme.dangerColor,
            onPressed: () => _initiateEmergencyCall(context),
          )
        else if (canCaregiver)
          _SeverityActionItem(
            icon: Icons.person,
            label: 'Liên hệ người chăm sóc',
            color: AppTheme.primaryBlue,
            onPressed: () => _callCaregiver(context),
          ),
        _SeverityActionItem(
          icon: Icons.notifications_active,
          label: 'Kích hoạt báo động',
          color: AppTheme.warningColor,
          onPressed: () => _activateAlarmForEvent(context, data),
        ),
        _SeverityActionItem(
          icon: Icons.videocam_outlined,
          label: 'Xem camera',
          color: AppTheme.primaryBlue,
          onPressed: () => _openCameraForEvent(context, eventForActions),
        ),
        _SeverityActionItem(
          icon: Icons.image_outlined,
          label: 'Xem hình',
          onPressed: () => _showImagesModal(context, eventForActions),
        ),
        if (_canEditEvent)
          _SeverityActionItem(
            icon: Icons.edit_outlined,
            label: 'Cập nhật sự kiện',
            onPressed: () => _showUpdateModal(context),
          ),
        _SeverityActionItem(
          icon: Icons.check_circle_outline,
          label: 'Đã xử lý',
          subtitle: _hasBeenHandled ? 'Sự kiện đã được xác nhận' : null,
          color: AppTheme.successColor,
          enabled: !_hasBeenHandled,
          onPressed: () => _markEventAsHandled(context),
        ),
      ];
    }

    if (severity == _NotificationSeverity.warning) {
      return [
        _SeverityActionItem(
          icon: Icons.image_outlined,
          label: 'Xem hình',
          onPressed: () => _showImagesModal(context, eventForActions),
        ),
        if (_canEditEvent)
          _SeverityActionItem(
            icon: Icons.edit_outlined,
            label: 'Cập nhật sự kiện',
            onPressed: () => _showUpdateModal(context),
          ),
        // _SeverityActionItem(
        //   icon: Icons.notifications_active,
        //   label: 'Báo động',
        //   color: AppTheme.warningColor,
        //   onPressed: () => _activateAlarmForEvent(context, data),
        // ),
        if (shouldShowEmergency)
          _SeverityActionItem(
            icon: Icons.call,
            label: 'Gọi khẩn cấp',
            color: AppTheme.dangerColor,
            onPressed: () => _initiateEmergencyCall(context),
          )
        else if (canCaregiver)
          _SeverityActionItem(
            icon: Icons.person,
            label: 'Liên hệ người chăm sóc',
            color: AppTheme.primaryBlue,
            onPressed: () => _callCaregiver(context),
          ),
      ];
    }

    return [];
  }

  bool _hasSeverityActions(_NotificationSeverity severity) {
    return severity == _NotificationSeverity.danger ||
        severity == _NotificationSeverity.warning;
  }

  String _severityLabel(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.danger:
        return 'NGUY HIỂM';
      case _NotificationSeverity.warning:
        return 'CẢNH BÁO';
      case _NotificationSeverity.info:
        return 'THÔNG TIN';
      case _NotificationSeverity.normal:
        return 'Bình thường';
    }
  }

  // String _severityActionLabel(_NotificationSeverity severity) {
  //   switch (severity) {
  //     case _NotificationSeverity.danger:
  //       return 'Xử lý khẩn cấp';
  //     case _NotificationSeverity.warning:
  //       return 'Xử lý cảnh báo';
  //     default:
  //       return 'Xử lý';
  //   }
  // }

  IconData _severityActionIcon(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.danger:
        return Icons.dangerous_rounded;
      case _NotificationSeverity.warning:
        return Icons.warning_amber_rounded;
      default:
        return Icons.chevron_right;
    }
  }

  IconData _severityIndicatorIcon(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.normal:
        return Icons.check_circle_outline;
      case _NotificationSeverity.info:
        return Icons.info_outline;
      default:
        return Icons.circle;
    }
  }

  Color _severityColor(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.danger:
        return AppTheme.dangerColor;
      case _NotificationSeverity.warning:
        return AppTheme.warningColor;
      case _NotificationSeverity.info:
        return AppTheme.primaryBlue;
      case _NotificationSeverity.normal:
        return Colors.grey.shade600;
    }
  }

  Color _cardBorderColor(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.danger:
        return AppTheme.dangerColor.withAlpha(120);
      case _NotificationSeverity.warning:
        return AppTheme.warningColor.withAlpha(120);
      case _NotificationSeverity.info:
        return AppTheme.primaryBlue.withAlpha(120);
      case _NotificationSeverity.normal:
        return Colors.grey.shade200;
    }
  }

  _NotificationSeverity _severityFromStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s.isEmpty) return _NotificationSeverity.normal;
    if (['danger', 'critical', 'emergency'].contains(s)) {
      return _NotificationSeverity.danger;
    }
    if (['warning', 'abnormal', 'suspect', 'alert'].contains(s)) {
      return _NotificationSeverity.warning;
    }
    if (['info', 'neutral'].contains(s)) {
      return _NotificationSeverity.info;
    }
    return _NotificationSeverity.normal;
  }

  Future<void> _initiateEmergencyCall(BuildContext context) async {
    bool canEmergency = true;
    try {
      final manager = callActionManager(context);
      canEmergency = manager.allowedActions.contains(CallAction.emergency);
    } catch (e) {
      // If provider context is not available (dialogs/modals), fall back
      // to allowing emergency calls so the picker/dialog can proceed.
      print('[ActionLogCard] callActionManager error: $e');
      canEmergency = true;
    }
    if (!canEmergency) {
      _showRestrictedCallMessage(context);
      return;
    }

    // Try to load emergency contacts (prioritize alertLevel 1 then 2)
    List<EmergencyContactDto> contacts = [];
    try {
      final ds = EmergencyContactsRemoteDataSource();
      final customerId = await ds.resolveCustomerId();
      if (customerId != null && customerId.isNotEmpty) {
        contacts = await ds.list(customerId);
      }
    } catch (e) {
      print('[ActionLogCard] failed to load emergency contacts: $e');
    }

    final valid = contacts.where((c) => c.phone.trim().isNotEmpty).toList();
    // Sort by alertLevel ascending (1 highest priority)
    valid.sort((a, b) => (a.alertLevel ?? 99).compareTo(b.alertLevel ?? 99));

    if (valid.isEmpty) {
      // No contacts: fall back to 115 directly
      await attemptCall(
        context: context,
        rawPhone: '115',
        actionLabel: 'Gọi khẩn cấp',
      );
      return;
    }

    // Build options (limit to 2: cấp 1, cấp 2)
    final options = <Map<String, String>>[];
    for (final c in valid) {
      final lvl = (c.alertLevel == null) ? '' : 'CẤP ${c.alertLevel}';
      final label = (c.name.trim().isNotEmpty == true)
          ? '$lvl: ${c.name} — ${c.phone}'
          : '$lvl: ${c.phone}';
      options.add({'label': label, 'phone': c.phone.trim()});
      if (options.length >= 2) break;
    }

    // Always include emergency fallback as last option
    options.add({'label': 'Gọi số khẩn cấp (115)', 'phone': '115'});

    // Show selection dialog
    String? chosen;
    try {
      chosen = await showModalBottomSheet<String?>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Chọn số để gọi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...options.map(
                  (o) => ListTile(
                    title: Text(o['label'] ?? ''),
                    onTap: () => Navigator.of(ctx).pop(o['phone']),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('[ActionLogCard] showModalBottomSheet error: $e');
      chosen = null;
    }
    if (chosen == null) return;

    try {
      print('[ActionLogCard] chosen phone from picker: $chosen');
    } catch (_) {}

    await attemptCall(
      context: context,
      rawPhone: chosen,
      actionLabel: 'Gọi khẩn cấp',
    );
  }

  Future<String> _resolveEmergencyPhoneNumber() async {
    String? phoneToCall;
    try {
      final ds = EmergencyContactsRemoteDataSource();
      final customerId = await ds.resolveCustomerId();
      if (customerId != null && customerId.isNotEmpty) {
        final contacts = await ds.list(customerId);
        final p1 = contacts
            .where((c) => (c.alertLevel == 1) && c.phone.trim().isNotEmpty)
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
    if (phoneToCall == null || phoneToCall.isEmpty) {
      return '115';
    }
    return phoneToCall;
  }

  void _showRestrictedCallMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bạn đã có người chăm sóc. Trong trường hợp khẩn cấp hệ thống sẽ liên hệ người chăm sóc trước.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _callCaregiver(BuildContext context) async {
    final manager = callActionManager(context);
    if (!manager.allowedActions.contains(CallAction.caregiver)) {
      _showRestrictedCallMessage(context);
      return;
    }
    final caregiverPhone = firstAssignedCaregiverPhone(context);
    if (caregiverPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có số điện thoại người chăm sóc để liên hệ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await attemptCall(
      context: context,
      rawPhone: caregiverPhone,
      actionLabel: 'Liên hệ người chăm sóc',
    );
  }

  Future<void> _markEventAsHandled(BuildContext context) async {
    if (_hasBeenHandled) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await EventsRemoteDataSource().confirmEvent(
        eventId: data.eventId,
        confirmStatusBool: true,
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã đánh dấu sự kiện là đã xử lý'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      onUpdated?.call('confirm', confirmed: true);
      try {
        AppEvents.instance.notifyEventsChanged();
      } catch (_) {}
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể đánh dấu đã xử lý: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _translateStatusLocal(String status) {
    final s = status.toLowerCase();
    if (s == 'all') return 'Tất cả trạng thái';
    if (s == 'abnormal') return 'Bất thường';
    // Delegate to BackendEnums for the standard translations.
    return be.BackendEnums.statusToVietnamese(s);
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
            _translateStatusLocal(status).toUpperCase(),
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

  // ignore: unused_element
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

  // ignore: unused_element
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade600;
    if (confidence >= 0.6) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  // ignore: unused_element
  String _percent(double v) {
    final p = (v * 100).clamp(0, 100).toStringAsFixed(1);
    return '$p%';
  }

  // ignore: unused_element
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
    try {
      return be.BackendEnums.eventTypeToVietnamese(t);
    } catch (_) {
      return t;
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

  String _normalizeLifecycle(String? s) {
    if (s == null) return '';
    final trimmed = s.toString().trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => m[1]!)
        .split(RegExp(r'[_\-\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return trimmed;
    final normalized = parts.map((p) {
      final low = p.toLowerCase();
      return low[0].toUpperCase() + (low.length > 1 ? low.substring(1) : '');
    }).join();
    return normalized;
  }

  /// Convert various lifecycle formats into the canonical backend form
  /// e.g. 'EmergencyResponseReceived' -> 'EMERGENCY_RESPONSE_RECEIVED'
  String _canonicalLifecycle(String? s) {
    if (s == null) return '';
    final trimmed = s.toString().trim();
    if (trimmed.isEmpty) return '';

    // If already contains separators, normalize them to underscores and uppercase
    if (trimmed.contains('_') ||
        trimmed.contains('-') ||
        trimmed.contains(' ')) {
      return trimmed
          .replaceAll('-', '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .toUpperCase();
    }

    // Insert underscores between camelCase / PascalCase boundaries
    final withUnderscores = trimmed.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}_${m[2]}',
    );
    return withUnderscores.toUpperCase();
  }

  Widget _lifecycleChip(String? lifecycle) {
    final canonical = _canonicalLifecycle(lifecycle);
    if (canonical.isEmpty) return const SizedBox.shrink();
    final label = be.BackendEnums.lifecycleStateToVietnamese(canonical);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  bool get _isLifecycleCanceled =>
      _canonicalLifecycle(data.lifecycleState) == 'CANCELED';

  bool get _isLifecycleResolved =>
      _canonicalLifecycle(data.lifecycleState) == 'RESOLVED';

  bool get _isUpdateWindowExpired {
    final reference = data.createdAt ?? data.detectedAt;
    if (reference == null) return false;
    final difference = DateTime.now().difference(reference);
    return difference >= _kEventUpdateWindow;
  }

  bool get _canEditEvent => !_isUpdateWindowExpired;

  bool get _isAutoCalling =>
      _canonicalLifecycle(data.lifecycleState) == 'AUTOCALLED';

  bool get _hasBeenHandled => data.confirmStatus == true;

  bool get _isEventOlderThan15Min {
    final created = data.createdAt;
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes > 15;
  }

  bool get _shouldHideAlarmButtons =>
      _isAutoCalling || _hasBeenHandled || _isEventOlderThan15Min;

  String get _autoCallBannerText {
    if (_isAutoCalling) {
      return '📞 Hệ thống đang gọi khẩn cấp tự động…';
    }
    if (_hasBeenHandled) {
      return 'Sự kiện đã được xử lý.';
    }
    if (_isEventOlderThan15Min) {
      return 'Sự kiện quá 15 phút sẽ không được kích hoạt báo động.';
    }
    return '';
  }

  void _showDetails(BuildContext context) async {
    try {
      print(
        '[ActionLogCard._showDetails] event=${data.eventId} detectedAt=${data.detectedAt} createdAt=${data.createdAt}',
      );
    } catch (_) {}
    final Color statusColor = AppTheme.getStatusColor(data.status);
    final Color typeColor = _eventTypeColor(data.eventType);

    final sub = AppEvents.instance.eventsChanged.listen((_) {
      try {
        Navigator.of(context, rootNavigator: true).maybePop();
      } catch (_) {}
    });

    bool modalIsActivating = false;
    bool modalIsCancelling = false;

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
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  data.eventDescription?.trim().isNotEmpty ==
                                          true
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
                    if (!_canEditEvent)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Text(
                          'Cập nhật chỉ khả dụng trong vòng ${_kEventUpdateWindow.inDays} ngày kể từ khi sự kiện được ghi nhận.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<EventLog>(
                              future: EventRepository(
                                EventService.withDefaultClient(),
                              ).getEventDetails(data.eventId),
                              builder: (context, snap) {
                                bool disabled = !_canEditEvent;
                                String tooltip = '';
                                if (snap.connectionState ==
                                        ConnectionState.done &&
                                    !snap.hasError &&
                                    snap.data != null) {
                                  final detail = snap.data!;
                                  final hasPending =
                                      detail.proposedStatus != null &&
                                      (detail.pendingUntil != null &&
                                          detail.pendingUntil!.isAfter(
                                            DateTime.now(),
                                          ));
                                  if (hasPending) {
                                    disabled = true;
                                    tooltip =
                                        'Sự kiện đang có đề xuất chờ duyệt';
                                  }
                                }

                                return ElevatedButton.icon(
                                  onPressed: disabled
                                      ? null
                                      : () async {
                                          try {
                                            Navigator.of(context).pop();
                                          } catch (_) {}
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProposeScreen(logEntry: data),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Đề xuất sửa đổi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: disabled
                                        ? Colors.grey.shade300
                                        : Colors.blue.shade600,
                                    foregroundColor: disabled
                                        ? Colors.grey.shade600
                                        : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                    // if (_shouldHideAlarmButtons)
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 20,
                    //       vertical: 12,
                    //     ),
                    //     child: Container(
                    //       decoration: BoxDecoration(
                    //         color: const Color(0xFFFFF5E5),
                    //         borderRadius: BorderRadius.circular(12),
                    //         border: Border.all(color: const Color(0xFFF3C37B)),
                    //       ),
                    //       padding: const EdgeInsets.symmetric(
                    //         horizontal: 16,
                    //         vertical: 12,
                    //       ),
                    //       child: Row(
                    //         crossAxisAlignment: CrossAxisAlignment.center,
                    //         children: [
                    //           Container(
                    //             padding: const EdgeInsets.all(8),
                    //             decoration: BoxDecoration(
                    //               color: Colors.orange.shade600,
                    //               shape: BoxShape.circle,
                    //               boxShadow: const [
                    //                 BoxShadow(
                    //                   blurRadius: 6,
                    //                   color: Colors.orangeAccent,
                    //                   offset: Offset(0, 2),
                    //                 ),
                    //               ],
                    //             ),
                    //             child: const Icon(
                    //               Icons.phone_in_talk,
                    //               size: 16,
                    //               color: Colors.white,
                    //             ),
                    //           ),
                    //           const SizedBox(width: 12),
                    //           Expanded(
                    //             child: Text(
                    //               _autoCallBannerText,
                    //               style: TextStyle(
                    //                 fontWeight: FontWeight.w600,
                    //                 color: Colors.orange.shade900,
                    //               ),
                    //             ),
                    //           ),
                    //           Container(
                    //             padding: const EdgeInsets.symmetric(
                    //               horizontal: 10,
                    //               vertical: 4,
                    //             ),
                    //             decoration: BoxDecoration(
                    //               color: Colors.orange.shade50,
                    //               borderRadius: BorderRadius.circular(12),
                    //               border: Border.all(
                    //                 color: Colors.orange.shade200,
                    //               ),
                    //             ),
                    //             child: Text(
                    //               'TỰ ĐỘNG',
                    //               style: TextStyle(
                    //                 fontSize: 10,
                    //                 letterSpacing: 0.5,
                    //                 fontWeight: FontWeight.w700,
                    //                 color: Colors.orange.shade700,
                    //               ),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   )
                    // else
                    if (!_isUpdateWindowExpired)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Directly invoke the emergency flow which will present
                              // a picker when multiple contacts exist, or call
                              // immediately when only one is available.
                              await _initiateEmergencyCall(context);
                            },
                            icon: const Icon(Icons.call, size: 20),
                            label: const Text(
                              'Gọi khẩn cấp',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Chi tiết sự kiện'),
                          const SizedBox(height: 12),
                          _detailCard([
                            if ((data.lifecycleState ?? '')
                                .toString()
                                .isNotEmpty)
                              _kvRow(
                                'Hiện tại sự kiện',
                                be.BackendEnums.lifecycleStateToVietnamese(
                                  _canonicalLifecycle(data.lifecycleState),
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
                            //   'Mã sự kiện',
                            //   _shortId(data.eventId),
                            //   Colors.grey.shade600,
                            //   Icons.fingerprint_outlined,
                            // ),
                            _kvRow(
                              'Thời gian tạo',
                              _formatDateTime(data.createdAt),
                              Colors.grey.shade600,
                              Icons.access_time_outlined,
                            ),
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
                                              onTap: () =>
                                                  showActionLogCardImageViewer(
                                                    context,
                                                    urls,
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

  // Widget _confirmChip(bool confirmed) {
  //   final Color c = confirmed ? Colors.green.shade600 : Colors.red.shade500;
  //   final String label = _be.BackendEnums.confirmStatusToVietnamese(confirmed);
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
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: c,
  //             fontSize: 11,
  //             fontWeight: FontWeight.w700,
  //             letterSpacing: 0.5,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
