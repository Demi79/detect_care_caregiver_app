import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';

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
            spreadRadius: 0,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statusChip(status, statusColor),
                    _confirmChip(data.confirmStatus),
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
                          _eventTypeChip(data.eventType, typeColor),

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
                                _formatDateTime(data.detectedAt),
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
                _factCard(
                  icon: Icons.analytics_outlined,
                  label: 'Confidence',
                  value: _percent(data.confidenceScore),
                  color: _getConfidenceColor(data.confidenceScore),
                  fullWidth: true,
                ),
                const SizedBox(height: 12),

                _factCard(
                  icon: Icons.fingerprint_outlined,
                  label: 'Event ID',
                  value: _shortId(data.eventId),
                  color: Colors.blue.shade600,
                  fullWidth: true,
                ),

                if (data.createdAt != null) ...[
                  const SizedBox(height: 12),
                  _factCard(
                    icon: Icons.schedule_outlined,
                    label: 'Created',
                    value: _formatDateTime(data.createdAt),
                    color: Colors.grey.shade600,
                    fullWidth: true,
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetails(context),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Details'),
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
            status.toUpperCase(),
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
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _titleFromType(String t) {
    switch (t.toLowerCase()) {
      case 'fall':
        return 'Fall Detection Alert';
      case 'abnormal_behavior':
        return 'Abnormal Behavior Detected';
      case 'visitor_detected':
        return 'Visitor Presence Detected';
      case 'seizure':
        return 'Seizure Activity Alert';
      default:
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

  void _showDetails(BuildContext context) {
    final Color statusColor = AppTheme.getStatusColor(data.status);
    final Color typeColor = _eventTypeColor(data.eventType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                              Row(
                                children: [
                                  _statusChip(data.status, statusColor),
                                  const SizedBox(width: 8),
                                  _eventTypeChip(data.eventType, typeColor),
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
                            onPressed: () => _showUpdateModal(context),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Update'),
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
                              );
                              _showImagesModal(context, eventLog);
                            },
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('View Images'),
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
                          _sectionTitle('Event Overview'),
                          const SizedBox(height: 12),
                          _detailCard([
                            _kvRow(
                              'Confirmed',
                              data.confirmStatus ? 'Yes' : 'No',
                              data.confirmStatus
                                  ? Colors.green.shade600
                                  : Colors.grey.shade600,
                              data.confirmStatus
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),

                            _kvRow(
                              'Status',
                              data.status,
                              statusColor,
                              Icons.flag_outlined,
                            ),
                            _kvRow(
                              'Type',
                              data.eventType,
                              typeColor,
                              Icons.category_outlined,
                            ),
                            _kvRow(
                              'Confidence',
                              _percent(data.confidenceScore),
                              _getConfidenceColor(data.confidenceScore),
                              Icons.analytics_outlined,
                            ),
                            _kvRow(
                              'Event ID',
                              _shortId(data.eventId),
                              Colors.grey.shade600,
                              Icons.fingerprint_outlined,
                            ),
                            _kvRow(
                              'Detected',
                              _formatDateTime(data.detectedAt),
                              Colors.grey.shade600,
                              Icons.access_time_outlined,
                            ),
                            if (data.createdAt != null)
                              _kvRow(
                                'Created',
                                _formatDateTime(data.createdAt),
                                Colors.grey.shade600,
                                Icons.schedule_outlined,
                              ),
                          ]),

                          if (data.contextData.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle('Context Data'),
                            const SizedBox(height: 12),
                            _jsonPreview(data.contextData),
                          ],

                          if (data.aiAnalysisResult.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle('AI Analysis Result'),
                            const SizedBox(height: 12),
                            _jsonPreview(data.aiAnalysisResult),
                          ],

                          if (data.detectionData.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle('Detection Data'),
                            const SizedBox(height: 12),
                            _jsonPreview(data.detectionData),
                          ],

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _confirmChip(bool confirmed) {
    final Color c = confirmed ? Colors.green.shade600 : Colors.red.shade500;
    final String label = confirmed ? 'CONFIRMED' : 'UNCONFIRMED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: c,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

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

  void _showUpdateModal(BuildContext pageContext) {
    final statusOptions = ['danger', 'warning', 'normal'];
    final statusLabels = {
      'danger': 'Nguy hiểm',
      'warning': 'Cảnh báo',
      'normal': 'Bình thường',
    };
    final statusIcons = {
      'danger': Icons.priority_high_rounded,
      'warning': Icons.warning_amber_rounded,
      'normal': Icons.check_circle_rounded,
    };

    String selectedStatus = data.status.toLowerCase();
    String note = '';
    bool? confirmToggle = data.confirmStatus;

    bool _mapStatusToConfirm(String s) {
      switch (s) {
        case 'danger':
        case 'warning':
          return true;
        case 'normal':
        default:
          return false;
      }
    }

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cập nhật sự kiện',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Trạng thái
                  _ElevatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              'Cập nhật trạng thái',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: statusOptions.map((status) {
                            final isSelected = selectedStatus == status;
                            final statusColor = AppTheme.getStatusColor(status);
                            final label = statusLabels[status]!;
                            final icon = statusIcons[status]!;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedStatus = status),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? statusColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isSelected
                                        ? statusColor
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: statusColor.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 8),
                                      )
                                    else
                                      const BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.06),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chọn mức độ phù hợp với tình trạng hiện tại.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Xác nhận (ưu tiên boolean)
                  _ElevatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Xác nhận sự kiện',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Đánh dấu đã xử lý'),

                          value:
                              (confirmToggle ??
                              _mapStatusToConfirm(selectedStatus)),
                          onChanged: (v) => setState(() => confirmToggle = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ghi chú
                  _ElevatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ghi chú',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => note = v,
                          maxLines: 4,
                          maxLength: 250,
                          decoration: InputDecoration(
                            hintText:
                                'Thêm ghi chú liên quan đến sự kiện (không bắt buộc)...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.edit_outlined),
                            counterText: '',
                            contentPadding: const EdgeInsets.all(12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Mẹo: mô tả ngắn gọn tình hình thực tế…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            foregroundColor: Colors.grey.shade700,
                          ),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmUpdate(
                            pageContext,
                            selectedStatus,
                            note,
                            confirmToggle,
                          ),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            'Lưu thay đổi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
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
    );
  }

  void _confirmUpdate(
    BuildContext pageContext,
    String newStatus,
    String note,
    bool? confirmToggle,
  ) {
    showDialog(
      context: pageContext,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_outlined,
                color: Colors.orange.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Xác nhận cập nhật',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ sửa đổi kết quả ghi nhận từ AI. Tiếp tục?',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(confirmCtx).pop();
              Navigator.of(pageContext).pop();
              await _performUpdate(pageContext, newStatus, note, confirmToggle);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpdate(
    BuildContext pageContext,
    String newStatus, // 'danger' | 'warning' | 'normal'
    String note,
    bool? confirmToggle,
  ) async {
    final messenger = ScaffoldMessenger.of(pageContext);

    print(
      '\n📝 [ActionLog] Starting update process for event ${data.eventId}:',
    );
    print('Input parameters:');
    print('  newStatus: $newStatus');
    print('  note: ${note.isEmpty ? "(empty)" : note}');
    print('  confirmToggle: $confirmToggle');

    try {
      final ds = EventsRemoteDataSource();

      // 1) Cập nhật status/notes (endpoint /events/{id})
      print('\n🔄 [ActionLog] Step 1: Updating event status and notes');
      print('  eventId: ${data.eventId}');
      print('  status: $newStatus');
      print('  notes: ${note.trim().isEmpty ? '-' : note.trim()}');

      await ds.updateEvent(
        eventId: data.eventId,
        status: newStatus,
        notes: note.trim().isEmpty ? '-' : note.trim(),
      );

      print('✅ [ActionLog] Status update successful');

      // 2) Gọi confirm:
      //    - Nếu user có bật/tắt toggle -> ưu tiên boolean 'confirm'
      //    - Nếu không đụng toggle -> gửi 'confirm_status' (legacy) để server map
      if (confirmToggle != null) {
        print('\n🔄 [ActionLog] Calling confirmEvent with toggle:');
        print('  eventId: ${data.eventId}');
        print('  confirm: $confirmToggle');
        print('  notes: ${note.trim().isEmpty ? 'null' : note.trim()}');

        await ds.confirmEvent(
          eventId: data.eventId,
          confirm: confirmToggle,
          notes: note.trim().isEmpty ? null : note.trim(),
        );
      } else {
        print('\n🔄 [ActionLog] Calling confirmEvent with status:');
        print('  eventId: ${data.eventId}');
        print('  confirmStatus: $newStatus');
        print('  notes: ${note.trim().isEmpty ? 'null' : note.trim()}');

        await ds.confirmEvent(
          eventId: data.eventId,
          confirmStatus: newStatus, // 'normal' | 'warning' | 'danger'
          notes: note.trim().isEmpty ? null : note.trim(),
        );
      }

      print('\n✅ [ActionLog] Event update completed successfully');
      print('Summary:');
      print('  - Updated status to: $newStatus');
      print(
        '  - Confirmation type: ${confirmToggle != null ? "toggle=$confirmToggle" : "status=$newStatus"}',
      );
      print('  - Notes updated: ${note.trim().isNotEmpty}');

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cập nhật sự kiện thành công'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      print('\n❌ [ActionLog] Event update failed:');
      print('Error: $e');
      print('Stack trace:');
      print(stack);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Cập nhật sự kiện thất bại: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showImagesModal(BuildContext context, EventLog event) {
    debugPrint('\n🖼️ Loading images for event ${event.eventId}...');
    final future = loadEventImageUrls(event).then((urls) {
      debugPrint('📸 Found ${urls.length} images:');
      for (var url in urls) {
        debugPrint('   - $url');
      }
      return urls;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
                      'Event Images',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                                        'Image ${index + 1}',
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
            'No Images Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No images were captured for this event.',
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
                  'Image ${index + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
