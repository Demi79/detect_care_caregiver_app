import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/features/search/models/search_models.dart';
import 'package:detect_care_caregiver_app/features/search/repositories/search_repository.dart';

class SearchProvider with ChangeNotifier {
  final SearchRepository _repository;

  SearchProvider({SearchRepository? repository})
    : _repository = repository ?? SearchRepository();

  // State
  SearchResponse? _searchResults;
  List<SearchHistory> _searchHistory = [];
  bool _isSearching = false;
  bool _isLoadingHistory = false;
  String? _error;

  // Getters
  SearchResponse? get searchResults => _searchResults;
  List<SearchHistory> get searchHistory => _searchHistory;
  bool get isSearching => _isSearching;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  // Computed getters
  bool get hasResults => _searchResults?.results.isNotEmpty ?? false;
  int get totalResults => _searchResults?.total ?? 0;
  Map<String, int> get resultSummary => _searchResults?.summary ?? {};

  /// Perform unified search
  Future<void> performSearch(SearchRequest request) async {
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _repository.unifiedSearch(request);
    } catch (e) {
      _error = e.toString();
      _searchResults = null;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Load search history
  Future<void> loadSearchHistory({int page = 1, int limit = 20}) async {
    _isLoadingHistory = true;
    _error = null;
    notifyListeners();

    try {
      final history = await _repository.getSearchHistory(
        page: page,
        limit: limit,
      );
      if (page == 1) {
        _searchHistory = history;
      } else {
        _searchHistory.addAll(history);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Execute quick action
  Future<bool> executeQuickAction(QuickActionRequest request) async {
    try {
      await _repository.executeQuickAction(request);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear search results
  void clearResults() {
    _searchResults = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _searchResults = null;
    _searchHistory = [];
    _isSearching = false;
    _isLoadingHistory = false;
    _error = null;
    notifyListeners();
  }
}
