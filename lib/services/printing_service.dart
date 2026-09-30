import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_config.dart';
import '../models/invoice_model.dart';
import '../providers/company_profile_provider.dart';

class PrintingService {
  /// Renders a tax invoice.
  ///
  /// [profile] is the selling pharmacy's own registration details. It is
  /// required rather than optional: a tax invoice that prints the software
  /// vendor's name and no GSTIN is not a valid document, and making it optional
  /// invites a caller to silently fall back to that state.
  static Future<Uint8List> generateInvoicePdf(
    InvoiceModel invoice, {
    required CompanyProfile profile,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        profile.pharmacyName,
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900),
                      ),
                      if (profile.fullAddress.isNotEmpty)
                        pw.Text(profile.fullAddress,
                            style: const pw.TextStyle(fontSize: 9)),
                      if (profile.gstin.isNotEmpty)
                        pw.Text('GSTIN: ${profile.gstin}',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                      if (profile.drugLicenseNo.isNotEmpty)
                        pw.Text('Drug Licence: ${profile.drugLicenseNo}',
                            style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text('Branch: ${invoice.branch}',
                          style: const pw.TextStyle(fontSize: 10)),
                      if (profile.phone.isNotEmpty)
                        pw.Text('Phone: ${profile.phone}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (profile.email.isNotEmpty)
                        pw.Text(profile.email,
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        invoice.isWholesale
                            ? 'TAX INVOICE (WHOLESALE)'
                            : 'TAX INVOICE',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800),
                      ),
                      pw.Text('Invoice No: ${invoice.invoiceNumber}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Date: ${invoice.timestamp.toString().substring(0, 10)}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Time: ${invoice.timestamp.hour.toString().padLeft(2, '0')}:${invoice.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.indigo900),
              pw.SizedBox(height: 8),

              // ── Customer & Doctor ──────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Billed To:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                      pw.Text('Name: ${invoice.customerName}',
                          style: const pw.TextStyle(fontSize: 10)),
                      if (invoice.customerPhone.isNotEmpty)
                        pw.Text('Phone: ${invoice.customerPhone}',
                            style: const pw.TextStyle(fontSize: 10)),
                      if (invoice.customerGstin != null)
                        pw.Text('GSTIN: ${invoice.customerGstin}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (invoice.doctorName != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Prescribed By:',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10)),
                        pw.Text('Dr. ${invoice.doctorName}',
                            style: const pw.TextStyle(fontSize: 10)),
                        if (invoice.doctorMciNo != null)
                          pw.Text('MCI Reg: ${invoice.doctorMciNo}',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 12),

              // ── Item table ─────────────────────────────────────────────────
              pw.TableHelper.fromTextArray(
                headers: [
                  'S.No',
                  'Medicine / Item',
                  'HSN',
                  'Batch',
                  'Exp',
                  'Pack',
                  'Qty',
                  'Free',
                  'MRP (₹)',
                  // Trade invoices must show the rate actually charged (PTR)
                  // alongside MRP; a retail bill has no use for it.
                  if (invoice.isWholesale) 'PTR (₹)',
                  'Rate (₹)',
                  'Disc (₹)',
                  'GST%',
                  'Amt (₹)',
                ],
                data: List.generate(invoice.items.length, (idx) {
                  final item = invoice.items[idx];
                  final expFmt =
                      '${item.batch.expDate.month}/${item.batch.expDate.year}';
                  final packLabel = item.product.packagingLabel;
                  return [
                    '${idx + 1}',
                    '${item.product.name}\n${item.product.genericSalt}',
                    item.product.hsnCode,
                    item.batch.batchNumber,
                    expFmt,
                    packLabel,
                    '${item.quantity}',
                    item.freeQuantity > 0 ? '${item.freeQuantity}' : '—',
                    item.batch.mrp.toStringAsFixed(2),
                    if (invoice.isWholesale)
                      item.batch.ptrPrice > 0
                          ? item.batch.ptrPrice.toStringAsFixed(2)
                          : '—',
                    item.unitPrice.toStringAsFixed(2),
                    item.lineDiscount > 0
                        ? item.lineDiscount.toStringAsFixed(2)
                        : '—',
                    '${item.taxPercent.toStringAsFixed(0)}%',
                    item.lineTotal.toStringAsFixed(2),
                  ];
                }),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 8),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                // Indices shift by one when the wholesale PTR column is present,
                // so they are computed rather than hardcoded.
                cellAlignments: {
                  0: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.center,
                  for (var i = 8; i < (invoice.isWholesale ? 14 : 13); i++)
                    i: pw.Alignment.centerRight,
                },
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  2: const pw.FixedColumnWidth(46),
                  3: const pw.FixedColumnWidth(44),
                  4: const pw.FixedColumnWidth(34),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FixedColumnWidth(22),
                  7: const pw.FixedColumnWidth(24),
                },
              ),
              pw.SizedBox(height: 12),

              // ── Totals ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left — payment + pharmacist note
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'Payment Mode: ${invoice.paymentMode.name.toUpperCase()}',
                          style: const pw.TextStyle(fontSize: 10)),
                      if (invoice.containsRestrictedDrugs)
                        pw.Text(
                          'Authorised Pharmacist PIN Verified ✓',
                          style: pw.TextStyle(
                              color: PdfColors.green900,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9),
                        ),
                      if (invoice.hasFreeItems)
                        pw.Text(
                          'Includes promotional free goods.',
                          style: const pw.TextStyle(
                              color: PdfColors.orange800, fontSize: 9),
                        ),
                    ],
                  ),

                  // Right — amount summary
                  pw.Container(
                    width: 210,
                    child: pw.Column(
                      children: [
                        _pdfRow('Subtotal (before disc):',
                            '₹${(invoice.subtotal + invoice.effectiveDiscount + invoice.totalLineDiscounts).toStringAsFixed(2)}'),
                        if (invoice.totalLineDiscounts > 0)
                          _pdfRow('Item Discounts:',
                              '-₹${invoice.totalLineDiscounts.toStringAsFixed(2)}'),
                        if (invoice.effectiveDiscount > 0)
                          _pdfRow('Invoice Discount:',
                              '-₹${invoice.effectiveDiscount.toStringAsFixed(2)}'),
                        // Taxable value is derived from the payable minus the
                        // rounded GST so that taxable + GST reconciles to the
                        // grand total exactly, matching what DbMapper persists.
                        _pdfRow('Taxable Amount:',
                            '₹${(invoice.grandTotal - invoice.totalTax).toStringAsFixed(2)}'),
                        _pdfRow('CGST:',
                            '₹${invoice.items.fold<double>(0, (s, i) => s + i.cgst).toStringAsFixed(2)}'),
                        _pdfRow('SGST:',
                            '₹${invoice.items.fold<double>(0, (s, i) => s + i.sgst).toStringAsFixed(2)}'),
                        _pdfRow('Total GST:',
                            '₹${invoice.totalTax.toStringAsFixed(2)}'),
                        _pdfRow('Round Off:',
                            '₹${invoice.roundOff.toStringAsFixed(2)}'),
                        pw.Divider(),
                        _pdfRow(
                          'Grand Total:',
                          '₹${invoice.payableTotal.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // ── Amount in words (statutory) ────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: pw.Text(
                  'Amount in Words: ${invoice.amountInWords}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),

              // ── HSN summary table ──────────────────────────────────────────
              pw.Text('HSN-wise Tax Summary:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 4),
              _buildHsnSummary(invoice),
              pw.SizedBox(height: 10),

              // ── Signatory ──────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (invoice.pharmacistPinApprovedBy != null)
                        pw.Text(
                          'Dispensed under: ${invoice.pharmacistPinApprovedBy}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      pw.Text(
                        'Goods once sold are not returnable except as per policy.',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 26),
                      pw.Container(width: 150, height: 0.7,
                          color: PdfColors.grey600),
                      pw.SizedBox(height: 3),
                      pw.Text('Authorised Signatory',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('for ${profile.pharmacyName}',
                          style: const pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Thank you for trusting ${profile.pharmacyName} '
                  '— Powered by ${AppConfig.appName}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── HSN summary ────────────────────────────────────────────────────────────
  static pw.Widget _buildHsnSummary(InvoiceModel invoice) {
    final Map<String, _HsnRow> hsnMap = {};
    for (final item in invoice.items) {
      final key = '${item.product.hsnCode}|${item.taxPercent}';
      hsnMap.putIfAbsent(
          key,
          () => _HsnRow(
                hsn: item.product.hsnCode,
                rate: item.taxPercent,
                taxableValue: 0,
                cgst: 0,
                sgst: 0,
              ));
      hsnMap[key]!.taxableValue += item.taxableValue;
      hsnMap[key]!.cgst += item.cgst;
      hsnMap[key]!.sgst += item.sgst;
    }

    return pw.TableHelper.fromTextArray(
      headers: ['HSN Code', 'Tax Rate', 'Taxable Value', 'CGST', 'SGST', 'Total Tax'],
      data: hsnMap.values.map((r) => [
        r.hsn,
        '${r.rate.toStringAsFixed(0)}%',
        '₹${r.taxableValue.toStringAsFixed(2)}',
        '₹${r.cgst.toStringAsFixed(2)}',
        '₹${r.sgst.toStringAsFixed(2)}',
        '₹${(r.cgst + r.sgst).toStringAsFixed(2)}',
      ]).toList(),
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
    );
  }

  static pw.Row _pdfRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight:
                    isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 9)),
        pw.Text(value,
            style: pw.TextStyle(
                fontWeight:
                    isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 9)),
      ],
    );
  }

  static Future<void> printInvoice(
    InvoiceModel invoice, {
    required CompanyProfile profile,
  }) async {
    final pdfBytes = await generateInvoicePdf(invoice, profile: profile);
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes);
  }
}

class _HsnRow {
  final String hsn;
  final double rate;
  double taxableValue;
  double cgst;
  double sgst;
  _HsnRow({
    required this.hsn,
    required this.rate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
  });
}
