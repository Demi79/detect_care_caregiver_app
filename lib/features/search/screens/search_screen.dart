import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/activity_logs/data/activity_logs_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/activity_logs/models/activity_log.dart'
    as AL;
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final EventRepository _eventRepository = EventRepository(
    EventService(ApiClient(tokenProvider: AuthStorage.getAccessToken)),
  );

  List<LogEntry> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _showFilters = false;
  String _selectedFilter = 'Tất cả';
  String _selectedSearchType = 'Sự kiện';
  DateTimeRange? _selectedDateRange;
  String? _selectedStatusBackend;
  double _minConfidence = 0.0;

  final List<String> _filterOptions = [
    'Tất cả',
    'Nguy hiểm',
    'Cảnh báo',
    'Bình thường',
  ];

  final List<String> _searchTypeOptions = ['Sự kiện', 'Nhật ký'];

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updatedHistory = [
      query,
      ..._searchHistory.where((item) => item != query),
    ].take(10).toList();
    await prefs.setStringList('search_history', updatedHistory);
    setState(() {
      _searchHistory = updatedHistory;
    });
  }

  // _clearSearchHistory was removed because it's not referenced from the UI.

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      await _saveSearchHistory(query);
      switch (_selectedSearchType) {
        case 'Sự kiện':
          await _searchEvents(query);
          break;
        case 'Nhật ký':
          await _searchActivityLogs(query);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tìm kiếm: $e')));
      }
    }
  }

  Future<void> _searchEvents(String query) async {
    print(
      '[SearchScreen] _searchEvents called - query="$query" status="$_selectedStatusBackend"',
    );
    final results = await _eventRepository.getEvents(
      page: 1,
      limit: 50,
      search: query,
      status: _selectedStatusBackend,
      dayRange: _selectedDateRange,
    );

    var filteredResults = results;
    if (_minConfidence > 0) {
      filteredResults = results
          .where((event) => event.confidenceScore >= _minConfidence)
          .toList();
    }

    if (mounted) {
      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
      print(
        '[SearchScreen] _searchEvents → returned ${filteredResults.length} results (status=$_selectedStatusBackend)',
      );
    }
  }

  Future<void> _searchActivityLogs(String query) async {
    setState(() => _isSearching = true);
    try {
      final userId = await AuthStorage.getUserId();
      if (userId == null) return;
      final ds = ActivityLogsRemoteDataSource();
      final logs = await ds.getUserLogs(
        userId: userId,
        limit: 50,
        search: query,
      );

      final mapped = logs.map((AL.ActivityLog a) {
        return LogEntry(
          eventId: a.id,
          status: a.severity,
          eventType: 'activity',
          eventDescription: a.message.isNotEmpty
              ? a.message
              : (a.resourceName ?? ''),
          confidenceScore: 0.0,
          detectedAt: a.timestamp,
          createdAt: a.timestamp,
          detectionData: a.meta,
          aiAnalysisResult: {},
          contextData: {},
          boundingBoxes: {},
          confirmStatus: false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = mapped;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tìm nhật ký: $e')));
      }
    }
  }

  String _formatTime(DateTime time) {
    final formatter = DateFormat('HH:mm dd/MM/yyyy ');
    return formatter.format(time);
  }

  String _getSmartHintText() {
    switch (_selectedSearchType) {
      case 'Sự kiện':
        return 'Tìm kiếm sự kiện, cảnh báo, hoạt động...';
      case 'Nhật ký':
        return 'Tìm kiếm nhật ký hoạt động...';
      default:
        return 'Nhập từ khóa tìm kiếm...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _searchResults;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildSearchBar(),
        leading: _buildBackButton(),
        actions: [_buildFilterToggle()],
      ),
      body: Column(
        children: [
          _buildSearchTypeSelector(),
          if (_showFilters && _selectedSearchType == 'Sự kiện')
            _buildAdvancedFilters(),
          if (_selectedSearchType == 'Sự kiện') _buildFilterTabs(),
          Expanded(
            child: _isSearching
                ? _buildLoadingState()
                : (_searchResults.isEmpty
                      ? (_searchController.text.isEmpty
                            ? _buildSearchHistory()
                            : _buildNoResultsState())
                      : _buildResultsList(filteredResults)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (value) {
          setState(() {});
          if (value.length >= 2) {
            _performSearch(value);
          } else {
            setState(() => _searchResults = []);
          }
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF475569),
          ),
          hintText: _getSmartHintText(),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF475569)),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildFilterToggle() {
    return IconButton(
      icon: Icon(
        _showFilters ? Icons.filter_list_off_rounded : Icons.tune_rounded,
        color: _showFilters ? AppTheme.primaryBlue : const Color(0xFF64748B),
      ),
      onPressed: () => setState(() => _showFilters = !_showFilters),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () async {
                  String? backendStatus;
                  switch (filter) {
                    case 'Nguy hiểm':
                      backendStatus = 'danger';
                      break;
                    case 'Cảnh báo':
                      backendStatus = 'warning';
                      break;
                    case 'Bình thường':
                      backendStatus = 'normal';
                      break;
                    default:
                      backendStatus = null;
                  }
                  setState(() {
                    _selectedFilter = filter;
                    _selectedStatusBackend = backendStatus;
                    _isSearching = true;
                  });
                  final query = _searchController.text.trim();
                  if (query.isNotEmpty && query.length >= 2) {
                    await _performSearch(query);
                  } else {
                    await _searchEvents('');
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.filter_alt_rounded,
                color: AppTheme.primaryBlue,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Bộ lọc nâng cao',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateRangePicker(),
          // const SizedBox(height: 16),
          // _buildConfidenceSlider(),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return InkWell(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range_rounded,
              color: AppTheme.primaryBlue,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedDateRange != null
                    ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}'
                    : 'Chọn khoảng thời gian',
                style: TextStyle(
                  color: _selectedDateRange != null
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildConfidenceSlider() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         children: [
  //           const Icon(
  //             Icons.show_chart_rounded,
  //             color: AppTheme.primaryBlue,
  //             size: 22,
  //           ),
  //           const SizedBox(width: 10),
  //           const Text(
  //             'Độ tin cậy tối thiểu',
  //             style: TextStyle(
  //               color: Color(0xFF475569),
  //               fontSize: 14,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           const Spacer(),
  //           Text(
  //             '${(_minConfidence * 100).round()}%',
  //             style: const TextStyle(
  //               color: AppTheme.primaryBlue,
  //               fontWeight: FontWeight.w700,
  //             ),
  //           ),
  //         ],
  //       ),
  //       SliderTheme(
  //         data: const SliderThemeData(
  //           activeTrackColor: AppTheme.primaryBlue,
  //           inactiveTrackColor: Color(0xFFE2E8F0),
  //           thumbColor: Colors.white,
  //           trackHeight: 4,
  //         ),
  //         child: Slider(
  //           value: _minConfidence,
  //           min: 0,
  //           max: 1,
  //           divisions: 10,
  //           onChanged: (val) => setState(() => _minConfidence = val),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Widget _buildSearchTypeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _searchTypeOptions.map((type) {
          final isSelected = _selectedSearchType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSearchType = type;
                  _searchResults = [];
                  _searchController.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlue.withOpacity(0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsList(List<LogEntry> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final displayTitle = result.eventDescription?.isNotEmpty == true
            ? result.eventDescription!
            : (result.notes?.isNotEmpty == true
                  ? result.notes!
                  : BackendEnums.eventTypeToVietnamese(result.eventType));
        final displayStatus = switch (result.status) {
          'danger' => 'Nguy hiểm',
          'warning' => 'Cảnh báo',
          'normal' => 'Bình thường',
          _ => 'Không xác định',
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _getEventColor(result.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getEventIcon(result.eventType),
                    color: _getEventColor(result.status),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trạng thái: $displayStatus',
                        style: TextStyle(
                          color: _getEventColor(result.status),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(
                              result.createdAt ??
                                  result.detectedAt ??
                                  DateTime.now(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),

                      // if (result.confidenceScore > 0)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 6),
                      //     child: Row(
                      //       children: [
                      //         Expanded(
                      //           flex: 1,
                      //           child: ClipRRect(
                      //             borderRadius: BorderRadius.circular(3),
                      //             child: LinearProgressIndicator(
                      //               value: result.confidenceScore,
                      //               backgroundColor: const Color(0xFFF1F5F9),
                      //               valueColor:
                      //                   const AlwaysStoppedAnimation<Color>(
                      //                     AppTheme.primaryBlue,
                      //                   ),
                      //               minHeight: 6,
                      //             ),
                      //           ),
                      //         ),
                      //         const SizedBox(width: 8),
                      //         Text(
                      //           '${(result.confidenceScore * 100).round()}%',
                      //           style: const TextStyle(
                      //             fontSize: 12,
                      //             color: AppTheme.primaryBlue,
                      //             fontWeight: FontWeight.w600,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 32, child: _buildQuickActions(result)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(LogEntry result) {
    return PopupMenuButton<String>(
      color: const Color(0xFFF8FAFC),
      onSelected: (action) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Thực hiện: $action')));
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Xem chi tiết', child: Text('Xem chi tiết')),
        // const PopupMenuItem(value: 'Chia sẻ', child: Text('Chia sẻ')),
      ],
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF64748B),
        size: 20,
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'activity':
        return Icons.directions_run_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'danger':
        return AppTheme.dangerColor;
      case 'warning':
        return const Color(0xFFFFA000);
      case 'normal':
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryBlue;
    }
  }

  Widget _buildLoadingState() =>
      const Center(child: CircularProgressIndicator(strokeWidth: 3));

  Widget _buildNoResultsState() =>
      const Center(child: Text('Không tìm thấy kết quả.'));

  Widget _buildSearchHistory() =>
      const Center(child: Text('Nhập từ khóa để tìm kiếm.'));
}
