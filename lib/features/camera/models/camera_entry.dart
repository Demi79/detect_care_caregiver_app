import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';

class CameraEntry {
  final String id;
  final String name;
  final String url;
  final String? thumb;
  final bool isOnline;

  /// Thông tin bổ sung từ API
  final String? userId;
  final String? cameraType;
  final String? ipAddress;
  final int? port;
  final String? rtspUrl;
  final String? hlsUrl;
  final String? webrtcUrl;
  final String? username;
  final String? password;
  final String? locationInRoom;
  final String? resolution;
  final int? fps;
  final String? status;
  final DateTime? lastPing;
  final DateTime? lastHeartbeatAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CameraEntry({
    required this.id,
    required this.name,
    required this.url,
    this.thumb,
    this.isOnline = true,
    this.userId,
    this.cameraType,
    this.ipAddress,
    this.port,
    this.rtspUrl,
    this.hlsUrl,
    this.webrtcUrl,
    this.username,
    this.password,
    this.locationInRoom,
    this.resolution,
    this.fps,
    this.status,
    this.lastPing,
    this.lastHeartbeatAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Alias for clarity: prefer `cameraId` where code may otherwise confuse with
  /// other `id` fields (eventId, timelineEntryId, snapshotId).
  String get cameraId => id;

  CameraEntry copyWith({
    String? id,
    String? name,
    String? url,
    String? thumb,
    bool? isOnline,
    String? userId,
    String? cameraType,
    String? ipAddress,
    int? port,
    String? rtspUrl,
    String? hlsUrl,
    String? webrtcUrl,
    String? username,
    String? password,
    String? locationInRoom,
    String? resolution,
    int? fps,
    String? status,
    DateTime? lastPing,
    DateTime? lastHeartbeatAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CameraEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      thumb: thumb ?? this.thumb,
      isOnline: isOnline ?? this.isOnline,
      userId: userId ?? this.userId,
      cameraType: cameraType ?? this.cameraType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      webrtcUrl: webrtcUrl ?? this.webrtcUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      locationInRoom: locationInRoom ?? this.locationInRoom,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      status: status ?? this.status,
      lastPing: lastPing ?? this.lastPing,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'camera_id': id,
    'camera_name': name,
    'url': url,
    'rtsp_url': rtspUrl ?? url,
    'thumb': thumb,
    'is_online': isOnline,
    'user_id': userId,
    'camera_type': cameraType,
    'ip_address': ipAddress,
    'port': port,
    'hls_url': hlsUrl,
    'webrtc_url': webrtcUrl,
    'username': username,
    'password': password,
    'location_in_room': locationInRoom,
    'resolution': resolution,
    'fps': fps,
    'status': status,
    'last_ping': lastPing?.toIso8601String(),
    'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory CameraEntry.fromJson(Map<String, dynamic> j) {
    // Ưu tiên sử dụng trường 'url' nếu có, nếu không thì xây dựng từ các thành phần
    String finalUrl = j['url']?.toString() ?? '';

    debugPrint('🔍 [CameraEntry] Parsing camera data:');
    debugPrint('  camera_id: ${j['camera_id']}');
    debugPrint('  rtsp_url: ${j['rtsp_url']}');
    debugPrint('  hls_url: ${j['hls_url']}');
    debugPrint('  username: ${j['username']}');
    debugPrint('  password: ${j['password'] != null ? "***" : "null"}');

    final rtspUrlRaw = j['rtsp_url']?.toString();
    // Nếu không có url, xây dựng từ rtsp_url + username/password
    if (finalUrl.isEmpty) {
      final rtspUrl = rtspUrlRaw ?? '';
      final username = j['username']?.toString();
      final password = j['password']?.toString();

      debugPrint('  Building URL from components...');

      if (rtspUrl.isNotEmpty) {
        if (username != null && username.isNotEmpty) {
          try {
            final uri = Uri.parse(rtspUrl);
            final userInfo = password != null && password.isNotEmpty
                ? '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}'
                : Uri.encodeComponent(username);

            // Xây dựng URL với authentication
            final port = uri.hasPort && uri.port != 0 ? ':${uri.port}' : '';
            finalUrl = '${uri.scheme}://$userInfo@${uri.host}$port${uri.path}';
            if (uri.query.isNotEmpty) {
              finalUrl += '?${uri.query}';
            }
            debugPrint('  ✅ Built authenticated URL: $finalUrl');
          } catch (e) {
            // Nếu parse lỗi, giữ nguyên rtsp_url
            finalUrl = rtspUrl;
            debugPrint('  ⚠️ Parse error, using original: $finalUrl');
          }
        } else {
          // Không có username, dùng rtsp_url gốc
          finalUrl = rtspUrl;
          debugPrint('  📝 No auth, using original URL: $finalUrl');
        }
      }
    } else {
      debugPrint('  📋 Using existing URL field: $finalUrl');
    }

    return CameraEntry(
      id: j['camera_id']?.toString() ?? '',
      name: j['camera_name']?.toString() ?? 'Camera',
      url: finalUrl,
      thumb: _normalizeThumb(_extractThumb(j)),
      isOnline: j['is_online'] is bool
          ? j['is_online']
          : (j['is_online']?.toString() == 'true'),
      userId: j['user_id']?.toString(),
      cameraType: j['camera_type']?.toString(),
      ipAddress: j['ip_address']?.toString(),
      port: _parseInt(j['port']),
      rtspUrl: rtspUrlRaw,
      hlsUrl: j['hls_url']?.toString(),
      webrtcUrl: j['webrtc_url']?.toString(),
      username: j['username']?.toString(),
      password: j['password']?.toString(),
      locationInRoom: j['location_in_room']?.toString(),
      resolution: j['resolution']?.toString(),
      fps: _parseInt(j['fps']),
      status: j['status']?.toString(),
      lastPing: _parseDate(j['last_ping']),
      lastHeartbeatAt: _parseDate(j['last_heartbeat_at']),
      createdAt: _parseDate(j['created_at']),
      updatedAt: _parseDate(j['updated_at']),
    );
  }

  static String? _extractThumb(Map<String, dynamic> json) {
    const keys = [
      'thumb',
      'thumbnail',
      'thumbnail_url',
      'thumbnailUrl',
      'snapshot',
      'snapshot_url',
      'snapshotUrl',
      'preview',
      'preview_url',
      'previewUrl',
    ];
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return null;
  }

  static String? _normalizeThumb(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    final value = raw.trim();
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image')) {
      return value;
    }
    if (value.startsWith('//')) {
      final scheme = Uri.tryParse(AppConfig.apiBaseUrl)?.scheme;
      final normalizedScheme = (scheme != null && scheme.isNotEmpty)
          ? scheme
          : 'https';
      return '$normalizedScheme:$value';
    }
    final base = AppConfig.apiBaseUrl;
    if (base.isEmpty) return value;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = value.startsWith('/') ? value : '/$value';
    return '$normalizedBase$normalizedPath';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
