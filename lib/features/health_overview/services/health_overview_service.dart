import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_overview_models.dart';

class HealthOverviewService {
  static const String baseUrl = 'API_BASE_URL';

  Future<HealthOverviewData> getHealthOverviewData({
    String? patientId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (patientId != null) queryParams['patientId'] = patientId;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse(
        '$baseUrl/health-overview',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // 'Authorization': 'Bearer <token>',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load health overview data: ${response.statusCode} ${response.body}',
        );
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);
      final payload = (jsonData['data'] is Map)
          ? jsonData['data'] as Map<String, dynamic>
          : jsonData;

      return HealthOverviewData.fromJson(payload);
    } catch (e) {
      throw Exception('Error fetching health overview data: $e');
    }
  }
}
