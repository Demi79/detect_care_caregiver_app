import 'package:flutter/material.dart';

import '../../models/plan.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:detect_care_caregiver_app/core/widgets/primary_button.dart';

class PlanSummary extends StatelessWidget {
  final Plan plan;
  final String? billingType;
  const PlanSummary({super.key, required this.plan, this.billingType});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 8 : 16,
        horizontal: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (plan.isRecommended)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Khuyên dùng',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Giá: ${plan.price ~/ 1000},000đ/tháng',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              color: AppTheme.primaryBlueDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.dividerColor),
          const SizedBox(height: 16),
          if (billingType != null) ...[
            const SizedBox(height: 12),
            Text(
              'Hình thức thanh toán: ${billingType == 'prepaid'
                  ? 'Trả trước'
                  : billingType == 'postpaid'
                  ? 'Trả sau'
                  : billingType}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.dividerColor),
          const SizedBox(height: 16),

          // Features as a list of tuples: [title, value, icon]
          ...<List<Object>>[
            ['Số camera giám sát', '${plan.cameraQuota}', Icons.videocam],
            [
              'Thời gian lưu trữ video',
              '${plan.retentionDays} ngày',
              Icons.calendar_today,
            ],
            [
              'Số lượng nhân viên chăm sóc',
              '${plan.caregiverSeats}',
              Icons.person,
            ],
            ['Số địa điểm sử dụng', '${plan.sites}', Icons.location_on],
            ['Dung lượng lưu trữ dữ liệu', plan.storageSize, Icons.sd_storage],
            [
              'Chu kỳ cập nhật phần mềm',
              '${plan.majorUpdatesMonths} tháng',
              Icons.update,
            ],
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item[2] as IconData,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item[0]}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item[1]}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingArea extends StatelessWidget {
  final String? message;
  final VoidCallback onCancel;
  const LoadingArea({super.key, this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isSmallScreen ? 8 : 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  message!,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.dangerColor, AppTheme.dangerColorDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(229, 57, 53, 0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel, size: 20, color: Colors.white),
                label: Text(
                  'Hủy & Quay lại',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  AppLogger.payment(
                    '[PAYMENT][CANCEL] User pressed cancel button during payment processing',
                  );
                  AppLogger.payment(
                    '[PAYMENT][CANCEL] Loading message: ${message ?? "No message"}',
                  );
                  AppLogger.payment(
                    '[PAYMENT][CANCEL] Timestamp: ${DateTime.now()}',
                  );
                  onCancel();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card that displays transaction identifiers and copy buttons.
class TransactionInfoCard extends StatelessWidget {
  final String? paymentId;
  final String? txnRef;
  const TransactionInfoCard({super.key, this.paymentId, this.txnRef});

  @override
  Widget build(BuildContext context) {
    if (paymentId == null && txnRef == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin giao dịch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (paymentId != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('PaymentId: $paymentId')),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentId ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã copy PaymentId')),
                        );
                      },
                    ),
                  ],
                ),
              if (txnRef != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('TxnRef: $txnRef')),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txnRef ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã copy TxnRef')),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable bottom actions UI for the payment screen. Accepts small set of
/// callbacks and state so it can be reused or tested independently.
class PaymentBottomActions extends StatelessWidget {
  final bool isLoading;
  final String? loadingMessage;
  final VoidCallback onCancel;
  final bool awaitingUserReturn;
  final String? statusInfoMessage;
  final bool canTriggerStatusCheck;
  final Duration? manualCheckRemaining;
  final VoidCallback? onTriggerManualPressed;
  final VoidCallback onBackPressed;
  final bool primaryIsLoading;
  final VoidCallback? onPrimaryPressed;
  final String? lastPaymentId;
  final String? lastVnpTxnRef;

  const PaymentBottomActions({
    super.key,
    required this.isLoading,
    this.loadingMessage,
    required this.onCancel,
    required this.awaitingUserReturn,
    this.statusInfoMessage,
    required this.canTriggerStatusCheck,
    this.manualCheckRemaining,
    this.onTriggerManualPressed,
    required this.onBackPressed,
    required this.primaryIsLoading,
    this.onPrimaryPressed,
    this.lastPaymentId,
    this.lastVnpTxnRef,
  });

  String _manualLabel(Duration? d) {
    if (d == null) return 'Đang kiểm tra...';
    return 'Chờ ${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LoadingArea(message: loadingMessage, onCancel: onCancel);
    }

    if (awaitingUserReturn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionInfoCard(paymentId: lastPaymentId, txnRef: lastVnpTxnRef),
          if (statusInfoMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                statusInfoMessage!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: canTriggerStatusCheck
                  ? 'Tôi đã thanh toán'
                  : _manualLabel(manualCheckRemaining),
              isLoading: primaryIsLoading,
              color: const Color(0xFF4CAF50),
              onPressed: canTriggerStatusCheck ? onTriggerManualPressed : null,
              minHeight: 44,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onBackPressed,
              child: const Text(
                'Quay lại',
                style: TextStyle(fontSize: 15, color: Color(0xFF1E88E5)),
              ),
            ),
          ),
        ],
      );
    }

    // Default primary action
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        label: primaryIsLoading ? 'Đang xử lý...' : 'Thanh toán & Đăng ký',
        isLoading: primaryIsLoading,
        onPressed: primaryIsLoading ? null : onPrimaryPressed,
        minHeight: 48,
      ),
    );
  }
}
