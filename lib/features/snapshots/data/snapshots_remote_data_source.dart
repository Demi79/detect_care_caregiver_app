import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class Snapshot {
  final String snapshotId;
  final String? cloudUrl;
  final String? imagePath;

  Snapshot({required this.snapshotId, this.cloudUrl, this.imagePath});

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
    snapshotId: (j['snapshot_id'] ?? j['id'] ?? '').toString(),
    cloudUrl: (j['cloud_url'] ?? j['url'])?.toString(),
    imagePath: (j['image_path'] ?? j['path'])?.toString(),
  );
}

class SnapshotsRemoteDataSource {
  final ApiClient _api;
  SnapshotsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<Snapshot> getById(String id) async {
    final res = await _api.get('/snapshots/$id');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch snapshot failed: ${res.statusCode} ${res.body}');
    }
    return Snapshot.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }

  Future<List<Snapshot>> getManyByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final unique = ids.toSet().toList();

    final res = await _api.get('/snapshots', query: {'ids': unique.join(',')});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = json.decode(res.body);
      final List list = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List)
          ? decoded['data'] as List
          : <dynamic>[];
      return list
          .cast<Map>()
          .map((e) => Snapshot.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final out = <Snapshot>[];
    for (final id in unique) {
      final one = await getById(id);
      out.add(one);
    }
    return out;
  }
}
