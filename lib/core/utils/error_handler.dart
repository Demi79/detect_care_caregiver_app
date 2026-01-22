String formatErrorMessage(Object? error) {
  final errorStr = error?.toString().toLowerCase() ?? '';

  // Check for 403 / permission denied
  if (errorStr.contains('403') ||
      errorStr.contains('permission') ||
      errorStr.contains('forbidden') ||
      errorStr.contains('access denied')) {
    return 'Bạn đang không được chia sẻ quyền này';
  }

  // Check for network / connection errors
  if (errorStr.contains('network') ||
      errorStr.contains('connection') ||
      errorStr.contains('timeout')) {
    return 'Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại.';
  }

  // Default: use original error
  return error?.toString() ?? 'Lỗi không xác định';
}

/// Check if error is a 403 permission denied
bool is403Error(Object? error) {
  final errorStr = error?.toString().toLowerCase() ?? '';
  return errorStr.contains('403') ||
      errorStr.contains('permission') ||
      errorStr.contains('forbidden') ||
      errorStr.contains('access denied');
}
