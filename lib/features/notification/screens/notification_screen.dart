import 'dart:async';

import 'package:detect_care_caregiver_app/core/models/notification.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/notification/screens/notification_detail_screen.dart';
import 'package:detect_care_caregiver_app/features/notification/utils/notification_translator.dart';
import 'package:detect_care_caregiver_app/features/notification/widgets/notification_filter_panel.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:detect_care_caregiver_app/services/notification_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_context.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';

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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationApiService _apiService = NotificationApiService();
  bool _loading = true;
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _filteredNotifications = [];
  String? _selectedFilterValue;
  String? _selectedStatusValue;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _unreadCount = 0;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  final List<Map<String, dynamic>> _filterOptions = [
    {'label': 'Tất cả loại', 'type': null},
    {'label': 'Cảnh báo sự kiện', 'type': 'event_alert'},
    {'label': 'Yêu cầu xác nhận', 'type': 'confirmation_request'},
    {'label': 'Lời mời người chăm sóc', 'type': 'caregiver_invitation'},
    {'label': 'Cập nhật hệ thống', 'type': 'system_update'},
    {'label': 'Khẩn cấp', 'type': 'emergency_alert'},
  ];

  final List<Map<String, dynamic>> _statusOptions = [
    {'label': 'Tất cả trạng thái', 'value': null},
    {'label': 'Đang chờ', 'value': 'pending'},
    {'label': 'Đã gửi', 'value': 'sent'},
    {'label': 'Đã giao', 'value': 'delivered'},
    {'label': 'Thất bại', 'value': 'failed'},
    {'label': 'Không đến được', 'value': 'bounced'},
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _fetchUnreadCount();

    try {
      _notificationSubscription = NotificationManager().onNewNotification
          .listen((event) {
            // Debounce rapid events: batch refreshes into 800ms window
            try {
              _debounceTimer?.cancel();
            } catch (_) {}
            _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
              if (!mounted) return;
              await _loadNotifications();
              await _fetchUnreadCount();
            });
          });
    } catch (_) {}
  }

  StreamSubscription<Map<String, dynamic>?>? _notificationSubscription;
  Timer? _debounceTimer;

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await _apiService.getNotifications();
      setState(() {
        _notifications = res.notifications;
        _notifications.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );
        _filteredNotifications = _notifications;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thông báo: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _apiService.getUnreadCount();
    setState(() => _unreadCount = count);
  }

  void _applyFilter() {
    // Use the pre-computed selected value fields for more robust matching.
    final selectedType = _selectedFilterValue;
    final selectedStatus = _selectedStatusValue;

    setState(() {
      _filteredNotifications = _notifications.where((n) {
        final businessMatch =
            selectedType == null || n.businessType == selectedType;
        // metadata status may be String or other; coerce to string for comparison
        final metaStatus = n.metadata?['status']?.toString();
        final statusMatch =
            selectedStatus == null || metaStatus == selectedStatus;
        final q = _searchQuery.trim().toLowerCase();
        final searchMatch =
            q.isEmpty ||
            n.title.toLowerCase().contains(q) ||
            n.message.toLowerCase().contains(q);
        return businessMatch && statusMatch && searchMatch;
      }).toList();
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllAsRead();
      await _loadNotifications();
      await _fetchUnreadCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả là đã đọc'),
            backgroundColor: Color(0xFF3B82F6),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa ${_selectedIds.length} thông báo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final id in _selectedIds) {
          await _apiService.deleteNotification(id);
        }
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        await _loadNotifications();
        await _fetchUnreadCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa thông báo'),
              backgroundColor: Color(0xFF3B82F6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa: $e'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSingle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa thông báo này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteNotification(id);
        await _loadNotifications();
        await _fetchUnreadCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa thông báo'),
              backgroundColor: Color(0xFF3B82F6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa: $e'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} đã chọn' : 'Thông báo',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        actions: [
          if (!_isSelectionMode) ...[
            if (_unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.done_all, color: Color(0xFF3B82F6)),
              tooltip: 'Đánh dấu tất cả đã đọc',
              onPressed: _unreadCount > 0 ? _markAllAsRead : null,
            ),
            IconButton(
              icon: const Icon(Icons.checklist, color: Color(0xFF64748B)),
              tooltip: 'Chọn để xóa',
              onPressed: _toggleSelectionMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.select_all, color: Color(0xFF3B82F6)),
              tooltip: 'Chọn tất cả',
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _filteredNotifications.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds = _filteredNotifications
                        .map((n) => n.id)
                        .where((id) => id.isNotEmpty)
                        .toSet();
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete,
                color: _selectedIds.isEmpty
                    ? Colors.grey.shade400
                    : Colors.red.shade400,
              ),
              tooltip: 'Xóa đã chọn',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          NotificationFilterPanel(
            searchController: _searchController,
            filterOptions: _filterOptions,
            statusOptions: _statusOptions,
            selectedFilterValue: _selectedFilterValue,
            selectedStatusValue: _selectedStatusValue,
            onSearchChanged: (value) {
              _searchQuery = value;
              _applyFilter();
            },
            onFilterSelected: (value) {
              setState(() {
                _selectedFilterValue = value;
                _applyFilter();
              });
            },
            onStatusSelected: (value) {
              setState(() {
                _selectedStatusValue = value;
                _applyFilter();
              });
            },
          ),

          const SizedBox(height: 8),

          // Notifications list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  )
                : _filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có thông báo nào',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, i) {
                      final n = _filteredNotifications[i];
                      final isUnread = n.isRead == false || n.readAt == null;
                      final typeVN = BackendEnums.businessTypeToVietnamese(
                        n.businessType,
                      );
                      // Determine status key (prefer explicit metadata.status, fallback to priority)
                      String? statusKey = n.metadata?['status']
                          ?.toString()
                          .toLowerCase();
                      if (statusKey == null || statusKey.isEmpty) {
                        final pr = n.priority ?? 0;
                        if (pr >= 8) {
                          statusKey = 'danger';
                        } else if (pr >= 4) {
                          statusKey = 'warning';
                        } else {
                          statusKey = 'normal';
                        }
                      }
                      final statusVN = NotificationTranslator.status(statusKey);
                      final severity = _severityFromStatus(statusKey);
                      final statusColor = NotificationTranslator.statusColor(
                        statusKey,
                      );
                      final borderColor = _notificationBorderColor(
                        severity,
                        isUnread,
                      );
                      final isSelected = _selectedIds.contains(n.id);

                      return Dismissible(
                        key: Key(n.id),
                        direction: _isSelectionMode
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Xác nhận xóa'),
                              content: const Text(
                                'Bạn có chắc muốn xóa thông báo này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await _apiService.deleteNotification(n.id);
                          await _loadNotifications();
                          await _fetchUnreadCount();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: isUnread ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  (0.04 * 255).round(),
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(n.id)
                                : () => _handleNotificationTap(
                                    context,
                                    n,
                                    severity,
                                  ),
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedIds.add(n.id);
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isSelectionMode)
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (v) =>
                                            _toggleSelection(n.id),
                                        activeColor: const Color(0xFF3B82F6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUnread
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.notifications,
                                        color: isUnread
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF94A3B8),
                                        size: 24,
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: isUnread
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF3B82F6),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          n.message,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                typeVN,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                // border: Border.all(
                                                //   color: statusColor
                                                //       .withOpacitySafe(0.24),
                                                // ),
                                              ),
                                              child: Text(
                                                statusVN,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (!_isSelectionMode)
                                              _buildSeverityIndicator(severity),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTime(n.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (!_isSelectionMode &&
                                                _shouldShowSeverityActionButton(
                                                  n,
                                                  severity,
                                                ))
                                              _buildSeverityActionButton(
                                                context,
                                                n,
                                                severity,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isSelectionMode)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Xóa'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deleteSingle(n.id);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      _notificationSubscription?.cancel();
    } catch (_) {}
    try {
      _debounceTimer?.cancel();
    } catch (_) {}
    _searchController.dispose();
    super.dispose();
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
    _NotificationSeverity severity,
  ) {
    if (_shouldShowSeverityActionButton(notification, severity)) {
      _showNotificationActionSheet(context, notification, severity);
    } else if (notification.businessType == 'confirmation_request') {
      _showConfirmationRequestSheet(context, notification);
    } else {
      _openNotificationDetail(context, notification);
    }
  }

  Widget _buildSeverityIndicator(_NotificationSeverity severity) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_severityIndicatorIcon(severity), size: 11, color: color),
    );
  }

  Widget _buildSeverityActionButton(
    BuildContext context,
    NotificationModel notification,
    _NotificationSeverity severity,
  ) {
    final color = _severityColor(severity);
    return TextButton.icon(
      onPressed: () =>
          _showNotificationActionSheet(context, notification, severity),
      icon: Icon(_severityActionIcon(severity), size: 16, color: color),
      label: Text(
        _severityActionLabel(severity),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: color.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  bool _hasSeverityActions(_NotificationSeverity severity) {
    return severity == _NotificationSeverity.danger ||
        severity == _NotificationSeverity.warning;
  }

  void _showNotificationActionSheet(
    BuildContext context,
    NotificationModel notification,
    _NotificationSeverity severity,
  ) {
    final actions = _notificationActionItems(context, notification, severity);
    final severityColor = _severityColor(severity);
    if (actions.isEmpty) {
      _openNotificationDetail(context, notification);
      return;
    }
    showModalBottomSheet<void>(
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
                                color: severityColor.withOpacity(0.15),
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
                                notification.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
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
                          'Chọn hành động phù hợp để xử lý thông báo này.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...actions.map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildNotificationActionTile(
                              action,
                              modalCtx,
                            ),
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

  Widget _buildNotificationActionTile(
    _SeverityActionItem action,
    BuildContext modalCtx,
  ) {
    return ListTile(
      enabled: action.enabled,
      onTap: action.enabled
          ? () {
              Navigator.of(modalCtx).pop();
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

  List<_SeverityActionItem> _notificationActionItems(
    BuildContext context,
    NotificationModel notification,
    _NotificationSeverity severity,
  ) {
    final manager = callActionManager(context);
    final bool canEmergency = manager.allowedActions.contains(
      CallAction.emergency,
    );
    final bool canCaregiver = manager.allowedActions.contains(
      CallAction.caregiver,
    );
    final eventId = _extractEventId(notification);
    final hasEvent = eventId != null;
    final items = <_SeverityActionItem>[];

    if (severity == _NotificationSeverity.danger) {
      items.addAll([
        if (canEmergency)
          _SeverityActionItem(
            icon: Icons.call,
            label: 'Gọi khẩn cấp',
            color: Colors.red.shade600,
            onPressed: () => _initiateEmergencyCall(context),
          )
        else if (canCaregiver)
          _SeverityActionItem(
            icon: Icons.person,
            label: 'Liên hệ người chăm sóc',
            color: Colors.blue.shade700,
            onPressed: () => _callCaregiver(context),
          ),
        _SeverityActionItem(
          icon: Icons.notifications_active,
          label: 'Kích hoạt báo động',
          color: Colors.orange.shade700,
          enabled: hasEvent,
          subtitle: hasEvent ? null : 'Không có sự kiện liên quan',
          onPressed: () {
            if (!hasEvent) {
              _showSnackBar(context, 'Không tìm thấy sự kiện liên quan');
              return;
            }
            _activateAlarmForNotification(context, eventId);
          },
        ),
        _SeverityActionItem(
          icon: Icons.visibility_outlined,
          label: 'Xem chi tiết',
          onPressed: () => _openNotificationDetail(context, notification),
        ),
        _SeverityActionItem(
          icon: Icons.check_circle_outline,
          label: 'Đã xử lý',
          subtitle: notification.hasBeenRead ? 'Đã đánh dấu là đã đọc' : null,
          color: Colors.green.shade600,
          enabled: !notification.hasBeenRead,
          onPressed: () => _markNotificationAsRead(context, notification),
        ),
        if (hasEvent)
          _SeverityActionItem(
            icon: Icons.flag_outlined,
            label: 'Đã xử lý sự kiện',
            subtitle: 'Gọi API xác nhận sự kiện',
            onPressed: () =>
                _confirmEventForNotification(context, eventId, confirm: true),
          ),
      ]);
    } else if (severity == _NotificationSeverity.warning) {
      items.addAll([
        _SeverityActionItem(
          icon: Icons.visibility_outlined,
          label: 'Xem chi tiết',
          onPressed: () => _openNotificationDetail(context, notification),
        ),
        _SeverityActionItem(
          icon: Icons.notifications_active,
          label: 'Báo động',
          color: Colors.orange.shade700,
          enabled: hasEvent,
          subtitle: hasEvent ? null : 'Không có sự kiện liên quan',
          onPressed: () {
            if (!hasEvent) {
              _showSnackBar(context, 'Không tìm thấy sự kiện liên quan');
              return;
            }
            _activateAlarmForNotification(context, eventId);
          },
        ),
        if (canEmergency)
          _SeverityActionItem(
            icon: Icons.call,
            label: 'Gọi khẩn cấp',
            color: Colors.red.shade600,
            onPressed: () => _initiateEmergencyCall(context),
          )
        else if (canCaregiver)
          _SeverityActionItem(
            icon: Icons.person,
            label: 'Liên hệ người chăm sóc',
            color: Colors.blue.shade700,
            onPressed: () => _callCaregiver(context),
          ),
        _SeverityActionItem(
          icon: Icons.check_circle_outline,
          label: 'Đã xử lý',
          subtitle: notification.hasBeenRead ? 'Đã đánh dấu là đã đọc' : null,
          color: Colors.green.shade600,
          enabled: !notification.hasBeenRead,
          onPressed: () => _markNotificationAsRead(context, notification),
        ),
      ]);
    }

    return items;
  }

  void _showConfirmationRequestSheet(
    BuildContext context,
    NotificationModel notification,
  ) {
    final eventId = _extractEventId(notification);
    final subtitle = eventId == null ? 'Không tìm thấy mã sự kiện' : null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yêu cầu xác nhận',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNotificationActionTile(
                      _SeverityActionItem(
                        icon: Icons.visibility,
                        label: 'Xem đề xuất',
                        onPressed: () =>
                            _openNotificationDetail(context, notification),
                      ),
                      modalCtx,
                    ),
                    _buildNotificationActionTile(
                      _SeverityActionItem(
                        icon: Icons.check,
                        label: 'Chấp nhận',
                        enabled: eventId != null,
                        subtitle: subtitle,
                        color: Colors.green.shade600,
                        onPressed: () {
                          if (eventId == null) {
                            _showSnackBar(
                              context,
                              'Không tìm thấy sự kiện liên quan',
                            );
                            return;
                          }
                          _confirmEventForNotification(
                            context,
                            eventId,
                            confirm: true,
                          );
                        },
                      ),
                      modalCtx,
                    ),
                    _buildNotificationActionTile(
                      _SeverityActionItem(
                        icon: Icons.close,
                        label: 'Từ chối',
                        enabled: eventId != null,
                        subtitle: subtitle,
                        color: Colors.red.shade600,
                        onPressed: () {
                          if (eventId == null) {
                            _showSnackBar(
                              context,
                              'Không tìm thấy sự kiện liên quan',
                            );
                            return;
                          }
                          _confirmEventForNotification(
                            context,
                            eventId,
                            confirm: false,
                          );
                        },
                      ),
                      modalCtx,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openNotificationDetail(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final changed = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
    if (changed == true) {
      await _loadNotifications();
      await _fetchUnreadCount();
    }
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

  String _severityActionLabel(_NotificationSeverity severity) {
    switch (severity) {
      case _NotificationSeverity.danger:
        return 'Xử lý khẩn cấp';
      case _NotificationSeverity.warning:
        return 'Xử lý cảnh báo';
      default:
        return 'Xử lý';
    }
  }

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
        return Colors.red.shade600;
      case _NotificationSeverity.warning:
        return Colors.orange.shade700;
      case _NotificationSeverity.info:
        return Colors.blue.shade600;
      case _NotificationSeverity.normal:
        return Colors.blue.shade300;
    }
  }

  Color _notificationBorderColor(
    _NotificationSeverity severity,
    bool isUnread,
  ) {
    final base = _severityColor(severity);
    if (isUnread) return base.withAlpha(200);
    return base.withAlpha(80);
  }

  _NotificationSeverity _severityFromStatus(String? statusKey) {
    final key = statusKey?.toLowerCase().trim() ?? '';
    if (key.isEmpty) return _NotificationSeverity.normal;
    if (['danger', 'critical', 'emergency'].contains(key)) {
      return _NotificationSeverity.danger;
    }
    if (['warning', 'abnormal', 'suspect', 'alert'].contains(key)) {
      return _NotificationSeverity.warning;
    }
    if (['info', 'neutral'].contains(key)) {
      return _NotificationSeverity.info;
    }
    return _NotificationSeverity.normal;
  }

  bool _shouldShowSeverityActionButton(
    NotificationModel notification,
    _NotificationSeverity severity,
  ) {
    if (!_hasSeverityActions(severity)) return false;
    if (_isNotificationOlderThanThreshold(notification)) return false;
    final lifecycle = _extractNotificationLifecycle(notification);
    if (lifecycle == null || lifecycle.isEmpty) return true;
    return !_terminalLifecycleStates.contains(lifecycle);
  }

  static const Set<String> _terminalLifecycleStates = {
    'RESOLVED',
    'CANCELED',
    'ACKNOWLEDGED',
    'EMERGENCY_RESPONSE_RECEIVED',
    'EMERGENCY_ESCALATION_FAILED',
    'FORWARDED',
  };

  String? _extractNotificationLifecycle(NotificationModel notification) {
    return _extractLifecycleFromCandidate(notification.metadata);
  }

  String? _extractLifecycleFromCandidate(dynamic candidate) {
    if (candidate == null) return null;
    if (candidate is Map) {
      for (final entry in candidate.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_lifecycleKeyNames.contains(key)) {
          final normalized = _normalizeLifecycleValue(entry.value?.toString());
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }
      }
      for (final value in candidate.values) {
        final nested = _extractLifecycleFromCandidate(value);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    } else if (candidate is Iterable) {
      for (final item in candidate) {
        final nested = _extractLifecycleFromCandidate(item);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }

  static const Set<String> _lifecycleKeyNames = {
    'lifecycle_state',
    'lifecyclestate',
  };

  bool _isNotificationOlderThanThreshold(NotificationModel notification) {
    final createdAt = notification.createdAt ?? notification.timestamp;
    final age = DateTime.now().difference(createdAt);
    return age.inMinutes >= 15;
  }

  String? _normalizeLifecycleValue(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
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

  Future<void> _initiateEmergencyCall(BuildContext context) async {
    await EmergencyCallHelper.initiateEmergencyCall(context);
  }

  void _showRestrictedCallMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bạn đã có người chăm sóc. Trong trường hợp khẩn cấp hệ thống sẽ liên hệ caregiver trước.',
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
      print('[NotificationScreen] load contacts error: $e');
    }
    if (phoneToCall == null || phoneToCall.isEmpty) {
      return '112';
    }
    return phoneToCall;
  }

  String? _extractEventId(NotificationModel notification) {
    final meta = notification.metadata ?? {};
    final candidates = [
      meta['event_id'],
      meta['eventId'],
      meta['event_id'],
      meta['eventId'],
      meta['id'],
      meta['event'],
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _activateAlarmForNotification(
    BuildContext context,
    String eventId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = await AuthStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      _showSnackBar(context, 'Không xác thực được người dùng');
      return;
    }
    try {
      await AlarmRemoteDataSource().setAlarm(
        eventId: eventId,
        userId: userId,
        enabled: true,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã kích hoạt báo động'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showSnackBar(context, 'Kích hoạt báo động thất bại: $e');
    }
  }

  Future<void> _markNotificationAsRead(
    BuildContext context,
    NotificationModel notification,
  ) async {
    try {
      await _apiService.markAsRead(notification.id);
      _showSnackBar(context, 'Đã đánh dấu là đã đọc');
      await _loadNotifications();
      await _fetchUnreadCount();
    } catch (e) {
      _showSnackBar(context, 'Lỗi: $e');
    }
  }

  Future<void> _confirmEventForNotification(
    BuildContext context,
    String eventId, {
    required bool confirm,
  }) async {
    try {
      await EventsRemoteDataSource().confirmEvent(
        eventId: eventId,
        confirmStatusBool: confirm,
      );
      _showSnackBar(
        context,
        confirm ? 'Đã xác nhận sự kiện' : 'Đã từ chối sự kiện',
      );
    } catch (e) {
      _showSnackBar(context, 'Không thể cập nhật sự kiện: $e');
    }
  }
}

// import 'package:detect_care_caregiver_app/features/notification/utils/notification_translator.dart';
// import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:detect_care_caregiver_app/core/models/notification.dart';
// import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
// import 'package:detect_care_caregiver_app/features/notification/screens/notification_detail_screen.dart';

// class NotificationScreen extends StatefulWidget {
//   const NotificationScreen({super.key});

//       final res = await _apiService.getNotifications();
//       setState(() {
//         _notifications = res.notifications;
//         _notifications.sort(
//           (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
//             a.createdAt ?? DateTime.now(),
//           ),
//         );
//         _filteredNotifications = _notifications;
//       });
//                                                 color: Colors.grey.shade500,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                   if (!_isSelectionMode)
//                                     PopupMenuButton<String>(
//                                       icon: Icon(
//                                         Icons.more_vert,
//                                         color: Colors.grey.shade400,
//                                         size: 20,
//                                       ),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       itemBuilder: (context) => [
//                                         PopupMenuItem(
//                                           value: 'delete',
//                                           child: Row(
//                                             children: const [
//                                               Icon(
//                                                 Icons.delete_outline,
//                                                 color: Colors.red,
//                                                 size: 20,
//                                               ),
//                                               SizedBox(width: 8),
//                                               Text('Xóa'),
//                                             ],
//                                           ),
//                                         ),
//                                       ],
//                                       onSelected: (value) {
//                                         if (value == 'delete') {
//                                           _deleteSingle(n.id);
//                                         }
//                                       },
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ),
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         shadowColor: Colors.black.withValues(alpha: 0.1),
//         title: Text(
//           _isSelectionMode ? '${_selectedIds.length} đã chọn' : 'Thông báo',
//           style: TextStyle(
//             color: Color(0xFF1E293B),
//             fontSize: 20,
//             fontWeight: FontWeight.w700,
//             letterSpacing: -0.5,
//           ),
//         ),
//         leading: Container(
//           margin: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF8FAFC),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: const Color(0xFFE2E8F0)),
//           ),
//           child: IconButton(
//             onPressed: () => Navigator.pop(context),
//             icon: const Icon(
//               Icons.arrow_back_ios_new,
//               color: Color(0xFF374151),
//               size: 18,
//             ),
//           ),
//         ),
//         actions: [
//           if (!_isSelectionMode) ...[
//             if (_unreadCount > 0)
//               Container(
//                 margin: const EdgeInsets.only(right: 8),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFEFF6FF),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 8,
//                       height: 8,
//                       decoration: const BoxDecoration(
//                         color: Color(0xFF3B82F6),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       '$_unreadCount',
//                       style: const TextStyle(
//                         color: Color(0xFF3B82F6),
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             IconButton(
//               icon: const Icon(Icons.done_all, color: Color(0xFF3B82F6)),
//               tooltip: 'Đánh dấu tất cả đã đọc',
//               onPressed: _unreadCount > 0 ? _markAllAsRead : null,
//             ),
//             IconButton(
//               icon: const Icon(Icons.checklist, color: Color(0xFF64748B)),
//               tooltip: 'Chọn để xóa',
//               onPressed: _toggleSelectionMode,
//             ),
//           ] else ...[
//             IconButton(
//               icon: const Icon(Icons.select_all, color: Color(0xFF3B82F6)),
//               tooltip: 'Chọn tất cả',
//               onPressed: () {
//                 setState(() {
//                   if (_selectedIds.length == _filteredNotifications.length) {
//                     _selectedIds.clear();
//                   } else {
//                     _selectedIds = _filteredNotifications
//                         .map((n) => n.id)
//                         .where((id) => id.isNotEmpty)
//                         .toSet();
//                   }
//                 });
//               },
//             ),
//             IconButton(
//               icon: Icon(
//                 Icons.delete,
//                 color: _selectedIds.isEmpty
//                     ? Colors.grey.shade400
//                     : Colors.red.shade400,
//               ),
//               tooltip: 'Xóa đã chọn',
//               onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
//             ),
//           ],
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search bar
//           Container(
//             color: Colors.white,
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF8FAFC),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: const Color(0xFFE2E8F0)),
//               ),
//               child: TextField(
//                 decoration: const InputDecoration(
//                   hintText: 'Tìm kiếm thông báo...',
//                   hintStyle: TextStyle(color: Color(0xFF94A3B8)),
//                   prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                 ),
//                 onChanged: (v) {
//                   _searchQuery = v;
//                   _applyFilter();
//                 },
//               ),
//             ),
//           ),

//           // Filter business_type
//           Container(
//             color: Colors.white,
//             height: 52,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               itemCount: _filterOptions.length,
//               itemBuilder: (context, index) {
//                 final o = _filterOptions[index];
//                 final isSelected = _selectedFilter == o['label'];
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: FilterChip(
//                     label: Text(
//                       o['label'],
//                       style: TextStyle(
//                         color: isSelected
//                             ? Colors.white
//                             : const Color(0xFF64748B),
//                         fontWeight: isSelected
//                             ? FontWeight.w600
//                             : FontWeight.w500,
//                         fontSize: 13,
//                       ),
//                     ),
//                     selected: isSelected,
//                     backgroundColor: const Color(0xFFF1F5F9),
//                     selectedColor: const Color(0xFF3B82F6),
//                     side: BorderSide(
//                       color: isSelected
//                           ? const Color(0xFF3B82F6)
//                           : const Color(0xFFE2E8F0),
//                     ),
//                     onSelected: (s) {
//                       setState(() {
//                         _selectedFilter = o['label'];
//                         _applyFilter();
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),

//           // Filter status
//           Container(
//             color: Colors.white,
//             height: 52,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               itemCount: _statusOptions.length,
//               itemBuilder: (context, i) {
//                 final o = _statusOptions[i];
//                 final isSelected = _selectedStatus == o['label'];
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: FilterChip(
//                     label: Text(
//                       o['label'],
//                       style: TextStyle(
//                         color: isSelected
//                             ? Colors.white
//                             : const Color(0xFF64748B),
//                         fontWeight: isSelected
//                             ? FontWeight.w600
//                             : FontWeight.w500,
//                         fontSize: 13,
//                       ),
//                     ),
//                     selected: isSelected,
//                     backgroundColor: const Color(0xFFF1F5F9),
//                     selectedColor: const Color(0xFF3B82F6),
//                     side: BorderSide(
//                       color: isSelected
//                           ? const Color(0xFF3B82F6)
//                           : const Color(0xFFE2E8F0),
//                     ),
//                     onSelected: (s) {
//                       setState(() {
//                         _selectedStatus = o['label'];
//                         _applyFilter();
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),

//           const SizedBox(height: 8),

//           // Notifications list
//           Expanded(
//             child: _loading
//                 ? const Center(
//                     child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
//                   )
//                 : _filteredNotifications.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.notifications_none,
//                           size: 64,
//                           color: Colors.grey.shade300,
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'Không có thông báo nào',
//                           style: TextStyle(
//                             color: Colors.grey.shade500,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: _filteredNotifications.length,
//                     itemBuilder: (context, i) {
//                       final n = _filteredNotifications[i];
//                       final isUnread = n.isRead == false || n.readAt == null;
//                       final typeVN = BackendEnums.businessTypeToVietnamese(
//                         n.businessType,
//                       );
//                       final statusVN = NotificationTranslator.status(
//                         n.metadata?['status']?.toString(),
//                       );
//                       final isSelected = _selectedIds.contains(n.id);

//                       return Dismissible(
//                         key: Key(n.id),
//                         direction: _isSelectionMode
//                             ? DismissDirection.none
//                             : DismissDirection.endToStart,
//                         background: Container(
//                           margin: const EdgeInsets.only(bottom: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.red.shade400,
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                           alignment: Alignment.centerRight,
//                           padding: const EdgeInsets.only(right: 20),
//                           child: const Icon(Icons.delete, color: Colors.white),
//                         ),
//                         confirmDismiss: (direction) async {
//                           return await showDialog<bool>(
//                             context: context,
//                             builder: (context) => AlertDialog(
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                               title: const Text('Xác nhận xóa'),
//                               content: const Text(
//                                 'Bạn có chắc muốn xóa thông báo này?',
//                               ),
//                               actions: [
//                                 TextButton(
//                                   onPressed: () =>
//                                       Navigator.pop(context, false),
//                                   child: const Text('Hủy'),
//                                 ),
//                                 ElevatedButton(
//                                   onPressed: () => Navigator.pop(context, true),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.red.shade400,
//                                     foregroundColor: Colors.white,
//                                   ),
//                                   child: const Text('Xóa'),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                         onDismissed: (direction) async {
//                           await _apiService.deleteNotification(n.id);
//                           await _loadNotifications();
//                           await _fetchUnreadCount();
//                         },
//                         child: Container(
//                           margin: const EdgeInsets.only(bottom: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(
//                               color: isUnread
//                                   ? const Color(0xFF3B82F6)
//                                   : const Color(0xFFE2E8F0),
//                               width: isUnread ? 2 : 1,
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withAlpha(
//                                   (0.04 * 255).round(),
//                                 ),
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: InkWell(
//                             onTap: _isSelectionMode
//                                 ? () => _toggleSelection(n.id)
//                                 : null,
//                             onLongPress: () {
//                               if (!_isSelectionMode) {
//                                 setState(() {
//                                   _isSelectionMode = true;
//                                   _selectedIds.add(n.id);
//                                 });
//                               }
//                             },
//                             borderRadius: BorderRadius.circular(16),
//                             child: Padding(
//                               padding: const EdgeInsets.all(16),
//                               child: Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   if (_isSelectionMode)
//                                     Container(
//                                       margin: const EdgeInsets.only(right: 12),
//                                       child: Checkbox(
//                                         value: isSelected,
//                                         onChanged: (v) =>
//                                             _toggleSelection(n.id),
//                                         activeColor: const Color(0xFF3B82F6),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             4,
//                                           ),
//                                         ),
//                                       ),
//                                     )
//                                   else
//                                     Container(
//                                       margin: const EdgeInsets.only(right: 12),
//                                       padding: const EdgeInsets.all(10),
//                                       decoration: BoxDecoration(
//                                         color: isUnread
//                                             ? const Color(0xFFEFF6FF)
//                                             : const Color(0xFFF8FAFC),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Icon(
//                                         Icons.notifications,
//                                         color: isUnread
//                                             ? const Color(0xFF3B82F6)
//                                             : const Color(0xFF94A3B8),
//                                         size: 24,
//                                       ),
//                                     ),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: Text(
//                                                 n.title,
//                                                 style: TextStyle(
//                                                   fontSize: 15,
//                                                   fontWeight: isUnread
//                                                       ? FontWeight.w600
//                                                       : FontWeight.w500,
//                                                   color: const Color(
//                                                     0xFF1E293B,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             if (isUnread)
//                                               Container(
//                                                 width: 8,
//                                                 height: 8,
//                                                 decoration: const BoxDecoration(
//                                                   color: Color(0xFF3B82F6),
//                                                   shape: BoxShape.circle,
//                                                 ),
//                                               ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 6),
//                                         Text(
//                                           n.message,
//                                           style: const TextStyle(
//                                             fontSize: 14,
//                                             color: Color(0xFF64748B),
//                                             height: 1.4,
//                                           ),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Wrap(
//                                           spacing: 8,
//                                           runSpacing: 4,
//                                           children: [
//                                             Container(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 8,
//                                                     vertical: 4,
//                                                   ),
//                                               decoration: BoxDecoration(
//                                                 color: const Color(0xFFEFF6FF),
//                                                 borderRadius:
//                                                     BorderRadius.circular(6),
//                                               ),
//                                               child: Text(
//                                                 typeVN,
//                                                 style: const TextStyle(
//                                                   fontSize: 11,
//                                                   color: Color(0xFF3B82F6),
//                                                   fontWeight: FontWeight.w500,
//                                                 ),
//                                               ),
//                                             ),
//                                             Container(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 8,
//                                                     vertical: 4,
//                                                   ),
//                                               decoration: BoxDecoration(
//                                                 color: const Color(0xFFF1F5F9),
//                                                 borderRadius:
//                                                     BorderRadius.circular(6),
//                                               ),
//                                               child: Text(
//                                                 statusVN,
//                                                 style: const TextStyle(
//                                                   fontSize: 11,
//                                                   color: Color(0xFF64748B),
//                                                   fontWeight: FontWeight.w500,
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Row(
//                                           children: [
//                                             Icon(
//                                               Icons.access_time,
//                                               size: 12,
//                                               color: Colors.grey.shade400,
//                                             ),
//                                             const SizedBox(width: 4),
//                                             Text(
//                                               _formatTime(n.createdAt),
//                                               style: TextStyle(
//                                                 fontSize: 12,
//                                                 color: Colors.grey.shade500,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                     ),
//                                     if (!_isSelectionMode)
//                                     PopupMenuButton<String>(
//                                       icon: Icon(
//                                         Icons.more_vert,
//                                         color: Colors.grey.shade400,
//                                         size: 20,
//                                       ),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       itemBuilder: (context) => [
//                                         const PopupMenuItem(
//                                           value: 'delete',
//                                           child: Row(
//                                             children: [
//                                               Icon(
//                                                 Icons.delete_outline,
//                                                 color: Colors.red,
//                                                 size: 20,
//                                               ),
//                                               SizedBox(width: 8),
//                                               Text('Xóa'),
//                                             ],
//                                           ),
//                                       ),
//                                       onTap: _isSelectionMode
//                                           ? () => _toggleSelection(n.id)
//                                           : () async {
//                                               final changed = await Navigator.push<bool?>(
//                                                 context,
//                                                 MaterialPageRoute(
//                                                   builder: (_) => NotificationDetailScreen(notification: n),
//                                                 ),
//                                               );
//                                               if (changed == true) {
//                                                 await _loadNotifications();
//                                                 await _fetchUnreadCount();
//                                               }
//                                             },
//                                       onLongPress: () {
//                                         if (!_isSelectionMode) {
//                                           setState(() {
//                                             _isSelectionMode = true;
//                                             _selectedIds.add(n.id);
//                                           });
//                                         }
//                                       },
//                                     ),
//                                       ],
//                                       onSelected: (value) {
//                                         if (value == 'delete') {
//                                           _deleteSingle(n.id);
//                                         }
//                                       },
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
