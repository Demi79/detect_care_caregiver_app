import 'package:detect_care_caregiver_app/features/home/widgets/alert_new_event_card.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/home/models/log_entry.dart';
import '../utils/app_lifecycle.dart';
import '../../main.dart';
import '../../features/events/data/events_remote_data_source.dart';

class InAppAlert {
  static bool _showing = false;

  static Future<void> show(LogEntry e) async {
    if (_showing || !AppLifecycle.isForeground) return;
    final ctx = NavigatorKey.navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    _showing = true;

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
                    patientName: "Bệnh nhân XYZ",
                    timestamp: e.detectedAt ?? e.createdAt ?? DateTime.now(),
                    location: "Phòng ngủ",
                    severity: _mapSeverityFrom(e),
                    description: (e.eventDescription?.isNotEmpty ?? false)
                        ? e.eventDescription!
                        : 'Chạm “Chi tiết” để xem thêm…',
                    isHandled: _isHandled(e),
                    onEmergencyCall: () async {
                      final uri = Uri.parse('tel:115');
                      await launchUrl(uri);
                    },
                    onMarkHandled: () async {
                      try {
                        final ds = EventsRemoteDataSource();
                        print('\n🔄 [InAppAlert] Calling confirmEvent:');
                        print('  eventId: ${e.eventId}');
                        print('  confirm: true');

                        await ds.confirmEvent(
                          eventId: e.eventId,
                          confirm: true,
                        );

                        Navigator.of(ctx, rootNavigator: true).maybePop();
                      } catch (err) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    onViewDetails: () {
                      Navigator.of(ctx, rootNavigator: true).maybePop();
                    },
                    onDismiss: () {
                      Navigator.of(ctx, rootNavigator: true).maybePop();
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
    _showing = false;
  }

  static String _mapSeverityFrom(LogEntry e) {
    final s = (e.status).toLowerCase();
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
