import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/search/models/search_models.dart';
import 'package:flutter/foundation.dart';

class SearchException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  SearchException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    if (statusCode != null) {
      return 'SearchException: $message (Status: $statusCode)';
    }
    return 'SearchException: $message';
  }
}

class SearchRemoteDataSource {
  final ApiClient _api;

  SearchRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  /// GET /search/unified - Unified search across events, caregivers, invoices
  Future<SearchResponse> unifiedSearch(SearchRequest request) async {
    try {
      debugPrint('🔍 [Search] Unified search request: ${request.toJson()}');

      final queryParams = _buildQueryParams(request);
      final uri = '/search/unified$queryParams';

      final res = await _api.get(uri);
      debugPrint('📡 [Search] Response status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = _api.extractDataFromResponse(res);
        if (data is Map<String, dynamic>) {
          return SearchResponse.fromJson(data);
        } else {
          throw SearchException(
            'Invalid response format: expected Map but got ${data.runtimeType}',
            statusCode: res.statusCode,
            body: res.body,
          );
        }
      } else {
        throw SearchException(
          'Failed to perform unified search',
          statusCode: res.statusCode,
          body: res.body,
        );
      }
    } catch (e) {
      if (e is SearchException) rethrow;
      throw SearchException(
        'Network error during unified search: ${e.toString()}',
      );
    }
  }

  /// GET /search/history - Get search history
  Future<List<SearchHistory>> getSearchHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      debugPrint(
        '📚 [Search] Fetching search history: page=$page, limit=$limit',
      );

      final uri = '/search/history?page=$page&limit=$limit';
      final res = await _api.get(uri);

      if (res.statusCode == 200) {
        final data = _api.extractDataFromResponse(res);
        if (data is List) {
          return data.map((item) => SearchHistory.fromJson(item)).toList();
        } else {
          throw SearchException(
            'Invalid response format: expected List but got ${data.runtimeType}',
            statusCode: res.statusCode,
            body: res.body,
          );
        }
      } else {
        throw SearchException(
          'Failed to fetch search history',
          statusCode: res.statusCode,
          body: res.body,
        );
      }
    } catch (e) {
      if (e is SearchException) rethrow;
      throw SearchException(
        'Network error during search history fetch: ${e.toString()}',
      );
    }
  }

  /// POST /search/quick-action/:action/:entityId - Execute quick action on search result
  Future<void> executeQuickAction(QuickActionRequest request) async {
    try {
      debugPrint(
        '⚡ [Search] Executing quick action: ${request.action} on ${request.entityType}:${request.entityId}',
      );

      final uri = '/search/quick-action/${request.action}/${request.entityId}';
      final res = await _api.post(uri, body: request.toJson());

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('✅ [Search] Quick action executed successfully');
        return;
      } else {
        throw SearchException(
          'Failed to execute quick action: ${request.action}',
          statusCode: res.statusCode,
          body: res.body,
        );
      }
    } catch (e) {
      if (e is SearchException) rethrow;
      throw SearchException(
        'Network error during quick action: ${e.toString()}',
      );
    }
  }

  /// Helper method to build query parameters from SearchRequest
  String _buildQueryParams(SearchRequest request) {
    final params = <String>[];

    if (request.query.isNotEmpty) {
      params.add('query=${Uri.encodeQueryComponent(request.query)}');
    }

    if (request.entityTypes.isNotEmpty) {
      params.add('entity_types=${request.entityTypes.join(',')}');
    }

    if (request.startDate != null) {
      params.add('start_date=${request.startDate!.toIso8601String()}');
    }

    if (request.endDate != null) {
      params.add('end_date=${request.endDate!.toIso8601String()}');
    }

    if (request.status != null && request.status!.isNotEmpty) {
      params.add('status=${Uri.encodeQueryComponent(request.status!)}');
    }

    if (request.minConfidence != null) {
      params.add('min_confidence=${request.minConfidence}');
    }

    if (request.maxAmount != null) {
      params.add('max_amount=${request.maxAmount}');
    }

    params.add('page=${request.page}');
    params.add('limit=${request.limit}');

    return params.isEmpty ? '' : '?${params.join('&')}';
  }
}
