class ActivityLogEndpoints {
  final String base;
  ActivityLogEndpoints(this.base);

  String userLogsPath(String userId) => '/activity-logs/user/$userId';

  Uri userLogsUri(String userId) => Uri.parse('$base${userLogsPath(userId)}');
}
