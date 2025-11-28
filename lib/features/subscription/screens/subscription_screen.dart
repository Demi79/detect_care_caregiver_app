import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/subscription/mixins/subscription_management_mixin.dart';
import 'package:detect_care_caregiver_app/features/subscription/providers/subscriptions_provider.dart';
import 'package:detect_care_caregiver_app/features/subscription/screens/select_subscription_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/utils/billing_utils.dart';
import 'package:detect_care_caregiver_app/features/subscription/utils/usage_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.initialTabIndex = 0});

  /// Which tab should be selected when the screen opens.
  final int initialTabIndex;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with
        TickerProviderStateMixin,
        SubscriptionManagementMixin<SubscriptionScreen> {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _billingHistory = [];
  Map<String, dynamic>? _planUsage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < 3)
          ? widget.initialTabIndex
          : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prov = context.read<SubscriptionsProvider>();
    await Future.wait([
      prov.fetchMySubscriptions(),
      _loadInvoices(),
      _loadBillingHistory(),
      _loadPlanUsage(),
    ]);
  }

  Future<void> _loadInvoices() async {
    final prov = context.read<SubscriptionsProvider>();
    _invoices = await prov.fetchInvoices();
    _safeSetState();
  }

  Future<void> _loadBillingHistory() async {
    final prov = context.read<SubscriptionsProvider>();
    _billingHistory = await prov.fetchBillingHistory();
    _safeSetState();
  }

  Future<void> _loadPlanUsage() async {
    final prov = context.read<SubscriptionsProvider>();
    _planUsage = await prov.fetchPlanUsage();

    // Debug log the received data
    AppLogger.api('Plan usage loaded: $_planUsage');

    _safeSetState();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  Widget _buildPaymentHistoryTab() {
    final combinedHistory = [
      ..._invoices.map(
        (invoice) => {
          ...invoice,
          'type': 'invoice',
          'date': invoice['issued_at'] ?? invoice['created_at'],
        },
      ),
      ..._billingHistory.map(
        (transaction) => {
          ...transaction,
          'type': 'transaction',
          'date': transaction['transaction_date'] ?? transaction['created_at'],
        },
      ),
    ];

    // Sort by date (most recent first). Use a tolerant parser because backend
    // can return ISO strings, epoch ints, or other formats.
    DateTime parseAnyDate(dynamic v) {
      try {
        if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is String) {
          final t = DateTime.tryParse(v);
          if (t != null) return t;
          // Try parsing common alternative formats, you can extend later
          // Fallback to epoch parse if string contains only digits
          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            final asInt = int.tryParse(digits);
            if (asInt != null && asInt > 0) {
              // Heuristic: treat as milliseconds when length >= 13
              if (digits.length >= 13) {
                return DateTime.fromMillisecondsSinceEpoch(asInt);
              }
              return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
            }
          }
        }
      } catch (_) {}
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    combinedHistory.sort((a, b) {
      final da = parseAnyDate(a['date']);
      final db = parseAnyDate(b['date']);
      return db.compareTo(da);
    });

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadInvoices(), _loadBillingHistory()]);
      },
      child: combinedHistory.isEmpty
          ? const Center(child: Text('Chưa có lịch sử thanh toán'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: combinedHistory.length,
              itemBuilder: (context, index) {
                final item = combinedHistory[index];
                return item['type'] == 'invoice'
                    ? BillingUtils.buildInvoiceCard(item)
                    : BillingUtils.buildTransactionCard(item);
              },
            ),
    );
  }

  Widget _buildUsageStatisticsTab() {
    return RefreshIndicator(
      onRefresh: _loadPlanUsage,
      child: _planUsage == null
          ? const Center(child: CircularProgressIndicator())
          : _planUsage!.isEmpty
          ? const Center(child: Text('Không có dữ liệu thống kê'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thống kê sử dụng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...UsageUtils.buildUsageCards(_planUsage!),
                  const SizedBox(height: 24),
                  const Text(
                    'Chi tiết entitlements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  UsageUtils.buildEntitlementsCard(_planUsage!),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
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
          'Quản lý gói dịch vụ',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),

        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gói dịch vụ'),
            Tab(text: 'Lịch sử thanh toán'),
            Tab(text: 'Thống kê sử dụng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const SelectSubscriptionScreen(),
          _buildPaymentHistoryTab(),
          _buildUsageStatisticsTab(),
        ],
      ),
    );
  }
}
