import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/features/subscription/providers/subscriptions_provider.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_detail_header.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_detail_summary.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_detail_line_items.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_detail_actions.dart';
import 'package:detect_care_caregiver_app/features/subscription/widgets/invoice_detail_metadata.dart';
import 'package:detect_care_caregiver_app/features/subscription/services/invoice_pdf_builder.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    this.apiProvider,
  });

  final Invoice invoice;
  final ApiProvider? apiProvider;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  bool _busy = false;

  Future<void> _handleShareOrDownload({required bool share}) async {
    setState(() => _busy = true);
    final api =
        widget.apiProvider ??
        ApiClient(tokenProvider: AuthStorage.getAccessToken);
    final subs = SubscriptionsProvider(apiProvider: api);
    try {
      final result = await subs.generateInvoicePdf(widget.invoice.id);

      if (result.containsKey('pdfBytes')) {
        final bytes = result['pdfBytes'] as List<int>;
        if (share) {
          await Printing.sharePdf(
            bytes: Uint8List.fromList(bytes),
            filename: 'invoice-${widget.invoice.id}.pdf',
          );
        } else {
          await Printing.layoutPdf(
            onLayout: (format) => Future.value(Uint8List.fromList(bytes)),
          );
        }
        return;
      }

      if (result['url'] is String) {
        try {
          final resp = await http.get(Uri.parse(result['url'] as String));
          if (resp.statusCode == 200 &&
              (resp.headers['content-type'] ?? '').contains(
                'application/pdf',
              )) {
            final bytes = resp.bodyBytes;
            if (share) {
              await Printing.sharePdf(
                bytes: Uint8List.fromList(bytes),
                filename: 'invoice-${widget.invoice.id}.pdf',
              );
            } else {
              await Printing.layoutPdf(
                onLayout: (format) => Future.value(Uint8List.fromList(bytes)),
              );
            }
            return;
          }
        } catch (_) {}
      }

      // If API returned no direct bytes/url, but the invoice object has an invoiceUrl,
      // try to download it using the authenticated ApiClient (preserves auth and base).
      if (widget.invoice.invoiceUrl != null &&
          widget.invoice.invoiceUrl!.isNotEmpty) {
        try {
          final resp = await api.get(widget.invoice.invoiceUrl!);
          if (resp.statusCode == 200 &&
              (resp.headers['content-type'] ?? '').contains(
                'application/pdf',
              )) {
            final bytes = resp.bodyBytes;
            if (share) {
              await Printing.sharePdf(
                bytes: Uint8List.fromList(bytes),
                filename: 'invoice-${widget.invoice.id}.pdf',
              );
            } else {
              await Printing.layoutPdf(
                onLayout: (format) => Future.value(Uint8List.fromList(bytes)),
              );
            }
            return;
          }
        } catch (_) {}
      }

      // Fallback to client-side generated PDF
      final doc = await buildInvoicePdf(
        widget.invoice,
        _dateFormat,
        _currencyFormat,
      );
      final bytes = await doc.save();
      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'invoice-${widget.invoice.id}.pdf',
        );
      } else {
        await Printing.layoutPdf(onLayout: (format) => doc.save());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tạo/chia sẻ PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // PDF generation moved to `invoice_pdf_builder.dart`.

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final issued = _dateFormat.format(inv.issuedAt.toLocal());
    final paid = inv.paidAt != null
        ? _dateFormat.format(inv.paidAt!.toLocal())
        : '-';
    Color statusColor(String status) {
      switch (status.toLowerCase()) {
        case 'paid':
        case 'success':
          return Colors.green.shade600;
        case 'failed':
        case 'error':
          return Colors.red.shade600;
        default:
          return Colors.orange.shade700;
      }
    }

    final chipColor = statusColor(inv.status);
    String statusLabel(String status) {
      // prefer explicit display text from API when available
      if (widget.invoice.statusDisplay != null &&
          widget.invoice.statusDisplay!.isNotEmpty) {
        return widget.invoice.statusDisplay!;
      }
      switch (status.toLowerCase()) {
        case 'paid':
        case 'success':
          return L10nVi.statusPaid;
        case 'failed':
        case 'error':
          return L10nVi.statusFailed;
        default:
          return status[0].toUpperCase() + status.substring(1);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(L10nVi.invoiceDisplayTitle(inv.id))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InvoiceDetailHeader(
                invoice: inv,
                issued: issued,
                paid: paid,
                statusLabel: statusLabel(inv.status),
                chipColor: chipColor,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: inv.id));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(L10nVi.copiedInvoiceId)),
                    );
                  }
                },
              ),

              InvoiceDetailSummary(
                invoice: inv,
                paidText: paid,
                totalText: _currencyFormat.format(inv.totalAmount),
              ),

              const SizedBox(height: 20),

              InvoiceDetailMetadata(
                planName: widget.invoice.planName,
                description: widget.invoice.description,
              ),

              InvoiceDetailLineItems(
                lineItems: inv.lineItems,
                formatCurrency: (v) => _currencyFormat.format(v),
              ),

              const SizedBox(height: 24),

              InvoiceDetailActions(
                busy: _busy,
                onDownload: () => _handleShareOrDownload(share: false),
                onShare: () => _handleShareOrDownload(share: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
