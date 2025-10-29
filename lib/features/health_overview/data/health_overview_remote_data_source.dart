import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import '../models/health_overview_models.dart';
import 'health_overview_endpoints.dart';

class HealthOverviewRemoteDataSource {
  final ApiProvider api;
  final HealthOverviewEndpoints endpoints;

  HealthOverviewRemoteDataSource({required this.api, required this.endpoints});

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

    final response = await api
        .get(uri.path, extraHeaders: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load health overview: ${response.statusCode} ${response.body}',
      );
    }

    dynamic jsonData;
    try {
      if (response.body.isEmpty) {
        throw Exception('Empty response body');
      }
      jsonData = json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to parse response: $e');
    }

    final payload = (jsonData is Map && jsonData['data'] is Map)
        ? jsonData['data'] as Map<String, dynamic>
        : jsonData as Map<String, dynamic>;

    return HealthOverviewData.fromJson(payload);
  }
}
