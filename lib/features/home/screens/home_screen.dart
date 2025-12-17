import 'dart:async';
import 'dart:developer' as dev;

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/widgets/custom_bottom_nav_bar.dart';
import 'package:detect_care_caregiver_app/core/services/permissions_service.dart';
import 'package:detect_care_caregiver_app/features/home/screens/low_confidence_events_screen.dart';
import 'package:detect_care_caregiver_app/features/assignments/screens/assignments_screen.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_home_screen.dart';
import 'package:detect_care_caregiver_app/features/health_overview/screens/health_overview_screen.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/constants/types.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/screens/high_confidence_events_screen.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/notification/screens/notification_screen.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/patient_profile_screen.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/sleep_checkin_screen.dart';
import 'package:detect_care_caregiver_app/features/profile/screens/profile_screen.dart';
import 'package:detect_care_caregiver_app/features/search/screens/search_screen.dart';
import 'package:detect_care_caregiver_app/features/setting/screens/settings_screen.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/payment_api.dart';
import 'package:detect_care_caregiver_app/services/notification_api_service.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
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
  int _selectedIndex = 4; // Home screen index
  String _selectedTab = 'highConfidence';
  String _selectedStatus = HomeFilters.defaultStatus;
  String _selectedPeriod = HomeFilters.defaultPeriod;

  DateTimeRange? _selectedDayRange = HomeFilters.defaultDayRange;
  final TextEditingController _searchController = TextEditingController();

  late final EventRepository _eventRepository;
  late final SupabaseService _supa;
  late final PaymentApi _paymentApi;

  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;
  int _invoiceCount = 0;
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

    // Initialize PermissionsProvider for realtime permission updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionsProvider>().initialize();
      _fetchCustomerId();
    });

    _eventRepository = EventRepository(
      EventService(ApiClient(tokenProvider: AuthStorage.getAccessToken)),
    );

    EventService(
      ApiClient(tokenProvider: AuthStorage.getAccessToken),
    ).debugProbe();
    _supa = SupabaseService();
    _paymentApi = PaymentApi(
      baseUrl: dotenv.env['API_BASE_URL'] ?? '',
      apiProvider: ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );
    _initSupabaseConnection();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), _refreshLogs);
      setState(() {});
    });
    _refreshLogs();
    _loadNotifications();
    _loadNotificationCount();

    // Initialize PermissionsService for realtime permission updates
    PermissionsService().initialize();

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
          if (_logs.any((event) => event.eventId == e.eventId)) {
            final index = _logs.indexWhere(
              (event) => event.eventId == e.eventId,
            );
            _logs[index] = e;
          } else {
            _logs.insert(0, e);
            _notificationCount++;
            HapticFeedback.selectionClick();
          }
        });
        dev.log('eventUpdated applied for=${e.eventId}');
      } catch (err, st) {
        dev.log(
          'Error applying eventUpdated: $err',
          error: err,
          stackTrace: st,
        );
      }
    });

    // Refresh notification count every 5 minutes
    _notificationRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadNotificationCount(),
    );
  }

  Future<void> _fetchCustomerId() async {
    try {
      final assignDs = AssignmentsRemoteDataSource();
      final list = await assignDs.listPending(status: 'accepted');
      if (list.isNotEmpty && mounted) {
        setState(() {
          _customerId = list.first.customerId;
        });
      }
    } catch (e) {
      debugPrint('[Home] Error fetching customerId: $e');
    }
  }

  void _loadNotifications() async {
    try {
      final token = await AuthStorage.getAccessToken();
      if (token == null) {
        setState(() => _invoiceCount = 0);
        return;
      }

      final count = await _paymentApi.getInvoiceCount(token);
      if (mounted) {
        setState(() => _invoiceCount = count);
      }
    } catch (e) {
      debugPrint('Error loading invoice count: $e');
      if (mounted) {
        setState(() => _invoiceCount = 0);
      }
    }
  }

  void _loadNotificationCount() async {
    try {
      final service = NotificationApiService();
      final count = await service.getUnreadCount();
      if (mounted) {
        setState(() => _notificationCount = count);
      }
      debugPrint(
        '[Home] Loaded notification count from API: $_notificationCount',
      );
    } catch (e) {
      debugPrint('Error loading notification count: $e');
      if (mounted) setState(() => _notificationCount = 0);
    }
  }

  void _resetNotificationCount() {
    setState(() => _notificationCount = 0);
    debugPrint('[Home] Reset notification count to 0');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notificationRefreshTimer?.cancel();
    _searchController.dispose();
    _supa.dispose();
    _eventsChangedSub?.cancel();
    _eventUpdatedSub?.cancel();
    super.dispose();
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
              _selectedStatus == null ||
              _selectedStatus!.isEmpty ||
              _selectedStatus!.toLowerCase() == 'all' ||
              e.status.toLowerCase() == _selectedStatus!.toLowerCase() ||
              (_selectedStatus!.toLowerCase() == 'abnormal' &&
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
    if (!mounted) return;
    try {
      _supa.initRealtimeSubscription(
        onEventReceived: (map) {
          if (!mounted) return;
          try {
            final e = EventLog.fromJson(map);
            setState(() {
              if (_logs.any((event) => event.eventId == e.eventId)) {
                final index = _logs.indexWhere(
                  (event) => event.eventId == e.eventId,
                );
                _logs[index] = e;
              } else {
                _logs.insert(0, e);
                _notificationCount++;
                HapticFeedback.selectionClick();
              }
            });
            dev.log(
              'realtime new=${e.eventId} type=${e.eventType}, notificationCount=$_notificationCount',
              name: 'HomeScreen',
            );
          } catch (e) {
            dev.log('Error processing event: $e', name: 'HomeScreen', error: e);
          }
        },
      );
    } catch (e) {
      dev.log(
        'Error initializing Supabase connection: $e',
        name: 'HomeScreen',
        error: e,
      );
    }
  }

  // Handle navigation
  void onTap(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // title: Text(
        //   _appBarTitle(),
        //   style: const TextStyle(color: AppTheme.text),
        // ),
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(
            Icons.settings,
            color: AppTheme.primaryBlue,
            size: 24,
          ),
          splashRadius: 20,
        ),
        actions: [
          // Search now opens Search Screen
          Semantics(
            button: true,
            label: 'Tìm kiếm',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                icon: const Icon(
                  Icons.search,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                splashRadius: 20,
              ),
            ),
          ),
          // Sleep checkin icon
          Semantics(
            button: true,
            label: 'Giờ ngủ',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: IconButton(
                tooltip: 'Giờ ngủ',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SleepCheckinScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.bedtime_outlined,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                splashRadius: 20,
              ),
            ),
          ),
          // Invoice icon with badge
          // Stack(
          //   alignment: Alignment.center,
          //   children: [
          //     Semantics(
          //       button: true,
          //       label: 'Hóa đơn',
          //       child: Padding(
          //         padding: const EdgeInsets.symmetric(horizontal: 6.0),
          //         child: IconButton(
          //           tooltip: 'Hóa đơn',
          //           onPressed: () {
          //             Navigator.of(context).push(
          //               MaterialPageRoute(
          //                 builder: (_) => const InvoicesScreen(),
          //               ),
          //             );
          //           },
          //           icon: const Icon(
          //             Icons.receipt_long,
          //             color: AppTheme.primaryBlue,
          //           ),
          //           splashRadius: 24,
          //         ),
          //       ),
          //     ),
          //     if (_invoiceCount > 0)
          //       Positioned(
          //         right: 6,
          //         top: 8,
          //         child: Semantics(
          //           label: '$_invoiceCount hóa đơn',
          //           child: Container(
          //             padding: const EdgeInsets.symmetric(
          //               horizontal: 4,
          //               vertical: 2,
          //             ),
          //             decoration: BoxDecoration(
          //               color: const Color(0xFFE53935),
          //               borderRadius: BorderRadius.circular(8),
          //               border: Border.all(color: Colors.white, width: 1),
          //             ),
          //             constraints: const BoxConstraints(
          //               minWidth: 12,
          //               minHeight: 12,
          //             ),
          //             child: Text(
          //               _invoiceCount > 99 ? '99+' : _invoiceCount.toString(),
          //               style: const TextStyle(
          //                 color: Colors.white,
          //                 fontSize: 10,
          //                 fontWeight: FontWeight.bold,
          //               ),
          //               textAlign: TextAlign.center,
          //             ),
          //           ),
          //         ),
          //       ),
          //   ],
          // ),
          // Notification icon with badge
          Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                button: true,
                label: 'Thông báo',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () async {
                      final navigator = Navigator.of(context);

                      try {
                        final service = NotificationApiService();
                        final success = await service.markAllAsRead();
                        if (success) {
                          _resetNotificationCount();
                        }
                      } catch (e) {
                        debugPrint('Error marking notifications as read: $e');
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        try {
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Navigation error (notification): $e');
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.notifications,
                      color: AppTheme.primaryBlue,
                    ),
                    splashRadius: 24,
                  ),
                ),
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Semantics(
                    label: '$_notificationCount thông báo',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _notificationCount > 99
                            ? '99+'
                            : _notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // // Send notification icon
          // Semantics(
          //   button: true,
          //   label: 'Gửi thông báo',
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
          //     child: IconButton(
          //       tooltip: 'Gửi thông báo',
          //       onPressed: () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(
          //             builder: (_) => const SendNotificationScreen(),
          //           ),
          //         );
          //       },
          //       icon: const Icon(
          //         Icons.send,
          //         color: AppTheme.primaryBlue,
          //         size: 24,
          //       ),
          //       splashRadius: 20,
          //     ),
          //   ),
          // ),
          // AI Suggestion
          // Send notification icon
          // Semantics(
          //   button: true,
          //   label: 'Gợi Ý AI',
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
          //     child: IconButton(
          //       tooltip: 'Gợi Ý AI',
          //       onPressed: () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(
          //             builder: (_) => const AISuggestionsDemoScreen(),
          //           ),
          //         );
          //       },
          //       icon: Container(
          //         decoration: BoxDecoration(
          //           color: AppTheme.primaryBlue.withOpacity(0.1),
          //           shape: BoxShape.circle,
          //         ),
          //         padding: const EdgeInsets.all(6),
          //         child: const Icon(
          //           // Icons.smart_toy_outlined,
          //           Icons.lightbulb,
          //           color: AppTheme.primaryBlue,
          //           size: 26,
          //         ),
          //       ),

          //       splashRadius: 22,
          //     ),
          //   ),
          // ),
        ],
      ),

      body: _buildContentByIndex(),
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
        badgeCounts: {2: _invoiceCount},
        borderRadius: 30,
        bottomMargin: 15,
        horizontalMargin: 10,
      ),
    );
  }

  Widget _buildContentByIndex() {
    switch (_selectedIndex) {
      case 0:
        return const LiveCameraHomeScreen();
      case 1:
        try {
          final auth = context.read<AuthProvider>();
          final user = auth.user;
          if (user != null &&
              (user.role.toLowerCase() == 'caregiver' ||
                  user.role.toLowerCase() == 'carer')) {
            return const CaregiverSettingsScreen(embedInParent: true);
          }
        } catch (_) {}
        return const AssignmentsScreen();
      case 2:
        return const PatientProfileScreen(embedInParent: true);
      case 3:
        return const ProfileScreen(embedInParent: true);
      case 4:
        return Column(
          children: [
            TabSelector(
              selectedTab: _selectedTab,
              onTabChanged: (t) => setState(() {
                _selectedTab = t;
                if (t == 'lowConfidence') {
                  _selectedStatus = 'all';
                } else if (t == 'highConfidence') {
                  _selectedStatus = HomeFilters.defaultStatus;
                }
              }),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildContentByTab(),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContentByTab() {
    switch (_selectedTab) {
      case 'highConfidence':
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshLogs,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return HighConfidenceEventsScreen(
          logs: _logs,
          selectedStatus: _selectedStatus,
          selectedDayRange: _selectedDayRange,
          selectedPeriod: _selectedPeriod,
          onRefresh: _refreshLogs,
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus);
            _refreshLogs();
          },
          onDayRangeChanged: (v) {
            setState(
              () => _selectedDayRange = v ?? HomeFilters.defaultDayRange,
            );
            _refreshLogs();
          },
          onPeriodChanged: (v) {
            setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod);
            _refreshLogs();
          },
        );
      case 'lowConfidence':
        return LowConfidenceEventsScreen(
          logs: _logs,
          selectedDayRange: _selectedDayRange,
          selectedStatus: _selectedStatus,
          selectedPeriod: _selectedPeriod,
          onDayRangeChanged: (v) {
            setState(
              () => _selectedDayRange = v ?? HomeFilters.defaultDayRange,
            );
            _refreshLogs();
          },
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus);
            _refreshLogs();
          },
          onPeriodChanged: (v) {
            setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod);
            _refreshLogs();
          },
          onRefresh: _refreshLogs,
          onEventUpdated: (eventId, {bool? confirmed}) {
            try {
              _refreshLogs();
            } catch (_) {}
          },
        );
      case 'report':
        return HealthOverviewScreen(patientId: _customerId);
      default:
        return const SizedBox.shrink();
    }
  }
}
