import 'package:detect_care_caregiver_app/features/search/data/search_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/search/models/search_models.dart';

class SearchRepository {
  final SearchRemoteDataSource _remoteDataSource;

  SearchRepository({SearchRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? SearchRemoteDataSource();

  /// Perform unified search across events, caregivers, and invoices
  Future<SearchResponse> unifiedSearch(SearchRequest request) async {
    return await _remoteDataSource.unifiedSearch(request);
  }

  /// Get search history
  Future<List<SearchHistory>> getSearchHistory({
    int page = 1,
    int limit = 20,
  }) async {
    return await _remoteDataSource.getSearchHistory(page: page, limit: limit);
  }

  /// Execute quick action on search result
  Future<void> executeQuickAction(QuickActionRequest request) async {
    return await _remoteDataSource.executeQuickAction(request);
  }
}
