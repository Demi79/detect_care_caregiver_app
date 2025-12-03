import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';

class CameraEntry {
  final String id;
  final String name;
  final String url;
  final String? thumb;
  final bool isOnline;

  const CameraEntry({
    required this.id,
    required this.name,
    required this.url,
    this.thumb,
    this.isOnline = true,
  });

  CameraEntry copyWith({
    String? id,
    String? name,
    String? url,
    String? thumb,
    bool? isOnline,
  }) {
    return CameraEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      thumb: thumb ?? this.thumb,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() => {
    'camera_id': id,
    'camera_name': name,
    'rtsp_url': url,
    'thumb': thumb,
    'is_online': isOnline,
  };

  factory CameraEntry.fromJson(Map<String, dynamic> j) {
    // Ưu tiên sử dụng trường 'url' nếu có, nếu không thì xây dựng từ các thành phần
    String finalUrl = j['url']?.toString() ?? '';

    debugPrint('🔍 [CameraEntry] Parsing camera data:');
    debugPrint('  camera_id: ${j['camera_id']}');
    debugPrint('  rtsp_url: ${j['rtsp_url']}');
    debugPrint('  username: ${j['username']}');
    debugPrint('  password: ${j['password'] != null ? "***" : "null"}');

    // Nếu không có url, xây dựng từ rtsp_url + username/password
    if (finalUrl.isEmpty) {
      final rtspUrl = j['rtsp_url']?.toString() ?? '';
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
}
