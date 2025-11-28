/// Configuration for payment and subscription features.
/// Controls feature flags for gradual rollout and backward compatibility.
class PaymentConfig {
  // The payment feature now targets the standardized OpenAPI endpoints
  // by default. The legacy endpoints have been removed from the codebase and
  // rollout is handled by updating server deployments. No runtime flag is
  // needed here.

  /// Whether to enable polling for payment status with backoff.
  /// When enabled, automatically polls payment status after checkout.
  static const bool enablePaymentStatusPolling = true;

  /// Base delay between polling attempts (in seconds).
  /// Will be multiplied by attempt number with exponential backoff.
  static const int pollingBaseDelaySeconds = 2;

  /// Maximum number of polling attempts before giving up.
  static const int maxPollingAttempts = 10;

  /// Timeout for payment status polling (in seconds).
  static const int pollingTimeoutSeconds = 300; // 5 minutes

  /// Whether to normalize checkout field names for backward compatibility.
  /// Maps paymentUrl, checkoutUrl, url, payment_url, checkout_url to consistent keys.
  static const bool enableFieldNormalization = true;
}
