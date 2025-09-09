class ActionLog {
  final String time;
  final String status;
  final String action;
  final String location;
  final String analysis;
  final String imageUrl;

  ActionLog({
    required this.time,
    required this.status,
    required this.action,
    required this.location,
    required this.analysis,
    required this.imageUrl,
  });
}

final List<ActionLog> fakeLogs = [
  ActionLog(
    time: '08:30',
    status: 'Normal',
    action: 'Patient sat up',
    location: 'Room 101',
    analysis: 'No signs of risk',
    imageUrl: 'https://via.placeholder.com/150',
  ),
  ActionLog(
    time: '09:15',
    status: 'Warning',
    action: 'Irregular movement',
    location: 'Room 102',
    analysis: 'Possible discomfort',
    imageUrl: 'https://via.placeholder.com/150',
  ),
  ActionLog(
    time: '10:00',
    status: 'Critical',
    action: 'Fall detected',
    location: 'Room 103',
    analysis: 'Emergency alert',
    imageUrl: 'https://via.placeholder.com/150',
  ),
];

List<ActionLog> getFilteredLogs({
  required bool showWarningsOnly,
  required String status,
  required String timeRange,
  required String period,
}) {
  return fakeLogs.where((log) {
    final matchStatus = status == 'All' || log.status == status;
    final matchWarning = !showWarningsOnly || log.status != 'Normal';
    return matchStatus && matchWarning;
  }).toList();
}
