import 'dart:async';

import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

/// (lifecycle_state == 'ALARM_ACTIVATED') detected within the last 30 minutes.
class AlarmBubbleOverlay extends StatefulWidget {
  const AlarmBubbleOverlay({super.key});

  @override
  State<AlarmBubbleOverlay> createState() => _AlarmBubbleOverlayState();
}

class _AlarmBubbleOverlayState extends State<AlarmBubbleOverlay>
    with SingleTickerProviderStateMixin {
  final EventsRemoteDataSource _ds = EventsRemoteDataSource();
  final Duration _pollInterval = const Duration(seconds: 30);
  Timer? _pollTimer;
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
    _startPolling();
    AppEvents.instance.tableChanged.listen((table) {
      if (table != 'event_detections') return;
      _fetchAlarms();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Immediate fetch, then periodic
    _fetchAlarms();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchAlarms());
  }

  Future<void> _fetchAlarms() async {
    try {
      final to = DateTime.now().toUtc();
      final from = to.subtract(const Duration(minutes: 30));
      final params = <String, dynamic>{
        'lifecycle_state': 'ALARM_ACTIVATED',
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'limit': 10,
      };
      final rows = await _ds.listEvents(extraQuery: params);
      final ids = rows
          .map(
            (r) =>
                (r['id'] ??
                        r['event_id'] ??
                        r['eventId'] ??
                        r['eventId']?.toString())
                    ?.toString(),
          )
          .whereType<String>()
          .toSet()
          .toList();

      if (mounted) {
        setState(() {
          _alarmEventIds = ids;
          _visible = ids.isNotEmpty;
        });
      }
      ActiveAlarmNotifier.instance.update(ids.isNotEmpty);
    } catch (e) {
      // ignore errors silently to avoid noisy logs; we can add debug prints if needed
    }
  }

  Future<void> _acknowledgeAlarms() async {
    if (_alarmEventIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final id in _alarmEventIds) {
        try {
          await _ds.updateEventLifecycle(
            eventId: id,
            lifecycleState: 'RESOLVED',
            notes: 'RESOLVED via alarm bubble',
          );
        } catch (e) {
          // continue acknowledging others but surface a message later
          AppLogger.e(
            'AlarmBubble: xác nhận tắt báo động thất bại cho $id: $e',
          );
        }
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã tắt báo động.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Notify app to refresh lists
      try {
        AppEvents.instance.notifyTableChanged('event_detections');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _visible = false;
          _alarmEventIds = [];
        });
      }
      ActiveAlarmNotifier.instance.update(false);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể tắt báo động: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        onTap: () async {
          final confirmed =
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFFF8FAFC),
                  title: const Text('Tắt báo động'),
                  content: const Text('Bạn muốn tắt báo động?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Đồng ý'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!confirmed) return;
          await _acknowledgeAlarms();
        },
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
