import 'dart:async';

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';
import 'package:detect_care_caregiver_app/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';
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

  String _getTimeAgo() {
    final now = DateTime.now();
    final source = (widget.createdAt ?? widget.timestamp).toLocal();
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

  void _handleEmergencyCall() {
    HapticFeedback.heavyImpact();
    try {
      widget.onEmergencyCall?.call();
    } catch (_) {}
    EmergencyCallHelper.initiateEmergencyCall(context);
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

      // Stop audio and any pending snooze when handled
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
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
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
            );
          },
        ),
      ),
    );
  }

  String _severityText() {
    // Display only two labels: 'Nguy hiểm' for critical/danger, 'Cảnh báo' otherwise
    if (widget.severity == 'critical') return 'Nguy hiểm';
    return 'Cảnh báo';
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
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
                    if (widget.patientName?.trim().isNotEmpty == true)
                      Text(
                        widget.patientName!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.isHandled)
                    Container(
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
                  const SizedBox(height: 4),
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

          if (widget.onDismiss != null)
            Positioned(
              top: -30,
              right: -20,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.black54,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: Colors.black26,
                  ),
                ),
              ),
            ),
          // Mute / Snooze controls
          Positioned(
            top: -30,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      size: 20,
                      color: Colors.black54,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 1,
                      shadowColor: Colors.black26,
                    ),
                  ),
                  // Snooze with duration selection and countdown badge
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: PopupMenuButton<int>(
                              icon: Icon(
                                Icons.snooze,
                                size: 20,
                                color: _isSnoozed
                                    ? Colors.deepOrange
                                    : Colors.black54,
                              ),
                              onSelected: (secs) => _snoozeNow(secs),
                              itemBuilder: (ctx) => [
                                PopupMenuItem<int>(
                                  value: 30,
                                  child: Text(L10nVi.snooze30s),
                                ),
                                PopupMenuItem<int>(
                                  value: 60,
                                  child: Text(L10nVi.snooze1m),
                                ),
                                PopupMenuItem<int>(
                                  value: 300,
                                  child: Text(L10nVi.snooze5m),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isSnoozed && _snoozeRemaining != null)
                          Positioned(
                            top: -8,
                            right: -8,
                            child: ScaleTransition(
                              scale: _badgeScaleAnimation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatRemaining(_snoozeRemaining!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildContent() {
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
    final source = (widget.createdAt ?? widget.timestamp).toLocal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // _buildInfoRow('Mã sự kiện', widget.eventId),
          // const SizedBox(height: 8),
          _buildInfoRow(
            'Thời gian',
            '${source.day}/${source.month}/${source.year} ${source.hour.toString().padLeft(2, '0')}:${source.minute.toString().padLeft(2, '0')}',
          ),

          const SizedBox(height: 8),

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

  // Widget _buildActionButtons() {
  //   if (widget.isHandled) {
  //     return Container(
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Colors.grey[50],
  //         border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
  //       ),
  //       child: Row(
  //         children: [
  //           const Icon(Icons.check_circle, color: Color(0xFF48BB78), size: 20),
  //           const SizedBox(width: 8),
  //           const Text(
  //             'Sự kiện đã được xử lý',
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: Color(0xFF48BB78),
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //           const Spacer(),
  //           TextButton(
  //             onPressed: widget.onViewDetails,
  //             child: const Text('Chi tiết'),
  //           ),
  //         ],
  //       ),
  //     );
  //   }

  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: _getSeverityColor().withValues(alpha: 0.05),
  //       border: Border(
  //         top: BorderSide(
  //           color: _getSeverityColor().withValues(alpha: 0.2),
  //           width: 1,
  //         ),
  //       ),
  //     ),
  //     child: Column(
  //       children: [
  //         SizedBox(
  //           width: double.infinity,
  //           child: ElevatedButton.icon(
  //             onPressed: _handleEmergencyCall,
  //             icon: const Icon(Icons.phone, color: Colors.white),
  //             label: Text(
  //               'GỌI KHẨN CẤP',
  //               style: const TextStyle(
  //                 fontWeight: FontWeight.bold,
  //                 color: Colors.white,
  //               ).copyWith(fontSize: 13),
  //             ),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: const Color(0xFFE53E3E),
  //               foregroundColor: Colors.white,
  //               padding: const EdgeInsets.symmetric(vertical: 12),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               elevation: 2,
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 8),

  //         SizedBox(
  //           width: double.infinity,
  //           child: OutlinedButton.icon(
  //             onPressed: () {
  //               final caregiver = context.read<AuthProvider>().user;
  //               if (caregiver == null) return;
  //               showModalBottomSheet(
  //                 context: context,
  //                 isScrollControlled: true,
  //                 backgroundColor: Colors.white,
  //                 shape: const RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.vertical(
  //                     top: Radius.circular(16),
  //                   ),
  //                 ),
  //                 builder: (_) => const FcmQuickSendSheet(),
  //               );
  //             },
  //             icon: const Icon(Icons.notifications_outlined),
  //             label: const Text('Gửi thông báo cho người chăm sóc'),
  //             style: OutlinedButton.styleFrom(
  //               padding: const EdgeInsets.symmetric(vertical: 12),
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 8),

  //         // Hàng nút phụ: Chi tiết / Đã xử lý
  //         Row(
  //           children: [
  //             Expanded(
  //               child: TextButton.icon(
  //                 onPressed: () => _showImagesModal(context),
  //                 icon: const Icon(Icons.info_outline),
  //                 label: const Text('Xem ảnh'),
  //                 style: TextButton.styleFrom(
  //                   foregroundColor: _getSeverityColor(),
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: TextButton.icon(
  //                 onPressed: (_isConfirming || _isConfirmed)
  //                     ? null
  //                     : _handleMarkAsHandled,
  //                 icon: const Icon(Icons.check),
  //                 label: _isConfirming
  //                     ? const Text('ĐANG XỬ LÝ...')
  //                     : (_isConfirmed
  //                           ? const Text('ĐÃ XỬ LÝ')
  //                           : const Text('ĐÃ XỬ LÝ')),
  //                 style: TextButton.styleFrom(
  //                   foregroundColor: const Color(0xFF48BB78),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActionButtons() {
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
          // Nút xem ảnh
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showImagesModal(context),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Xem ảnh'),
              style: TextButton.styleFrom(
                foregroundColor: _getSeverityColor(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Nút Báo động
          // SizedBox(
          //   width: double.infinity,
          //   child: ElevatedButton.icon(
          //     onPressed: () async {
          //       final messenger = ScaffoldMessenger.of(context);
          //       HapticFeedback.mediumImpact();
          //       try {
          //         messenger.showSnackBar(
          //           const SnackBar(content: Text('Đang kích hoạt báo động...')),
          //         );

          //         await EventsRemoteDataSource().updateEventLifecycle(
          //           eventId: widget.eventId,
          //           lifecycleState: 'ALARM_ACTIVATED',
          //           notes: 'Activated from app',
          //         );

          //         messenger.showSnackBar(
          //           const SnackBar(content: Text('Đã kích hoạt báo động')),
          //         );
          //       } catch (e) {
          //         messenger.showSnackBar(
          //           SnackBar(content: Text('Kích hoạt báo động thất bại: $e')),
          //         );
          //       }
          //     },
          //     icon: const Icon(
          //       Icons.warning_amber_rounded,
          //       color: Colors.white,
          //     ),
          //     label: const Text(
          //       'BÁO ĐỘNG',
          //       style: TextStyle(
          //         fontWeight: FontWeight.bold,
          //         color: Colors.white,
          //         fontSize: 13,
          //       ),
          //     ),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.deepOrange,
          //       padding: const EdgeInsets.symmetric(vertical: 12),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //       elevation: 2,
          //     ),
          //   ),
          // ),

          // const SizedBox(height: 8),

          // Nút Gọi khẩn cấp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleEmergencyCall,
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                'GỌI KHẨN CẤP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Nút Hủy bỏ cảnh báo (popup xác nhận)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận hủy cảnh báo'),
                    content: const Text(
                      'Bạn có chắc chắn rằng cảnh báo này là giả và muốn hủy bỏ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Không'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Xác nhận'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  HapticFeedback.heavyImpact();
                  setState(() => _isCancelling = true);
                  try {
                    final ds = EventsRemoteDataSource();
                    await ds.cancelEvent(eventId: widget.eventId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cảnh báo đã được hủy.'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    try {
                      AppEvents.instance.notifyEventsChanged();
                    } catch (_) {}
                    // Close the in-app alert popup after successful cancel.
                    // Prefer calling the provided onDismiss callback (host may
                    // manage how the alert was shown). Fallback to popping the
                    // current route/dialog if no callback is provided.
                    try {
                      if (widget.onDismiss != null) {
                        widget.onDismiss!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    } catch (_) {}
                  } catch (e) {
                    AppLogger.e('Cancel event failed: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hủy cảnh báo thất bại: $e'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isCancelling = false);
                  }
                }
              },
              icon: const Icon(Icons.cancel_outlined),
              label: _isCancelling
                  ? const Text('Đang hủy...')
                  : const Text('Hủy cảnh báo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagesModal(BuildContext context) {
    EventLog buildEventFromWidget() {
      final det = Map<String, dynamic>.from(widget.detectionData);
      final ctx = Map<String, dynamic>.from(widget.contextData);
      if ((det['camera_id'] ??
                  det['camera'] ??
                  ctx['camera_id'] ??
                  ctx['camera']) ==
              null &&
          widget.cameraId != null &&
          widget.cameraId!.isNotEmpty) {
        det['camera_id'] = widget.cameraId;
        ctx['camera_id'] = widget.cameraId;
      }

      return EventLog(
        eventId: widget.eventId,
        status: widget.severity,
        eventType: widget.eventType,
        eventDescription: widget.description,
        confidenceScore: widget.confidence ?? 0.0,
        detectedAt: widget.timestamp,
        createdAt: widget.createdAt ?? widget.timestamp,
        detectionData: det,
        aiAnalysisResult: {},
        contextData: ctx,
        boundingBoxes: {},
        confirmStatus: widget.isHandled,
        cameraId: widget.cameraId,
        imageUrls: (() {
          final list = <String>[];
          list.addAll(widget.imageUrls);
          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
            list.add(widget.imageUrl!);
          }
          return list;
        })(),
      );
    }

    final event = buildEventFromWidget();
    final future = loadEventImageUrls(event).then((urls) => urls);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ảnh sự kiện',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    onPressed: () async {
                      final event = buildEventFromWidget();
                      await _openCameraForEvent(ctx, event);
                    },
                    icon: const Icon(Icons.videocam_outlined),
                    tooltip: 'Xem camera',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          'Lỗi tải ảnh: ${snap.error}',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      );
                    }

                    final urls = snap.data ?? const [];
                    if (urls.isEmpty) {
                      return Center(
                        child: Text(
                          'Ảnh sự kiện tạm thời chưa khả dụng.\nVui lòng chờ ít giây để hệ thống đồng bộ.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    if (urls.length == 1) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          urls.first,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      );
                    }

                    // Multiple images: show a grid like in ActionLogCard.
                    return SizedBox(
                      height: 220,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
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
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.black,
                                  insetPadding: const EdgeInsets.all(20),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          errorBuilder: (c, e, s) => Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                              255,
                                              255,
                                              255,
                                              0.9,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: IconButton(
                                            onPressed: () async {
                                              final event =
                                                  buildEventFromWidget();
                                              Navigator.of(context).pop();
                                              await _openCameraForEvent(
                                                context,
                                                event,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.videocam,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (c, w, progress) =>
                                      progress == null
                                      ? w
                                      : const Center(
                                          child: CircularProgressIndicator(),
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
        ),
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
      final res = await api.getCamerasByUser(customerId: customerId);
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
      print('🎬 Opening LiveCameraScreen with url=$cameraUrl');

      // Xóa cache url cũ trước khi mở
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rtsp_url');
      } catch (_) {}

      //  Điều hướng sang màn hình camera
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LiveCameraScreen(initialUrl: cameraUrl, loadCache: false),
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
