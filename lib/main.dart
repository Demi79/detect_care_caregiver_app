import 'dart:convert';

import 'package:detect_care_caregiver_app/widgets/alarm_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/services/device_health_service.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/theme/theme_provider.dart';
import 'package:detect_care_caregiver_app/core/utils/app_lifecycle.dart';
import 'package:detect_care_caregiver_app/core/utils/deep_link_handler.dart';

import 'package:detect_care_caregiver_app/features/auth/data/auth_endpoints.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/auth/repositories/auth_repository.dart';

import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_registration.dart';

import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_endpoints.dart';
import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_repository_impl.dart';
import 'package:detect_care_caregiver_app/features/health_overview/providers/health_overview_provider.dart';

import 'package:detect_care_caregiver_app/features/home/screens/pending_assignment_screen.dart';

import 'package:detect_care_caregiver_app/features/setting/data/settings_endpoints.dart';
import 'package:detect_care_caregiver_app/features/setting/data/settings_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/setting/data/settings_repository_impl.dart';
import 'package:detect_care_caregiver_app/features/setting/providers/settings_provider.dart';
import 'package:detect_care_caregiver_app/features/setting/screens/settings_screen.dart';

import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/firebase_options.dart';
import 'package:detect_care_caregiver_app/services/notification_manager.dart';
import 'package:detect_care_caregiver_app/widgets/auth_gate.dart';

/// ------------------------- FCM BACKGROUND HANDLER ------------------------- ///

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final startTime = DateTime.now();
  debugPrint('🔔 [FCM-BG] Handler started at $startTime');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final flnp = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  try {
    final initStart = DateTime.now();
    await flnp.initialize(initSettings);
    final initDuration = DateTime.now().difference(initStart);
    debugPrint(
      '⏱️ [FCM-BG] FlutterLocalNotifications init: ${initDuration.inMilliseconds}ms',
    );

    final data = message.data;
    final eventType = data['event_type'] ?? data['eventType'];
    final lifecycle = data['lifecycle_state'] ?? data['lifecycleState'];
    final eventId = (data['event_id'] ?? data['id'] ?? data['eventId'])
        ?.toString();

    // Stop any active alarm/notification for resolved events.
    if (eventType == 'event_resolved' ||
        lifecycle?.toString().toUpperCase() == 'RESOLVED') {
      debugPrint('🛑 [FCM-BG] Stopping alarm for resolved event');
      try {
        await FlutterRingtonePlayer().stop();
      } catch (_) {}

      if (eventId != null && eventId.isNotEmpty) {
        try {
          final id = eventId.hashCode & 0x7FFFFFFF;
          await flnp.cancel(id);
        } catch (_) {}
      }
      return;
    }

    if (eventType != null) {
      final t = eventType.toString().trim().toLowerCase();
      if (t == 'normal_activity' ||
          t == 'normal activity' ||
          t == 'normal-activity') {
        return;
      }
    }

    const channelId = 'healthcare_alerts';
    const channelName = 'Cảnh báo Y tế';
    const channelDesc = 'Thông báo cảnh báo y tế và sự kiện khẩn cấp';

    final status = message.data['status']?.toString().toLowerCase();
    final playSoundForStatus =
        status == 'danger' || status == 'critical' || status == 'warning';

    final androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFFFF0000),
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      sound: playSoundForStatus
          ? const RawResourceAndroidNotificationSound('notification_emergency')
          : null,
    );

    final channelStart = DateTime.now();
    await flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
    final channelDuration = DateTime.now().difference(channelStart);
    debugPrint(
      '⏱️ [FCM-BG] Channel creation: ${channelDuration.inMilliseconds}ms',
    );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      sound: playSoundForStatus
          ? const RawResourceAndroidNotificationSound('notification_emergency')
          : null,
      playSound: playSoundForStatus,
    );

    final iosDetails = DarwinNotificationDetails(
      sound: playSoundForStatus ? 'notification_emergency.mp3' : null,
      presentSound: playSoundForStatus,
      presentAlert: true,
      presentBadge: true,
    );

    String? payload;
    try {
      final deeplink =
          data['deeplink'] ?? data['link'] ?? data['url'] ?? data['action_url'];
      if (deeplink != null && deeplink.toString().isNotEmpty) {
        payload = jsonEncode({'deeplink': deeplink.toString()});
      } else if (eventId != null && eventId.isNotEmpty) {
        payload = jsonEncode({'deeplink': 'detectcare://alert/$eventId'});
      }
    } catch (_) {}

    int notificationId;
    if (eventId != null && eventId.isNotEmpty) {
      notificationId = eventId.hashCode & 0x7FFFFFFF;
    } else {
      notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    }

    final showStart = DateTime.now();
    await flnp.show(
      notificationId,
      message.notification?.title ?? 'New Alert',
      message.notification?.body ?? 'New healthcare event detected',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
    final showDuration = DateTime.now().difference(showStart);
    debugPrint(
      '⏱️ [FCM-BG] Notification show: ${showDuration.inMilliseconds}ms',
    );
  } catch (e) {
    debugPrint('❌ Background notification failed: $e');
  }

  final totalDuration = DateTime.now().difference(startTime);
  debugPrint(
    '✅ [FCM-BG] Handler completed in ${totalDuration.inMilliseconds}ms',
  );
}

