import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:detect_care_caregiver_app/services/notification_service.dart';
import 'package:flutter/foundation.dart';

typedef OnData = void Function(Map<String, dynamic> data);

class WsService {
  io.WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final OnData onData;
  final String url;
  final String? authToken;

  bool _manuallyDisconnected = false;
  int _reconnectAttempt = 0;

  WsService({required this.onData, required this.url, this.authToken});

  Future<void> connect() async {
    _manuallyDisconnected = false;

    try {
      debugPrint('[WS] Attempting to connect to: $url');
      final uri = Uri.parse(url);
      debugPrint(
        '[WS] Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, port: ${uri.port}',
      );

      // Kết nối IO WebSocket (Android emulator/desktop/mobile)
      final socket = await io.WebSocket.connect(
        url,
        headers: (authToken != null && authToken!.isNotEmpty)
            ? {'Authorization': 'Bearer $authToken'}
            : null,
      ).timeout(const Duration(seconds: 8));

      // Giữ kết nối tránh bị middlebox cắt
      socket.pingInterval = const Duration(seconds: 25);

      // Lưu lại socket để sử dụng
      _socket = socket;

      debugPrint('[WS] WebSocket handshake completed successfully');

      // Gửi thông điệp chào
      _safeSend({
        'type': 'connect',
        'client': kIsWeb ? 'flutter_web' : 'flutter_io',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Lắng nghe dữ liệu
      _subscription = _socket!.listen(
        (data) {
          debugPrint('[WS] Received raw data type: ${data.runtimeType}');
          debugPrint('[WS] Received data: $data');
          try {
            if (data is String) {
              debugPrint('[WS] Parsing JSON string data');
              final jsonData = json.decode(data);
              _handleIncomingData(Map<String, dynamic>.from(jsonData));
            } else if (data is Map) {
              debugPrint('[WS] Processing Map data directly');
              _handleIncomingData(Map<String, dynamic>.from(data));
            } else {
              debugPrint(
                '[WS] Unknown data type received: ${data.runtimeType}',
              );
            }
          } catch (e) {
            debugPrint('[WS] Error parsing message: $e');
            debugPrint('[WS] Error details: ${e.toString()}');
          }
        },
        onError: (error) {
          debugPrint('[WS] Connection error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          try {
            final cc = _socket?.closeCode;
            final cr = _socket?.closeReason;
            debugPrint('[WS] Connection closed. code=$cc, reason=$cr');
          } catch (_) {
            debugPrint('[WS] Connection closed.');
          }
          if (!_manuallyDisconnected) _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Heartbeat app-level (bổ sung bên cạnh TCP ping)
      _startHeartbeat();

      debugPrint('[WS] Connection established');
      _reconnectAttempt = 0;
    } catch (e) {
      debugPrint('[WS] Error creating connection: $e');
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _safeSend({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  void _safeSend(Map<String, dynamic> payload) {
    final sock = _socket;
    if (sock == null) return;
    try {
      sock.add(json.encode(payload));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  void _scheduleReconnect() {
    // _reconnectAttempt++;
    // final capped = _reconnectAttempt > 5 ? 5 : _reconnectAttempt;
    // // Exponential backoff: 2^capped seconds (1,2,4,8,16,32)
    // final delaySeconds = 1 << capped;
    // _reconnectTimer?.cancel();
    // debugPrint('[WS] scheduling reconnect in ${delaySeconds}s');
    // _reconnectTimer = Timer(Duration(seconds: delaySeconds.toInt()), () {
    //   if (!_manuallyDisconnected) {
    //     connect();
    //   }
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    _reconnectAttempt++;

    // Exponential backoff với trần + jitter
    final exp = 1 << (_reconnectAttempt.clamp(0, 6)); // 1,2,4,8,16,32,64
    final base = Duration(seconds: exp);
    final capped = base <= const Duration(seconds: 30)
        ? base
        : const Duration(seconds: 30);
    final jitterMs = math.Random().nextInt(1000);
    final delay = capped + Duration(milliseconds: jitterMs);

    debugPrint(
      '[WS] Scheduling reconnect in ${delay.inSeconds}s (attempt=$_reconnectAttempt)',
    );
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected) connect();
    });
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _socket?.close(1000);
    } catch (_) {}
    _socket = null;
    debugPrint('[WS] Disconnected by user.');
  }

  void dispose() => disconnect();

  void _handleIncomingData(Map<String, dynamic> data) {
    try {
      debugPrint('[WS] Processing data: $data');

      // Handle system messages (welcome, ping)
      final type = data['type']?.toString();
      if (type != null) {
        switch (type) {
          case 'welcome':
            debugPrint('[WS] Welcome message: ${data['message']}');
            return;
          case 'ping':
            // Respond with pong to keep connection alive
            _safeSend({
              'type': 'pong',
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            return;
          case 'test':
            debugPrint('[WS] Test message received');
            return;
        }
      }

      // Handle alert events
      final status = data['status']?.toString().toLowerCase();
      final eventType = data['event_type']?.toString();
      final imageUrl = data['image_url']?.toString();
      final eventId = data['event_id']?.toString();
      final detectedAt = data['detected_at'] as String?;

      if (status == null || eventType == null) {
        debugPrint('[WS] Skipping incomplete data');
        return;
      }

      debugPrint('[WS] Processing alert: status=$status, type=$eventType');

      // Handle all alert types
      if (['critical', 'warning'].contains(status)) {
        // Convert status and get readable description
        final appStatus = status == 'critical' ? 'danger' : status;
        final eventDesc = switch (eventType.toLowerCase()) {
          'fall' => 'Phát hiện ngã',
          'seizure' => 'Phát hiện co giật',
          'violence' => 'Phát hiện hành vi bạo lực',
          'unusual_behavior' => 'Phát hiện hành vi bất thường',
          _ => eventType,
        };

        final alertData = <String, dynamic>{
          'status': appStatus,
          'event_type': eventType,
          'event_id': eventId,
          'event_description': eventDesc,
          if (imageUrl != null) 'image_url': imageUrl,
          'detected_at': detectedAt ?? DateTime.now().toIso8601String(),
        };

        debugPrint('[WS] Sending alert to UI: $alertData');
        onData(alertData);

        // Show notification
        NotificationService.show(
          '${appStatus.toUpperCase()} Alert',
          eventDesc,
          urgent: appStatus == 'danger',
          severity: appStatus == 'danger' ? 'critical' : 'warning',
        );
      } else {
        //     debugPrint('[WS] Unknown payload type');
        //     return;
        //   }

        //   final status = (data['status'] as String? ?? '').toLowerCase();
        //   if (status != 'warning' && status != 'danger') {
        //     debugPrint('[WS] Ignored non-warning/danger event: $status');
        //     return;
        //   }

        //   final severity = status == 'danger' ? 'critical' : 'warning';
        //   onData(data);

        //   NotificationService.show(
        //     '${status.toUpperCase()} Alert',
        //     data['action']?.toString() ?? 'No detail',
        //     urgent: status == 'danger',
        //     severity: severity,
        //   );
        // } catch (e) {
        //   debugPrint('[WS] error handling incoming: $e');
        debugPrint('[WS] Ignored event with status: $status');
      }
    } catch (e, stackTrace) {
      debugPrint('[WS] Error handling incoming data: $e');
      debugPrint('[WS] Stack trace: $stackTrace');
    }
  }
}
