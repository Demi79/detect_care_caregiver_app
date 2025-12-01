import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/features/activity_logs/data/activity_logs_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/activity_logs/models/activity_log.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _controller = ScrollController();
  final _ds = ActivityLogsRemoteDataSource();

  String? _userId;
  bool _loadingUserId = true;

  final List<ActivityLog> _logs = [];
  bool _initialLoading = true;
  bool _pagingLoading = false;
  bool _hasMore = true;
  String? _error;

  int _offset = 0;
  final int _limit = 20;

  String? _severityFilter;
  String? _actionFilter;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (_controller.position.pixels >=
            _controller.position.maxScrollExtent - 200 &&
        !_pagingLoading &&
        _hasMore &&
        !_initialLoading) {
      _loadMore();
    }
  }

  Future<void> _bootstrap() async {
    final uid = await AuthStorage.getUserId();
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _loadingUserId = false;
    });
    if (uid == null || uid.isEmpty) {
      setState(() {
        _error = 'Không tìm thấy userId trong AuthStorage';
        _initialLoading = false;
      });
      return;
    }
    await _loadInitial();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (_userId == null) return;
    setState(() {
      _initialLoading = true;
      _error = null;
      _logs.clear();
      _offset = 0;
      _hasMore = true;
    });
    try {
      final logs = await _ds.getUserLogs(
        userId: _userId!,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _logs.addAll(_applyLocalFilter(logs));
        _hasMore = logs.length == _limit;
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _userId == null) return;
    setState(() => _pagingLoading = true);
    try {
      _offset += _limit;
      final logs = await _ds.getUserLogs(
        userId: _userId!,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _logs.addAll(_applyLocalFilter(logs));
        _hasMore = logs.length == _limit;
        _pagingLoading = false;
      });
    } catch (e) {
      _offset -= _limit;
      setState(() {
        _pagingLoading = false;
        _error = e.toString();
      });
    }
  }

  List<ActivityLog> _applyLocalFilter(List<ActivityLog> input) {
    var out = input;
    if (_severityFilter != null) {
      out = out.where((e) => e.severity == _severityFilter).toList();
    }
    if (_actionFilter != null) {
      out = out.where((e) => e.action == _actionFilter).toList();
    }
    return out;
  }

  Future<void> _onRefresh() => _loadInitial();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // appBar: AppBar(
      //   title: const Text(
      //     'Nhật ký hoạt động',
      //     style: TextStyle(
      //       fontWeight: FontWeight.w600,
      //       color: Color(0xFF1E293B),
      //     ),
      //   ),
      //   backgroundColor: surfaceColor,
      //   elevation: 0,
      //   shadowColor: Colors.transparent,
      //   surfaceTintColor: Colors.transparent,
      //   iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      //   actions: [
      //     Container(
      //       margin: const EdgeInsets.only(right: 16),
      //       child: IconButton(
      //         tooltip: 'Làm mới',
      //         onPressed: _initialLoading ? null : _loadInitial,
      //         icon: AnimatedRotation(
      //           turns: _initialLoading ? 1 : 0,
      //           duration: const Duration(seconds: 1),
      //           child: Icon(
      //             Icons.refresh_rounded,
      //             color: _initialLoading ? textSecondary : primaryBlue,
      //           ),
      //         ),
      //         style: IconButton.styleFrom(
      //           backgroundColor: lightBlue,
      //           padding: const EdgeInsets.all(8),
      //         ),
      //       ),
      //     ),
      //   ],
      // ),
      body: _loadingUserId
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryBlue,
                strokeWidth: 3,
              ),
            )
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    final severities = ['info', 'warn', 'warning', 'error'];
    final actions = _uniqueActions();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Bộ lọc',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Mức độ nghiêm trọng',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'Tất cả',
                    _severityFilter == null,
                    () => setState(() => _severityFilter = null),
                  ),
                  const SizedBox(width: 8),
                  for (final s in severities) ...[
                    _buildFilterChip(
                      _getSeverityDisplayName(s),
                      _severityFilter == s,
                      () => setState(() => _severityFilter = s),
                      color: _colorForSeverity(s),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hành động',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'Tất cả',
                    _actionFilter == null,
                    () => setState(() => _actionFilter = null),
                  ),
                  const SizedBox(width: 8),
                  for (final a in actions) ...[
                    _buildFilterChip(
                      _getActionDisplayName(a),
                      _actionFilter == a,
                      () => setState(() => _actionFilter = a),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? primaryBlue).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? (color ?? primaryBlue) : borderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? primaryBlue) : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _getSeverityDisplayName(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return 'Thông tin';
      case 'warn':
      case 'warning':
        return 'Cảnh báo';
      case 'error':
        return 'Lỗi';
      default:
        return severity;
    }
  }

  String _getActionDisplayName(String action) {
    switch (action) {
      case 'send_fcm_message':
        return 'Gửi thông báo';
      case 'accept_assignment':
        return 'Nhận nhiệm vụ';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  List<String> _uniqueActions() {
    final set = <String>{};
    for (final e in _logs) {
      set.add(e.action);
    }
    final list = set.toList()..sort();
    return list;
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadInitial);
    }
    if (_logs.isEmpty) {
      return const _EmptyView();
    }

    final filtered = _applyLocalFilter(_logs);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: primaryBlue,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: filtered.length + (_pagingLoading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_pagingLoading && index == filtered.length) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: const Center(
                child: CircularProgressIndicator(
                  color: primaryBlue,
                  strokeWidth: 3,
                ),
              ),
            );
          }
          final log = filtered[index];
          return _LogTile(log: log, onTap: () => _showDetail(log));
        },
      ),
    );
  }

  Color _colorForSeverity(String severity) {
    final s = severity.toLowerCase();
    if (s == 'error') return const Color(0xFFEF4444);
    if (s == 'warn' || s == 'warning') return const Color(0xFFF59E0B);
    return primaryBlue;
  }

  void _showDetail(ActivityLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LogDetailSheet(log: log),
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  final VoidCallback? onTap;

  const _LogTile({required this.log, this.onTap});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final icon = _iconForAction(log.action);
    final color = _colorForSeverity(log.severity);
    final when = _friendlyTime(log.timestamp);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getActionDisplayName(log.action),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (log.message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Badge(
                            text: _getSeverityDisplayName(log.severity),
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          if (log.resourceType.isNotEmpty)
                            _Badge(text: log.resourceType),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        when,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getActionDisplayName(String action) {
    switch (action) {
      case 'send_fcm_message':
        return 'Gửi thông báo';
      case 'accept_assignment':
        return 'Nhận nhiệm vụ';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  String _getSeverityDisplayName(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return 'Thông tin';
      case 'warn':
      case 'warning':
        return 'Cảnh báo';
      case 'error':
        return 'Lỗi';
      default:
        return severity;
    }
  }

  static IconData _iconForAction(String action) {
    switch (action) {
      case 'send_fcm_message':
        return Icons.notifications_rounded;
      case 'accept_assignment':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  static Color _colorForSeverity(String severity) {
    final s = severity.toLowerCase();
    if (s == 'error') return const Color(0xFFEF4444);
    if (s == 'warn' || s == 'warning') return const Color(0xFFF59E0B);
    return primaryBlue;
  }

  static String _friendlyTime(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color? color;
  const _Badge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withOpacity(0.2), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: effectiveColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  final ActivityLog log;
  const _LogDetailSheet({required this.log});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_rounded,
                      color: primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Chi tiết hoạt động',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(),
                    // const SizedBox(height: 24),
                    // _buildMetaSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.access_time_rounded,
            'Thời gian',
            _LogTile._friendlyTime(log.timestamp),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.priority_high_rounded,
            'Mức độ',
            _getSeverityDisplayName(log.severity),
            valueColor: _colorForSeverity(log.severity),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.play_arrow_rounded,
            'Hành động',
            _getActionDisplayName(log.action),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.person_rounded,
            'Thực hiện bởi',
            '${log.actorName ?? '(Không xác định)'} ',
            // • ${log.actorId}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.category_rounded,
            'Nguồn',
            '${log.resourceType}${log.resourceId != null ? ' • ${log.resourceId}' : ''}',
          ),
          if (log.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.message_rounded, 'Tin nhắn', log.message),
          ],
          if (log.ip != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.wifi_rounded, 'Địa chỉ IP', log.ip!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Icon(icon, size: 16, color: primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildMetaSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         children: [
  //           Icon(Icons.code_rounded, size: 20, color: primaryBlue),
  //           const SizedBox(width: 8),
  //           const Text(
  //             'Dữ liệu Meta (JSON)',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.w700,
  //               color: Color(0xFF1E293B),
  //             ),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: 12),
  //       Container(
  //         width: double.infinity,
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: const Color(0xFF1E293B),
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: borderColor, width: 1),
  //         ),
  //         child: Text(
  //           const JsonEncoder.withIndent('  ').convert(log.meta),
  //           style: const TextStyle(
  //             fontFamily: 'monospace',
  //             fontSize: 12,
  //             color: Color(0xFF94A3B8),
  //             height: 1.4,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  String _getSeverityDisplayName(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return 'Thông tin';
      case 'warn':
      case 'warning':
        return 'Cảnh báo';
      case 'error':
        return 'Lỗi';
      default:
        return severity;
    }
  }

  String _getActionDisplayName(String action) {
    switch (action) {
      case 'send_fcm_message':
        return 'Gửi thông báo';
      case 'accept_assignment':
        return 'Nhận nhiệm vụ';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  Color _colorForSeverity(String severity) {
    final s = severity.toLowerCase();
    if (s == 'error') return const Color(0xFFEF4444);
    if (s == 'warn' || s == 'warning') return const Color(0xFFF59E0B);
    return primaryBlue;
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.inbox_rounded, size: 40, color: primaryBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có hoạt động nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các hoạt động của bạn sẽ hiển thị ở đây.\nKéo xuống để làm mới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Thử lại',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
