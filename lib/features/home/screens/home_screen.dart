import 'dart:async';
import 'dart:developer' as dev;

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/core/services/permissions_service.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/widgets/custom_bottom_nav_bar.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/assignments_screen.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_home_screen.dart';
import 'package:detect_care_caregiver_app/features/health_overview/screens/health_overview_screen.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/screens/high_confidence_events_screen.dart';
import 'package:detect_care_caregiver_app/features/home/screens/low_confidence_events_screen.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/notification/screens/notification_screen.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/patient_profile_screen.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/sleep_checkin_screen.dart';
import 'package:detect_care_caregiver_app/features/profile/screens/profile_screen.dart';
import 'package:detect_care_caregiver_app/features/search/screens/search_screen.dart';
import 'package:detect_care_caregiver_app/features/setting/screens/settings_screen.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/payment_api.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../widgets/tab_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 4;
  String _selectedTab = 'highConfidence';
  String _selectedStatus = HomeFilters.defaultStatus;
  String _selectedPeriod = HomeFilters.defaultPeriod;
  DateTimeRange? _selectedDayRange = HomeFilters.defaultDayRange;

  final TextEditingController _searchController = TextEditingController();

  late final EventRepository _eventRepository;
  late final SupabaseService _supa;
  late final PaymentApi _paymentApi;

  final ScrollController _contentScrollController = ScrollController();
  final GlobalKey _fullFilterKey = GlobalKey();

  bool _showAppBar = true;
  bool _compactVisible = false;
  double _lastScrollOffset = 0.0;
  double _filterBarHeight = 0.0;
  List<LogEntry> _allLogs = [];
  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;
  int _notificationCount = 0;
  String? _customerId;

  Timer? _searchDebounce;
  Timer? _notificationRefreshTimer;
  StreamSubscription<void>? _eventsChangedSub;
  StreamSubscription<Map<String, dynamic>>? _eventUpdatedSub;

  bool _skipMergeOnNextRefresh = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionsProvider>().initialize();
      _fetchCustomerId();
    });

    _eventRepository = EventRepository(
      EventService(ApiClient(tokenProvider: AuthStorage.getAccessToken)),
    );

    _supa = SupabaseService();
    _paymentApi = PaymentApi(
      baseUrl: dotenv.env['API_BASE_URL'] ?? '',
      apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );

    _initSupabaseConnection();
    PermissionsService().initialize();

    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), _refreshLogs);
      setState(() {});
    });

    _refreshLogs();
    _loadNotificationCount();

    _eventsChangedSub = AppEvents.instance.eventsChanged.listen((_) {
      if (!mounted) return;
      _skipMergeOnNextRefresh = true;
      _refreshLogs();
    });

    _eventUpdatedSub = AppEvents.instance.eventUpdated.listen((map) {
      if (!mounted) return;
      try {
        final e = EventLog.fromJson(map);
        setState(() {
          final idx = _logs.indexWhere(
            (element) => element.eventId == e.eventId,
          );
          if (idx >= 0) {
            _logs[idx] = e;
          } else {
            _logs.insert(0, e);
            _notificationCount++;
            HapticFeedback.selectionClick();
          }
        });
      } catch (e, st) {
        dev.log('eventUpdated error', error: e, stackTrace: st);
      }
    });

    _notificationRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadNotificationCount(),
    );
  }

  // ===================== SCROLL =====================

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final offset = notification.metrics.pixels;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    if (offset <= 0) {
      if (!_showAppBar) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showAppBar = true);
        });
      }
      return false;
    }

    if (delta < -2 && !_showAppBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showAppBar = true);
      });
    } else if (delta > 2 && _showAppBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showAppBar = false);
      });
    }

    final shouldShowCompact =
        offset >= (_filterBarHeight + 16) && _selectedTab != 'report';

    if (shouldShowCompact != _compactVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _compactVisible = shouldShowCompact);
      });
    }

    return false;
  }

  void _measureFilterBarHeight() {
    final ctx = _fullFilterKey.currentContext;
    if (ctx == null) return;
    final size = (ctx.findRenderObject() as RenderBox?)?.size;
    final h = size?.height ?? 0;
    if ((h - _filterBarHeight).abs() > 1) {
      setState(() => _filterBarHeight = h);
    }
  }

  // ===================== DATA =====================

  Future<void> _fetchCustomerId() async {
    try {
      final ds = AssignmentsRemoteDataSource();
      final list = await ds.listPending(status: 'accepted');
      if (list.isNotEmpty && mounted) {
        setState(() => _customerId = list.first.customerId);
      }
    } catch (_) {}
  }

  Future<void> _loadNotificationCount() async {
    try {
      final service = NotificationApiService();
      final count = await service.getUnreadCount();
      if (mounted) setState(() => _notificationCount = count);
    } catch (_) {
      if (mounted) setState(() => _notificationCount = 0);
    }
  }

  Future<void> _refreshLogs() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    debugPrint('[Home] Refresh with auth status: ${authProvider.status}');
    debugPrint('[Home] Refresh with userID: ${authProvider.currentUserId}');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (authProvider.status != AuthStatus.authenticated ||
          authProvider.currentUserId == null) {
        if (!mounted) return;
        setState(() {
          _logs = [];
          _error = 'Chưa đăng nhập. Vui lòng đăng nhập để xem cảnh báo.';
          _isLoading = false;
        });
        return;
      }
      int effectiveLimit = 50;
      try {
        if (_selectedDayRange != null) {
          final days =
              _selectedDayRange!.end
                  .difference(_selectedDayRange!.start)
                  .inDays +
              1;
          if (days > 1) {
            effectiveLimit = (days * 50).clamp(200, 500);
          }
        }
      } catch (_) {}
      final events = await _eventRepository.getEvents(
        page: 1,
        limit: effectiveLimit,
        status: _selectedStatus,
        dayRange: _selectedDayRange,
        period: _selectedPeriod,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        includeCanceled: false, // exclude canceled for main lists
      );

      final allEvents = await _eventRepository.getEvents(
        page: 1,
        limit: 100,
        status: null,
        dayRange: _selectedDayRange,
        period: null,
        search: null,
        includeCanceled: null,
      );

      if (!mounted) return;

      final snapshotMap = <String, LogEntry>{
        for (final e in events) e.eventId: e,
      };

      if (_skipMergeOnNextRefresh) {
        _skipMergeOnNextRefresh = false;
        debugPrint('[Home] Skipping local-merge on refresh (eventsChanged)');
      } else {
        for (final e in _logs) {
          final matchesStatus =
              _selectedStatus.isEmpty ||
              _selectedStatus.toLowerCase() == 'all' ||
              e.status.toLowerCase() == _selectedStatus.toLowerCase() ||
              (_selectedStatus.toLowerCase() == 'abnormal' &&
                  (e.status.toLowerCase() == 'danger' ||
                      e.status.toLowerCase() == 'warning'));

          if (!matchesStatus) continue;

          if (!snapshotMap.containsKey(e.eventId)) {
            snapshotMap[e.eventId] = e;
          }
        }
      }

      final merged = snapshotMap.values.toList()
        ..sort((a, b) {
          final aDt =
              a.detectedAt ??
              a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDt =
              b.detectedAt ??
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDt.compareTo(aDt);
        });

      setState(() {
        _logs = merged;
        _allLogs = allEvents;
        _error = null;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Error refreshing logs: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải sự kiện: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _initSupabaseConnection() {
    _supa.initRealtimeSubscription(
      onEventReceived: (_) {
        if (!mounted) return;
        _skipMergeOnNextRefresh = true;
        _refreshLogs();
      },
    );
  }

  List<LogEntry> get _visibleLogs {
    try {
      return _logs.where((e) {
        try {
          final ls = e.lifecycleState?.toString().toLowerCase();
          if (ls != null && ls == 'canceled') return false;
        } catch (_) {}
        return true;
      }).toList();
    } catch (_) {
      return List.from(_logs);
    }
  }

  // ===================== UI =====================

  void onTap(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        break; // LiveCameraHomeScreen
      case 1:
        break; // AssignmentsScreen
      case 2:
        break; // PatientProfileScreen
      case 3:
        break; // ProfileScreen
      case 4:
        break; // HomeScreen (current)
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureFilterBarHeight();
    });

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.settings, color: AppTheme.primaryBlue),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        color: AppTheme.primaryBlue,
                      ),
                      onPressed: () async {
                        await NotificationApiService().markAllAsRead();
                        setState(() => _notificationCount = 0);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationScreen(),
                          ),
                        );
                      },
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.red,
                          child: Text(
                            _notificationCount > 99
                                ? '99+'
                                : _notificationCount.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          : null,
      body: _buildContent(),
      floatingActionButton: Semantics(
        button: true,
        label: 'Trang chính',
        child: FloatingActionButton(
          heroTag: 'fab_home',
          onPressed: () {
            if (_selectedIndex != 4) {
              setState(() => _selectedIndex = 4);
            }
          },
          shape: const CircleBorder(),
          backgroundColor: AppTheme.primaryBlue,
          elevation: 6,
          child: const Icon(Icons.home, color: Colors.white, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: onTap,
        badgeCounts: {2: 0},
        borderRadius: 30,
        bottomMargin: 15,
        horizontalMargin: 10,
      ),
    );
  }

  Widget _buildCompactFilterBar() {
    String statusLabel = _selectedStatus;
    switch (_selectedStatus.toLowerCase()) {
      case 'abnormal':
        statusLabel = 'Bất thường';
        break;
      case 'danger':
        statusLabel = 'Nguy hiểm';
        break;
      case 'warning':
        statusLabel = 'Cảnh báo';
        break;
      case 'normal':
        statusLabel = 'Bình thường';
        break;
      case 'suspect':
        statusLabel = 'Đáng ngờ';
        break;
      case 'unknowns':
        statusLabel = 'Không xác định';
        break;
      case 'all':
      default:
        statusLabel = 'Tất cả';
    }

    String periodLabel = _selectedPeriod;
    switch (_selectedPeriod.toLowerCase()) {
      case '00-06':
        periodLabel = '00–06h';
        break;
      case '06-12':
        periodLabel = '06–12h';
        break;
      case '12-18':
        periodLabel = '12–18h';
        break;
      case '18-24':
        periodLabel = '18–24h';
        break;
      case 'morning':
        periodLabel = 'Buổi sáng';
        break;
      case 'afternoon':
        periodLabel = 'Buổi chiều';
        break;
      case 'evening':
        periodLabel = 'Buổi tối';
        break;
      case 'night':
        periodLabel = 'Đêm';
        break;
      case 'all':
      default:
        periodLabel = 'Cả ngày';
    }

    String rangeLabel = 'Khoảng ngày';
    try {
      if (_selectedDayRange != null) {
        final s = _selectedDayRange!.start;
        final e = _selectedDayRange!.end;
        rangeLabel = '${s.day}/${s.month} – ${e.day}/${e.month}';
      } else {
        rangeLabel = 'Mọi ngày';
      }
    } catch (_) {}

    Widget chip(String label, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: chip(rangeLabel, Icons.calendar_today)),
        const SizedBox(width: 8),
        Expanded(child: chip(statusLabel, Icons.filter_alt)),
        const SizedBox(width: 8),
        Expanded(child: chip(periodLabel, Icons.schedule)),
      ],
    );
  }

  Widget _buildContent() {
    if (_selectedIndex != 4) {
      switch (_selectedIndex) {
        case 0:
          return const LiveCameraHomeScreen();
        case 1:
          return const CaregiverSettingsScreen();
        case 2:
          return const PatientProfileScreen(embedInParent: true);
        case 3:
          return const ProfileScreen(embedInParent: true);
      }
    }

    return Column(
      children: [
        TabSelector(
          selectedTab: _selectedTab,
          onTabChanged: (t) {
            setState(() {
              _selectedTab = t;
              _selectedStatus = t == 'lowConfidence'
                  ? 'all'
                  : HomeFilters.defaultStatus;
            });
            _refreshLogs();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_contentScrollController.hasClients) {
                _contentScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
        if (_compactVisible)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: GestureDetector(
              onTap: () => _contentScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
              child: _buildCompactFilterBar(),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    switch (_selectedTab) {
      case 'highConfidence':
        return HighConfidenceEventsScreen(
          logs: _visibleLogs,
          allLogs: _allLogs,
          scrollController: _contentScrollController,
          filterBarKey: _fullFilterKey,
          selectedStatus: _selectedStatus,
          selectedDayRange: _selectedDayRange,
          selectedPeriod: _selectedPeriod,
          onRefresh: _refreshLogs,
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus);
            _refreshLogs();
          },
          onDayRangeChanged: (v) {
            setState(() => _selectedDayRange = v);
            _refreshLogs();
          },
          onPeriodChanged: (v) {
            setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod);
            _refreshLogs();
          },
        );
      case 'lowConfidence':
        return LowConfidenceEventsScreen(
          logs: _visibleLogs,
          allLogs: _allLogs,
          scrollController: _contentScrollController,
          filterBarKey: _fullFilterKey,
          selectedStatus: _selectedStatus,
          selectedDayRange: _selectedDayRange,
          selectedPeriod: _selectedPeriod,
          onRefresh: _refreshLogs,
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus);
            _refreshLogs();
          },
          onDayRangeChanged: (v) {
            setState(() => _selectedDayRange = v);
            _refreshLogs();
          },
          onPeriodChanged: (v) {
            setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod);
            _refreshLogs();
          },
        );
      case 'report':
        return HealthOverviewScreen(patientId: _customerId);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notificationRefreshTimer?.cancel();
    _searchController.dispose();
    _contentScrollController.dispose();
    _eventsChangedSub?.cancel();
    _eventUpdatedSub?.cancel();
    _supa.dispose();
    super.dispose();
  }
}
