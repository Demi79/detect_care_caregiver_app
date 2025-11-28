import 'dart:async';

import 'package:detect_care_caregiver_app/core/widgets/primary_button.dart';
import 'package:detect_care_caregiver_app/features/service_package/services/service_package_api.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/package_item.dart';
import 'package:detect_care_caregiver_app/services/deep_link_service.dart';
import 'package:detect_care_caregiver_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class ServicePackageScreen extends StatefulWidget {
  const ServicePackageScreen({super.key});

  @override
  State<ServicePackageScreen> createState() => _ServicePackageScreenState();
}

class _ServicePackageScreenState extends State<ServicePackageScreen>
    with WidgetsBindingObserver {
  late final ServicePackageApi _api;
  late final PaymentService _paymentService;
  late final DeepLinkService _deepLinkService;
  int? _selectedPackage;
  int? _currentPackageId; // Gói hiện tại của user
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  bool _selecting = false;
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _api = ServicePackageApi();
    _paymentService = PaymentService();
    _deepLinkService = DeepLinkService();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _fetchPackages();
    _checkPaymentStatus(); // Check for any pending payments on startup
  }

  Future<void> _initDeepLinks() async {
    await _deepLinkService.init();
    _deepLinkSubscription = _deepLinkService.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
    );
  }

  void _handleDeepLink(Uri uri) {
    AppLogger.payment('Payment callback received: $uri');
    // Extract transaction info from URI
    final transactionId = uri.queryParameters['transactionId'];
    final status = uri.queryParameters['status'];

    if (transactionId != null && status != null) {
      _handlePaymentCallback(transactionId, status);
    }
  }

  Future<void> _handlePaymentCallback(
    String transactionId,
    String status,
  ) async {
    // First update local storage with callback status
    await PaymentStorageService.updatePaymentStatus(transactionId, status);

    // Verify with backend to ensure status is accurate
    final backendStatus = await _paymentService.checkPaymentStatus(
      transactionId,
    );
    final finalStatus = backendStatus?['status'] ?? status;

    // Update with verified status
    await PaymentStorageService.updatePaymentStatus(transactionId, finalStatus);

    if (finalStatus == 'success' || finalStatus == 'completed') {
      // Payment successful - navigate to subscription screen or show success
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!')));
        await _fetchPackages();
      }
    } else {
      // Payment failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thanh toán thất bại: $finalStatus')),
        );
      }
    }

    // Remove from pending payments after processing
    await PaymentStorageService.removePendingPayment(transactionId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed, check if payment was completed
      _checkPaymentStatus();
    }
  }

  Future<void> _checkPaymentStatus() async {
    // Check pending payments and verify status with backend
    final pendingPayments = await PaymentStorageService.getPendingPayments();

    for (final entry in pendingPayments.entries) {
      final transactionId = entry.key;
      final paymentData = entry.value;

      if (paymentData['status'] == 'pending') {
        // Check status with backend
        final statusData = await _paymentService.checkPaymentStatus(
          transactionId,
        );
        if (statusData != null) {
          final newStatus = statusData['status'] ?? 'unknown';
          await PaymentStorageService.updatePaymentStatus(
            transactionId,
            newStatus,
          );

          if (newStatus == 'success' || newStatus == 'completed') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thanh toán đã được xử lý thành công!'),
                ),
              );
              // Refresh packages so the UI can show the newly active package
              await _fetchPackages();
            }
          }
        }
      }
    }
  }

  Future<void> _fetchPackages() async {
    setState(() {
      _loading = true;
    });
    try {
      final rawPackages = await _api.fetchPackages();

      final normalized = <Map<String, dynamic>>[];
      for (final p in rawPackages) {
        try {
          final map = Map<String, dynamic>.from(p);

          dynamic idRaw = map['id'] ?? map['packageId'] ?? map['package_id'];
          int? id;
          if (idRaw is int) {
            id = idRaw;
          } else if (idRaw is String) {
            id = int.tryParse(idRaw);
          }
          map['id'] = id;

          final priceRaw = map['price'];
          double? price;
          if (priceRaw is num) {
            price = priceRaw.toDouble();
          } else if (priceRaw is String) {
            price = double.tryParse(priceRaw.replaceAll(',', ''));
          }
          map['price'] = price;

          map['is_current'] = map['is_current'] ?? map['current'] ?? false;

          if (id != null) normalized.add(map);
        } catch (_) {
          continue;
        }
      }

      int? currentId;
      if (normalized.isNotEmpty) {
        final currentPkg = normalized.firstWhere(
          (p) => p['is_current'] == true,
          orElse: () => {},
        );
        if (currentPkg.isNotEmpty && currentPkg['id'] != null) {
          currentId = currentPkg['id'] as int?;
        } else if (normalized.first.containsKey('currentPackageId')) {
          final v = normalized.first['currentPackageId'];
          if (v is int) currentId = v;
          if (v is String) currentId = int.tryParse(v);
        } else if (normalized.first.containsKey('current_package_id')) {
          final v = normalized.first['current_package_id'];
          if (v is int) currentId = v;
          if (v is String) currentId = int.tryParse(v);
        }
      }

      setState(() {
        _packages = normalized;
        _currentPackageId = currentId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải gói dịch vụ: $e')));
      }
    }
  }

  Future<void> _selectPackage() async {
    if (_selectedPackage == null) return;
    setState(() {
      _selecting = true;
    });
    try {
      const userId = 'user_id_demo';
      final selectedPkg = _packages.firstWhere(
        (p) => p['id'] == _selectedPackage,
      );
      final planCode = selectedPkg['code'] ?? 'basic'; // Giả sử có field 'code'
      final amount = (selectedPkg['price'] as num?)?.toDouble() ?? 0.0;

      // Tạo payment và subscription tự động
      final paymentData = await _paymentService.createSubscriptionPayment(
        planCode: planCode,
        amount: amount,
        userId: userId,
        description: 'Thanh toán gói ${selectedPkg['name']}',
      );

      setState(() {
        _selecting = false;
      });

      if (mounted) {
        // Redirect to VNPay URL
        final vnpayUrl = paymentData['paymentUrl'] ?? paymentData['url'];
        if (vnpayUrl != null) {
          final url = Uri.parse(vnpayUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã mở trang thanh toán. Vui lòng hoàn tất thanh toán và quay lại app.',
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể mở trang thanh toán')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể tạo link thanh toán')),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _selecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo thanh toán: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Chọn gói dịch vụ',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
          ? const Center(child: Text('Không có gói dịch vụ nào'))
          : ListView.builder(
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                final isSelected = _selectedPackage == pkg['id'];
                final isUpgrade =
                    _currentPackageId != null &&
                    _selectedPackage != null &&
                    _selectedPackage != _currentPackageId &&
                    pkg['id'] == _selectedPackage &&
                    pkg['price'] != null &&
                    _packages.any(
                      (p) =>
                          p['id'] == _currentPackageId &&
                          p['price'] != null &&
                          pkg['price'] > p['price'],
                    );

                return PackageItem(
                  pkg: pkg,
                  isSelected: isSelected,
                  isUpgrade: isUpgrade,
                  onSelected: (id) {
                    setState(() {
                      _selectedPackage = id;
                    });
                  },
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: PrimaryButton(
            label: 'Xác nhận',
            isLoading: _selecting,
            onPressed: _selectedPackage != null && !_selecting
                ? _selectPackage
                : null,
            minHeight: 44,
          ),
        ),
      ),
    );
  }
}
