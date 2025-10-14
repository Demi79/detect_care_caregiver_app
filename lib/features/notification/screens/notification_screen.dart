import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/models/notification.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationApiService _apiService = NotificationApiService();

  List<NotificationModel> _notifications = [];
  List<NotificationModel> _filteredNotifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _selectedFilter = 'Tất cả';
  final List<String> _filterOptions = [
    'Tất cả',
    'Cảnh báo',
    'Nhắc nhở',
    'Cập nhật',
    'Khẩn cấp',
  ];

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasNextPage = false;

  // Bulk actions
  final Set<String> _selectedNotifications = {};
  bool _isSelectionMode = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilter();
      });
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedNotifications.clear();
    });
  }

  void _toggleNotificationSelection(String notificationId) {
    setState(() {
      if (_selectedNotifications.contains(notificationId)) {
        _selectedNotifications.remove(notificationId);
      } else {
        _selectedNotifications.add(notificationId);
      }
    });
  }

  void _selectAllNotifications() {
    setState(() {
      _selectedNotifications.clear();
      _selectedNotifications.addAll(_filteredNotifications.map((n) => n.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedNotifications.clear();
    });
  }

  Future<void> _bulkMarkAsRead() async {
    try {
      // For bulk operations, we'll mark each one individually
      // In a real app, you'd have a bulk API endpoint
      for (final id in _selectedNotifications) {
        await _apiService.markAsRead(id);
      }

      setState(() {
        for (final id in _selectedNotifications) {
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
            );
          }
        }
        _applyFilter();
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã đánh dấu ${_selectedNotifications.length} thông báo đã đọc',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đánh dấu đã đọc: $e')),
        );
      }
    }
  }

  Future<void> _bulkDelete() async {
    try {
      for (final id in _selectedNotifications) {
        await _apiService.deleteNotification(id);
      }

      setState(() {
        _notifications.removeWhere(
          (n) => _selectedNotifications.contains(n.id),
        );
        _applyFilter();
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ${_selectedNotifications.length} thông báo'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa thông báo: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    debugPrint(
      '🔔 NotificationScreen: _loadNotifications called with loadMore=$loadMore',
    );
    if (loadMore && !_hasNextPage) return;

    try {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
          _hasError = false;
          _currentPage = 1;
        }
      });

      final filter = _getCurrentFilter();
      final response = await _apiService.getNotifications(
        page: loadMore ? _currentPage + 1 : 1,
        pageSize: _pageSize,
        filter: filter,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      debugPrint('📱 Loaded ${response.notifications.length} notifications');
      debugPrint(
        '📄 Page: ${response.page}, Has next: ${response.hasNextPage}',
      );

      setState(() {
        if (loadMore) {
          _notifications.addAll(response.notifications);
          _currentPage++;
        } else {
          _notifications = response.notifications;
        }

        _hasNextPage = response.hasNextPage;

        _applyFilter();
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
      debugPrint('Error loading notifications: $e');
    }
  }

  NotificationFilter? _getCurrentFilter() {
    if (_selectedFilter == 'Tất cả') return null;

    final typeMap = {
      'Cảnh báo': NotificationType.warning,
      'Nhắc nhở': NotificationType.reminder,
      'Cập nhật': NotificationType.update,
      'Khẩn cấp': NotificationType.emergency,
    };

    final type = typeMap[_selectedFilter];
    return type != null ? NotificationFilter(type: type) : null;
  }

  void _applyFilter() {
    if (_selectedFilter == 'Tất cả') {
      _filteredNotifications = _notifications.where((notification) {
        if (_searchQuery.isEmpty) return true;
        return notification.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            notification.message.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    } else {
      final typeMap = {
        'Cảnh báo': NotificationType.warning,
        'Nhắc nhở': NotificationType.reminder,
        'Cập nhật': NotificationType.update,
        'Khẩn cấp': NotificationType.emergency,
      };
      final type = typeMap[_selectedFilter];
      _filteredNotifications = _notifications.where((notification) {
        final typeMatch = type == null || notification.type == type;
        final searchMatch =
            _searchQuery.isEmpty ||
            notification.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            notification.message.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        return typeMatch && searchMatch;
      }).toList();
    }

    debugPrint(
      '🔍 Filtered notifications: ${_filteredNotifications.length} out of ${_notifications.length}',
    );
  }

  Future<void> _markAsRead(String id) async {
    try {
      final success = await _apiService.markAsRead(id);
      if (success) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
            );
            _applyFilter();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đánh dấu đã đọc: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _apiService.markAllAsRead();
      if (success) {
        setState(() {
          _notifications = _notifications
              .map((n) => n.copyWith(isRead: true))
              .toList();
          _applyFilter();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đánh dấu tất cả đã đọc: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      final success = await _apiService.deleteNotification(id);
      if (success) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
          _applyFilter();
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa thông báo')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa thông báo: $e')));
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  Future<void> _loadMoreNotifications() async {
    if (_hasNextPage && !_isLoadingMore) {
      await _loadNotifications(loadMore: true);
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read first
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Handle different notification types
    if (notification.patientId != null) {
      // Navigate to patient details
      _navigateToPatient(notification.patientId!, notification.patientName);
    } else if (notification.actionUrl != null) {
      // Handle action URL
      _handleActionUrl(notification.actionUrl!);
    } else {
      // Show notification details
      _showNotificationDetails(notification);
    }
  }

  void _navigateToPatient(String patientId, String? patientName) {
    // TODO: Navigate to patient details screen
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Điều hướng đến bệnh nhân: ${patientName ?? patientId}',
          ),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () {
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (context) => PatientDetailsScreen(patientId: patientId),
              // ));
            },
          ),
        ),
      );
    }
  }

  void _handleActionUrl(String actionUrl) {
    // TODO: Handle different action URLs
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Action URL: $actionUrl')));
  }

  void _showNotificationDetails(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 16),
            Text(
              'Thời gian: ${_formatTime(notification.timestamp)}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            if (notification.patientName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Bệnh nhân: ${notification.patientName}',
                style: TextStyle(color: AppTheme.primaryBlue),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          if (notification.patientId != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPatient(
                  notification.patientId!,
                  notification.patientName,
                );
              },
              child: const Text('Xem bệnh nhân'),
            ),
        ],
      ),
    );
  }

  void _showNotificationActions(NotificationModel notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              notification.isRead ? Icons.markunread : Icons.mark_email_read,
              color: AppTheme.primaryBlue,
            ),
            title: Text(
              notification.isRead ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc',
            ),
            onTap: () {
              Navigator.of(context).pop();
              if (notification.isRead) {
                _markAsUnread(notification.id);
              } else {
                _markAsRead(notification.id);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: AppTheme.dangerColor),
            title: const Text('Xóa thông báo'),
            onTap: () {
              Navigator.of(context).pop();
              _confirmDelete(notification);
            },
          ),
          if (notification.patientId != null)
            ListTile(
              leading: Icon(Icons.person, color: AppTheme.accentGreen),
              title: const Text('Xem bệnh nhân'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToPatient(
                  notification.patientId!,
                  notification.patientName,
                );
              },
            ),
          ListTile(
            leading: Icon(Icons.share, color: AppTheme.primaryBlue),
            title: const Text('Chia sẻ'),
            onTap: () {
              Navigator.of(context).pop();
              _shareNotification(notification);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _markAsUnread(String notificationId) async {
    try {
      final success = await _apiService.markAsUnread(notificationId);
      if (success) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: false,
            );
            _applyFilter();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đánh dấu chưa đọc: $e')),
        );
      }
    }
  }

  void _confirmDelete(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa thông báo "${notification.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNotification(notification.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _shareNotification(NotificationModel notification) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Chia sẻ: ${notification.title}')));
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.reminder:
        return Icons.medication;
      case NotificationType.update:
        return Icons.update;
      case NotificationType.emergency:
        return Icons.emergency;
      case NotificationType.system:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return AppTheme.dangerColor;
      case NotificationType.reminder:
        return AppTheme.accentGreen;
      case NotificationType.update:
        return AppTheme.primaryBlue;
      case NotificationType.emergency:
        return Colors.red;
      case NotificationType.system:
        return AppTheme.primaryBlue;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${difference.inDays} ngày trước';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _isSelectionMode
            ? Text(
                '${_selectedNotifications.length} đã chọn',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                'Thông báo',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: AppTheme.primaryBlue),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                if (_selectedNotifications.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      Icons.mark_email_read,
                      color: AppTheme.primaryBlue,
                    ),
                    onPressed: _bulkMarkAsRead,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: AppTheme.dangerColor),
                    onPressed: _bulkDelete,
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _selectedNotifications.length ==
                            _filteredNotifications.length
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: AppTheme.primaryBlue,
                  ),
                  onPressed:
                      _selectedNotifications.length ==
                          _filteredNotifications.length
                      ? _clearSelection
                      : _selectAllNotifications,
                ),
              ]
            : [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedFilter = value;
                      _applyFilter();
                    });
                  },
                  itemBuilder: (context) => _filterOptions.map((option) {
                    return PopupMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _selectedFilter,
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          Icons.filter_list,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.mark_email_read,
                    color: AppTheme.primaryBlue,
                  ),
                  onPressed: _markAllAsRead,
                ),
                IconButton(
                  icon: Icon(Icons.select_all, color: AppTheme.primaryBlue),
                  onPressed: _toggleSelectionMode,
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm thông báo...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.textMuted),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.textMuted),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryBlue),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.dangerColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không thể tải thông báo',
                      style: TextStyle(color: AppTheme.text, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadNotifications,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : _filteredNotifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 64,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Không tìm thấy thông báo nào'
                          : 'Không có thông báo nào',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount:
                    _filteredNotifications.length + (_hasNextPage ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator for next page
                  if (index == _filteredNotifications.length) {
                    _loadMoreNotifications();
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final notification = _filteredNotifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppTheme.dangerColor,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteNotification(notification.id);
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: notification.isRead ? 1 : 3,
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: _selectedNotifications.contains(
                                  notification.id,
                                ),
                                onChanged: (value) =>
                                    _toggleNotificationSelection(
                                      notification.id,
                                    ),
                              )
                            : CircleAvatar(
                                backgroundColor: _getNotificationColor(
                                  notification.type,
                                ).withValues(alpha: 0.1 * 255),
                                child: Icon(
                                  _getNotificationIcon(notification.type),
                                  color: _getNotificationColor(
                                    notification.type,
                                  ),
                                ),
                              ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            color: AppTheme.text,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.message,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(notification.timestamp),
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: notification.isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2196F3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: _isSelectionMode
                            ? () =>
                                  _toggleNotificationSelection(notification.id)
                            : () {
                                _markAsRead(notification.id);
                                _handleNotificationTap(notification);
                              },
                        onLongPress: _isSelectionMode
                            ? null
                            : () => _showNotificationActions(notification),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
