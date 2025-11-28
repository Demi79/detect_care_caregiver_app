import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/features/subscription/models/invoice.dart';
import 'package:detect_care_caregiver_app/l10n/vi.dart';

/// Builds a PDF document for an [Invoice].
///
/// This extracts the PDF generation logic out of the screen so it's testable
/// and easier to reuse.
Future<pw.Document> buildInvoicePdf(
  Invoice inv,
  DateFormat dateFormat,
  NumberFormat currencyFormat,
) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Hóa đơn #${inv.id}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${L10nVi.issuedDate}: ${dateFormat.format(inv.issuedAt.toLocal())}',
          ),
          pw.Text(
            '${L10nVi.paidDate}: ${inv.paidAt != null ? dateFormat.format(inv.paidAt!.toLocal()) : '-'}',
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${L10nVi.total}: ${currencyFormat.format(inv.totalAmount)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (inv.taxAmount != null)
            pw.Text(
              '${L10nVi.tax}: ${currencyFormat.format(inv.taxAmount)}${inv.taxRate != null ? ' (${(inv.taxRate! * 100).toStringAsFixed(2)}%)' : ''}',
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            L10nVi.details,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...inv.lineItems.map((item) {
            final Map<String, dynamic> li = Map<String, dynamic>.from(item);
            final name = (li['name'] ?? li['title'] ?? '-').toString();
            final qty = li['quantity'] ?? li['qty'] ?? 1;
            final unitPrice =
                li['unit_price'] ?? li['unitPrice'] ?? li['price'] ?? 0;
            final total =
                li['total'] ??
                li['amount'] ??
                (unitPrice is num ? unitPrice * (qty is num ? qty : 1) : 0);
            final desc = li['description'] ?? li['desc'] ?? '';

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('${L10nVi.qty}: ${qty.toString()}'),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '${L10nVi.unitPrice}: ${currencyFormat.format(unitPrice)}',
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '${L10nVi.lineTotal}: ${currencyFormat.format(total)}',
                        ),
                      ),
                    ],
                  ),
                  if (desc.toString().isNotEmpty) pw.SizedBox(height: 6),
                  if (desc.toString().isNotEmpty)
                    pw.Text('${L10nVi.description}: $desc'),
                ],
              ),
            );
          }),
        ];
      },
    ),
  );

  return doc;
}
