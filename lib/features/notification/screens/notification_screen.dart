import 'package:detect_care_caregiver_app/features/notification/utils/notification_translator.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/core/models/notification.dart';

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
  String _selectedFilter = 'Tất cả loại';
  String _selectedStatus = 'Tất cả trạng thái';
  String _searchQuery = '';
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
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải thông báo: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _apiService.getUnreadCount();
    setState(() => _unreadCount = count);
  }

  void _applyFilter() {
    final selectedType = _filterOptions.firstWhere(
      (e) => e['label'] == _selectedFilter,
    )['type'];
    final selectedStatus = _statusOptions.firstWhere(
      (e) => e['label'] == _selectedStatus,
    )['value'];

    setState(() {
      _filteredNotifications = _notifications.where((n) {
        final businessMatch =
            selectedType == null || n.businessType == selectedType;
        final statusMatch =
            selectedStatus == null || (n.metadata?['status'] == selectedStatus);
        final searchMatch =
            _searchQuery.isEmpty ||
            n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.message.toLowerCase().contains(_searchQuery.toLowerCase());
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
                        .map((n) => n.id ?? '')
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
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm thông báo...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilter();
                },
              ),
            ),
          ),

          // Filter business_type
          Container(
            color: Colors.white,
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final o = _filterOptions[index];
                final isSelected = _selectedFilter == o['label'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      o['label'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF3B82F6),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (s) {
                      setState(() {
                        _selectedFilter = o['label'];
                        _applyFilter();
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Filter status
          Container(
            color: Colors.white,
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _statusOptions.length,
              itemBuilder: (context, i) {
                final o = _statusOptions[i];
                final isSelected = _selectedStatus == o['label'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      o['label'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF3B82F6),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (s) {
                      setState(() {
                        _selectedStatus = o['label'];
                        _applyFilter();
                      });
                    },
                  ),
                );
              },
            ),
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
                      final typeVN = NotificationTranslator.businessType(
                        n.businessType,
                      );
                      final statusVN = NotificationTranslator.status(
                        n.metadata?['status']?.toString(),
                      );
                      final isSelected = _selectedIds.contains(n.id ?? '');

                      return Dismissible(
                        key: Key(n.id ?? i.toString()),
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
                          await _apiService.deleteNotification(n.id ?? '');
                          await _loadNotifications();
                          await _fetchUnreadCount();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnread
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFE2E8F0),
                              width: isUnread ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(n.id ?? '')
                                : null,
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedIds.add(n.id ?? '');
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
                                            _toggleSelection(n.id ?? ''),
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
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusVN,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
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
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                              ),
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
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
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
                                          _deleteSingle(n.id ?? '');
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
}