/// ----------------------------- BOOTSTRAP APP ------------------------------ ///

Future<void> _initEnv() async {
  const envFile = String.fromEnvironment('ENV_FILE', defaultValue: '.env.dev');
  await dotenv.load(fileName: envFile);
  debugPrint('📝 Environment loaded ($envFile)');

  try {
    final cloud = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    debugPrint('[ENV] CLOUDINARY_CLOUD_NAME=${cloud ?? 'null'}');
    debugPrint('[ENV] CLOUDINARY_UPLOAD_PRESET=${preset ?? 'null'}');
    debugPrint(
      '[ENV] API_BASE_URL=${AppConfig.apiBaseUrl.isEmpty ? 'null/empty' : AppConfig.apiBaseUrl}',
    );
    debugPrint('[ENV] FLAVOR=${AppConfig.flavor}');
  } catch (e) {
    debugPrint('[ENV] Error reading env keys: $e');
  }
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔥 Firebase initialized');

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  debugPrint('🔄 Firebase background handler registered');
}

Future<void> _initSupabase() async {
  final supabaseUrl = AppConfig.supabaseUrl.isNotEmpty
      ? AppConfig.supabaseUrl
      : 'https://undznprwlqjpnxqsgyiv.supabase.co';

  await Supabase.initialize(url: supabaseUrl, anonKey: AppConfig.supabaseKey);

  // Defer auto-signin to microtask để không block boot
  Future.microtask(() async {
    final auth = Supabase.instance.client.auth;

    if (auth.currentSession == null) {
      final email = dotenv.env['SUPABASE_DEV_EMAIL'] ?? '';
      final password = dotenv.env['SUPABASE_DEV_PASSWORD'] ?? '';

      try {
        final signInStart = DateTime.now();
        await auth.signInWithPassword(email: email, password: password);
        final signInDuration = DateTime.now().difference(signInStart);
        debugPrint(
          '⏱️ [Supabase] Auto-signin: ${signInDuration.inMilliseconds}ms',
        );
      } catch (e) {
        debugPrint('[Supabase] signIn error: $e');
      }
    }
  });
}

Future<void> _initNotifications() async {
  final notificationManager = NotificationManager();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    notificationManager
        .initialize()
        .then((_) => notificationManager.setupFcmTapHandler())
        .catchError((e, st) {
          debugPrint('❌ Deferred notification init failed: $e');
          debugPrint('$st');
        });
  });
}

Future<void> _bootstrapCore() async {
  final bootStart = DateTime.now();
  debugPrint('🚀 [BOOTSTRAP] Starting app initialization...');

  AppLifecycle.init();

  final envStart = DateTime.now();
  await _initEnv();
  debugPrint(
    '⏱️ [BOOTSTRAP] Env loaded: ${DateTime.now().difference(envStart).inMilliseconds}ms',
  );

  final firebaseStart = DateTime.now();
  await _initFirebase();
  debugPrint(
    '⏱️ [BOOTSTRAP] Firebase init: ${DateTime.now().difference(firebaseStart).inMilliseconds}ms',
  );

  final supabaseStart = DateTime.now();
  await _initSupabase();
  debugPrint(
    '⏱️ [BOOTSTRAP] Supabase init: ${DateTime.now().difference(supabaseStart).inMilliseconds}ms',
  );

  await _initNotifications();
  debugPrint('⏱️ [BOOTSTRAP] Notifications scheduled (deferred)');

  final deviceHealthService = DeviceHealthService();
  deviceHealthService.startHealthMonitoring();

  final totalDuration = DateTime.now().difference(bootStart);
  debugPrint(
    '✅ [BOOTSTRAP] Total boot time: ${totalDuration.inMilliseconds}ms',
  );
}

