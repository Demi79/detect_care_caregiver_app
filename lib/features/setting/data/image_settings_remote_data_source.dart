import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageSetting {
  final String id;
  final String key;
  final String? value;
  final bool isEnabled;

  ImageSetting({
    required this.id,
    required this.key,
    required this.value,
    required this.isEnabled,
  });

  factory ImageSetting.fromJson(Map<String, dynamic> json) {
    return ImageSetting(
      id: json['id'],
      key: json['key'],
      value: json['value'],
      isEnabled: json['is_enabled'],
    );
  }
}

class ImageSettingsRemoteDataSource {
  final String baseUrl;

  ImageSettingsRemoteDataSource(this.baseUrl);

  Future<List<ImageSetting>> fetchSettings() async {
    final res = await http.get(Uri.parse('$baseUrl/image-settings'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ImageSetting.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load settings');
    }
  }

  Future<void> updateSetting(String key, String value) async {
    final res = await http.put(
      Uri.parse('$baseUrl/image-settings/$key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"value": value}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update $key');
    }
  }

  Future<void> toggleSetting(String key, bool enabled) async {
    final res = await http.put(
      Uri.parse('$baseUrl/image-settings/$key/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"enabled": enabled}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to toggle $key');
    }
  }
}
