import 'dart:async';

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:provider/provider.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_status.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/alarm_status_service.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/events/screens/propose_screen.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/action_log_card_image_viewer_helper.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';
import 'dart:io';
import 'package:detect_care_caregiver_app/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_lifecycle_service.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/backend_enums.dart' as be;

class AlertEventCard extends StatefulWidget {
  final String eventId;
  final String eventType;
  final String? patientName;
  final DateTime timestamp;
  final DateTime? createdAt;
  // final String location;
  final String severity;
  final String description;
  final String? imageUrl;
  final String? cameraId;
  final Map<String, dynamic> detectionData;
  final Map<String, dynamic> contextData;
  final List<String> imageUrls;
  final double? confidence;
  final bool isHandled;
  final VoidCallback? onEmergencyCall;
  final VoidCallback? onMarkHandled;
  final VoidCallback? onViewDetails;
  final VoidCallback? onDismiss;
  final LogEntry? event;

  const AlertEventCard({
    super.key,
    required this.eventId,
    required this.eventType,
    this.patientName,
    required this.timestamp,
    this.createdAt,
    // required this.location,
    required this.severity,
    required this.description,
    this.imageUrl,
    this.cameraId,
    this.detectionData = const {},
    this.contextData = const {},
    this.imageUrls = const [],
    this.confidence,
    this.isHandled = false,
    this.onEmergencyCall,
    this.onMarkHandled,
    this.onViewDetails,
    this.onDismiss,
    this.event,
  });

  @override
  State<AlertEventCard> createState() => _AlertEventCardState();
}

