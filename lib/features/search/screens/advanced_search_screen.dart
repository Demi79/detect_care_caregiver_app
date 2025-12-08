import 'package:detect_care_caregiver_app/features/search/models/search_models.dart';
import 'package:detect_care_caregiver_app/features/search/providers/search_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // Filter state
  List<String> _selectedEntityTypes = ['events', 'caregivers', 'invoices'];
  DateTimeRange? _selectedDateRange;
  String _selectedStatus = '';
  double _minConfidence = 0.0;
  double _maxAmount = 1000000.0;

  // UI state
  bool _showFilters = false;
  bool _showHistory = false;

  final List<String> _entityTypeOptions = ['events', 'caregivers', 'invoices'];

  final List<String> _statusOptions = [
    '',
    'pending',
    'processed',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final provider = context.read<SearchProvider>();
    await provider.loadSearchHistory();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final request = SearchRequest(
      query: query,
      entityTypes: _selectedEntityTypes,
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
      minConfidence: _minConfidence > 0 ? _minConfidence : null,
      maxAmount: _maxAmount < 1000000 ? _maxAmount : null,
    );

    final provider = context.read<SearchProvider>();
    await provider.performSearch(request);
  }

  Future<void> _executeQuickAction(String action, SearchResult result) async {
    final request = QuickActionRequest(
      action: action,
      entityId: result.id,
      entityType: result.entityType,
    );

    final provider = context.read<SearchProvider>();
    final success = await provider.executeQuickAction(request);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thao tác "$action" thực hiện thành công')),
      );
      // Refresh search results
      await _performSearch();
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to execute action')));
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sự kiện, nhật ký...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  context.read<SearchProvider>().clearResults();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm kiếm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: _showFilters ? Theme.of(context).primaryColor : null,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showHistory = !_showHistory;
                  });
                },
                icon: Icon(
                  _showHistory ? Icons.history : Icons.history_outlined,
                  color: _showHistory ? Theme.of(context).primaryColor : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    if (!_showFilters) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bộ lọc',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Entity Types
          const Text(
            'Tìm trong:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Wrap(
            spacing: 8,
            children: _entityTypeOptions.map((type) {
              final isSelected = _selectedEntityTypes.contains(type);
              return FilterChip(
                label: Text(_getEntityTypeDisplayName(type)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEntityTypes.add(type);
                    } else {
                      _selectedEntityTypes.remove(type);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Date Range
          const Text(
            'Khoảng ngày:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                initialDateRange: _selectedDateRange,
              );
              if (range != null) {
                setState(() {
                  _selectedDateRange = range;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDateRange != null
                        ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
                        : 'Chọn khoảng ngày',
                    style: TextStyle(
                      color: _selectedDateRange != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedDateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status
          const Text(
            'Trạng thái:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _statusOptions.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.isEmpty ? 'Tất cả' : status),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value ?? '';
              });
            },
          ),

          const SizedBox(height: 16),

          // Confidence slider (for events)
          if (_selectedEntityTypes.contains('events')) ...[
            const Text(
              'Độ tin cậy tối thiểu:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Slider(
              value: _minConfidence,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_minConfidence * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _minConfidence = value;
                });
              },
            ),
          ],

          // Amount range (for invoices)
          if (_selectedEntityTypes.contains('invoices')) ...[
            const Text(
              'Số tiền tối đa (VND):',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Slider(
              value: _maxAmount,
              min: 0,
              max: 10000000,
              divisions: 100,
              label: NumberFormat.currency(
                locale: 'vi_VN',
                symbol: '₫',
              ).format(_maxAmount),
              onChanged: (value) {
                setState(() {
                  _maxAmount = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (!_showHistory) return const SizedBox.shrink();

    final provider = context.watch<SearchProvider>();
    final history = provider.searchHistory;

    if (history.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Chưa có lịch sử tìm kiếm')),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch sử tìm kiếm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // Clear history functionality could be added here
                },
                child: const Text('Xóa tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...history.map(
            (item) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(item.query),
              subtitle: Text(
                '${item.entityTypes.join(', ')} • ${item.resultCount} results • ${_dateFormat.format(item.searchedAt)}',
              ),
              onTap: () {
                _searchController.text = item.query;
                setState(() {
                  _selectedEntityTypes = item.entityTypes;
                });
                _performSearch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final provider = context.watch<SearchProvider>();
    final results = provider.searchResults;
    final isSearching = provider.isSearching;
    final error = provider.error;

    if (isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Tìm kiếm thất bại',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(error),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (results == null || results.results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Không tìm thấy kết quả',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Thử thay đổi từ khóa hoặc bộ lọc',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${results.total} kết quả',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: results.results.length,
              itemBuilder: (context, index) {
                final result = results.results[index];
                return _buildResultItem(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getEntityTypeColor(result.entityType),
          child: Icon(
            _getEntityTypeIcon(result.entityType),
            color: Colors.white,
          ),
        ),
        title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getEntityTypeColor(
                      result.entityType,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getEntityTypeDisplayName(result.entityType),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getEntityTypeColor(result.entityType),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (result.confidence != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(result.confidence! * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (result.status != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        result.status!,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.status!,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(result.status!),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _executeQuickAction(action, result),
          itemBuilder: (context) => _getQuickActions(result.entityType),
        ),
        onTap: () {
          // Navigate to detail screen based on entity type
          _navigateToDetail(result);
        },
      ),
    );
  }

  List<PopupMenuEntry<String>> _getQuickActions(String entityType) {
    switch (entityType) {
      case 'events':
        return [
          const PopupMenuItem(
            value: 'mark_processed',
            child: Text('Đánh dấu đã xử lý'),
          ),
          const PopupMenuItem(value: 'escalate', child: Text('Chuyển xử lý')),
        ];
      case 'invoices':
        return [
          const PopupMenuItem(
            value: 'initiate_payment',
            child: Text('Khởi tạo thanh toán'),
          ),
          const PopupMenuItem(value: 'download', child: Text('Tải PDF')),
        ];
      case 'caregivers':
        return [
          const PopupMenuItem(
            value: 'assign_patient',
            child: Text('Gán bệnh nhân'),
          ),
          const PopupMenuItem(value: 'view_schedule', child: Text('Xem lịch')),
        ];
      default:
        return [];
    }
  }

  void _navigateToDetail(SearchResult result) {
    // TODO: Implement navigation to detail screens
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đi đến chi tiết ${_getEntityTypeDisplayName(result.entityType)}',
        ),
      ),
    );
  }

  Color _getEntityTypeColor(String entityType) {
    switch (entityType) {
      case 'events':
        return Colors.blue;
      case 'caregivers':
        return Colors.green;
      case 'invoices':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEntityTypeIcon(String entityType) {
    switch (entityType) {
      case 'events':
        return Icons.event;
      case 'caregivers':
        return Icons.person;
      case 'invoices':
        return Icons.receipt;
      default:
        return Icons.article;
    }
  }

  String _getEntityTypeDisplayName(String entityType) {
    switch (entityType) {
      case 'events':
        return 'Sự kiện';
      case 'activity-logs':
        return 'Nhật ký';
      default:
        return entityType;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processed':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm nâng cao'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          _buildSearchHistory(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }
}
