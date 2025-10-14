class UploadSession {
  final String id;
  final String userId;
  final String sessionType;
  final List<String> fileIds;
  final UploadStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;
  final List<UploadFile> files;

  const UploadSession({
    required this.id,
    required this.userId,
    required this.sessionType,
    required this.fileIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.metadata,
    required this.files,
  });

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    return UploadSession(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sessionType: json['session_type']?.toString() ?? 'general',
      fileIds: List<String>.from(json['file_ids'] ?? []),
      status: UploadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UploadStatus.pending,
      ),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      files:
          (json['files'] as List<dynamic>?)
              ?.map((file) => UploadFile.fromJson(file as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'session_type': sessionType,
    'file_ids': fileIds,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'metadata': metadata,
    'files': files.map((file) => file.toJson()).toList(),
  };

  UploadSession copyWith({
    String? id,
    String? userId,
    String? sessionType,
    List<String>? fileIds,
    UploadStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
    List<UploadFile>? files,
  }) {
    return UploadSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionType: sessionType ?? this.sessionType,
      fileIds: fileIds ?? this.fileIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
      files: files ?? this.files,
    );
  }

  bool get isCompleted => status == UploadStatus.completed;
  bool get isFailed => status == UploadStatus.failed;
  bool get isInProgress => status == UploadStatus.processing;
  double get progress => files.isEmpty
      ? 0.0
      : files.where((f) => f.isUploaded).length / files.length;
}

class UploadFile {
  final String id;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final String cloudUrl;
  final UploadFileStatus status;
  final DateTime uploadedAt;
  final Map<String, dynamic>? metadata;
  final String? errorMessage;

  const UploadFile({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.fileSize,
    required this.cloudUrl,
    required this.status,
    required this.uploadedAt,
    this.metadata,
    this.errorMessage,
  });

  factory UploadFile.fromJson(Map<String, dynamic> json) {
    return UploadFile(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      fileSize: json['file_size'] ?? 0,
      cloudUrl: json['cloud_url']?.toString() ?? '',
      status: UploadFileStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UploadFileStatus.pending,
      ),
      uploadedAt: DateTime.parse(
        json['uploaded_at'] ?? DateTime.now().toIso8601String(),
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
      errorMessage: json['error_message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'original_name': originalName,
    'mime_type': mimeType,
    'file_size': fileSize,
    'cloud_url': cloudUrl,
    'status': status.name,
    'uploaded_at': uploadedAt.toIso8601String(),
    'metadata': metadata,
    'error_message': errorMessage,
  };

  UploadFile copyWith({
    String? id,
    String? fileName,
    String? originalName,
    String? mimeType,
    int? fileSize,
    String? cloudUrl,
    UploadFileStatus? status,
    DateTime? uploadedAt,
    Map<String, dynamic>? metadata,
    String? errorMessage,
  }) {
    return UploadFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isUploaded => status == UploadFileStatus.completed;
  bool get hasError => status == UploadFileStatus.failed;
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    }
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum UploadStatus { pending, processing, completed, failed, cancelled }

enum UploadFileStatus { pending, uploading, completed, failed }

class UploadSessionRequest {
  final String sessionType;
  final List<UploadFileRequest> files;
  final Map<String, dynamic> metadata;

  const UploadSessionRequest({
    required this.sessionType,
    required this.files,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'session_type': sessionType,
    'files': files.map((file) => file.toJson()).toList(),
    'metadata': metadata,
  };
}

class UploadFileRequest {
  final String fileName;
  final String mimeType;
  final int fileSize;
  final Map<String, dynamic> metadata;

  const UploadFileRequest({
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'file_name': fileName,
    'mime_type': mimeType,
    'file_size': fileSize,
    'metadata': metadata,
  };
}
