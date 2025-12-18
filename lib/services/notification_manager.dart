import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:detect_care_caregiver_app/core/alerts/alert_coordinator.dart';
import 'package:detect_care_caregiver_app/core/utils/deep_link_handler.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/firebase_options.dart';
import 'package:detect_care_caregiver_app/services/push_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quản lý thông báo và push notifications cho ứng dụng y tế
/// Xử lý Firebase FCM, local notifications và Supabase realtime
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();

  /// Singleton instance để đảm bảo chỉ có một instance duy nhất
  factory NotificationManager() => _instance;

  NotificationManager._internal();

  // Core services
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  final SupabaseClient _supabase = Supabase.instance.client;

  // State management
  bool _isFirebaseReady = false;
  bool _isInitialized = false;

  // Notification ID counter để tránh duplicate
  static int _notificationIdCounter = 1000;
  // Recently shown event notifications (eventId -> shownAt) to avoid dupes
  final Map<String, DateTime> _recentlyShownEvents = {};

  final StreamController<Map<String, dynamic>?> _notificationStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();

  // Notification channel constants cho healthcare
  static const String _channelId = 'healthcare_alerts';
  static const String _channelName = 'Cảnh báo Y tế';
  static const String _channelDesc =
      'Thông báo cảnh báo y tế và sự kiện khẩn cấp';
  // Silent channel for notifications that should not play sound
  static const String _silentChannelId = 'healthcare_alerts_silent_v2';
  static const String _silentChannelName = 'Cảnh báo Y tế (Im lặng)';
  static const String _silentChannelDesc = 'Thông báo y tế không phát âm thanh';
  // Foreground realtime wait timeout when trying to sync notification timing
  static const Duration _fgRealtimeTimeout = Duration(seconds: 30);

  /// Generate unique notification ID
  static int _generateNotificationId() {
    _notificationIdCounter = (_notificationIdCounter + 1) % 999999;
    return _notificationIdCounter;
  }

  /// Wait for a Supabase realtime insert matching [eventId], with a [timeout].
  /// Returns the row map when found, or null on timeout.
  Future<Map<String, dynamic>?> _waitForRealtimeEvent(
    String eventId,
    Duration timeout,
  ) async {
    final completer = Completer<Map<String, dynamic>?>();
    RealtimeChannel? oneOff;
    try {
      oneOff = _supabase.channel(
        'fg_sync_${eventId}_${DateTime.now().microsecondsSinceEpoch}',
      );
      oneOff.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'event_detections',
        callback: (payload) {
          try {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final id = (row['event_id'] ?? row['id'] ?? row['eventId'])
                ?.toString();
            if (id == eventId && !completer.isCompleted) {
              completer.complete(row.cast<String, dynamic>());
            }
          } catch (e, st) {
            AppLogger.d('Realtime oneOff callback error: $e', e, st);
          }
        },
      );
      oneOff.subscribe();

      final result = await Future.any([
        completer.future,
        Future<Map<String, dynamic>?>.delayed(timeout, () => null),
      ]);
      return result;
    } finally {
      try {
        await oneOff?.unsubscribe();
      } catch (_) {}
    }
  }

  /// Khởi tạo tất cả các dịch vụ thông báo
  /// Nên gọi một lần khi app khởi động
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.i('ℹ️ NotificationManager đã được khởi tạo');
      return;
    }

    try {
      AppLogger.i('🚀 Đang khởi tạo NotificationManager...');

      // 1. Thiết lập thông báo cục bộ
      await _setupLocalNotifications();
      AppLogger.i('✅ Thông báo cục bộ đã sẵn sàng');

      // 2. Thiết lập Firebase Cloud Messaging
      await _setupFCM();
      AppLogger.i('✅ FCM đã sẵn sàng');

      // 3. Thiết lập Supabase realtime cho sự kiện foreground
      _setupSupabaseRealtime();
      AppLogger.i('✅ Supabase realtime đã sẵn sàng');

      _isInitialized = true;
      AppLogger.i('🎉 NotificationManager khởi tạo thành công');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Lỗi khởi tạo NotificationManager: $e', e, stackTrace);
      _isFirebaseReady = false;
      rethrow;
    }
  }

  /// Thiết lập thông báo cục bộ cho Android và iOS
  Future<void> _setupLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTapped,
      );

      if (initialized == false) {
        AppLogger.w('⚠️ Không thể khởi tạo local notifications');
        return;
      }

      // Tạo notification channel cho Android
      await _createNotificationChannel();

      AppLogger.i('📱 Local notifications đã được cấu hình');
    } catch (e) {
      AppLogger.e('❌ Lỗi thiết lập local notifications: $e', e);
      rethrow;
    }
  }

  /// Xử lý khi user tap vào notification trong foreground
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.i('👆 User tapped notification: ${response.payload}');
    // If payload contains a deeplink, try to process it
    try {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        // Expecting payload to be either a plain deeplink string or JSON with 'deeplink'
        String? deeplink;
        try {
          final parsed = Uri.tryParse(payload);
          if (parsed != null && parsed.scheme == 'detectcare') {
            deeplink = payload;
          }
        } catch (_) {}

        if (deeplink == null) {
          try {
            final map = payload.startsWith('{')
                ? Map<String, dynamic>.from(jsonDecode(payload))
                : {};
            deeplink = map['deeplink'] as String? ?? map['link'] as String?;
          } catch (_) {}
        }

        if (deeplink != null && deeplink.isNotEmpty) {
          DeepLinkHandler.processUri(Uri.parse(deeplink));
          return;
        }
      }
    } catch (e) {
      AppLogger.e('Error processing local notification payload: $e', e);
    }

    // Fallback: existing behavior (TODO: further routing)
  }

  /// Xử lý khi user tap vào notification trong background
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    AppLogger.i('👆 Background notification tapped: ${response.payload}');
    try {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        String? deeplink;
        try {
          final parsed = Uri.tryParse(payload);
          if (parsed != null && parsed.scheme == 'detectcare') {
            deeplink = payload;
          }
        } catch (_) {}

        if (deeplink == null) {
          try {
            final map = payload.startsWith('{')
                ? Map<String, dynamic>.from(jsonDecode(payload))
                : {};
            deeplink = map['deeplink'] as String? ?? map['link'] as String?;
          } catch (_) {}
        }

        if (deeplink != null && deeplink.isNotEmpty) {
          AppLogger.i(
            'Background notification contained deeplink (saving): $deeplink',
          );
          try {
            SharedPreferences.getInstance()
                .then((prefs) async {
                  await prefs.setString('pending_deeplink', deeplink!);
                  AppLogger.i('Saved pending deeplink to shared prefs');
                })
                .catchError((e) {
                  AppLogger.e('Failed to save pending deeplink: $e', e);
                });
          } catch (e) {
            AppLogger.e('Error persisting pending deeplink: $e', e);
          }
        }
      }
    } catch (e) {
      AppLogger.e('Error processing background notification payload: $e', e);
    }
  }

  /// Tạo notification channel cho Android với các thiết lập ưu tiên
  Future<void> _createNotificationChannel() async {
    // Audible channel (for urgent notifications)
    final androidAudible = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFFFF0000),
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      sound: const RawResourceAndroidNotificationSound(
        'notification_emergency',
      ),
    );

    const androidSilent = AndroidNotificationChannel(
      _silentChannelId,
      _silentChannelName,
      description: _silentChannelDesc,
      importance: Importance.high,
      enableVibration: false,
      enableLights: false,
      sound: null,
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.createNotificationChannel(androidAudible);
    await androidImpl?.createNotificationChannel(androidSilent);
  }

  /// Thiết lập Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    try {
      // Khởi tạo Firebase nếu chưa sẵn sàng
      if (!_isFirebaseReady) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isFirebaseReady = true;
        AppLogger.i('🔥 Firebase đã khởi tạo thành công');
      }

      // Khởi tạo FCM
      _fcm = FirebaseMessaging.instance;
      AppLogger.i('📱 FCM instance đã tạo');

      // Yêu cầu quyền thông báo
      final settings = await _fcm?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.i('✅ Quyền thông báo đã được cấp');
      } else {
        AppLogger.w('⚠️ Quyền thông báo bị từ chối');
        return;
      }

      if (Platform.isAndroid) {
        try {
          final status = await Permission.notification.status;
          if (!status.isGranted) {
            final result = await Permission.notification.request();
            if (result.isGranted) {
              AppLogger.i('✅ Android POST_NOTIFICATIONS permission granted');
            } else {
              AppLogger.w(
                '⚠️ Android POST_NOTIFICATIONS permission not granted',
              );
            }
          }
        } catch (e) {
          AppLogger.w(
            'Không thể yêu cầu permission notification trên Android: $e',
          );
        }
      }

      Future.delayed(Duration.zero, () => _registerDeviceToken());

      _fcm?.onTokenRefresh.listen((newToken) {
        try {
          AppLogger.d(
            '� FCM Token đã làm mới: ${newToken.substring(0, 10)}...',
          );
        } catch (_) {}
        Future.microtask(() => _registerDeviceToken());
      });

      AppLogger.d(
        '🔄 Skipping background handler registration here (handled in main)',
      );

      // Xử lý khi app được mở từ notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      AppLogger.i('🎯 App open từ notification handler đã đăng ký');

      // Xử lý foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      AppLogger.i('📨 Foreground message handler đã đăng ký');
      // Trên iOS: đảm bảo tuỳ chọn hiển thị thông báo khi app ở foreground
      // (alert/badge/sound) được bật để hệ thống vẫn có thể trình notification
      // ngay cả khi app đang hoạt động ở foreground. Không ảnh hưởng Android.
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
        AppLogger.d(
          'Đã đặt tuỳ chọn hiển thị thông báo khi foreground trên iOS: alert/badge/sound=true',
        );
      } catch (e) {
        AppLogger.w(
          'Không thể đặt tuỳ chọn hiển thị thông báo khi foreground trên iOS: $e',
        );
      }
    } catch (e) {
      AppLogger.e('❌ Lỗi thiết lập FCM: $e', e);
      _isFirebaseReady = false;
    }
  }

  /// Đăng ký FCM token với backend
  Future<void> _registerDeviceToken() async {
    try {
      final token = await _fcm?.getToken();
      if (token == null) {
        // AppLogger.w('❌ FCM token rỗng');
        return;
      }

      // AppLogger.d('🔑 FCM Token đã nhận: ${token.substring(0, 10)}...');

      // Đăng ký token với BE chỉ khi user đã xác thực
      final userId = await AuthStorage.getUserId();
      final jwt = await AuthStorage.getAccessToken();

      if (userId != null && jwt != null) {
        await PushService.registerDeviceToken();
        // AppLogger.i('✅ FCM token đã đăng ký thành công');
      } else {
        // AppLogger.d('⏳ Bỏ qua đăng ký device token - user chưa xác thực');
      }
    } catch (e) {
      // AppLogger.e('❌ Lỗi đăng ký FCM token: $e', e);
    }
  }

  /// Thiết lập Supabase realtime cho sự kiện foreground
  void _setupSupabaseRealtime() {
    // Listen for new event inserts (existing behavior) and also for
    // updates that represent caregiver proposals so we can show a
    // notification when a proposal is created/updated.
    final ch = _supabase.channel('healthcare_events');

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_detections',
          callback: _handleForegroundEvent,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_detections',
          callback: (payload) async {
            try {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;

              // Consider this an incoming proposal if confirmation_state == 'pending'
              // or proposed_status is present.
              final confirmation = (newRow['confirmation_state'] ?? '')
                  .toString();
              final proposed = newRow['proposed_status'];
              if ((confirmation.isNotEmpty &&
                      confirmation.toLowerCase() == 'pending') ||
                  (proposed != null && proposed.toString().isNotEmpty)) {
                AppLogger.i(
                  '🔔 Detected proposal update for event ${newRow['event_id']}',
                );

                final eventId = (newRow['event_id'] ?? newRow['id'])
                    ?.toString();
                final title = 'Đề xuất trạng thái từ caregiver';
                final body = proposed != null && proposed.toString().isNotEmpty
                    ? 'Đề xuất: ${proposed.toString()}'
                    : 'Có đề xuất trạng thái mới cần xem xét';

                // Show a silent notification (no sound) to avoid doubling alert sounds
                // since proposals are informational. We still include deeplink.
                await showNotification(
                  title: title,
                  body: body,
                  urgent: false,
                  playSound: false,
                  eventId: eventId,
                  eventData: newRow.cast<String, dynamic>(),
                );
              }
            } catch (e, st) {
              AppLogger.e(
                'Error handling proposal update realtime payload: $e',
                e,
                st,
              );
            }
          },
        )
        .subscribe();

    AppLogger.i('📡 Supabase realtime đã thiết lập');
  }

  /// Xử lý sự kiện foreground từ Supabase
  Future<void> _handleForegroundEvent(PostgresChangePayload payload) async {
    AppLogger.d('\n🔔 Đang xử lý thông báo foreground');

    final eventData = payload.newRecord;
    final isUrgent = _determineUrgency(eventData);

    AppLogger.d('├─ Loại sự kiện: ${eventData['event_type']}');
    AppLogger.d(
      '└─ Độ khẩn cấp: ${isUrgent ? '🚨 KHẨN CẤP' : '📝 Bình thường'}\n',
    );

    final imageUrl = _extractImageUrl(eventData);
    AppLogger.d('📷 [Foreground] Extracted imageUrl: ${imageUrl ?? "(null)"}');
    if (imageUrl != null) {
      AppLogger.d('📷 [Foreground] Image URL length: ${imageUrl.length}');
    }
    await showNotification(
      title: 'Cảnh báo Y tế',
      body: _generateNotificationBody(eventData),
      urgent: isUrgent,
      // When app is foreground we play in-app audio; avoid duplicating
      // system/local notification sound.
      playSound: false,
      eventId: (eventData['event_id'] ?? eventData['id'])?.toString(),
      imageUrl: imageUrl,
      eventData: eventData,
    );
    AppLogger.d('Đã gọi showNotification cho sự kiện Supabase (foreground)');
  }

  /// Xử lý message khi app được mở từ background
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('📲 Xử lý background message');
    await _fetchLatestEvents();
  }

  /// Xử lý foreground FCM messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.i('📨 Nhận foreground FCM message');
    AppLogger.i(
      '📨 onMessage fired. data=${message.data} notification=${message.notification}',
    );

    final data = message.data;
    if (data.isEmpty) return;

    final entry = AlertCoordinator.fromData(data);
    AlertCoordinator.handle(entry);

    final eventId = (data['event_id'] ?? data['id'] ?? data['eventId'])
        ?.toString();
    final status = data['status']?.toString();
    final urgent = status == 'critical' || status == 'danger';

    if (eventId != null && eventId.isNotEmpty) {
      // 1) Prefer realtime delivery: wait briefly for the exact row to appear
      try {
        final realtimeRow = await _waitForRealtimeEvent(
          eventId,
          _fgRealtimeTimeout,
        );
        if (realtimeRow != null) {
          final imageUrl = _extractImageUrl(realtimeRow);
          await showNotification(
            title: message.notification?.title ?? 'Cảnh báo Y tế',
            body: _generateNotificationBody(realtimeRow),
            urgent: urgent,
            playSound: false,
            eventId: eventId,
            imageUrl: imageUrl,
            eventData: realtimeRow,
          );
          AppLogger.d(
            'Foreground FCM: shown (synced via realtime) for $eventId',
          );
          return;
        }
      } catch (e, st) {
        AppLogger.w('Waiting for realtime event failed: $e', e, st);
      }

      // 2) Fallback: fetch detail from backend
      try {
        final svc = EventService.withDefaultClient();
        final found = await svc.fetchLogDetail(eventId);
        final eventMap = found.toMapString();
        final imageUrl = found.imageUrls.isNotEmpty
            ? found.imageUrls.first
            : null;
        await showNotification(
          title: message.notification?.title ?? 'Cảnh báo Y tế',
          body: _generateNotificationBody(eventMap),
          urgent: urgent,
          playSound: false,
          eventId: eventId,
          imageUrl: imageUrl,
          eventData: eventMap,
        );
        AppLogger.d('Foreground FCM: shown (synced via fetch) for $eventId');
        return;
      } catch (e) {
        AppLogger.d('Fetch detail fallback failed for event $eventId: $e');
      }
    }

    // Final fallback: show immediate notification using FCM payload
    await showNotification(
      title: message.notification?.title ?? 'Cảnh báo Y tế',
      body: message.notification?.body ?? 'Đã phát hiện sự kiện y tế',
      urgent: urgent,
      playSound: false,
      eventId: eventId,
    );
    AppLogger.d('Đã gọi showNotification cho FCM (foreground) [fallback]');
  }

  /// Hiển thị thông báo cục bộ
  Future<void> showNotification({
    required String title,
    required String body,
    bool urgent = false,
    bool playSound = true,
    String? eventId,
    String? imageUrl,
    Map<String, dynamic>? eventData,
  }) async {
    try {
      AppLogger.i(
        '[NotificationManager] showNotification called title="$title" urgent=$urgent playSound=$playSound',
      );
      AppLogger.d('[NotificationManager] call stack:\n${StackTrace.current}');
      // Deduplicate notifications for the same event id within 2 minutes
      if (eventId != null && eventId.isNotEmpty) {
        final now = DateTime.now();
        _recentlyShownEvents.removeWhere(
          (k, v) => now.difference(v).inMinutes >= 2,
        );
        if (_recentlyShownEvents.containsKey(eventId)) {
          AppLogger.i('🔇 Skipping duplicate notification for event $eventId');
          return;
        }
      }
      AppLogger.d(
        'Chuẩn bị hiển thị thông báo cục bộ: title="$title" urgent=$urgent playSound=$playSound',
      );

      // Đảm bảo kênh thông báo đã tồn tại trước khi show (an toàn trên iOS).
      try {
        await _createNotificationChannel();
      } catch (e) {
        AppLogger.w('Tạo kênh thông báo thất bại trước khi hiển thị: $e');
      }

      final soundName = urgent
          ? 'notification_emergency'
          : 'notification_default';

      // Choose channel depending on whether we should play sound.
      final selectedChannelId = playSound ? _channelId : _silentChannelId;
      final selectedChannelName = playSound ? _channelName : _silentChannelName;
      final selectedChannelDesc = playSound ? _channelDesc : _silentChannelDesc;

      // Download and prepare image for notification
      String? bigPicturePath;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        AppLogger.d(
          '📷 [ShowNotification] Attempting to download image from: $imageUrl',
        );
        try {
          bigPicturePath = await _downloadAndSaveImage(
            imageUrl,
            eventId ?? 'event',
          );
          if (bigPicturePath != null) {
            AppLogger.i(
              '✅ [ShowNotification] Image downloaded successfully: $bigPicturePath',
            );
          } else {
            AppLogger.w('⚠️ [ShowNotification] Image download returned null');
          }
        } catch (e, st) {
          AppLogger.e(
            '❌ [ShowNotification] Failed to download notification image: $e',
            e,
            st,
          );
        }
      } else {
        AppLogger.d(
          '📷 [ShowNotification] No imageUrl provided (imageUrl=${imageUrl ?? "null"})',
        );
      }

      // Enhanced body with event details
      String enhancedBody = body;
      if (eventData != null) {
        final cameraId = eventData['camera_id'] as String?;
        final detectedAt = eventData['detected_at'] as String?;

        final parts = <String>[body];
        if (cameraId != null) {
          parts.add('Camera: $cameraId');
        }
        if (detectedAt != null) {
          try {
            final dt = DateTime.parse(detectedAt);
            parts.add(
              'Thời gian: ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
            );
          } catch (_) {}
        }
        enhancedBody = parts.join('\n');
      }

      final importanceValue = urgent ? Importance.max : Importance.high;
      final priorityValue = Priority.high;

      final androidDetails = AndroidNotificationDetails(
        selectedChannelId,
        selectedChannelName,
        channelDescription: selectedChannelDesc,
        importance: importanceValue,
        priority: priorityValue,
        sound: playSound
            ? RawResourceAndroidNotificationSound(soundName)
            : null,
        playSound: playSound,
        enableVibration: playSound,
        vibrationPattern: playSound
            ? Int64List.fromList([0, 500, 200, 500])
            : null,
        ledColor: playSound ? (urgent ? const Color(0xFFFF0000) : null) : null,
        ledOnMs: playSound ? (urgent ? 1000 : null) : null,
        ledOffMs: playSound ? (urgent ? 500 : null) : null,
        styleInformation: bigPicturePath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(bigPicturePath),
                contentTitle: title,
                summaryText: enhancedBody,
                htmlFormatContentTitle: true,
                htmlFormatSummaryText: true,
              )
            : null,
      );

      final iosDetails = DarwinNotificationDetails(
        sound: playSound ? '$soundName.mp3' : null,
        presentSound: playSound,
        presentAlert: true,
        presentBadge: true,
        attachments: bigPicturePath != null
            ? [DarwinNotificationAttachment(bigPicturePath)]
            : null,
      );

      AppLogger.i(
        '[NotificationManager] Calling _localNotifications.show() sound=$soundName playSound=$playSound urgent=$urgent imageUrl=$imageUrl',
      );

      String? payload;
      try {
        if (eventId != null && eventId.isNotEmpty) {
          payload = jsonEncode({'deeplink': 'detectcare://alert/$eventId'});
        }
      } catch (e) {
        AppLogger.w('Failed to build notification payload: $e');
      }

      await _localNotifications.show(
        _generateNotificationId(),
        title,
        enhancedBody,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
      AppLogger.i('[NotificationManager] _localNotifications.show() completed');

      AppLogger.d('Hoàn tất gọi .show() cho thông báo: title="$title"');

      // Haptic feedback cho thông báo khẩn cấp
      if (urgent) {
        await HapticFeedback.vibrate();
        await HapticFeedback.heavyImpact();
      }

      AppLogger.i('🔔 Thông báo đã hiển thị: $title');

      if (eventId != null && eventId.isNotEmpty) {
        _recentlyShownEvents[eventId] = DateTime.now();
      }
      // Emit an event so any UI (e.g. notifications list) can refresh
      try {
        _notificationStreamController.add(
          eventId != null && eventId.isNotEmpty ? {'event_id': eventId} : null,
        );
      } catch (e, st) {
        AppLogger.w('Failed to emit notification event: $e', e, st);
      }
    } catch (e) {
      AppLogger.e('❌ Lỗi hiển thị thông báo: $e', e);
    }
  }

  /// Download và lưu ảnh cho notification
  Future<String?> _downloadAndSaveImage(String url, String filename) async {
    try {
      AppLogger.d('📥 [Download] Starting download from: $url');

      // Validate URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        AppLogger.w('❌ [Download] Invalid URL scheme: $url');
        return null;
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        AppLogger.w('❌ [Download] Failed to parse URL: $url');
        return null;
      }

      AppLogger.d('🌐 [Download] Parsed URI: ${uri.toString()}');

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger.w('⏱️ [Download] Timeout after 10s');
              throw TimeoutException('Image download timeout');
            },
          );

      AppLogger.d('📡 [Download] Response status: ${response.statusCode}');
      AppLogger.d(
        '📦 [Download] Content length: ${response.contentLength ?? "unknown"} bytes',
      );
      AppLogger.d(
        '📋 [Download] Content type: ${response.headers['content-type'] ?? "unknown"}',
      );

      if (response.statusCode != 200) {
        AppLogger.w('❌ [Download] Failed with status ${response.statusCode}');
        return null;
      }

      if (response.bodyBytes.isEmpty) {
        AppLogger.w('❌ [Download] Response body is empty');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${directory.path}/notification_${filename}_$timestamp.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      final fileSize = await file.length();
      AppLogger.i('✅ [Download] Image saved to: $filePath ($fileSize bytes)');
      return filePath;
    } catch (e, st) {
      AppLogger.e(
        '❌ [Download] Error downloading notification image: $e',
        e,
        st,
      );
      return null;
    }
  }

  /// Xác định độ khẩn cấp của sự kiện
  bool _determineUrgency(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type'] as String?;
    final confidenceScore = eventData['confidence_score'] as num?;

    return eventType == 'FALL_DETECTION' ||
        (confidenceScore != null && confidenceScore > 0.85);
  }

  /// Extract image URL từ event data
  String? _extractImageUrl(Map<String, dynamic> eventData) {
    try {
      AppLogger.d(
        '🔍 [ExtractImage] Event data keys: ${eventData.keys.join(", ")}',
      );

      // Thử lấy từ snapshot_url trực tiếp
      final snapshotUrl = eventData['snapshot_url'] ?? eventData['snapshotUrl'];
      if (snapshotUrl != null && snapshotUrl.toString().isNotEmpty) {
        final url = snapshotUrl.toString();
        AppLogger.i('✅ [ExtractImage] Found snapshot_url: $url');
        return url;
      }

      // Thử lấy từ snapshots object
      final snapshots = eventData['snapshots'] ?? eventData['snapshot'];
      if (snapshots != null) {
        AppLogger.d(
          '🔍 [ExtractImage] Found snapshots field: ${snapshots.runtimeType}',
        );

        if (snapshots is String && snapshots.isNotEmpty) {
          AppLogger.i('✅ [ExtractImage] Found snapshots as string: $snapshots');
          return snapshots;
        }
        if (snapshots is Map) {
          AppLogger.d(
            '🔍 [ExtractImage] Snapshots map keys: ${snapshots.keys.join(", ")}',
          );
          final url = snapshots['cloud_url'] ?? snapshots['url'];
          if (url != null && url.toString().isNotEmpty) {
            final urlStr = url.toString();
            AppLogger.i('✅ [ExtractImage] Found URL in snapshots map: $urlStr');
            return urlStr;
          }
          // Thử lấy từ files array trong snapshots
          if (snapshots['files'] is List) {
            final files = snapshots['files'] as List;
            AppLogger.d(
              '🔍 [ExtractImage] Found files array with ${files.length} items',
            );
            if (files.isNotEmpty) {
              final first = files.first;
              if (first is Map) {
                final fileUrl = first['cloud_url'] ?? first['url'];
                if (fileUrl != null && fileUrl.toString().isNotEmpty) {
                  final urlStr = fileUrl.toString();
                  AppLogger.i(
                    '✅ [ExtractImage] Found URL in files[0]: $urlStr',
                  );
                  return urlStr;
                }
              }
            }
          }
        }
      }

      // Thử lấy từ image_urls array
      final imageUrls = eventData['image_urls'] ?? eventData['imageUrls'];
      if (imageUrls is List && imageUrls.isNotEmpty) {
        final url = imageUrls.first.toString();
        AppLogger.i('✅ [ExtractImage] Found image_urls[0]: $url');
        return url;
      }

      AppLogger.w('⚠️ [ExtractImage] No image URL found in event data');
    } catch (e, st) {
      AppLogger.e('❌ [ExtractImage] Error extracting image URL: $e', e, st);
    }
    return null;
  }

  /// Tạo nội dung thông báo từ dữ liệu sự kiện
  String _generateNotificationBody(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type'] as String? ?? 'UNKNOWN';
    return 'Đã phát hiện sự kiện: $eventType';
  }

  /// Lấy các sự kiện gần nhất từ database
  Future<void> _fetchLatestEvents() async {
    try {
      await _supabase
          .from('event_detections')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
    } catch (e) {
      AppLogger.e('❌ Lỗi lấy sự kiện gần nhất: $e', e);
    }
  }

  /// Đăng ký device token sau khi user xác thực
  /// Gọi method này sau khi login thành công
  Future<void> registerDeviceTokenAfterAuth() async {
    if (!_isFirebaseReady || _fcm == null) {
      AppLogger.w('⚠️ Firebase chưa sẵn sàng, không thể đăng ký device token');
      return;
    }

    try {
      final token = await _fcm?.getToken();
      if (token != null) {
        final userId = await AuthStorage.getUserId();
        final jwt = await AuthStorage.getAccessToken();

        if (userId != null && jwt != null) {
          AppLogger.i('📤 Đang đăng ký device token sau xác thực...');
          await PushService.registerDeviceToken();
          AppLogger.i('✅ Device token đã đăng ký thành công');
        } else {
          AppLogger.w(
            '⚠️ Không thể đăng ký device token - thiếu userId hoặc jwt',
          );
        }
      }
    } catch (e) {
      AppLogger.e('❌ Lỗi đăng ký device token sau xác thực: $e', e);
    }
  }

  /// Debug method để kiểm tra trạng thái FCM
  Future<void> debugFCMStatus() async {
    try {
      AppLogger.d('🔍 === FCM DEBUG INFO ===');

      // Kiểm tra Firebase ready
      AppLogger.d('Firebase ready: $_isFirebaseReady');

      // Kiểm tra FCM instance
      AppLogger.d('FCM instance: ${_fcm != null ? 'OK' : 'NULL'}');

      if (_fcm != null) {
        // Lấy token hiện tại
        final token = await _fcm!.getToken();
        AppLogger.d('Current FCM token: ${token?.substring(0, 20)}...');

        // Kiểm tra permission
        final settings = await _fcm!.getNotificationSettings();
        AppLogger.d('Notification permission: ${settings.authorizationStatus}');

        // Kiểm tra user auth status
        final userId = await AuthStorage.getUserId();
        final jwt = await AuthStorage.getAccessToken();
        AppLogger.d('User authenticated: ${userId != null && jwt != null}');
        AppLogger.d('User ID: $userId');
        AppLogger.d('JWT exists: ${jwt != null}');
      }

      AppLogger.d('=== END FCM DEBUG ===');
    } catch (e) {
      AppLogger.e('❌ FCM Debug error: $e', e);
    }
  }

  /// Xử lý khi app được mở do người dùng bấm vào thông báo (background/killed)
  Future<void> setupFcmTapHandler() async {
    // Khi app đang background, user bấm vào notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.i('📲 App opened from FCM tap (background)');
      if (message.data.isNotEmpty) {
        // If message contains a deeplink, process it
        final deeplink =
            message.data['deeplink'] ??
            message.data['link'] ??
            message.data['url'];
        if (deeplink != null && deeplink.toString().isNotEmpty) {
          try {
            DeepLinkHandler.processUri(Uri.parse(deeplink.toString()));
            return;
          } catch (e) {
            AppLogger.e('Invalid deeplink in FCM data: $e', e);
          }
        }

        final entry = AlertCoordinator.fromData(message.data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AlertCoordinator.handle(entry);
        });
      }
    });

    // Khi app bị kill, user bấm notif để mở
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) {
      AppLogger.i('📲 App opened from FCM tap (terminated)');
      final deeplink =
          initial.data['deeplink'] ??
          initial.data['link'] ??
          initial.data['url'];
      if (deeplink != null && deeplink.toString().isNotEmpty) {
        try {
          DeepLinkHandler.processUri(Uri.parse(deeplink.toString()));
          return;
        } catch (e) {
          AppLogger.e('Invalid deeplink in initial FCM data: $e', e);
        }
      }

      final entry = AlertCoordinator.fromData(initial.data);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AlertCoordinator.handle(entry);
      });
    }
  }

  /// Kiểm tra trạng thái khởi tảo
  ///
  bool get isInitialized => _isInitialized;

  /// Kiểm tra trạng thái Firebase
  bool get isFirebaseReady => _isFirebaseReady;

  /// Stream that emits when a new notification / alert arrives.
  /// Payload is the raw event map from Supabase/FCM when available, or null.
  Stream<Map<String, dynamic>?> get onNewNotification =>
      _notificationStreamController.stream;

  /// Dispose resources if needed (not strictly used in app lifecycle)
  void dispose() {
    try {
      _notificationStreamController.close();
    } catch (_) {}
  }
}

/// Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationManager = NotificationManager();
  await notificationManager.showNotification(
    title: message.notification?.title ?? 'Cảnh báo Mới',
    body: message.notification?.body ?? 'Đã phát hiện sự kiện y tế mới',
    urgent: message.data['urgent'] == 'true',
  );
}
