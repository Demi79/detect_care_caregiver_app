import 'dart:async';

import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/ui/in_app_alert.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_status.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/alarm_status_service.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';

class AlarmBubbleOverlay extends StatefulWidget {
  const AlarmBubbleOverlay({super.key});

  @override
  State<AlarmBubbleOverlay> createState() => _AlarmBubbleOverlayState();
}

class _AlarmBubbleOverlayState extends State<AlarmBubbleOverlay>
    with SingleTickerProviderStateMixin {
  final AlarmStatusService _alarmStatusService = AlarmStatusService.instance;
  AlarmStatus? _lastStatus;
  StreamSubscription? _tableChangedSub;
  VoidCallback? _statusListener;
  bool _visible = false;
  List<String> _alarmEventIds = [];
  Offset _position = const Offset(20, 220);

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _statusListener = () {
      _applyStatus(_alarmStatusService.statusNotifier.value);
    };

    _alarmStatusService.startPolling(interval: const Duration(seconds: 10));
    _alarmStatusService.statusNotifier.addListener(_statusListener!);
    _applyStatus(_alarmStatusService.statusNotifier.value);

    _tableChangedSub = AppEvents.instance.tableChanged.listen((table) {
      if (table != 'event_detections') return;
      _alarmStatusService.refreshStatus();
    });
  }

  @override
  void dispose() {
    _tableChangedSub?.cancel();
    if (_statusListener != null) {
      _alarmStatusService.statusNotifier.removeListener(_statusListener!);
    }
    _pulseController.dispose();
    super.dispose();
  }

  void _applyStatus(AlarmStatus? status) {
    _lastStatus = status;

    final ids = <String>[];
    if (status != null) {
      final fromStatus = status.eventId;
      if (fromStatus != null && fromStatus.isNotEmpty) {
        ids.add(fromStatus);
      }
    }

    final shouldShow = status?.isPlaying == true;

    if (mounted) {
      setState(() {
        _alarmEventIds = ids;
        _visible = shouldShow;
      });
    }

    ActiveAlarmNotifier.instance.update(shouldShow);
  }

  Future<void> _openAlertCard() async {
    final messenger = ScaffoldMessenger.of(context);
    final resolvedEventId = _lastStatus?.eventId;

    if (resolvedEventId == null || resolvedEventId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy sự kiện báo động đang phát'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.05),
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    EventLog? event;
    try {
      event = await EventService.withDefaultClient().fetchLogDetail(
        resolvedEventId,
      );
    } catch (e, st) {
      AppLogger.e('AlarmBubble: load event $resolvedEventId failed: $e', e, st);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể tải chi tiết sự kiện: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    if (!mounted || event == null) return;
    await InAppAlert.show(event, allowProposedOrUpdated: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final maxX = screenSize.width - 64;
    final maxY = screenSize.height - 120;
    final dx = _position.dx.clamp(8.0, maxX);
    final dy = _position.dy.clamp(80.0, maxY);

    return Positioned(
      left: dx,
      top: dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() => _position += d.delta);
        },
        onTap: _openAlertCard,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // pulse effect
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                final scale = 1.0 + (t * 0.8);
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Container(
                  width: 64 * scale,
                  height: 64 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.08 * opacity),
                  ),
                );
              },
            ),

            // main bubble
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 22,
                    ),
                    if (_alarmEventIds.length > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        _alarmEventIds.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
