import 'dart:async';
import 'dart:developer' as dev;

import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/widgets/custom_bottom_nav_bar.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_home_screen.dart';
import 'package:detect_care_caregiver_app/features/health_overview/screens/health_overview_screen.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/constants/types.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/screens/warning_log_screen.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/patient/screens/patient_profile_screen.dart';
import 'package:detect_care_caregiver_app/features/profile/screens/profile_screen.dart';
import 'package:detect_care_caregiver_app/features/setting/screens/settings_screen.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/tab_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 4; // Home screen index
  String _selectedTab = 'Warning';
  String _selectedStatus = HomeFilters.defaultStatus;
  String _selectedPeriod = HomeFilters.defaultPeriod;

  DateTimeRange? _selectedDayRange = HomeFilters.defaultDayRange;
  final TextEditingController _searchController = TextEditingController();

  late final EventRepository _eventRepository;
  late final SupabaseService _supa;

  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;

  Timer? _searchDebounce;
  @override
  void initState() {
    super.initState();

    _eventRepository = EventRepository(EventService());

    EventService().debugProbe();
    _supa = SupabaseService();
    _initSupabaseConnection();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), _refreshLogs);
      setState(() {});
    });
    _refreshLogs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _supa.dispose();
    super.dispose();
  }

  Future<void> _refreshLogs() async {
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('[Home] Refresh with userID: ${user?.id}');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await _eventRepository.getEvents(
        page: 1,
        limit: 20,
        status: _selectedStatus,
        dayRange: _selectedDayRange,
        period: _selectedPeriod,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      dev.log(
        'UI got events=${events.length}, firstIds=${events.take(3).map((e) => e.eventId).toList()}',
        name: 'HomeScreen',
      );

      if (!mounted) return;
      setState(() {
        _logs = events;
        _error = null;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Error refreshing logs: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events. Please try again.';
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
                HapticFeedback.selectionClick();
              }
            });
            dev.log(
              'realtime new=${e.eventId} type=${e.eventType}',
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
        leading: IconButton(
          icon: const Icon(Icons.settings, color: AppTheme.primaryBlue),
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
        ),
      ),
      body: _buildContentByIndex(),
      floatingActionButton: FloatingActionButton(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: onTap,
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
        return const Center(child: Text('Search content here'));
      case 2:
        return const Center(child: Text('Notifications content here'));
      case 3:
        return const ProfileScreen();
      case 4:
        return Column(
          children: [
            TabSelector(
              selectedTab: _selectedTab,
              onTabChanged: (t) => setState(() => _selectedTab = t),
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
      case 'Warning':
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return WarningLogScreen(
          logs: _logs,
          selectedStatus: _selectedStatus,
          selectedDayRange: _selectedDayRange,
          selectedPeriod: _selectedPeriod,
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
      case 'Activity':
        return const Center(child: Text('Activity content here'));
      case 'Report':
        return const HealthOverviewScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
