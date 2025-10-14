class SearchRequest {
  final String query;
  final List<String> entityTypes;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final double? minConfidence;
  final double? maxAmount;
  final int page;
  final int limit;

  SearchRequest({
    required this.query,
    required this.entityTypes,
    this.startDate,
    this.endDate,
    this.status,
    this.minConfidence,
    this.maxAmount,
    this.page = 1,
    this.limit = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'entity_types': entityTypes,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'min_confidence': minConfidence,
      'max_amount': maxAmount,
      'page': page,
      'limit': limit,
    };
  }

  factory SearchRequest.fromJson(Map<String, dynamic> json) {
    return SearchRequest(
      query: json['query'] ?? '',
      entityTypes: List<String>.from(json['entity_types'] ?? []),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      status: json['status'],
      minConfidence: json['min_confidence']?.toDouble(),
      maxAmount: json['max_amount']?.toDouble(),
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
    );
  }
}

class SearchResult {
  final String id;
  final String entityType;
  final String title;
  final String description;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final double? confidence;
  final String? status;

  SearchResult({
    required this.id,
    required this.entityType,
    required this.title,
    required this.description,
    required this.data,
    this.createdAt,
    this.confidence,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'title': title,
      'description': description,
      'data': data,
      'created_at': createdAt?.toIso8601String(),
      'confidence': confidence,
      'status': status,
    };
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] ?? '',
      entityType: json['entity_type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      data: json['data'] ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      confidence: json['confidence']?.toDouble(),
      status: json['status'],
    );
  }
}

class SearchResponse {
  final List<SearchResult> results;
  final int total;
  final int page;
  final int limit;
  final Map<String, int> summary;

  SearchResponse({
    required this.results,
    required this.total,
    required this.page,
    required this.limit,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'total': total,
      'page': page,
      'limit': limit,
      'summary': summary,
    };
  }

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results:
          (json['results'] as List<dynamic>?)
              ?.map((r) => SearchResult.fromJson(r))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      summary: Map<String, int>.from(json['summary'] ?? {}),
    );
  }
}

class SearchHistory {
  final String id;
  final String query;
  final List<String> entityTypes;
  final DateTime searchedAt;
  final int resultCount;

  SearchHistory({
    required this.id,
    required this.query,
    required this.entityTypes,
    required this.searchedAt,
    required this.resultCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'entity_types': entityTypes,
      'searched_at': searchedAt.toIso8601String(),
      'result_count': resultCount,
    };
  }

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'] ?? '',
      query: json['query'] ?? '',
      entityTypes: List<String>.from(json['entity_types'] ?? []),
      searchedAt: DateTime.parse(
        json['searched_at'] ?? DateTime.now().toIso8601String(),
      ),
      resultCount: json['result_count'] ?? 0,
    );
  }
}

class QuickActionRequest {
  final String action;
  final String entityId;
  final String entityType;
  final Map<String, dynamic>? metadata;

  QuickActionRequest({
    required this.action,
    required this.entityId,
    required this.entityType,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'entity_id': entityId,
      'entity_type': entityType,
      'metadata': metadata,
    };
  }

  factory QuickActionRequest.fromJson(Map<String, dynamic> json) {
    return QuickActionRequest(
      action: json['action'] ?? '',
      entityId: json['entity_id'] ?? '',
      entityType: json['entity_type'] ?? '',
      metadata: json['metadata'],
    );
  }
}