/// ------------------------------- MAIN ENTRY ------------------------------- ///

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _bootstrapCore();
  } catch (e, st) {
    debugPrint('❌ Initialization error: $e');
    debugPrint('$st');
  }

  // Shared ApiClient cho toàn app
  final apiClient = ApiClient(tokenProvider: AuthStorage.getAccessToken);

  // Auth
  final authRepo = AuthRepository(
    AuthRemoteDataSource(endpoints: AuthEndpoints(AppConfig.apiBaseUrl)),
  );

  // Health overview
  final healthOverviewRepo = HealthOverviewRepositoryImpl(
    HealthOverviewRemoteDataSource(
      api: apiClient,
      endpoints: HealthOverviewEndpoints(),
    ),
  );

  // Settings
  final settingsRepo = SettingsRepositoryImpl(
    SettingsRemoteDataSource(endpoints: SettingsEndpoints()),
  );

  // FCM registration
  final fcmRemoteDataSource = FcmRemoteDataSource(
    api: apiClient,
    endpoints: FcmEndpoints(AppConfig.apiBaseUrl),
  );
  final fcmRegistration = FcmRegistration(fcmRemoteDataSource);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
        ChangeNotifierProxyProvider<AuthProvider, PermissionsProvider>(
          create: (_) => PermissionsProvider(),
          update: (_, auth, previous) {
            final provider = previous ?? PermissionsProvider();
            if (auth.user != null) {
              provider.initialize();
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => HealthOverviewProvider(healthOverviewRepo),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SettingsProvider>(
          create: (_) => SettingsProvider(repo: settingsRepo, userId: ''),
          update: (_, auth, previous) {
            final userId = auth.user?.id ?? '';
            final provider =
                previous ??
                SettingsProvider(repo: settingsRepo, userId: userId);

            provider.updateUserId(userId, reload: false);

            if (userId.isNotEmpty) {
              provider.load();
              // Đăng ký FCM cho user hiện tại
              fcmRegistration.registerForUser(userId);
              // Subscribe to realtime notifications for badge updates
              NotificationManager().subscribeToNotifications(userId);
            }

            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );

  _setupApiClientUnauthenticatedHandler();
  _setupOnAssignmentLostHandler();
  _setupApiClientTooManyRequestsHandler();
}

void _setupApiClientTooManyRequestsHandler() {
  try {
    ApiClient.onTooManyRequests = () async {
      try {
        final navigator = NavigatorKey.navigatorKey.currentState;
        if (navigator == null) return;
        final ctx = navigator.context;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text(
                  'Hệ thống đang quá tải, vui lòng thử lại sau vài giây',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          } catch (_) {}
        });
      } catch (e) {
        print('onTooManyRequests handler failed: $e');
      }
    };
  } catch (e) {
    print('Failed to register onTooManyRequests handler: $e');
  }
}

/// ------------------------- GLOBAL NAVIGATOR & APP ------------------------- ///

class NavigatorKey {
  static final navigatorKey = GlobalKey<NavigatorState>();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHandler.start();
    });
  }

  @override
  void dispose() {
    DeepLinkHandler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Detect Care App',
      navigatorKey: NavigatorKey.navigatorKey,
      theme: AppTheme.caregiverLightTheme,
      darkTheme: AppTheme.caregiverDarkTheme,
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      home: Stack(children: const [AuthGate(), AlarmBubbleOverlay()]),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/waiting': (_) => const PendingAssignmentsScreen(),
      },
    );
  }
}

/// ---------------------- SIDE EFFECT: API & ASSIGNMENT --------------------- ///

void _setupApiClientUnauthenticatedHandler() {
  bool unauthInProgress = false;

  ApiClient.onUnauthenticated = () async {
    if (unauthInProgress) return;
    unauthInProgress = true;

    try {
      final navigator = NavigatorKey.navigatorKey.currentState;
      if (navigator == null) return;

      final ctx = navigator.context;

      // Thông báo hết hạn phiên
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
              ),
              duration: Duration(milliseconds: 1100),
            ),
          );
        } catch (_) {}
      });

      await Future.delayed(const Duration(milliseconds: 1200));

      // Logout qua AuthProvider
      try {
        final auth = Provider.of<AuthProvider>(ctx, listen: false);
        try {
          final permProvider = Provider.of<PermissionsProvider>(
            ctx,
            listen: false,
          );
          permProvider.reset();
        } catch (_) {}
        await auth.logout();
      } catch (_) {}

      // Điều hướng về AuthGate
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      });
    } catch (e) {
      debugPrint('ApiClient.onUnauthenticated handler failed: $e');
    } finally {
      unauthInProgress = false;
    }
  };
}

void _setupOnAssignmentLostHandler() {
  try {
    final navigator = NavigatorKey.navigatorKey.currentState;
    final ctx = navigator?.context;

    if (ctx == null) return;

    final auth = Provider.of<AuthProvider>(ctx, listen: false);

    auth.onAssignmentLost = () async {
      try {
        auth.status = AuthStatus.assignVerified;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              title: const Text(
                'Liên kết chăm sóc đã kết thúc',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Bạn và khách hàng này không còn được kết nối trong hệ thống.\n'
                'Một số tính năng và dữ liệu liên quan sẽ không còn khả dụng.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          );
        });

        await Future.delayed(const Duration(milliseconds: 1400));

        navigator?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PendingAssignmentsScreen()),
          (route) => false,
        );
      } catch (e) {
        debugPrint('onAssignmentLost handler failed: $e');
      }
    };
  } catch (e) {
    debugPrint('Failed to register onAssignmentLost: $e');
  }
}
