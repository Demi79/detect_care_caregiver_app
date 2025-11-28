import 'dart:async';

import '../../../core/utils/logger.dart';

/// Utility class for polling payment status with exponential backoff
class PaymentStatusPoller {
  /// Poll payment status until completion or failure
  ///
  /// [statusChecker] - Function that returns payment status data
  /// [isComplete] - Function that determines if polling should stop (returns true when payment is complete/failed)
  /// [maxAttempts] - Maximum number of polling attempts (default: 30)
  /// [initialDelay] - Initial delay between polls in seconds (default: 2)
  /// [maxDelay] - Maximum delay between polls in seconds (default: 30)
  /// [backoffMultiplier] - Multiplier for exponential backoff (default: 1.5)
  /// [onProgress] - Optional callback for each polling attempt
  /// [onComplete] - Optional callback when polling completes
  /// [onError] - Optional callback when polling fails
  static Future<Map<String, dynamic>> pollStatus({
    required Future<Map<String, dynamic>> Function() statusChecker,
    required bool Function(Map<String, dynamic>) isComplete,
    int maxAttempts = 30,
    int initialDelay = 2,
    int maxDelay = 30,
    double backoffMultiplier = 1.5,
    Function(int attempt, Map<String, dynamic> data)? onProgress,
    Function(Map<String, dynamic> data)? onComplete,
    Function(String error)? onError,
  }) async {
    int currentDelay = initialDelay;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        AppLogger.payment(
          'Polling attempt $attempt/$maxAttempts, delay: ${currentDelay}s',
        );

        // Check status
        final result = await statusChecker();

        // Call progress callback
        onProgress?.call(attempt, result);

        // Check if payment is complete
        if (isComplete(result)) {
          AppLogger.payment('Payment polling completed on attempt $attempt');
          onComplete?.call(result);
          return result;
        }

        // If this is the last attempt, don't wait
        if (attempt == maxAttempts) {
          break;
        }

        // Wait before next attempt with exponential backoff
        await Future.delayed(Duration(seconds: currentDelay));

        // Calculate next delay with exponential backoff, capped at maxDelay
        currentDelay = (currentDelay * backoffMultiplier).round();
        if (currentDelay > maxDelay) {
          currentDelay = maxDelay;
        }
      } catch (e) {
        final errorMsg = 'Payment polling failed on attempt $attempt: $e';
        AppLogger.paymentError(errorMsg);
        onError?.call(errorMsg);

        // If this is the last attempt, throw the error
        if (attempt == maxAttempts) {
          throw Exception(
            'Payment polling failed after $maxAttempts attempts: $e',
          );
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: currentDelay));
        currentDelay = (currentDelay * backoffMultiplier).round();
        if (currentDelay > maxDelay) {
          currentDelay = maxDelay;
        }
      }
    }

    // If we get here, polling timed out
    final timeoutMsg = 'Payment polling timed out after $maxAttempts attempts';
    AppLogger.paymentError(timeoutMsg);
    onError?.call(timeoutMsg);

    throw Exception(timeoutMsg);
  }

  /// Convenience method for polling VNPay payment status
  ///
  /// [getStatus] - Function to get payment status (should return the data from PaymentApi.getPaymentStatus)
  /// [isPaymentComplete] - Function to check if payment is complete based on status data
  /// Other parameters same as pollStatus
  static Future<Map<String, dynamic>> pollVNPayStatus({
    required Future<({Map<String, dynamic> data, Map<String, String> headers})>
    Function()
    getStatus,
    required bool Function(Map<String, dynamic>) isPaymentComplete,
    int maxAttempts = 30,
    int initialDelay = 2,
    int maxDelay = 30,
    double backoffMultiplier = 1.5,
    Function(int attempt, Map<String, dynamic> data)? onProgress,
    Function(Map<String, dynamic> data)? onComplete,
    Function(String error)? onError,
  }) async {
    int currentDelay = initialDelay;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        AppLogger.payment(
          'Polling attempt $attempt/$maxAttempts, delay: ${currentDelay}s',
        );

        // Check status
        final result = await getStatus();
        final data = result.data;
        final headers = result.headers;

        // Check for Retry-After header and adjust delay
        final retryAfter = headers['retry-after'] ?? headers['Retry-After'];
        if (retryAfter != null) {
          try {
            final serverDelay = int.parse(retryAfter);
            if (serverDelay > 0 && serverDelay <= maxDelay) {
              currentDelay = serverDelay;
              AppLogger.payment(
                'Using server Retry-After delay: ${currentDelay}s',
              );
            }
          } catch (e) {
            AppLogger.payment(
              'Invalid Retry-After header: $retryAfter, using exponential backoff',
            );
          }
        }

        // Call progress callback
        onProgress?.call(attempt, data);

        // Check if payment is complete
        if (isPaymentComplete(data)) {
          AppLogger.payment('Payment polling completed on attempt $attempt');
          onComplete?.call(data);
          return data;
        }

        // If this is the last attempt, don't wait
        if (attempt == maxAttempts) {
          break;
        }

        // Wait before next attempt
        await Future.delayed(Duration(seconds: currentDelay));

        // Calculate next delay with exponential backoff (only if no Retry-After)
        if (retryAfter == null) {
          currentDelay = (currentDelay * backoffMultiplier).round();
          if (currentDelay > maxDelay) {
            currentDelay = maxDelay;
          }
        }
      } catch (e) {
        final errorMsg = 'Payment polling failed on attempt $attempt: $e';
        AppLogger.paymentError(errorMsg);
        onError?.call(errorMsg);

        // If this is the last attempt, throw the error
        if (attempt == maxAttempts) {
          throw Exception(
            'Payment polling failed after $maxAttempts attempts: $e',
          );
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: currentDelay));
        currentDelay = (currentDelay * backoffMultiplier).round();
        if (currentDelay > maxDelay) {
          currentDelay = maxDelay;
        }
      }
    }

    // If we get here, polling timed out
    final timeoutMsg = 'Payment polling timed out after $maxAttempts attempts';
    AppLogger.paymentError(timeoutMsg);
    onError?.call(timeoutMsg);

    throw Exception(timeoutMsg);
  }

  /// Default function to check if VNPay payment is complete
  /// Returns true if payment status indicates completion (success or failure)
  static bool isVNPayPaymentComplete(Map<String, dynamic> statusData) {
    // Check various possible status fields that VNPay might return
    final status =
        statusData['vnp_TransactionStatus'] ??
        statusData['status'] ??
        statusData['transactionStatus'];

    if (status == null) return false;

    // VNPay status codes:
    // '00' = Success
    // '01' = Pending
    // '02' = Failed
    // Other codes = Various failure reasons
    final statusStr = status.toString();
    return statusStr == '00' ||
        statusStr == '02' ||
        (statusStr != '01' && statusStr != 'pending');
  }

  /// Default function to check if OpenAPI payment is complete
  static bool isOpenApiPaymentComplete(Map<String, dynamic> statusData) {
    final status = statusData['status']?.toString().toLowerCase();
    if (status == null) return false;

    // OpenAPI status values (assuming common patterns)
    return status == 'completed' ||
        status == 'succeeded' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'expired';
  }
}