class _AlertEventCardState extends State<AlertEventCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _badgeController;
  late Animation<double> _badgeScaleAnimation;

  bool _isExpanded = false;
  bool _isConfirming = false;
  bool _isConfirmed = false;
  bool _isMuted = false;
  bool _isSnoozed = false;
  int _snoozeSeconds = 60;
  Timer? _snoozeTicker;
  int? _snoozeRemaining;
  bool _isCancelling = false;
  bool _cancelSent = false;
  bool _isEmergencyCalling = false;
  bool _isResolving = false;
  bool _isImagesLoading = false;
  bool _imagesPrefetched = false;
  bool _alarmResolved = false;
  bool _localEmergencyCalled = false;
  final AlarmStatusService _alarmStatusService = AlarmStatusService.instance;

  EventLog? _liveEvent;
  StreamSubscription<Map<String, dynamic>>? _eventUpdatedSub;
  Future<List<ImageSource>>? _prefetchFuture;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers and tweens
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(
      begin: 0.99,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _badgeScaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.easeInOut),
    );

    // Start the entrance animation
    try {
      _slideController.forward();
    } catch (_) {}

    // Pulse if critical and not handled
    if (!widget.isHandled && _isCritical()) {
      try {
        _pulseController.repeat(reverse: true);
      } catch (_) {}
      // Try to play urgent audio. Failure should not break UI.
      try {
        if (!_isMuted && !_isSnoozed) {
          AudioService.instance.play(urgent: true, loud: true);
        }
      } catch (_) {}
    }

    _alarmStatusService.startPolling(interval: const Duration(seconds: 10));

    // Cancel auto-dismiss listeners were moved to InAppAlert.

    // Prefetch images for the event and gate the "Xem ảnh" button
    try {
      _isImagesLoading = true;
      final event = _buildEventLogForImages();
      _prefetchFuture = loadEventImageUrls(event);
      _prefetchFuture!
          .then((_) {
            if (!mounted) return;
            setState(() {
              _isImagesLoading = false;
              _imagesPrefetched = true;
            });
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              _isImagesLoading = false;
              _imagesPrefetched = true; // allow opening modal even if failed
            });
          });
    } catch (_) {
      // In case of any unexpected error, ensure the button isn't blocked
      _isImagesLoading = false;
      _imagesPrefetched = true;
    }

    try {
      _eventUpdatedSub = AppEvents.instance.eventUpdated.listen((
        payload,
      ) async {
        try {
          final id = payload is Map
              ? (payload['id'] ?? payload['eventId'] ?? payload['event_id'])
              : null;
          if (id == null || id.toString() != widget.eventId) return;

          // If payload contains lifecycle, use it to adjust local state quickly
          final ls = payload is Map
              ? (payload['lifecycle_state'] ??
                    payload['lifecycleState'] ??
                    payload['lifecycle'])
              : null;
          if (ls != null) {
            final upper = ls.toString().toUpperCase();
            if (upper == 'RESOLVED' ||
                upper == 'CANCELED' ||
                upper == 'CANCELLED') {
              if (mounted) setState(() => _alarmResolved = true);
            } else if (upper == 'ALARM_ACTIVATED') {
              if (mounted) setState(() => _alarmResolved = false);
            }
          }

          try {
            final svc = EventService.withDefaultClient();
            final latest = await svc.fetchLogDetail(widget.eventId);
            if (mounted) setState(() => _liveEvent = latest);
          } catch (_) {}
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    // Ensure any playing audio is stopped when the alert card is disposed
    try {
      AudioService.instance.stop();
    } catch (_) {}

    _pulseController.dispose();
    _slideController.dispose();
    try {
      _snoozeTicker?.cancel();
    } catch (_) {}
    try {
      _badgeController.dispose();
    } catch (_) {}
    try {
      _eventUpdatedSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  bool _isCritical() => widget.severity == 'critical';

  Color _getSeverityColor() {
    switch (widget.severity) {
      case 'critical':
        return const Color(0xFFE53E3E);
      case 'high':
        return const Color(0xFFED8936);
      case 'medium':
        return const Color(0xFFED8936);
      case 'low':
        return const Color(0xFF48BB78);
      default:
        return const Color(0xFF718096);
    }
  }

  IconData _getEventIcon() {
    switch (widget.eventType.toLowerCase()) {
      case 'fall':
        return Icons.person_off;
      case 'heart_rate':
        return Icons.favorite;
      case 'temperature':
        return Icons.thermostat;
      case 'movement':
        return Icons.directions_run;
      case 'medication':
        return Icons.medication;
      default:
        return Icons.warning;
    }
  }

  bool _shouldShowCancelButton(
    AlarmStatus? status,
    String evLifecycle,
    bool hasAlarmFlag,
  ) {
    if (_alarmResolved) return false;

    if (status != null) {
      final activeForEvent = status.isEventActive(widget.eventId);
      final noActiveList = status.activeAlarms.isEmpty;
      return status.isPlaying && (activeForEvent || noActiveList);
    }

    final terminalStates = [
      'CANCELED',
      'NOTIFIED',
      'AUTOCALLED',
      'ACKNOWLEDGED',
      'EMERGENCY_RESPONSE_RECEIVED',
      'RESOLVED',
      'EMERGENCY_ESCALATION_FAILED',
    ];
    final bool isAlarmActiveExplicit = evLifecycle == 'ALARM_ACTIVATED';
    final bool isAlarmActiveImplicit = evLifecycle.isEmpty && hasAlarmFlag;
    return !terminalStates.contains(evLifecycle) &&
        (isAlarmActiveExplicit || isAlarmActiveImplicit);
  }

  bool isCustomerVerified() {
    try {
      final ev =
          _liveEvent ??
          (widget.event is EventLog ? widget.event as EventLog : null);
      if (ev == null) return false;
      final hasEmergency = ev.hasEmergencyCall == true;
      final lastEmergencySource = (ev.lastEmergencyCallSource ?? '')
          .toString()
          .toUpperCase();
      final hasAlarm = ev.hasAlarmActivated == true;
      final lastAlarmSource = (ev.lastAlarmActivatedSource ?? '')
          .toString()
          .toUpperCase();

      if (hasEmergency && lastEmergencySource == 'CUSTOMER') return true;
      if (hasAlarm && lastAlarmSource == 'CUSTOMER') return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final raw = widget.createdAt ?? widget.timestamp;

    final source = (widget.createdAt ?? widget.timestamp).toLocal();
    AppLogger.d(
      '[TimeAgo] createdAt=${widget.createdAt} timestamp=${widget.timestamp} now=$now raw=$raw source(local)=$source diff=${now.difference(source)}',
    );

    final difference = now.difference(source);

    if (difference.inMinutes < 1) {
      return 'Vừa xảy ra';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${difference.inDays} ngày trước';
    }
  }

  String _formatRemaining(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      if (s == 0) return '${m}m';
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  Future<void> _handleEmergencyCall() async {
    if (_isEmergencyCalling) return;

    setState(() {
      _isEmergencyCalling = true;
      _localEmergencyCalled = true;
    });

    try {
      HapticFeedback.heavyImpact();

      try {
        widget.onEmergencyCall?.call();
      } catch (_) {}

      try {
        await EmergencyCallHelper.initiateEmergencyCall(context);

        try {
          await EventLifecycleService.withDefaultClient().updateLifecycleFlags(
            eventId: widget.eventId,
            hasEmergencyCall: true,
          );
          AppLogger.api('Set hasEmergencyCall=true for ${widget.eventId}');

          try {
            final ds = EventsRemoteDataSource();
            await ds.updateEventLifecycle(
              eventId: widget.eventId,
              lifecycleState: 'AUTOCALLED',
              notes: 'Gọi khẩn cấp từ ứng dụng người chăm sóc',
            );
          } catch (e) {
            AppLogger.e('Emergency call: lifecycle update failed: $e');
          }

          try {
            final svc = EventService.withDefaultClient();
            final latest = await svc.fetchLogDetail(widget.eventId);
            if (mounted) setState(() => _liveEvent = latest);
          } catch (e) {
            AppLogger.e(
              'Failed to fetch latest event after emergency call: $e',
            );
          }
        } catch (e, st) {
          AppLogger.e(
            'Failed to set hasEmergencyCall for ${widget.eventId}: $e',
            e,
            st,
          );
        }
      } catch (e, st) {
        AppLogger.e('Emergency call failed: $e', e, st);

        if (mounted) {
          setState(() {
            _localEmergencyCalled = false;
          });
        }

        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể thực hiện cuộc gọi khẩn cấp: $e'),
            ),
          );
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmergencyCalling = false;
        });
      }
    }
  }

  Future<void> _initiateEmergencyCall(BuildContext ctx) async {
    if (_isEmergencyCalling) return;
    _isEmergencyCalling = true;

    try {
      HapticFeedback.heavyImpact();
      try {
        widget.onEmergencyCall?.call();
      } catch (_) {}
      try {
        await EmergencyCallHelper.initiateEmergencyCall(ctx);
        try {
          await EventLifecycleService.withDefaultClient().updateLifecycleFlags(
            eventId: widget.eventId,
            hasEmergencyCall: true,
          );
          AppLogger.api('Set hasEmergencyCall=true for ${widget.eventId}');

          try {
            final ds = EventsRemoteDataSource();
            await ds.updateEventLifecycle(
              eventId: widget.eventId,
              lifecycleState: 'AUTOCALLED',
              notes: 'Emergency call initiated from UI',
            );
          } catch (e) {
            AppLogger.e('Emergency call: lifecycle update failed: $e');
          }

          try {
            final svc = EventService.withDefaultClient();
            final latest = await svc.fetchLogDetail(widget.eventId);
            if (mounted) setState(() => _liveEvent = latest);
          } catch (e) {
            AppLogger.e(
              'Failed to fetch latest event after emergency call: $e',
            );
          }
        } catch (e, st) {
          AppLogger.e(
            'Failed to set hasEmergencyCall for ${widget.eventId}: $e',
            e,
            st,
          );
        }
      } catch (e, st) {
        AppLogger.e('Emergency call failed: $e', e, st);
        try {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Không thể thực hiện cuộc gọi khẩn cấp: $e'),
            ),
          );
        } catch (_) {}
      }
    } finally {
      _isEmergencyCalling = false;
    }
  }

  Future<void> _handleMarkAsHandled() async {
    if (_isConfirming || _isConfirmed) return;

    HapticFeedback.selectionClick();
    setState(() => _isConfirming = true);

    final ds = EventsRemoteDataSource();
    try {
      await ds.confirmEvent(
        eventId: widget.eventId,
        confirm: true,
        confirmStatusBool: true,
      );

      _pulseController.stop();
      setState(() {
        _isConfirming = false;
        _isConfirmed = true;
      });

      try {
        await AudioService.instance.stop();
      } catch (_) {}
      _cancelSnooze();

      widget.onMarkHandled?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sự kiện đã được đánh dấu là đã xử lý')),
      );
    } catch (e, st) {
      setState(() => _isConfirming = false);
      AppLogger.e('Failed to confirm event ${widget.eventId}: $e', e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $e')),
      );
    }
  }

  Future<void> _handleResolveAlarm() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);

    try {
      HapticFeedback.heavyImpact();
      final userId = await AuthStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xác thực được người dùng.')),
          );
        }
        return;
      }

      await AlarmRemoteDataSource().cancelAlarm(
        eventId: widget.eventId,
        userId: userId,
        cameraId: widget.cameraId,
      );

      try {
        final ds = EventsRemoteDataSource();
        await ds.updateEventLifecycle(
          eventId: widget.eventId,
          lifecycleState: 'RESOLVED',
          notes: 'Resolved from UI',
        );
      } catch (e) {
        AppLogger.e('Resolve alarm: lifecycle update failed: $e');
      }

      await _alarmStatusService.refreshStatus();

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy báo động'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1400),
          ),
        );
      } catch (_) {}
      if (mounted) setState(() => _alarmResolved = true);

      try {
        final svc = EventService.withDefaultClient();
        final latest = await svc.fetchLogDetail(widget.eventId);
        if (mounted) setState(() => _liveEvent = latest);
      } catch (e) {
        AppLogger.e('Failed to fetch latest event after resolve: $e');
      }
    } catch (e) {
      AppLogger.e('Resolve alarm failed: $e');
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hủy báo động thất bại: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      // stop immediate audio
      try {
        AudioService.instance.stop();
      } catch (_) {}
    } else {
      // resume sound once if critical
      try {
        if (_isCritical()) AudioService.instance.play(urgent: true, loud: true);
      } catch (_) {}
    }
  }

  void _snoozeNow([int? seconds]) {
    if (_isSnoozed) return;
    final secs = seconds ?? _snoozeSeconds;
    setState(() {
      _isSnoozed = true;
      _snoozeSeconds = secs;
      _snoozeRemaining = secs;
    });
    // stop current playback
    try {
      AudioService.instance.stop();
    } catch (_) {}

    // cancel any existing tickers
    try {
      _snoozeTicker?.cancel();
    } catch (_) {}

    // start ticker to update remaining seconds every second
    _snoozeTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_snoozeRemaining != null && _snoozeRemaining! > 0) {
          _snoozeRemaining = _snoozeRemaining! - 1;
        }
      });
      if (_snoozeRemaining != null && _snoozeRemaining! <= 0) {
        // expire
        try {
          _snoozeTicker?.cancel();
        } catch (_) {}
        setState(() {
          _isSnoozed = false;
          _snoozeRemaining = null;
        });
        try {
          _badgeController.stop();
          _badgeController.reset();
        } catch (_) {}
        if (!_isMuted && !_isConfirmed) {
          try {
            AudioService.instance.play(
              urgent: _isCritical(),
              loud: _isCritical(),
            );
          } catch (_) {}
        }
      }
    });
    // start badge animation when snooze begins
    try {
      _badgeController.repeat(reverse: true);
    } catch (_) {}
  }

  void _cancelSnooze() {
    try {
      _snoozeTicker?.cancel();
    } catch (_) {}
    _snoozeTicker = null;
    setState(() {
      _isSnoozed = false;
      _snoozeRemaining = null;
    });
    try {
      _badgeController.stop();
      _badgeController.reset();
    } catch (_) {}
  }

  String _severityText() {
    if (widget.severity == 'critical') return 'Nguy hiểm';
    return 'Cảnh báo';
  }

  bool _shouldDisableCancelButton(EventLog ev) {
    try {
      final hasEmergency = ev.hasEmergencyCall ?? false;
      final emergencySource = ev.lastEmergencyCallSource?.toString().trim();
      final hasAlarm = ev.hasAlarmActivated ?? false;
      final alarmSource = ev.lastAlarmActivatedSource?.toString().trim();

      if (hasEmergency &&
          emergencySource != null &&
          emergencySource.isNotEmpty &&
          emergencySource.toUpperCase() != 'SYSTEM') {
        return true;
      }

      if (hasAlarm &&
          alarmSource != null &&
          alarmSource.isNotEmpty &&
          alarmSource.toUpperCase() != 'SYSTEM') {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  bool _shouldDisableEmergencyCallButton(EventLog ev) {
    try {
      final hasEmergency = ev.hasEmergencyCall ?? false;
      final emergencySource = ev.lastEmergencyCallSource?.toString().trim();

      return hasEmergency &&
          emergencySource != null &&
          emergencySource.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 38, 16, 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Card chính
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _getSeverityColor().withValues(alpha: 0.3),
                            blurRadius: _isCritical() ? 20 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getSeverityColor().withValues(alpha: 0.45),
                            width: widget.isHandled ? 1 : 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            _buildContent(),
                            if (_isExpanded) _buildExpandedContent(),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),

                    // Positioned buttons
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mute button
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                size: 12,
                                color: Colors.black87,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Close button
                          if (widget.onDismiss != null)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: widget.onDismiss,
                                icon: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.black87,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _getSeverityColor().withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: _getSeverityColor().withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main header content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getEventIcon(), color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event type và severity badge
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            be.BackendEnums.eventTypeToVietnamese(
                              widget.eventType.toLowerCase(),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _getSeverityColor(),
                              letterSpacing: .5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _severityText(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Patient name
                      if (widget.patientName?.trim().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(right: 80),
                          child: Text(
                            widget.patientName!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status và Time row
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              isCustomerVerified() ? 0 : 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.isHandled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48BB78),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ĐÃ XỬ LÝ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Text(
                      _getTimeAgo(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isCustomerVerified()) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.10)),
              child: Row(
                children: const [
                  Icon(Icons.verified, size: 12, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sự kiện đã được khách hàng xác thực',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final source = (widget.createdAt ?? widget.timestamp).toLocal();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5568),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoRow(
            'Thời gian',
            '${source.day}/${source.month}/${source.year} ${source.hour.toString().padLeft(2, '0')}:${source.minute.toString().padLeft(2, '0')}',
          ),
          const SizedBox(height: 12),

          // Location
          // Row(
          //   children: [
          //     const Icon(Icons.location_on, size: 16, color: Color(0xFF718096)),
          //     const SizedBox(width: 4),
          //     Expanded(
          //       child: Text(
          //         widget.location,
          //         style: const TextStyle(
          //           fontSize: 12,
          //           color: Color(0xFF718096),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 12),

          // View more button
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              HapticFeedback.lightImpact();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_isExpanded ? 'Thu gọn' : 'Xem chi tiết'),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: _getSeverityColor(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          _buildInfoRow(
            'Loại',
            be.BackendEnums.eventTypeToVietnamese(widget.eventType),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Mô tả',
            widget.description.isNotEmpty ? widget.description : '-',
          ),
          const SizedBox(height: 8),
          // Show camera display name (camera_name) when available from API.
          if (widget.cameraId == null)
            _buildInfoRow('Camera', 'Phòng khách')
          else
            FutureBuilder<CameraEntry>(
              future: CameraApi(
                ApiClient(tokenProvider: AuthStorage.getAccessToken),
              ).getCameraDetail(widget.cameraId!),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _buildInfoRow('Camera', 'Đang tải...');
                }
                if (snap.hasError) {
                  // Fallback to showing cameraId if API call fails.
                  return _buildInfoRow('Camera', widget.cameraId!);
                }
                final cam = snap.data;
                return _buildInfoRow('Camera', cam?.name ?? widget.cameraId!);
              },
            ),

          // const SizedBox(height: 8),
          // _buildInfoRow(
          //   'Độ tin cậy',
          //   widget.confidence != null
          //       ? widget.confidence!.toStringAsFixed(2)
          //       : '-',
          // ),
          if (widget.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final EventLog baseEv =
        _liveEvent ??
        (widget.event is EventLog
            ? widget.event as EventLog
            : _buildEventLogForImages());

    final EventLog _ev = baseEv.copyWith(
      hasEmergencyCall:
          _localEmergencyCalled || (baseEv.hasEmergencyCall ?? false),
      lastEmergencyCallSource: _localEmergencyCalled
          ? 'CAREGIVER'
          : baseEv.lastEmergencyCallSource,
    );

    // Temporarily disable advanced decision logic; keep simple fallbacks
    // final decision = _ev.getAlertActionDecision();
    // final bool isCancelDisabled = decision.disableCancel;
    // final bool showCancelling = _isCancelling && !isCancelDisabled;
    final bool isCancelDisabled = false;
    final bool showCancelling = _isCancelling;

    if (widget.isHandled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF48BB78), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Sự kiện đã được xử lý',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF48BB78),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onViewDetails,
              child: const Text('Chi tiết'),
            ),
          ],
        ),
      );
    }

    String canonicalLifecycle(String? s) {
      if (s == null) return '';
      final trimmed = s.toString().trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.contains('_') ||
          trimmed.contains('-') ||
          trimmed.contains(' ')) {
        return trimmed
            .replaceAll('-', '_')
            .replaceAll(RegExp(r'\s+'), '_')
            .toUpperCase();
      }
      final withUnderscores = trimmed.replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]}_${m[2]}',
      );
      return withUnderscores.toUpperCase();
    }

    final evLifecycle = canonicalLifecycle(_ev.lifecycleState);
    final hasAlarmFlag = _ev.hasAlarmActivated ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getSeverityColor().withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: _getSeverityColor().withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== Xem ảnh =====
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _isImagesLoading
                  ? null
                  : () => _showImagesModal(context),
              icon: _isImagesLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getSeverityColor(),
                        ),
                      ),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(_isImagesLoading ? 'Đang tải ảnh…' : 'Xem ảnh'),
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) => states.contains(MaterialState.disabled)
                      ? Colors.grey.shade400
                      : _getSeverityColor(),
                ),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 12),
                ),
                overlayColor: MaterialStateProperty.all(
                  _getSeverityColor().withOpacity(0.08),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ===== HỦY BÁO ĐỘNG (chỉ khi đang ALARM_ACTIVATED) =====
          ValueListenableBuilder<AlarmStatus?>(
            valueListenable: _alarmStatusService.statusNotifier,
            builder: (context, status, _) {
              final shouldShowResolveButton = _shouldShowCancelButton(
                status,
                evLifecycle,
                hasAlarmFlag,
              );

              if (!shouldShowResolveButton) return const SizedBox.shrink();

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isResolving ? null : _handleResolveAlarm,
                      icon: _isResolving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.cancel_presentation_outlined,
                              color: Colors.white,
                            ),
                      label: _isResolving
                          ? const Text('Đang hủy...')
                          : const Text(
                              'HỦY BÁO ĐỘNG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.deepOrange.withOpacity(0.45);
                              }
                              return Colors.deepOrange;
                            }),
                        foregroundColor: MaterialStateProperty.all<Color>(
                          Colors.white,
                        ),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        elevation: MaterialStateProperty.resolveWith<double?>(
                          (states) =>
                              states.contains(MaterialState.disabled) ? 0 : 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          // ===== GỌI KHẨN CẤP =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_isEmergencyCalling ||
                      _shouldDisableEmergencyCallButton(_ev))
                  ? null
                  : _handleEmergencyCall,
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                'GỌI KHẨN CẤP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(MaterialState.disabled)) {
                    return const Color(0xFFE53E3E).withOpacity(0.45);
                  }
                  return const Color(0xFFE53E3E);
                }),
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 12),
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                elevation: MaterialStateProperty.resolveWith<double?>(
                  (states) => states.contains(MaterialState.disabled) ? 0 : 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ===== HỦY CẢNH BÁO GIẢ =====
          ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    (_isCancelling ||
                        _cancelSent ||
                        _shouldDisableCancelButton(_ev))
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              'Gửi yêu cầu hủy cảnh báo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            content: const Text(
                              'Bạn sắp gửi yêu cầu hủy cảnh báo tới khách hàng để duyệt. Thao tác này không thể hoàn tác và không thể gửi lại.',
                              style: TextStyle(fontSize: 15, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            actionsAlignment: MainAxisAlignment.center,
                            actionsPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Xác nhận gửi',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          HapticFeedback.heavyImpact();
                          setState(() => _isCancelling = true);
                          try {
                            final ds = EventsRemoteDataSource();
                            await ds.proposeDelete(
                              eventId: widget.eventId,
                              reason: 'Sự kiện không chính xác',
                            );

                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Sự kiện đã được gửi đến khách hàng để duyệt',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(milliseconds: 2500),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }

                            if (mounted) {
                              setState(() {
                                _cancelSent = true;
                              });
                            }
                          } catch (e) {
                            AppLogger.e('Propose delete failed: $e');
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Gửi yêu cầu thất bại: $e',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isCancelling = false);
                          }
                        }
                      },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Colors.white,
                  ),
                  foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                    (states) => states.contains(MaterialState.disabled)
                        ? Colors.grey.shade500
                        : Colors.redAccent,
                  ),
                  side: MaterialStateProperty.resolveWith<BorderSide?>(
                    (states) => states.contains(MaterialState.disabled)
                        ? BorderSide(color: Colors.grey.shade300, width: 1.2)
                        : const BorderSide(color: Colors.redAccent, width: 1.2),
                  ),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  overlayColor: MaterialStateProperty.all(
                    Colors.redAccent.withOpacity(0.06),
                  ),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(48),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all(
                    const Size.fromHeight(48),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCancelling)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isCancelling || _cancelSent
                                ? Colors.grey.shade400
                                : Colors.redAccent,
                          ),
                        ),
                      )
                    else
                      Icon(
                        _cancelSent
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _isCancelling
                          ? 'Đang gửi...'
                          : _cancelSent
                          ? (_ev.confirmationState == 'REJECTED_BY_CUSTOMER'
                                ? 'Đã bị từ chối'
                                : 'Đã gửi yêu cầu')
                          : 'Hủy cảnh báo',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  EventLog _buildEventLogForImages() {
    final detection = Map<String, dynamic>.from(widget.detectionData);
    final context = Map<String, dynamic>.from(widget.contextData);
    final cameraId = widget.cameraId;
    final existingCamera =
        detection['camera_id'] ??
        detection['camera'] ??
        context['camera_id'] ??
        context['camera'];
    if ((existingCamera == null || existingCamera.toString().isEmpty) &&
        cameraId != null &&
        cameraId.isNotEmpty) {
      detection['camera_id'] = cameraId;
      context['camera_id'] = cameraId;
    }

    return EventLog(
      eventId: widget.eventId,
      eventType: widget.eventType,
      eventDescription: widget.description,
      confidenceScore: widget.confidence ?? 0,
      detectedAt: widget.timestamp,
      createdAt: widget.createdAt,
      detectionData: detection,
      aiAnalysisResult: const {},
      contextData: context,
      boundingBoxes: const {},
      confirmStatus: widget.isHandled,
      status: widget.isHandled ? 'handled' : 'new',
      imageUrls: widget.imageUrls,
      cameraId: cameraId,
      hasEmergencyCall: false,
      hasAlarmActivated: false,
      lastEmergencyCallSource: null,
      lastAlarmActivatedSource: null,
      lastEmergencyCallAt: null,
      lastAlarmActivatedAt: null,
      isAlarmTimeoutExpired: false,
    );
  }

  Future<void> _showImagesModal(BuildContext pageContext) {
    final event = _buildEventLogForImages();
    return buildEventImagesModal(
      pageContext: pageContext,
      event: event,
      onOpenCamera: _openCameraForEvent,
      showEditButton: false,
      title: 'Hình ảnh',
      alarmSectionBuilder:
          (
            context,
            setDialogState,
            selectedIndex,
            selectedSource,
            isAlarmWorking,
          ) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _cancelSent
                        ? null
                        : () => _initiateEmergencyCall(context),
                    icon: const Icon(Icons.call),
                    label: const Text('Gọi khẩn cấp'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openCameraForEvent(BuildContext context, EventLog event) async {
    final messenger = ScaffoldMessenger.of(context);
    String? cameraId =
        event.cameraId ??
        event.detectionData['camera_id']?.toString() ??
        event.contextData['camera_id']?.toString();

    print('----------------------');
    print('[DEBUG] 🎯 eventId=${event.eventId}');
    print('[DEBUG] initial cameraId=$cameraId');
    print('[DEBUG] detectionData keys=${event.detectionData.keys}');
    print('[DEBUG] contextData keys=${event.contextData.keys}');

    //  Nếu chưa có cameraId hoặc muốn fallback thêm camera khác
    if (cameraId == null) {
      try {
        print('[INFO] cameraId not found, calling getEventById...');
        final detail = await EventsRemoteDataSource().getEventById(
          eventId: event.eventId,
        );

        // Thu thập tất cả camera_id khả dĩ
        final possibleIds = <String>{
          if (detail['camera_id'] != null) detail['camera_id'].toString(),
          if (detail['cameras'] is Map &&
              detail['cameras']['camera_id'] != null)
            detail['cameras']['camera_id'].toString(),
          if (detail['snapshots'] is Map &&
              detail['snapshots']['camera_id'] != null)
            detail['snapshots']['camera_id'].toString(),
        };

        // Nếu có nhiều cameraId thì chọn cái khác event.cameraId (nếu trùng)
        if (possibleIds.isNotEmpty) {
          if (event.cameraId != null && possibleIds.contains(event.cameraId)) {
            possibleIds.remove(event.cameraId);
          }
          cameraId = possibleIds.first;
        }

        print('[INFO] possible cameraIds=$possibleIds');
        print('[INFO] selected cameraId=$cameraId');
      } catch (e) {
        print('[❌] getEventById failed: $e');
      }
    }

    if (cameraId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy camera phù hợp cho sự kiện này.'),
        ),
      );
      return;
    }

    //  Gọi API để lấy danh sách camera người dùng
    try {
      String? customerId;
      try {
        final assignmentsDs = AssignmentsRemoteDataSource();
        final assignments = await assignmentsDs.listPending(status: 'accepted');
        final active = assignments
            .where((a) => a.isActive && (a.status.toLowerCase() == 'accepted'))
            .toList();
        if (active.isNotEmpty) customerId = active.first.customerId;
      } catch (_) {}

      customerId ??= await AuthStorage.getUserId();

      if (customerId == null || customerId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể xác định người dùng để lấy danh sách camera.',
            ),
          ),
        );
        return;
      }

      final api = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      final res = await api.getCamerasByUser(userId: customerId);
      if (res['data'] is! List) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách camera.')),
        );
        return;
      }

      final cameras = (res['data'] as List)
          .map((e) => CameraEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      //  Ưu tiên camera trùng id
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

      // Extract customerId from event context for permission checking
      final eventCustomerId = event.contextData['customer_id']?.toString();

      print(
        '🎬 Opening LiveCameraScreen with url=$cameraUrl, customerId=$eventCustomerId',
      );

      // Xóa cache url cũ trước khi mở
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rtsp_url');
      } catch (_) {}

      //  Điều hướng sang màn hình camera
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveCameraScreen(
            initialUrl: cameraUrl,
            loadCache: false,
            camera: matched,
            customerId: eventCustomerId,
          ),
        ),
      );
    } catch (e, st) {
      print('[❌] _openCameraForEvent error: $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể mở camera: $e')),
      );
    }
  }
}

