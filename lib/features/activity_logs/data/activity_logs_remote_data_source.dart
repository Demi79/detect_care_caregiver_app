import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/activity_logs/data/activity_log_endpoints.dart';
import 'package:detect_care_caregiver_app/features/activity_logs/models/activity_log.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class ActivityLogsRemoteDataSource {
  final ApiClient _api;
  final ActivityLogEndpoints _ep;

  ActivityLogsRemoteDataSource({
    ApiClient? api,
    ActivityLogEndpoints? endpoints,
  }) : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken),
       _ep =
           endpoints ??
           ActivityLogEndpoints(
             ApiClient(tokenProvider: AuthStorage.getAccessToken).base,
           );

  Future<List<ActivityLog>> getUserLogs({
    required String userId,
    int? limit,
    int? offset,
  }) async {
    final path = _ep.userLogsPath(userId);

    final res = await _api.get(
      path,
      query: {
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Fetch activity logs failed: ${res.statusCode} ${res.body}',
      );
    }

    return ActivityLog.listFromJson(res.body);
  }
}
