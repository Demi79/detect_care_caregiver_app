import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/features/subscription/screens/invoice_detail_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_app_bar.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_filters.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_screen_content.dart';
import 'package:flutter/material.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    this.apiProvider,
    this.embedInParent = false,
  });

  final ApiProvider? apiProvider;
  final bool embedInParent;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final List<Invoice> _invoices = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _page = 1;
  int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  int? _totalCount;
  final TextEditingController _jumpController = TextEditingController();

  // Filters
  String _sort = 'date_desc';
  String _statusFilter = 'paid';
  String _sourceFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices(page: _page);
    _scrollController.addListener(_onScroll);
  }

  void _openFilters() {
    showInvoiceFiltersModal(
      context: context,
      sort: _sort,
      status: _statusFilter,
      source: _sourceFilter,
      limit: _limit,
      jumpController: _jumpController,
      onSortChanged: (v) => setState(() => _sort = v),
      onStatusChanged: (v) => setState(() => _statusFilter = v),
      onSourceChanged: (v) => setState(() => _sourceFilter = v),
      onLimitChanged: (val) {
        setState(() {
          _limit = val;
          _page = 1;
        });
        _loadInvoices(page: 1, append: false);
      },
      onJumpToPage: (p) => _loadInvoices(page: p, append: false),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page += 1;
    await _loadInvoices(page: _page, append: true);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _loadInvoices({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = page;
        _hasMore = true;
      });
    }

    try {
      final api =
          widget.apiProvider ??
          ApiClient(tokenProvider: AuthStorage.getAccessToken);
      final res = await api.get(
        '/transactions/billing/history',
        query: {'status': 'paid', 'page': page, 'limit': _limit},
      );
      final data = api.extractDataFromResponse(res);

      List<Invoice> invoices = [];
      if (data is List) {
        invoices = data
            .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (data is Map) {
        if (data['items'] is List) {
          invoices = (data['items'] as List)
              .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          final total = data['total'];
          if (total is int) {
            _hasMore = invoices.length + ((_page - 1) * _limit) < total;
          } else {
            _hasMore = (data['items'] as List).length == _limit;
          }
        } else if (data['invoices'] is List) {
          invoices = (data['invoices'] as List)
              .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _hasMore = invoices.length == _limit;
        } else if (data['data'] is List) {
          invoices = (data['data'] as List)
              .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _hasMore = invoices.length == _limit;
        }
      }

      if (!mounted) return;
      setState(() {
        if (append) {
          _invoices.addAll(invoices);
        } else {
          _invoices
            ..clear()
            ..addAll(invoices);
        }
        _isLoading = false;
        if (data is Map) {
          final total = data['total'];
          if (total is int) _totalCount = total;
        }

        if (_totalCount != null) {
          final fetched = _invoices.length + ((_page - 1) * _limit);
          _hasMore = fetched < (_totalCount ?? 0);
        } else {
          if (invoices.length < _limit) _hasMore = false;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _jumpController.text = '$_page';
          if (!append && _scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        } catch (_) {
          // ignore animation errors
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải hóa đơn: $e';
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = InvoiceScreenContent(
      invoices: _invoices,
      isLoading: _isLoading,
      error: _error,
      page: _page,
      limit: _limit,
      hasMore: _hasMore,
      isLoadingMore: _isLoadingMore,
      totalCount: _totalCount,
      scrollController: _scrollController,
      jumpController: _jumpController,
      onPrev: () => _loadInvoices(page: _page - 1, append: false),
      onNext: () => _loadMore(),
      onChangeLimit: (val) {
        setState(() {
          _limit = val;
          _page = 1;
        });
        _loadInvoices(page: 1, append: false);
      },
      onJump: (p) => _loadInvoices(page: p, append: false),
      onOpenFilters: _openFilters,
      onTapInvoice: (inv) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(
              invoice: inv,
              apiProvider: widget.apiProvider,
            ),
          ),
        );
      },
    );

    if (widget.embedInParent) {
      // final statusBarHeight = MediaQuery.of(context).padding.top;
      // final appBarHeight =
      //     AppBarTheme.of(context).toolbarHeight ?? kToolbarHeight;
      final topOffset = 36.0;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: topOffset),
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: InvoiceAppBar(
        totalCount: _totalCount,
        isLoading: _isLoading,
        onRefresh: () => _loadInvoices(page: 1, append: false),
      ),
      body: content,
    );
  }
}