Widget _buildImageWidget(dynamic imagePath) {
  final path = imagePath is ImageSource ? imagePath.path : imagePath as String;
  final isLocal = imagePath is ImageSource
      ? imagePath.isLocal
      : !path.startsWith('http');

  if (isLocal) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) {
        debugPrint('Error loading local image: $path - $e');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade400,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Không thể tải ảnh',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // Network URL
  return Image.network(
    path,
    fit: BoxFit.contain,
    loadingBuilder: (c, w, progress) {
      if (progress == null) return w;
      return Center(
        child: CircularProgressIndicator(
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      );
    },
    errorBuilder: (c, e, s) {
      debugPrint('Error loading network image: $path - $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'Không thể tải ảnh',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> buildEventImagesModal({
  required BuildContext pageContext,
  required EventLog event,
  Future<void> Function(BuildContext, EventLog)? onOpenCamera,
  VoidCallback? onEdit,
  bool showEditButton = true,
  String title = 'Hình ảnh',
  String Function(bool enabled)? editTooltipBuilder,
  Widget Function(
    BuildContext context,
    StateSetter setDialogState,
    int? selectedIndex,
    ImageSource? selectedSource,
    bool isAlarmWorking,
  )?
  alarmSectionBuilder,
}) {
  final resolveEditTooltip = editTooltipBuilder ?? (_) => 'Cập nhật sự kiện';
  AppLogger.d('\n[ImageModal] Đang tải ảnh cho sự kiện ${event.eventId}...');
  final future = loadEventImageUrls(event).then((imageSources) {
    AppLogger.d('[ImageModal] Tìm thấy ${imageSources.length} ảnh:');
    for (var source in imageSources) {
      AppLogger.d(' - ${source.path}');
    }
    return imageSources;
  });

  return showDialog(
    context: pageContext,
    builder: (dialogCtx) {
      int? selectedIndex;
      bool isAlarmWorking = false;

      return StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (onOpenCamera != null)
                      IconButton(
                        onPressed: () {
                          final navContext = pageContext;
                          final eventData = event;
                          Navigator.of(dialogCtx).pop();
                          Future.delayed(const Duration(milliseconds: 250), () {
                            onOpenCamera(navContext, eventData);
                          });
                        },
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: 'Xem camera',
                      ),
                    if (showEditButton)
                      IconButton(
                        onPressed: onEdit != null
                            ? () {
                                if (!dialogCtx.mounted) return;
                                Navigator.of(dialogCtx).pop();
                                Future.delayed(
                                  const Duration(milliseconds: 200),
                                  () {
                                    onEdit();
                                  },
                                );
                              }
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: resolveEditTooltip(onEdit != null),
                      ),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Main content
                Expanded(
                  child: FutureBuilder<List<ImageSource>>(
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

                      final imageSources = snap.data ?? const [];
                      if (imageSources.isEmpty) {
                        return _emptyImagesWidget();
                      }

                      selectedIndex ??= 0;
                      final selectedSource = selectedIndex != null
                          ? imageSources[selectedIndex!]
                          : null;

                      final footer = alarmSectionBuilder?.call(
                        context,
                        setDialogState,
                        selectedIndex,
                        selectedSource,
                        isAlarmWorking,
                      );

                      return Column(
                        children: [
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.3,
                                  ),
                              itemCount: imageSources.length,
                              itemBuilder: (context, index) {
                                final imageSource = imageSources[index];
                                final isSelected = selectedIndex == index;
                                return GestureDetector(
                                  onTap: () {
                                    if (!dialogCtx.mounted) return;
                                    setDialogState(() => selectedIndex = index);
                                  },
                                  child: Material(
                                    clipBehavior: Clip.antiAlias,
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.12),
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.grey.shade200,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _buildImageWidget(imageSource),
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

                                        // Zoom icon button
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              if (!dialogCtx.mounted) return;
                                              setDialogState(
                                                () => selectedIndex = index,
                                              );
                                              showActionLogCardImageViewer(
                                                dialogCtx,
                                                imageSources,
                                                index,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color.fromRGBO(
                                                  255,
                                                  255,
                                                  255,
                                                  0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.zoom_in,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 12),
                            footer,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Empty images placeholder widget
Widget _emptyImagesWidget() {
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
