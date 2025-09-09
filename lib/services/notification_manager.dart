import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/notification_payload.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  final _supabase = Supabase.instance.client;
  bool _isFirebaseReady = false;

  static const String _channelId = 'healthcare_alerts';
  static const String _channelName = 'Healthcare Alerts';
  static const String _channelDesc = 'Notifications for healthcare events';

  Future<void> initialize() async {
    // 1. Setup Local Notifications
    await _setupLocalNotifications();

    // 2. Setup FCM for background notifications
    await _setupFCM();

    // 3. Setup Supabase Realtime for foreground events
    _setupSupabaseRealtime();
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _setupFCM() async {
    try {
      // Initialize Firebase if not already
      if (!_isFirebaseReady) {
        await Firebase.initializeApp();
        _isFirebaseReady = true;
        debugPrint('🔥 Firebase initialized successfully');
      }

      // Initialize FCM
      _fcm = FirebaseMessaging.instance;
      debugPrint('📱 FCM instance created');

      // Request permission
      final settings = await _fcm?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permissions granted');
      } else {
        debugPrint('⚠️ Notification permissions denied');
        return;
      }

      final token = await _fcm?.getToken();
      if (token != null) {
        debugPrint('📤 FCM Token obtained: ${token.substring(0, 10)}...');
      }

      // Only register foreground handler here, background handler is in main.dart
      FirebaseMessaging.onMessage.listen(_handleForegroundFCMMessage);
      debugPrint('📬 Foreground message handler registered');

      // Register app open handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      debugPrint('🎯 App open from notification handler registered');
    } catch (e) {
      debugPrint('❌ FCM setup error: $e');
      _isFirebaseReady = false;
    }
  }

  void _setupSupabaseRealtime() {
    _supabase
        .channel('healthcare_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_detections',
          callback: (payload) {
            _handleForegroundEvent(payload);
          },
        )
        .subscribe();
  }

  Future<void> _handleForegroundFCMMessage(RemoteMessage message) async {
    debugPrint('\n📱 Processing foreground FCM message');

    final payload = NotificationPayload.fromFCM(message);

    if (!payload.isValid) {
      debugPrint('❌ Invalid FCM payload, ignoring');
      return;
    }

    // Show notifications for both system events and actor messages
    debugPrint('🔔 Showing notification for ${payload.type}');

    // Different handling based on type
    if (payload.isSystemEvent) {
      // For system events: show notification + update state
      await showNotification(
        title: payload.getTitle(),
        body: payload.message ?? 'New system event detected',
        urgent: true,
      );
      await _fetchLatestEvents();
    } else if (payload.isActorMessage) {
      // For actor messages: show notification with appropriate urgency
      final isUrgent = payload.category == 'help';
      await showNotification(
        title: payload.getTitle(),
        body: payload.message ?? 'New message received',
        urgent: isUrgent,
      );
    }
  }

  Future<void> _handleForegroundEvent(PostgresChangePayload payload) async {
    debugPrint('\n🔔 Processing foreground notification');

    final eventData = payload.newRecord;
    final isUrgent = _determineUrgency(eventData);

    debugPrint('├─ Event type: ${eventData['event_type']}');
    debugPrint('└─ Urgency: ${isUrgent ? '🚨 URGENT' : '📝 Normal'}\n');

    await showNotification(
      title: 'Healthcare Alert',
      body: _generateNotificationBody(eventData),
      urgent: isUrgent,
    );
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('\n🔗 Handling notification open');

    // 1. Parse basic info first
    final isSystemEvent = message.data['type'] == 'system_event';
    final eventId = message.data['event_id'];

    debugPrint('Type: ${message.data['type']}');
    debugPrint('Event ID: $eventId');

    // 2. For system events, fetch and show the event model
    if (isSystemEvent && eventId != null) {
      debugPrint('📋 System Event - Will show event model');
      await _fetchLatestEvents();
      // TODO: Show event model via your state management solution
      // Example: Provider.of<EventProvider>(context, listen: false).showEventModel(eventId);
    } else {
      debugPrint('💬 Actor Message - Just navigate to app');
      // No additional action needed, app will just open
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    final soundName = urgent ? 'danger' : 'warning';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundName),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    );

    final iosDetails = DarwinNotificationDetails(
      sound: '$soundName.mp3',
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    if (urgent) {
      HapticFeedback.vibrate();
      HapticFeedback.heavyImpact();
    }
  }

  bool _determineUrgency(Map<String, dynamic> eventData) {
    return eventData['event_type'] == 'FALL_DETECTION' ||
        (eventData['confidence_score'] as num) > 0.85;
  }

  String _generateNotificationBody(Map<String, dynamic> eventData) {
    return 'New ${eventData['event_type']} detected';
  }

  Future<void> _fetchLatestEvents() async {
    try {
      await _supabase
          .from('event_detections')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
    } catch (e) {
      debugPrint('Error fetching latest events: $e');
    }
  }
}

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final notificationManager = NotificationManager();

  debugPrint('\n📱 FCM Message Received:');
  debugPrint('Data: ${message.data}');

  // Determine notification type and content
  final isSystemEvent = message.data['type'] == 'system_event';
  final messageType =
      message.data['message_type'] ?? ''; // e.g., 'help', 'chat'

  // Prepare notification content
  String title;
  String body;
  bool urgent = false;

  if (isSystemEvent) {
    title = 'New Event Detected';
    body = message.data['event_description'] ?? 'A new event has been detected';
    urgent = message.data['priority'] == 'high';
  } else {
    // Actor message
    if (messageType == 'help') {
      title = '🆘 Help Request';
      urgent = true;
    } else {
      title = 'New Message';
      urgent = false;
    }
    body = message.data['message'] ?? 'You have a new message';
  }

  await notificationManager.showNotification(
    title: title,
    body: body,
    urgent: urgent,
  );
}
