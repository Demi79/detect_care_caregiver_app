import 'dart:async';

import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/alert_new_event_card.dart';
import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_context.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';

import '../../features/auth/data/auth_storage.dart';
import '../../features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import '../../features/events/data/events_remote_data_source.dart';
import '../../features/home/models/log_entry.dart';
import '../../features/home/widgets/action_log_card.dart';
import '../../main.dart';
import '../../services/alert_settings_manager.dart';
import '../../services/audio_service.dart';
import '../events/app_events.dart';
import '../utils/app_lifecycle.dart';

class InAppAlert {
  static bool _showing = false;
  static DateTime? _lastShownMinute;

  static Future<void> show(LogEntry e) async {
    print('🧩 [InAppAlert] Request to show popup for event ${e.eventId}');
    print(' - _showing: $_showing');
    print(' - isForeground: ${AppLifecycle.isForeground}');
    final eventTime = e.detectedAt ?? e.createdAt ?? DateTime.now();
    DateTime truncateToMinute(DateTime t) =>
        DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final eventMinute = truncateToMinute(eventTime);

    final statusLower = e.status.toString().toLowerCase();
    if (!(statusLower.contains('danger') || statusLower.contains('warning'))) {
      print('❌ Popup suppressed: status not danger/warning (${e.status})');
      return;
    }

    // If app not foreground, skip showing
    if (!AppLifecycle.isForeground) {
      print('❌ Popup suppressed: app not in foreground');
      return;
    }

    final ctx = NavigatorKey.navigatorKey.currentState?.overlay?.context;
    print('🧭 NavigatorKey context = $ctx');
    if (ctx == null) {
      print('⚠️ InAppAlert: context is null → cannot show popup');
      return;
    }

    if (_lastShownMinute != null && _lastShownMinute == eventMinute) {
      print('❌ Popup suppressed: already shown an event in the same minute');
      return;
    }

    if (_showing &&
        _lastShownMinute != null &&
        eventMinute.isAfter(_lastShownMinute!)) {
      try {
        print('ℹ️ New-minute event arrived; dismissing old popup to show new');
        Navigator.of(ctx, rootNavigator: true).maybePop();
        await Future.delayed(const Duration(milliseconds: 220));
      } catch (_) {}
    }

    _showing = true;
    _lastShownMinute = eventMinute;

    final settings = AlertSettingsManager.instance.settings;
    Timer? forwardTimer;
    void cancelForwardTimerLocal() {
      try {
        forwardTimer?.cancel();
      } catch (_) {}
      forwardTimer = null;
    }

    if (settings.forwardingMode == 'elapsed_time') {
      // Lấy ngưỡng cấu hình (giây) để auto-forward.
      // Giới hạn trong khoảng 30–60s để phù hợp với yêu cầu sản phẩm
      // (tránh người dùng đặt giá trị quá ngắn hoặc quá dài).
      final seconds = settings.forwardingElapsedThresholdSeconds;
      final int clampSeconds = seconds < 30
          ? 30
          : (seconds > 60 ? 60 : seconds);
      try {
        // Khởi tạo timer client-side: nếu caregiver không tương tác trong
        // `clampSeconds` giây kể từ khi modal hiển thị, client sẽ gọi API
        // để chuyển lifecycle sang trạng thái forward (tạm thời do client)
        // — backend nên có worker đảm bảo hành động này ở phía server.
        forwardTimer = Timer(Duration(seconds: clampSeconds), () async {
          AppLogger.i(
            '⏱️ Auto-forward timer fired for ${e.eventId} after ${clampSeconds}s',
          );
          try {
            // Double-check latest lifecycle to avoid racing with a cancel/confirm
            final svc = EventService.withDefaultClient();
            final latest = await svc.fetchLogDetail(e.eventId);
            final ls = (latest.lifecycleState ?? '').toString().toUpperCase();
            if (ls == 'CANCELED' ||
                ls == BackendEnums.lifecycleForwarded.toUpperCase()) {
              AppLogger.i(
                'ℹ️ Event ${e.eventId} already $ls — skipping auto-forward',
              );
              return;
            }
          } catch (err) {
            AppLogger.w(
              '⚠️ Failed to double-check event before auto-forward: $err',
            );
            // proceed to attempt forward anyway
          }

          try {
            // Auto-forward disabled temporarily — comment out lifecycle update.
            // Re-enable when ready to let the client auto-forward events again.
            /*
            await EventsRemoteDataSource().updateEventLifecycle(
              eventId: e.eventId,
              lifecycleState: BackendEnums.lifecycleForwarded,
              notes:
                  'Tự động chuyển tiếp bởi ứng dụng sau ${clampSeconds}s không có phản hồi từ người chăm sóc',
            );
            try {
              AppEvents.instance.notifyEventsChanged();
            } catch (_) {}
            AppLogger.i('✅ Auto-forwarded event ${e.eventId}');
            */
            AppLogger.i(
              'ℹ️ Auto-forward (client) is temporarily disabled for ${e.eventId}',
            );
          } catch (ex, st) {
            AppLogger.e(
              '❌ Failed to auto-forward event ${e.eventId}: $ex',
              ex,
              st,
            );
          }
        });
      } catch (e) {
        AppLogger.e('Failed to start auto-forward timer: $e', e);
      }
    }

    try {
      await showGeneralDialog(
        context: ctx,
        barrierDismissible: true,
        barrierLabel: 'alert',
        barrierColor: const Color.fromRGBO(0, 0, 0, 0.35),
        pageBuilder: (_, __, ___) {
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, minWidth: 220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: AlertEventCard(
                      eventId: e.eventId,
                      eventType: e.eventType,
                      // patientName: "Bệnh nhân XYZ",
                      timestamp: e.detectedAt ?? e.createdAt ?? DateTime.now(),
                      // location: "Phòng ngủ",
                      severity: _mapSeverityFrom(e),
                      description: (e.eventDescription?.isNotEmpty ?? false)
                          ? e.eventDescription!
                          : 'Chạm “Chi tiết” để xem thêm…',
                      isHandled: _isHandled(e),
                      detectionData: e.detectionData,
                      contextData: e.contextData,
                      cameraId: (() {
                        try {
                          final det = e.detectionData;
                          final ctx = e.contextData;
                          return (det['camera_id'] ??
                                  det['camera'] ??
                                  ctx['camera_id'] ??
                                  ctx['camera'])
                              ?.toString();
                        } catch (_) {
                          return null;
                        }
                      })(),
                      confidence: (() {
                        try {
                          if (e.confidenceScore != 0.0) {
                            return e.confidenceScore;
                          }
                          final det = e.detectionData;
                          final ctx = e.contextData;
                          final c =
                              det['confidence'] ??
                              det['confidence_score'] ??
                              ctx['confidence'];
                          if (c == null) return null;
                          if (c is num) return c.toDouble();
                          return double.tryParse(c.toString());
                        } catch (_) {
                          return null;
                        }
                      })(),
                      // onEmergencyCall: () async {
                      //   try {
                      //     String phone = '115';

                      //     final userId = await AuthStorage.getUserId();
                      //     if (userId != null && userId.isNotEmpty) {
                      //       try {
                      //         final ds = EmergencyContactsRemoteDataSource();
                      //         final list = await ds.list(userId);
                      //         if (list.isNotEmpty) {
                      //           list.sort(
                      //             (a, b) =>
                      //                 b.alertLevel.compareTo(a.alertLevel),
                      //           );
                      //           EmergencyContactDto? chosen;
                      //           for (final c in list) {
                      //             if (c.phone.trim().isNotEmpty) {
                      //               chosen = c;
                      //               break;
                      //             }
                      //           }
                      //           chosen ??= list.first;
                      //           if (chosen.phone.trim().isNotEmpty) {
                      //             phone = chosen.phone.trim();
                      //           }
                      //         }
                      //       } catch (_) {}
                      //     }

                      //     String normalized = phone.replaceAll(
                      //       RegExp(r'[\s\-\(\)]'),
                      //       '',
                      //     );
                      //     if (normalized.startsWith('+84')) {
                      //       normalized = '0${normalized.substring(3)}';
                      //     } else if (normalized.startsWith('84')) {
                      //       normalized = '0${normalized.substring(2)}';
                      //     }

                      //     final uri = Uri.parse('tel:$normalized');
                      //     await launchUrl(uri);
                      //   } catch (err) {
                      //     ScaffoldMessenger.of(ctx).showSnackBar(
                      //       SnackBar(
                      //         content: Text('Không thể gọi: $err'),
                      //         backgroundColor: Colors.red,
                      //       ),
                      //     );
                      //   }
                      // },
                      onEmergencyCall: () async {
                        await EmergencyCallHelper.initiateEmergencyCall(ctx);
                        cancelForwardTimerLocal();
                      },

                      onMarkHandled: () async {
                        try {
                          final ds = EventsRemoteDataSource();
                          debugPrint('\n🔄 [InAppAlert] Calling confirmEvent:');
                          debugPrint('  eventId: ${e.eventId}');
                          debugPrint('  confirm: true');

                          cancelForwardTimerLocal();
                          await ds.confirmEvent(
                            eventId: e.eventId,
                            confirmStatusBool: true,
                          );

                          Navigator.of(ctx, rootNavigator: true).maybePop();
                          try {
                            AppEvents.instance.notifyEventsChanged();
                          } catch (_) {}
                        } catch (err) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $err'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          cancelForwardTimerLocal();
                        }
                      },
                      onViewDetails: () async {
                        cancelForwardTimerLocal();
                        Navigator.of(ctx, rootNavigator: true).maybePop();

                        try {
                          final overlayCtx = NavigatorKey
                              .navigatorKey
                              .currentState
                              ?.overlay
                              ?.context;
                          if (overlayCtx == null) return;

                          final sub = AppEvents.instance.eventsChanged.listen((
                            _,
                          ) {
                            try {
                              Navigator.of(
                                overlayCtx,
                                rootNavigator: true,
                              ).maybePop();
                            } catch (_) {}
                          });

                          await showModalBottomSheet(
                            context: overlayCtx,
                            isScrollControlled: true,
                            isDismissible: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) {
                              return DraggableScrollableSheet(
                                initialChildSize: 0.75,
                                minChildSize: 0.5,
                                maxChildSize: 0.95,
                                expand: false,
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
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Builder(
                                          builder: (ctx) {
                                            try {
                                              print(
                                                '[InAppAlert.onViewDetails] creating ActionLogCard for event=${e.eventId} detectedAt=${e.detectedAt} createdAt=${e.createdAt}',
                                              );
                                            } catch (_) {}
                                            return ActionLogCard(
                                              data: e,
                                              onUpdated:
                                                  (newStatus, {confirmed}) {
                                                    try {
                                                      Navigator.of(
                                                        context,
                                                        rootNavigator: true,
                                                      ).maybePop();
                                                    } catch (_) {}
                                                  },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );

                          try {
                            await sub.cancel();
                          } catch (_) {}
                        } catch (_) {
                          // fallback: do nothing if navigation fails
                        }
                      },
                      onDismiss: () {
                        Navigator.of(ctx).maybePop();
                        cancelForwardTimerLocal();
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      // Always stop any in-app audio when the alert closes.
      try {
        AudioService.instance.stop();
      } catch (_) {}
      _showing = false;
    }
  }

  static Future<String> _chooseEmergencyPhone() async {
    // String phone = '115';
    String phone = '';
    try {
      final ds = EmergencyContactsRemoteDataSource();
      final customerId = await ds.resolveCustomerId();
      if (customerId != null && customerId.isNotEmpty) {
        final list = await ds.list(customerId);
        if (list.isNotEmpty) {
          list.sort((a, b) => b.alertLevel.compareTo(a.alertLevel));
          EmergencyContactDto? chosen;
          for (final c in list) {
            if (c.phone.trim().isNotEmpty) {
              chosen = c;
              break;
            }
          }
          chosen ??= list.first;
          if (chosen.phone.trim().isNotEmpty) {
            phone = chosen.phone.trim();
          }
        }
      }
    } catch (_) {}
    // if (phone.isEmpty) return '112';
    if (phone.isEmpty) return '';
    return phone;
  }

  static void _showRestrictedCallMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bạn đã có người chăm sóc. Trong trường hợp khẩn cấp hệ thống sẽ liên hệ caregiver trước.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _mapSeverityFrom(LogEntry e) {
    final s = e.status.toString().toLowerCase();
    if (s.contains('danger')) return 'critical';
    if (s.contains('warning')) return 'medium';
    if (s.contains('critical')) return 'critical';
    if (s.contains('high')) return 'high';
    if (s.contains('medium')) return 'medium';
    if (s.contains('low')) return 'low';
    return 'high';
  }

  static bool _isHandled(LogEntry e) {
    try {
      final dynamic d = e;
      if (d is Map && d['isHandled'] is bool) return d['isHandled'] as bool;
      if (d is Object && (d as dynamic).isHandled is bool) {
        return (d as dynamic).isHandled as bool;
      }
    } catch (_) {}
    return false;
  }
}
