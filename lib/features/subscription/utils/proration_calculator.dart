import 'package:detect_care_caregiver_app/core/utils/logger.dart';

/// Proration calculation utility for subscription billing
class ProrationCalculator {
  /// Calculate proration delta for plan changes
  ///
  /// Formula:
  /// - Upgrade: charge = max(0, P_new - P_old) * (t_left / t_total)
  /// - Downgrade: credit = max(0, P_old - P_new) * (t_left / t_total)
  ///
  /// @param oldPrice - Current plan price per billing cycle
  /// @param newPrice - New plan price per billing cycle
  /// @param currentPeriodStart - Start of current billing period
  /// @param currentPeriodEnd - End of current billing period
  /// @param changeEffectiveAt - When the change takes effect (default: now)
  /// @return Map with proration details
  static Map<String, dynamic> calculateProration({
    required double oldPrice,
    required double newPrice,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    DateTime? changeEffectiveAt,
  }) {
    final effectiveAt = changeEffectiveAt ?? DateTime.now();

    // Ensure effectiveAt is within the current period
    if (effectiveAt.isBefore(currentPeriodStart) ||
        effectiveAt.isAfter(currentPeriodEnd)) {
      throw ArgumentError(
        'Change effective date must be within current billing period',
      );
    }

    // Calculate total seconds in period
    final totalSeconds = currentPeriodEnd
        .difference(currentPeriodStart)
        .inSeconds;
    final remainingSeconds = currentPeriodEnd.difference(effectiveAt).inSeconds;

    // Calculate proration ratio
    final prorationRatio = remainingSeconds / totalSeconds;

    // Calculate price difference
    final priceDelta = newPrice - oldPrice;

    // Calculate proration amounts
    final prorationCharge = priceDelta > 0 ? priceDelta * prorationRatio : 0.0;
    final prorationCredit = priceDelta < 0 ? -priceDelta * prorationRatio : 0.0;

    AppLogger.i('''
[ProrationCalculator] Plan change proration:
  Old Price: $oldPrice
  New Price: $newPrice
  Price Delta: $priceDelta
  Period Total: $totalSeconds seconds
  Remaining: $remainingSeconds seconds
  Proration Ratio: ${prorationRatio.toStringAsFixed(4)}
  Proration Charge: $prorationCharge
  Proration Credit: $prorationCredit
''');

    return {
      'proration_charge': prorationCharge,
      'proration_credit': prorationCredit,
      'price_delta': priceDelta,
      'proration_ratio': prorationRatio,
      'remaining_seconds': remainingSeconds,
      'total_seconds': totalSeconds,
      'effective_at': effectiveAt,
      'is_upgrade': priceDelta > 0,
      'is_downgrade': priceDelta < 0,
    };
  }

  /// Calculate prorated amount for add-ons or one-time charges
  static double calculateAddonProration({
    required double unitPrice,
    required int quantity,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    DateTime? effectiveAt,
  }) {
    final changeAt = effectiveAt ?? DateTime.now();

    if (changeAt.isBefore(currentPeriodStart) ||
        changeAt.isAfter(currentPeriodEnd)) {
      throw ArgumentError(
        'Effective date must be within current billing period',
      );
    }

    final totalSeconds = currentPeriodEnd
        .difference(currentPeriodStart)
        .inSeconds;
    final remainingSeconds = currentPeriodEnd.difference(changeAt).inSeconds;
    final prorationRatio = remainingSeconds / totalSeconds;

    return unitPrice * quantity * prorationRatio;
  }

  /// Normalize prices between different billing cycles
  ///
  /// @param price - Price in current cycle
  /// @param fromCycle - Current billing cycle ('monthly', 'annual')
  /// @param toCycle - Target billing cycle ('monthly', 'annual')
  /// @return Normalized price
  static double normalizePrice(double price, String fromCycle, String toCycle) {
    if (fromCycle == toCycle) return price;

    // Simple annual/monthly conversion (can be enhanced for calendar accuracy)
    const monthsPerYear = 12;

    if (fromCycle == 'annual' && toCycle == 'monthly') {
      return price / monthsPerYear;
    } else if (fromCycle == 'monthly' && toCycle == 'annual') {
      return price * monthsPerYear;
    }

    throw ArgumentError('Unsupported cycle conversion: $fromCycle -> $toCycle');
  }

  /// Format proration explanation for UI
  static String formatProrationExplanation(Map<String, dynamic> proration) {
    final charge = proration['proration_charge'] as double;
    final credit = proration['proration_credit'] as double;
    final ratio = proration['proration_ratio'] as double;
    final isUpgrade = proration['is_upgrade'] as bool;
    final isDowngrade = proration['is_downgrade'] as bool;

    if (isUpgrade) {
      final percentage = (ratio * 100).round();
      return 'Phí chênh lệch $percentage% kỳ còn lại: ${charge.toStringAsFixed(0)}₫';
    } else if (isDowngrade) {
      final percentage = (ratio * 100).round();
      return 'Hoàn tiền $percentage% kỳ còn lại: ${credit.toStringAsFixed(0)}₫';
    } else {
      return 'Không phát sinh phí thay đổi gói trong kỳ này.';
    }
  }
}
