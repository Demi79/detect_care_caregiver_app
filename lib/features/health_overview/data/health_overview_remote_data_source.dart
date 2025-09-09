import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_overview_models.dart';
import 'health_overview_endpoints.dart';

class HealthOverviewRemoteDataSource {
  final http.Client client;
  final HealthOverviewEndpoints endpoints;

  HealthOverviewRemoteDataSource({
    required this.client,
    required this.endpoints,
  });

  Future<HealthOverviewData> fetchOverview({
    String? patientId,
    String? startDate,
    String? endDate,
  }) async {
    final uri = endpoints.getHealthOverview(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
    );

    final response = await client
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load health overview: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> jsonData = json.decode(response.body);
    final payload = (jsonData['data'] is Map)
        ? jsonData['data'] as Map<String, dynamic>
        : jsonData;

    return HealthOverviewData.fromJson(payload);
  }
}
