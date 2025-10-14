import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/fcm/widgets/fcm_quick_send_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AlertEventCard extends StatefulWidget {
  final String eventId;
  final String eventType;
  final String? patientName;
  final DateTime timestamp;
  // final String location;
  final String severity;
  final String description;
  final String? imageUrl;
  final String? cameraId;
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
    // required this.location,
    required this.severity,
    required this.description,
    this.imageUrl,
    this.cameraId,
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

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _slideController.forward();
    if (!widget.isHandled && _isCritical()) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
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
        return const Color(0xFFECC94B);
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
    final difference = now.difference(widget.timestamp);

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

  void _handleEmergencyCall() {
    HapticFeedback.heavyImpact();
    widget.onEmergencyCall?.call();
  }

  void _handleMarkAsHandled() {
    HapticFeedback.selectionClick();
    _pulseController.stop();
    widget.onMarkHandled?.call();
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
    switch (widget.severity) {
      case 'critical':
        return 'RẤT CAO';
      case 'high':
        return 'CAO';
      case 'medium':
        return 'TRUNG BÌNH';
      case 'low':
        return 'THẤP';
      default:
        return 'CAO';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
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
                      widget.eventType.toUpperCase(),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
            ],
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
                Text(
                  _isExpanded ? 'Thu gọn' : 'Xem chi tiết',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getSeverityColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
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

          _buildInfoRow('Mã sự kiện', widget.eventId),
          const SizedBox(height: 8),

          _buildInfoRow(
            'Thời gian',
            '${widget.timestamp.day}/${widget.timestamp.month}/${widget.timestamp.year} ${widget.timestamp.hour.toString().padLeft(2, '0')}:${widget.timestamp.minute.toString().padLeft(2, '0')}',
          ),

          const SizedBox(height: 8),

          _buildInfoRow('Loại', widget.eventType),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Mô tả',
            widget.description.isNotEmpty ? widget.description : '-',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Camera', widget.cameraId ?? '-'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Độ tin cậy',
            widget.confidence != null
                ? widget.confidence!.toStringAsFixed(2)
                : '-',
          ),

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
        children: [
          // Hàng 2 nút chính
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleEmergencyCall,
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: Text(
                    'GỌI KHẨN CẤP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ).copyWith(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleMarkAsHandled,
                  icon: const Icon(Icons.check),
                  label: Text(
                    'ĐÃ XỬ LÝ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ).copyWith(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF48BB78),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final caregiver = context.read<AuthProvider>().user;
                if (caregiver == null) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (_) => const FcmQuickSendSheet(),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Gửi thông báo cho người nhà'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Hàng nút phụ: Chi tiết / Bỏ qua
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Chi tiết'),
                  style: TextButton.styleFrom(
                    foregroundColor: _getSeverityColor(),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close),
                  label: const Text('Bỏ qua'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF718096),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
