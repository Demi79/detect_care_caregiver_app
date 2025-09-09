import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';

import 'package:detect_care_caregiver_app/core/utils/app_lifecycle.dart';
import 'package:detect_care_caregiver_app/core/alerts/alert_coordinator.dart';

import 'package:detect_care_caregiver_app/features/auth/data/auth_endpoints.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/auth/repositories/auth_repository.dart';

import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_endpoints.dart';
import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/health_overview/data/health_overview_repository_impl.dart';
import 'package:detect_care_caregiver_app/features/health_overview/providers/health_overview_provider.dart';

import 'package:detect_care_caregiver_app/features/setting/data/settings_endpoints.dart';
import 'package:detect_care_caregiver_app/features/setting/data/settings_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/setting/data/settings_repository_impl.dart';
import 'package:detect_care_caregiver_app/features/setting/screens/settings_screen.dart';
import 'package:detect_care_caregiver_app/features/setting/providers/settings_provider.dart';
import 'package:detect_care_caregiver_app/features/home/screens/pending_assignment_screen.dart';

import 'package:detect_care_caregiver_app/widgets/auth_gate.dart';
import 'package:detect_care_caregiver_app/services/notification_manager.dart';

import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_registration.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final notifManager = NotificationManager();
  final isSystemEvent = message.data['type'] == 'system_event';
  final messageType = message.data['message_type'];

  String title;
  String body;
  bool urgent;

  if (isSystemEvent) {
    title = message.data['event_type'] ?? 'New Event';
    body = message.data['event_description'] ?? 'A new event has been detected';
    urgent = message.data['priority'] == 'high';
  } else {
    if (messageType == 'help') {
      title = '🆘 Help Request';
      body = message.data['message'] ?? 'Help is needed!';
      urgent = true;
    } else {
      title = 'New Message';
      body = message.data['message'] ?? 'You have a new message';
      urgent = false;
    }
  }

  await notifManager.showNotification(title: title, body: body, urgent: urgent);
}

// FCM wiring để show modal khi app mở từ notif (foreground/background/terminated)
Future<void> _wireUpFcmModal() async {
  // Foreground
  FirebaseMessaging.onMessage.listen((m) {
    if (m.data.isNotEmpty) {
      final entry = AlertCoordinator.fromData(m.data);
      AlertCoordinator.handle(entry);
    }
  });

  // Background -> mở app
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    if (m.data.isNotEmpty) {
      final isSystemEvent = m.data['type'] == 'system_event';

      if (isSystemEvent) {
        // Show event modal for system events
        final entry = AlertCoordinator.fromData(m.data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AlertCoordinator.handle(entry);
        });
      } else {
        // Handle deeplink for actor messages
        final deeplink = m.data['deeplink'];
        if (deeplink != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AlertCoordinator.handleDeeplink(deeplink);
          });
        }
      }
    }
  });

  // Terminated -> mở app
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial?.data.isNotEmpty == true) {
    final isSystemEvent = initial!.data['type'] == 'system_event';

    if (isSystemEvent) {
      final entry = AlertCoordinator.fromData(initial.data);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AlertCoordinator.handle(entry);
      });
    } else {
      final deeplink = initial.data['deeplink'];
      if (deeplink != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AlertCoordinator.handleDeeplink(deeplink);
        });
      }
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycle.init();

  try {
    // 1) ENV
    await dotenv.load(
      fileName: const String.fromEnvironment(
        'ENV_FILE',
        defaultValue: '.env.dev',
      ),
    );
    debugPrint('📝 Environment loaded');

    // 2) Firebase
    await Firebase.initializeApp();
    debugPrint('🔥 Firebase initialized');

    // 3) Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    debugPrint('🔄 Firebase background handler registered');

    // 4) Supabase
    await Supabase.initialize(
      url: 'https://undznprwlqjpnxqsgyiv.supabase.co',
      anonKey: AppConfig.supabaseKey,
    );
    debugPrint('⚡ Supabase initialized');

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      final email = dotenv.env['SUPABASE_DEV_EMAIL'] ?? '';
      final password = dotenv.env['SUPABASE_DEV_PASSWORD'] ?? '';
      try {
        await auth.signInWithPassword(email: email, password: password);
        debugPrint('[Supabase] signIn ok user=${auth.currentUser?.id}');
      } catch (e) {
        debugPrint('[Supabase] signIn error: $e');
      }
    }
    debugPrint('[Supabase] hasSession=${auth.currentSession != null}');

    // 5) Notification Manager
    final notificationManager = NotificationManager();
    await notificationManager.initialize();
    debugPrint('🔔 Notification manager initialized');

    // 6) FCM modal routing
    await _wireUpFcmModal();
  } catch (e, st) {
    debugPrint('❌ Initialization error: $e');
    debugPrint(st.toString());
  }

  // Repository & Provider setup
  final client = http.Client();

  final authEndpoints = AuthEndpoints(AppConfig.apiBaseUrl);
  final authRepo = AuthRepository(
    AuthRemoteDataSource(endpoints: authEndpoints),
  );

  final hoRepo = HealthOverviewRepositoryImpl(
    HealthOverviewRemoteDataSource(
      client: client,
      endpoints: HealthOverviewEndpoints(),
    ),
  );

  final settingsRepo = SettingsRepositoryImpl(
    SettingsRemoteDataSource(endpoints: SettingsEndpoints()),
  );

  // FCM: data source & registration (dùng endpoint đơn /fcm/token)
  final fcmDs = FcmRemoteDataSource(
    client: client,
    endpoints: FcmEndpoints(AppConfig.apiBaseUrl),
  );
  final fcmReg = FcmRegistration(fcmDs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
        ChangeNotifierProvider(create: (_) => HealthOverviewProvider(hoRepo)),

        // Khi userId có giá trị -> load settings & đăng ký FCM token cho user hiện tại
        ChangeNotifierProxyProvider<AuthProvider, SettingsProvider>(
          create: (_) => SettingsProvider(repo: settingsRepo, userId: ''),
          update: (_, auth, previous) {
            final uid = auth.user?.id ?? '';
            final sp =
                previous ?? SettingsProvider(repo: settingsRepo, userId: uid);

            sp.updateUserId(uid, reload: false);
            if (uid.isNotEmpty) {
              sp.load();

              // Đăng ký FCM cho user hiện tại: getToken + onTokenRefresh -> gọi /api/fcm/token
              fcmReg.registerForUser(uid);
            }
            return sp;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// NavigatorKey global
class NavigatorKey {
  static final navigatorKey = GlobalKey<NavigatorState>();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detect Care App',
      navigatorKey: NavigatorKey.navigatorKey,
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/waiting': (_) => const PendingAssignmentsScreen(),
      },
    );
  }
}
