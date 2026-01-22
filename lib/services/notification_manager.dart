import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:detect_care_caregiver_app/core/alerts/alert_coordinator.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart' as be;
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
  RealtimeChannel? _notificationsChannel;

  // State management
  bool _isFirebaseReady = false;
  bool _isInitialized = false;

  // Notification ID counter để tránh duplicate
  static int _notificationIdCounter = 1000;
  // Recently shown notifications (dedupeKey -> shownAt) to avoid dupes
  final Map<String, DateTime> _recentlyShownEvents = {};
  final Map<String, String> _lastConfirmationStates = {};
  final Map<String, String> _lastLifecycleStates = {};
  final Map<String, DateTime> _fcmPendingShown = {};

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
  static const Duration _fcmRealtimeSuppressWindow = Duration(seconds: 30);
  static const Map<String, String> _notificationTitles = {
    // System notifications
    'fall_detection': '🚨 Phát hiện ngã',
    'abnormal_behavior': '⚠️ Hành vi bất thường',
    'emergency': '🆘 Khẩn cấp',
    'inactivity': '😴 Không có hoạt động',
    'intrusion': '🚪 Phát hiện người lạ',
    'medication_reminder': '💊 Nhắc uống thuốc',
    'system_maintenance': '🔧 Bảo trì hệ thống',
    'device_offline': '📵 Thiết bị offline',
    'quota_exceeded': '📊 Vượt quá hạn mức',
    'subscription_expiry': '⏰ Gia hạn đăng ký',
    'payment_success': '✅ Thanh toán thành công',
    'payment_failed': '❌ Thanh toán thất bại',
    'invoice_generated': '🧾 Hóa đơn mới',
    'health_check_reminder': '🏥 Nhắc kiểm tra sức khỏe',
    'caregiver_shift': '👨‍⚕️ Ca làm việc',
    'emergency_drill': '🚨 Diễn tập khẩn cấp',
    'appointment_reminder': '📅 Nhắc lịch hẹn',
    // User notifications
    'actor_message_help': '🆘 Yêu cầu trợ giúp',
    'actor_message_reminder': '⏰ Nhắc nhở',
    'actor_message_report': '📝 Báo cáo',
    'actor_message_confirm': '✅ Xác nhận',
    'caregiver_invitation_sent': '📨 Lời mời chăm sóc',
    'caregiver_invitation_accepted': '✅ Chấp nhận lời mời',
    'caregiver_invitation_rejected': '❌ Từ chối lời mời',
    'caregiver_unassigned': '🔓 Hủy phân công',
    'permission_request': '🔐 Yêu cầu quyền truy cập',
    'permission_granted': '✅ Cấp quyền truy cập',
    'permission_revoked': '🔒 Thu hồi quyền truy cập',
    'permission_updated': '🔄 Cập nhật quyền truy cập',
    'event_update_requested': '📝 Yêu cầu cập nhật sự kiện',
    'event_update_approved': '✅ Phê duyệt cập nhật',
    'event_update_rejected': '❌ Từ chối cập nhật',
  };

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
      oneOff.onPostgresChanges(
        event: PostgresChangeEvent.update,
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
            AppLogger.d('Realtime oneOff update callback error: $e', e, st);
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

              // Only show caregiver proposal notifications when confirmation_state
              // explicitly indicates a caregiver update.
              final eventId = (newRow['event_id'] ?? newRow['id'])?.toString();
              final eventData = Map<String, dynamic>.from(newRow);
              eventData['ui_type'] = _resolveUiType(eventData);
              final confirmation = (newRow['confirmation_state'] ?? '')
                  .toString();
              final proposed = newRow['proposed_status'];
              final proposedBy = (newRow['proposed_by'] ?? '').toString();
              final newState = confirmation.toUpperCase();

              final oldRow = payload.oldRecord;
              final oldState = (oldRow['confirmation_state'] ?? '')
                  .toString()
                  .toUpperCase();

              final isCaregiverUpdated = newState == 'CAREGIVER_UPDATED';
              final previousState = oldState.isNotEmpty
                  ? oldState
                  : (eventId != null && eventId.isNotEmpty
                        ? _lastConfirmationStates[eventId] ?? ''
                        : '');
              final isNewCaregiverState =
                  isCaregiverUpdated &&
                  previousState.isNotEmpty &&
                  previousState != 'CAREGIVER_UPDATED';

              final lifecycle = _readStringKey(newRow, const [
                'lifecycle_state',
                'lifecycleState',
              ]);
              final oldLifecycle = _readStringKey(oldRow, const [
                'lifecycle_state',
                'lifecycleState',
              ]);
              final shouldSuppress = _shouldSuppressRealtimeNotification(
                eventData,
              );
              if (shouldSuppress) {
                if (eventId != null && eventId.isNotEmpty) {
                  if (newState.isNotEmpty) {
                    _lastConfirmationStates[eventId] = newState;
                  }
                  if (lifecycle != null && lifecycle.isNotEmpty) {
                    _lastLifecycleStates[eventId] = lifecycle;
                  }
                }
                return;
              }

              if (isCaregiverUpdated &&
                  proposedBy.isNotEmpty &&
                  isNewCaregiverState) {
                AppLogger.i(
                  '🔔 Detected proposal update for event ${newRow['event_id']}',
                );
                final title = _resolveNotificationTitle(
                  eventData,
                  fallback: '📬 Thông báo mới',
                );
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
                  eventData: eventData,
                );
              }
              if (eventId != null &&
                  eventId.isNotEmpty &&
                  newState.isNotEmpty) {
                _lastConfirmationStates[eventId] = newState;
              }

              final lifecycleTransition = _resolveLifecycleTransition(
                eventId,
                lifecycle,
                oldLifecycle,
              );
              if (lifecycleTransition != null) {
                final transitionLabel = lifecycleTransition.isNotEmpty
                    ? be.BackendEnums.lifecycleStateToVietnamese(
                        lifecycleTransition,
                      )
                    : '';
                final title = _resolveNotificationTitle(
                  eventData,
                  fallback: '📬 Thông báo mới',
                );
                final body = transitionLabel.isNotEmpty
                    ? 'Cập nhật trạng thái: $transitionLabel'
                    : 'Cập nhật trạng thái sự kiện';
                await showNotification(
                  title: title,
                  body: body,
                  urgent: _isUrgentLifecycle(lifecycleTransition),
                  playSound: false,
                  eventId: eventId,
                  eventData: eventData,
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

  /// Subscribe to notifications table for a specific user.
  void subscribeToNotifications(String userId) {
    if (userId.isEmpty) return;

    try {
      if (_notificationsChannel != null) {
        _supabase.removeChannel(_notificationsChannel!);
      }

      AppLogger.i('🔔 Subscribing to notifications for user $userId');
      _notificationsChannel = _supabase.channel('user_notifications_$userId');
      _notificationsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) {
              AppLogger.i('🔔 Realtime notification received (INSERT)');
              AppEvents.instance.notifyNotificationReceived();
            },
          )
          .subscribe();
    } catch (e) {
      AppLogger.e('Error subscribing to notifications: $e', e);
    }
  }

  void unsubscribeFromNotifications() {
    try {
      if (_notificationsChannel != null) {
        _supabase.removeChannel(_notificationsChannel!);
        _notificationsChannel = null;
      }
    } catch (e) {
      AppLogger.e('Error unsubscribing from notifications: $e', e);
    }
  }

  /// Xử lý sự kiện foreground từ Supabase
  Future<void> _handleForegroundEvent(PostgresChangePayload payload) async {
    AppLogger.d('\n🔔 Đang xử lý thông báo foreground');

    final eventData = payload.newRecord;
    final eventId = (eventData['event_id'] ?? eventData['id'])?.toString();
    final lifecycle = _readStringKey(eventData, const [
      'lifecycle_state',
      'lifecycleState',
    ]);
    if (eventId != null && eventId.isNotEmpty && lifecycle != null) {
      _lastLifecycleStates[eventId] = lifecycle;
    }
    if (_shouldSuppressRealtimeNotification(eventData)) {
      return;
    }
    final isUrgent = _determineUrgency(eventData);
    final title = _resolveNotificationTitle(
      eventData,
      fallback: '📬 Thông báo mới',
    );

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
      title: title,
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
    if (_isCanceledLifecycle(data)) {
      AppLogger.i('🔕 Foreground FCM skipped: lifecycle canceled in payload');
      return;
    }
    if (_shouldSkipByStatus(data)) {
      AppLogger.i('🔕 Foreground FCM skipped: status not danger/warning');
      return;
    }
    final currentUserId = await AuthStorage.getUserId();
    if (_isCreatedByCurrentUser(data, currentUserId)) {
      AppLogger.i('🔕 Foreground FCM skipped: created by current user');
      return;
    }
    _markFcmPending(data);

    final entry = AlertCoordinator.fromData(data);
    AlertCoordinator.handle(entry);
    await _scheduleForegroundFcmDisplay(message);
  }

  String _foregroundDelayKey(RemoteMessage message) {
    final data = message.data;
    final eventId = (data['event_id'] ?? data['id'] ?? data['eventId'])
        ?.toString();
    if (eventId != null && eventId.isNotEmpty) return eventId;
    final msgId = message.messageId;
    if (msgId != null && msgId.isNotEmpty) return msgId;
    return data.hashCode.toString();
  }

  Future<void> _scheduleForegroundFcmDisplay(RemoteMessage message) async {
    final key = _foregroundDelayKey(message);
    AppLogger.i('⏩ Showing foreground FCM immediately for $key');
    await _processForegroundMessage(message);
  }

  Future<void> _processForegroundMessage(RemoteMessage message) async {
    final data = message.data;

    final eventId = (data['event_id'] ?? data['id'] ?? data['eventId'])
        ?.toString();
    if (_isCanceledLifecycle(data)) {
      AppLogger.i('🔕 Foreground FCM skipped: event canceled in payload');
      return;
    }
    if (_shouldSkipByStatus(data)) {
      AppLogger.i('🔕 Foreground FCM skipped: status not danger/warning');
      return;
    }
    final currentUserId = await AuthStorage.getUserId();
    if (_isCreatedByCurrentUser(data, currentUserId)) {
      AppLogger.i('🔕 Foreground FCM skipped: created by current user');
      return;
    }
    if (eventId != null && eventId.isNotEmpty) {
      try {
        final svc = EventService.withDefaultClient();
        final latest = await svc.fetchLogDetail(eventId);
        final latestLifecycle = (latest.lifecycleState ?? '')
            .toString()
            .toUpperCase();
        if (latestLifecycle == 'CANCELED' || latestLifecycle == 'CANCELLED') {
          AppLogger.i(
            '🔕 Foreground FCM skipped: event $eventId canceled on server',
          );
          return;
        }
        final latestStatus = latest.status.toString();
        if (latestStatus.isNotEmpty && !_isAbnormalStatus(latestStatus)) {
          AppLogger.i(
            '🔕 Foreground FCM skipped: event $eventId status=$latestStatus',
          );
          return;
        }
        final latestMap = latest.toMapString();
        final latestCreatedBy = _readStringKey(latestMap, const [
          'created_by',
          'createdBy',
        ]);
        if (latestCreatedBy != null &&
            latestCreatedBy.isNotEmpty &&
            currentUserId != null &&
            currentUserId.isNotEmpty &&
            latestCreatedBy == currentUserId) {
          AppLogger.i(
            '🔕 Foreground FCM skipped: event $eventId created by current user',
          );
          return;
        }
      } catch (e) {
        AppLogger.w('⚠️ Foreground FCM cancel check failed: $e');
      }
    }
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
          _markFcmPending(realtimeRow);
          final imageUrl = _extractImageUrl(realtimeRow);
          final title = _resolveNotificationTitle(
            realtimeRow,
            fallback: message.notification?.title ?? '📬 Thông báo mới',
          );
          await showNotification(
            title: title,
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
        _markFcmPending(eventMap);
        final imageUrl = found.imageUrls.isNotEmpty
            ? found.imageUrls.first
            : null;
        final title = _resolveNotificationTitle(
          eventMap,
          fallback: message.notification?.title ?? '📬 Thông báo mới',
        );
        await showNotification(
          title: title,
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
    final fallbackTitle = _resolveNotificationTitle(
      data,
      fallback: message.notification?.title ?? '📬 Thông báo mới',
    );
    await showNotification(
      title: fallbackTitle,
      body: message.notification?.body ?? 'Đã phát hiện sự kiện y tế',
      urgent: urgent,
      playSound: false,
      eventId: eventId,
      eventData: data,
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
      if (_isNormalActivityEvent(eventData)) {
        AppLogger.i('🔕 Skip notification for normal_activity event');
        return;
      }
      if (_shouldSkipByStatus(eventData)) {
        AppLogger.i('🔕 Skip notification for non-abnormal status event');
        return;
      }
      final currentUserId = await AuthStorage.getUserId();
      if (_isCreatedByCurrentUser(eventData ?? const {}, currentUserId)) {
        AppLogger.i('🔕 Skip notification for self-created event');
        return;
      }
      AppLogger.i(
        '[NotificationManager] showNotification called title="$title" urgent=$urgent playSound=$playSound',
      );
      AppLogger.d('[NotificationManager] call stack:\n${StackTrace.current}');
      // Deduplicate notifications for the same business/ui/target within 2 minutes
      final dedupeKey = _buildDedupeKey(eventData: eventData, eventId: eventId);
      if (dedupeKey != null && dedupeKey.isNotEmpty) {
        final now = DateTime.now();
        _recentlyShownEvents.removeWhere(
          (k, v) => now.difference(v).inMinutes >= 2,
        );
        if (_recentlyShownEvents.containsKey(dedupeKey)) {
          AppLogger.i('🔇 Skipping duplicate notification for $dedupeKey');
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

      int notificationId;
      if (eventId != null && eventId.isNotEmpty) {
        notificationId = eventId.hashCode & 0x7FFFFFFF;
      } else {
        notificationId = _generateNotificationId();
      }

      await _localNotifications.show(
        notificationId,
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

      if (dedupeKey != null && dedupeKey.isNotEmpty) {
        _recentlyShownEvents[dedupeKey] = DateTime.now();
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

  String _resolveNotificationTitle(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final uiType = _resolveUiType(data);
    if (uiType == null) return fallback;
    return _notificationTitles[uiType.toLowerCase()] ?? fallback;
  }

  String? _resolveUiType(Map<String, dynamic> data) {
    final direct = _readStringKey(data, const ['ui_type', 'uiType']);
    if (direct != null && direct.isNotEmpty) return direct;
    final meta = data['metadata'];
    if (meta is Map<String, dynamic>) {
      final metaUiType = _readStringKey(meta, const ['ui_type', 'uiType']);
      if (metaUiType != null && metaUiType.isNotEmpty) return metaUiType;
    }
    return _fallbackUiTypeFromEvent(data);
  }

  String? _fallbackUiTypeFromEvent(Map<String, dynamic> data) {
    final confirmation = _readStringKey(data, const [
      'confirmation_state',
      'confirmationState',
    ]);
    if (confirmation?.toUpperCase() == 'CAREGIVER_UPDATED') {
      return 'event_update_requested';
    }

    final eventType = _readStringKey(data, const ['event_type', 'eventType']);
    final status = _readStringKey(data, const ['status']);
    final lifecycle = _readStringKey(data, const [
      'lifecycle_state',
      'lifecycleState',
    ]);

    final normalizedType = eventType?.toLowerCase() ?? '';
    if (normalizedType.contains('fall')) return 'fall_detection';
    if (normalizedType.contains('abnormal')) return 'abnormal_behavior';
    if (normalizedType.contains('inactivity')) return 'inactivity';
    if (normalizedType.contains('intrusion') ||
        normalizedType.contains('visitor')) {
      return 'intrusion';
    }
    if (normalizedType.contains('emergency') ||
        normalizedType.contains('sos')) {
      return 'emergency';
    }

    final normalizedStatus = status?.toLowerCase() ?? '';
    if (normalizedStatus == 'danger' ||
        normalizedStatus == 'critical' ||
        normalizedStatus == 'emergency') {
      return 'emergency';
    }

    final normalizedLifecycle = lifecycle?.toLowerCase() ?? '';
    if (normalizedLifecycle.contains('alarm') ||
        normalizedLifecycle.contains('autocall') ||
        normalizedLifecycle.contains('emergency')) {
      return 'emergency';
    }

    return null;
  }

  String? _readStringKey(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _buildDedupeKey({Map<String, dynamic>? eventData, String? eventId}) {
    final data = eventData ?? const <String, dynamic>{};
    final businessType = _normalizeBusinessType(data);
    final uiType = _resolveUiType(data) ?? 'unknown';
    final targetId =
        _readStringKey(data, const [
          'target_id',
          'targetId',
          'event_id',
          'eventId',
          'id',
        ]) ??
        eventId ??
        '';
    if (targetId.isEmpty) return null;
    return '$businessType:$uiType:$targetId';
  }

  void _markFcmPending(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    if (data['ui_type'] == null && data['uiType'] == null) {
      final uiType = _resolveUiType(data);
      if (uiType != null) {
        data['ui_type'] = uiType;
      }
    }
    if (data['business_type'] == null && data['businessType'] == null) {
      data['business_type'] = _normalizeBusinessType(data);
    }
    final eventId = _readStringKey(data, const ['event_id', 'eventId', 'id']);
    final dedupeKey = _buildDedupeKey(eventData: data, eventId: eventId);
    if (dedupeKey == null || dedupeKey.isEmpty) return;
    _cleanupFcmPending();
    _fcmPendingShown[dedupeKey] = DateTime.now();
  }

  bool _shouldSuppressRealtimeNotification(Map<String, dynamic> eventData) {
    if (eventData.isEmpty) return false;
    _cleanupFcmPending();
    final eventId = _readStringKey(eventData, const [
      'event_id',
      'eventId',
      'id',
    ]);
    final dedupeKey = _buildDedupeKey(eventData: eventData, eventId: eventId);
    if (dedupeKey == null || dedupeKey.isEmpty) return false;
    final last = _fcmPendingShown[dedupeKey];
    if (last == null) return false;
    return DateTime.now().difference(last) <= _fcmRealtimeSuppressWindow;
  }

  bool _isNormalActivityEvent(Map<String, dynamic>? eventData) {
    if (eventData == null || eventData.isEmpty) return false;
    final eventType = _readStringKey(eventData, const [
      'event_type',
      'eventType',
    ]);
    return _isNormalActivityType(eventType);
  }

  bool _shouldSkipByStatus(Map<String, dynamic>? eventData) {
    if (eventData == null || eventData.isEmpty) return false;
    final hasEventMarker =
        _readStringKey(eventData, const ['event_id', 'eventId', 'id']) !=
            null ||
        _readStringKey(eventData, const ['event_type', 'eventType']) != null;
    if (!hasEventMarker) return false;
    final status = _readStringKey(eventData, const ['status', 'severity']);
    if (status == null || status.isEmpty) return true;
    return !_isAbnormalStatus(status);
  }

  bool _isAbnormalStatus(String? raw) {
    if (raw == null) return false;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t == 'danger' || t == 'warning';
  }

  bool _isCanceledLifecycle(Map<String, dynamic> data) {
    final lifecycle = _readStringKey(data, const [
      'lifecycle_state',
      'lifecycleState',
      'lifecycle',
    ]);
    final normalized = lifecycle?.toUpperCase();
    return normalized == 'CANCELED' || normalized == 'CANCELLED';
  }

  bool _isCreatedByCurrentUser(
    Map<String, dynamic> data,
    String? currentUserId,
  ) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    final createdBy = _readStringKey(data, const ['created_by', 'createdBy']);
    if (createdBy == null || createdBy.isEmpty) return false;
    return createdBy == currentUserId;
  }

  bool _isNormalActivityType(String? raw) {
    if (raw == null) return false;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t == 'normal_activity' ||
        t == 'normal activity' ||
        t == 'normal-activity';
  }

  void _cleanupFcmPending() {
    final now = DateTime.now();
    _fcmPendingShown.removeWhere(
      (key, value) => now.difference(value) > _fcmRealtimeSuppressWindow,
    );
  }

  String? _resolveLifecycleTransition(
    String? eventId,
    String? newLifecycle,
    String? oldLifecycle,
  ) {
    final trimmedNew = newLifecycle?.trim() ?? '';
    if (trimmedNew.isEmpty) return null;
    final trimmedOld = oldLifecycle?.trim() ?? '';
    String? previous = trimmedOld.isNotEmpty ? trimmedOld : null;
    if (previous == null &&
        eventId != null &&
        eventId.isNotEmpty &&
        _lastLifecycleStates.containsKey(eventId)) {
      previous = _lastLifecycleStates[eventId];
    }
    if (previous == null || previous.isEmpty) {
      if (eventId != null && eventId.isNotEmpty) {
        _lastLifecycleStates[eventId] = trimmedNew;
      }
      return null;
    }
    if (previous == trimmedNew) {
      if (eventId != null && eventId.isNotEmpty) {
        _lastLifecycleStates[eventId] = trimmedNew;
      }
      return null;
    }
    if (eventId != null && eventId.isNotEmpty) {
      _lastLifecycleStates[eventId] = trimmedNew;
    }
    return trimmedNew;
  }

  bool _isUrgentLifecycle(String? lifecycle) {
    final value = lifecycle?.toLowerCase() ?? '';
    if (value.isEmpty) return false;
    return value.contains('alarm') ||
        value.contains('autocall') ||
        value.contains('emergency') ||
        value.contains('sos');
  }

  String _normalizeBusinessType(Map<String, dynamic> data) {
    final raw = _readStringKey(data, const ['business_type', 'businessType']);
    if (raw != null && raw.isNotEmpty) return raw.toLowerCase();
    return _looksLikeEvent(data) ? 'event_alert' : 'system_update';
  }

  bool _looksLikeEvent(Map<String, dynamic> data) {
    final targetType = _readStringKey(data, const [
      'target_type',
      'targetType',
    ]);
    if (targetType != null && targetType.toLowerCase() == 'event') return true;
    return _readStringKey(data, const [
          'event_id',
          'eventId',
          'event_type',
          'eventType',
        ]) !=
        null;
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
    final eventTypeRaw = _readStringKey(eventData, const [
      'event_type',
      'eventType',
    ]);
    if (eventTypeRaw == null || eventTypeRaw.isEmpty) {
      return 'Đã phát hiện sự kiện';
    }
    final eventTypeVi = be.BackendEnums.eventTypeToVietnamese(eventTypeRaw);
    return 'Đã phát hiện sự kiện: $eventTypeVi';
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

  try {
    final deeplink =
        message.data['deeplink'] ?? message.data['link'] ?? message.data['url'];
    if (deeplink != null && deeplink.toString().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_deeplink', deeplink.toString());
    }
  } catch (_) {}
}
