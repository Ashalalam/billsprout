import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_config.dart';
import '../models/invoice_model.dart';
import '../providers/company_profile_provider.dart';

class PrintingService {
  /// Renders a customer-facing TAX INVOICE (Reference Image 1 style)
  /// Professional pharmacy invoice with logo, WhatsApp, prescription details
  static Future<Uint8List> generateTaxInvoicePdf(
    InvoiceModel invoice, {
    required CompanyProfile profile,
  }) async {
    final pdf = pw.Document();

    // Load logo - try custom logo first, then fallback to default LifeSprout logo
    pw.ImageProvider? logoImage;
    if (profile.logoPath != null && profile.logoPath!.isNotEmpty) {
      try {
        final file = File(profile.logoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        // Custom logo loading failed, try default logo
      }
    }
    
    // Fallback to bundled LifeSprout logo
    if (logoImage == null) {
      try {
        final bytes = await rootBundle.load('assets/images/lifesprout_logo.png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        // Default logo also failed, continue without logo
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ══════════════════════════════════════════════════════════════
              // HEADER - Logo, Company Info, Invoice Details
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left - Logo + Company Info
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Logo + Pharmacy Name
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (logoImage != null) ...[
                              pw.Container(
                                width: 50,
                                height: 50,
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              ),
                              pw.SizedBox(width: 10),
                            ],
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    profile.pharmacyName,
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blue900,
                                    ),
                                  ),
                                  if (profile.ownerName.isNotEmpty)
                                    pw.Text(
                                      profile.ownerName,
                                      style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        
                        // Address
                        if (profile.fullAddress.isNotEmpty)
                          pw.Text(
                            profile.fullAddress,
                            style: const pw.TextStyle(fontSize: 9),
                            maxLines: 2,
                          ),
                        
                        // Contact Details
                        pw.SizedBox(height: 4),
                        if (profile.phone.isNotEmpty)
                          pw.Text('Phone: ${profile.phone}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (profile.whatsappNumber != null && profile.whatsappNumber!.isNotEmpty)
                          pw.Text('WhatsApp: ${profile.whatsappNumber}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.green800,
                                fontWeight: pw.FontWeight.bold,
                              )),
                        if (profile.email.isNotEmpty)
                          pw.Text(profile.email,
                              style: const pw.TextStyle(fontSize: 9)),
                        
                        pw.SizedBox(height: 4),
                        
                        // Legal Details
                        if (profile.gstin.isNotEmpty)
                          pw.Text('GSTIN: ${profile.gstin}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              )),
                        if (profile.drugLicenseNo.isNotEmpty)
                          pw.Text('Drug Licence: ${profile.drugLicenseNo}',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(width: 20),
                  
                  // Right - Invoice Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue900,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'TAX INVOICE',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildInfoRow('Invoice No:', invoice.invoiceNumber, isBold: true),
                      _buildInfoRow('Date:', 
                          '${invoice.timestamp.day.toString().padLeft(2, '0')}-${invoice.timestamp.month.toString().padLeft(2, '0')}-${invoice.timestamp.year}'),
                      _buildInfoRow('Time:', 
                          '${invoice.timestamp.hour.toString().padLeft(2, '0')}:${invoice.timestamp.minute.toString().padLeft(2, '0')}'),
                    ],
                  ),
                ],
              ),
              
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 10),

              // ══════════════════════════════════════════════════════════════
              // CUSTOMER & DOCTOR INFORMATION
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Billed To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              decoration: pw.TextDecoration.underline,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.customerName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            )),
                        if (invoice.customerPhone.isNotEmpty)
                          pw.Text('Phone: ${invoice.customerPhone}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (invoice.customerGstin != null)
                          pw.Text('GSTIN: ${invoice.customerGstin}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              )),
                      ],
                    ),
                  ),
                  
                  // Prescribed By (if available)
                  if (invoice.doctorName != null)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Prescribed By:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                decoration: pw.TextDecoration.underline,
                              )),
                          pw.SizedBox(height: 4),
                          pw.Text('Dr. ${invoice.doctorName}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              )),
                          if (invoice.doctorMciNo != null)
                            pw.Text('MCI Reg No: ${invoice.doctorMciNo}',
                                style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                ],
              ),
              
              pw.SizedBox(height: 12),

              // ══════════════════════════════════════════════════════════════
              // MEDICINE/ITEMS TABLE
              // ══════════════════════════════════════════════════════════════
              _buildItemsTable(invoice),
              
              pw.SizedBox(height: 12),

              // ══════════════════════════════════════════════════════════════
              // PAYMENT INFO & TOTALS
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left - Payment & Notes
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Payment Mode: ${invoice.paymentMode.name.toUpperCase()}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                )),
                            if (invoice.containsRestrictedDrugs && 
                                invoice.pharmacistPinApprovedBy != null)
                              pw.Text(
                                'Authorized Pharmacist PIN Verified: Yes',
                                style: pw.TextStyle(
                                  color: PdfColors.green900,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (invoice.hasFreeItems)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            '* Invoice includes promotional free goods',
                            style: const pw.TextStyle(
                              color: PdfColors.orange800,
                              fontSize: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Right - Amount Summary
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      children: [
                        _buildAmountRow('Subtotal:', invoice.subtotal),
                        if (invoice.totalLineDiscounts > 0)
                          _buildAmountRow('Item Discount:', -invoice.totalLineDiscounts,
                              color: PdfColors.red700),
                        if (invoice.effectiveDiscount > 0)
                          _buildAmountRow('Invoice Discount:', -invoice.effectiveDiscount,
                              color: PdfColors.red700),
                        _buildAmountRow('Taxable Amount:', 
                            invoice.grandTotal - invoice.totalTax),
                        _buildAmountRow('CGST:', 
                            invoice.items.fold<double>(0, (s, i) => s + i.cgst)),
                        _buildAmountRow('SGST:', 
                            invoice.items.fold<double>(0, (s, i) => s + i.sgst)),
                        if (invoice.cessAmount > 0)
                          _buildAmountRow('Cess:', invoice.cessAmount),
                        if (invoice.otherCharges > 0)
                          _buildAmountRow('Other Charges:', invoice.otherCharges),
                        _buildAmountRow('Round Off:', invoice.roundOff),
                        pw.Divider(thickness: 1.5),
                        _buildAmountRow('Grand Total:', invoice.payableTotal,
                            isBold: true, fontSize: 11),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 10),

              // ══════════════════════════════════════════════════════════════
              // AMOUNT IN WORDS
              // ══════════════════════════════════════════════════════════════
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Amount in Words: ${invoice.amountInWords}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              
              pw.Spacer(),

              // ══════════════════════════════════════════════════════════════
              // FOOTER - Terms, Signature, Thank You
              // ══════════════════════════════════════════════════════════════
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms & Conditions
                  if (profile.termsAndConditions != null &&
                      profile.termsAndConditions!.isNotEmpty)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Terms & Conditions:',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              )),
                          pw.Text(
                            profile.termsAndConditions!,
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Left - Pharmacist & Return Policy
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (invoice.pharmacistPinApprovedBy != null)
                            pw.Text(
                              'Dispensed by: ${invoice.pharmacistPinApprovedBy}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          pw.Text(
                            'Goods once sold are not returnable except as per policy.',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      
                      // Right - Signature
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(height: 20),
                          pw.Container(
                            width: 120,
                            height: 0.5,
                            color: PdfColors.grey800,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            profile.authorizedSignatory ?? 'Authorized Signatory',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'for ${profile.pharmacyName}',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 0.5),
                  pw.Center(
                    child: pw.Text(
                      'Thank you for choosing ${profile.pharmacyName} — Powered by ${AppConfig.appName}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildItemsTable(InvoiceModel invoice) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'S.N',
        'Item Description',
        'Batch',
        'Exp',
        'HSN',
        'Qty',
        'MRP',
        'Rate',
        'Disc',
        'Tax%',
        'Tax Amt',
        'Amount',
      ],
      data: List.generate(invoice.items.length, (idx) {
        final item = invoice.items[idx];
        final expFmt = '${item.batch.expDate.month.toString().padLeft(2, '0')}/${item.batch.expDate.year}';
        return [
          '${idx + 1}',
          '${item.product.name}\n${item.product.genericSalt}',
          item.batch.batchNumber,
          expFmt,
          item.product.hsnCode,
          item.quantityDisplay,
          '₹${item.batch.mrp.toStringAsFixed(2)}',
          '₹${item.unitPrice.toStringAsFixed(2)}',
          item.lineDiscount > 0 ? '₹${item.lineDiscount.toStringAsFixed(2)}' : '—',
          '${item.taxPercent.toStringAsFixed(0)}%',
          '₹${item.taxAmount.toStringAsFixed(2)}',
          '₹${item.lineTotal.toStringAsFixed(2)}',
        ];
      }),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 8,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      cellAlignments: {
        0: pw.Alignment.center,
        5: pw.Alignment.center,
        for (var i = 6; i < 12; i++) i: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(35),
        4: const pw.FixedColumnWidth(45),
        5: const pw.FixedColumnWidth(30),
      },
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label ',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
        ],
      ),
    );
  }

  static pw.Widget _buildAmountRow(String label, double amount,
      {bool isBold = false, double fontSize = 9, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: fontSize,
              )),
          pw.Text('₹${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: fontSize,
                color: color,
              )),
        ],
      ),
    );
  }

  /// Renders a detailed B2B GST BILL (Reference Image 2 style)
  /// Professional pharmaceutical invoice with pack/unit, discount%, GST summary by rate
  static Future<Uint8List> generateGstBillPdf(
    InvoiceModel invoice, {
    required CompanyProfile profile,
  }) async {
    final pdf = pw.Document();

    // Load logo - try custom logo first, then fallback to default LifeSprout logo
    pw.ImageProvider? logoImage;
    if (profile.logoPath != null && profile.logoPath!.isNotEmpty) {
      try {
        final file = File(profile.logoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        // Custom logo loading failed, try default logo
      }
    }
    
    // Fallback to bundled LifeSprout logo
    if (logoImage == null) {
      try {
        final bytes = await rootBundle.load('assets/images/lifesprout_logo.png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        // Default logo also failed, continue without logo
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ══════════════════════════════════════════════════════════════
              // HEADER - Logo, Company Info, GST BILL Title
              // ══════════════════════════════════════════════════════════════
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 1.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left - Logo + Company Info
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 50,
                            height: 50,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              profile.pharmacyName,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(profile.fullAddress,
                                style: const pw.TextStyle(fontSize: 8)),
                            if (profile.gstin.isNotEmpty)
                              pw.Text('GSTIN: ${profile.gstin}',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                            if (profile.drugLicenseNo.isNotEmpty)
                              pw.Text('D.L. No: ${profile.drugLicenseNo}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.panNumber != null)
                              pw.Text('PAN: ${profile.panNumber}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.phone.isNotEmpty)
                              pw.Text('Ph: ${profile.phone}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.whatsappNumber != null)
                              pw.Text('WhatsApp: ${profile.whatsappNumber}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.email.isNotEmpty)
                              pw.Text(profile.email,
                                  style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                    // Right - GST BILL Title + Invoice Details
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'GST BILL',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Divider(thickness: 1),
                        pw.Text('Invoice No: ${invoice.invoiceNumber}',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            'Date: ${invoice.timestamp.day.toString().padLeft(2, '0')}/${invoice.timestamp.month.toString().padLeft(2, '0')}/${invoice.timestamp.year}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                            'Time: ${invoice.timestamp.hour.toString().padLeft(2, '0')}:${invoice.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const pw.TextStyle(fontSize: 9)),
                        if (invoice.dueDate != null)
                          pw.Text(
                              'Due Date: ${invoice.dueDate!.day.toString().padLeft(2, '0')}/${invoice.dueDate!.month.toString().padLeft(2, '0')}/${invoice.dueDate!.year}',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // ══════════════════════════════════════════════════════════════
              // CUSTOMER & TRANSPORT DETAILS
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Billing To
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey600),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Billing To:',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.customerName,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                          if (invoice.billingAddress != null)
                            pw.Text(invoice.billingAddress!,
                                style: const pw.TextStyle(fontSize: 8)),
                          if (invoice.customerPhone.isNotEmpty)
                            pw.Text('Phone: ${invoice.customerPhone}',
                                style: const pw.TextStyle(fontSize: 8)),
                          if (invoice.customerGstin != null)
                            pw.Text('GSTIN: ${invoice.customerGstin}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Shipping To
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey600),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Shipping To:',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold)),
                          if (invoice.shippingAddress != null)
                            pw.Text(invoice.shippingAddress!,
                                style: const pw.TextStyle(fontSize: 8))
                          else
                            pw.Text('Same as Billing Address',
                                style: const pw.TextStyle(
                                    fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Transport Details
              if (invoice.lrNumber != null || invoice.transportDetails != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    children: [
                      if (invoice.lrNumber != null)
                        pw.Text('LR No: ${invoice.lrNumber}  ',
                            style: const pw.TextStyle(fontSize: 8)),
                      if (invoice.transportDetails != null)
                        pw.Text('Transport: ${invoice.transportDetails}',
                            style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              if (invoice.lrNumber != null || invoice.transportDetails != null)
                pw.SizedBox(height: 6),

              // ══════════════════════════════════════════════════════════════
              // ITEMS TABLE - Enhanced with Pack, Unit, Disc%
              // ══════════════════════════════════════════════════════════════
              pw.TableHelper.fromTextArray(
                headers: [
                  'S.No',
                  'Product Name\n& Generic',
                  'HSN',
                  'Batch',
                  'Exp',
                  'Pack',
                  'Unit',
                  'Qty',
                  'Free',
                  'MRP',
                  'Rate',
                  'Disc%',
                  'Disc Amt',
                  'GST%',
                  'Taxable',
                  'Tax Amt',
                  'Amount',
                ],
                data: List.generate(invoice.items.length, (idx) {
                  final item = invoice.items[idx];
                  final expFmt =
                      '${item.batch.expDate.month.toString().padLeft(2, '0')}/${item.batch.expDate.year}';
                  return [
                    '${idx + 1}',
                    '${item.product.name}\n${item.product.genericSalt}',
                    item.product.hsnCode,
                    item.batch.batchNumber,
                    expFmt,
                    item.product.packagingLabel,
                    item.unit ?? 'Units',
                    '${item.quantity}',
                    item.freeQuantity > 0 ? '${item.freeQuantity}' : '—',
                    item.batch.mrp.toStringAsFixed(2),
                    item.unitPrice.toStringAsFixed(2),
                    item.discountPercent != null
                        ? '${item.discountPercent!.toStringAsFixed(1)}%'
                        : '—',
                    item.lineDiscount > 0
                        ? item.lineDiscount.toStringAsFixed(2)
                        : '—',
                    '${item.taxPercent.toStringAsFixed(0)}%',
                    item.taxableValue.toStringAsFixed(2),
                    item.taxAmount.toStringAsFixed(2),
                    item.lineTotal.toStringAsFixed(2),
                  ];
                }),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 7,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellHeight: 18,
                cellAlignments: {
                  0: pw.Alignment.center,
                  7: pw.Alignment.center,
                  8: pw.Alignment.center,
                  for (var i = 9; i < 17; i++) i: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(30),
                  5: const pw.FixedColumnWidth(35),
                  6: const pw.FixedColumnWidth(32),
                  7: const pw.FixedColumnWidth(25),
                  8: const pw.FixedColumnWidth(25),
                },
              ),
              pw.SizedBox(height: 8),

              // ══════════════════════════════════════════════════════════════
              // AMOUNT SUMMARY & GST BREAKDOWN
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left - GST Summary by Rate
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GST Summary:',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 3),
                        _buildGstSummaryByRate(invoice),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Right - Amount Summary
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey600),
                        color: PdfColors.grey50,
                      ),
                      child: pw.Column(
                        children: [
                          _buildAmountRow('Subtotal:', invoice.subtotal),
                          if (invoice.totalLineDiscounts > 0)
                            _buildAmountRow(
                                'Item Discounts:', -invoice.totalLineDiscounts),
                          if (invoice.effectiveDiscount > 0)
                            _buildAmountRow('Invoice Discount:',
                                -invoice.effectiveDiscount),
                          _buildAmountRow('Taxable Amount:',
                              invoice.grandTotal - invoice.totalTax),
                          pw.Divider(thickness: 0.5),
                          _buildAmountRow('CGST:', invoice.totalTax / 2),
                          _buildAmountRow('SGST:', invoice.totalTax / 2),
                          _buildAmountRow('Total GST:', invoice.totalTax,
                              isBold: true),
                          if (invoice.cessAmount != null &&
                              invoice.cessAmount! > 0)
                            _buildAmountRow('Cess:', invoice.cessAmount!),
                          if (invoice.otherCharges != null &&
                              invoice.otherCharges! > 0)
                            _buildAmountRow('Other Charges:',
                                invoice.otherCharges!),
                          _buildAmountRow('Round Off:', invoice.roundOff),
                          pw.Divider(thickness: 1),
                          _buildAmountRow('Grand Total:', invoice.payableTotal,
                              isBold: true, fontSize: 11),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // ══════════════════════════════════════════════════════════════
              // AMOUNT IN WORDS
              // ══════════════════════════════════════════════════════════════
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  color: PdfColors.yellow50,
                ),
                child: pw.Text(
                  'Amount in Words: ${invoice.amountInWords}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),

              // ══════════════════════════════════════════════════════════════
              // BANK DETAILS & TERMS
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bank Details
                  if (profile.bankName != null || profile.accountNumber != null)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey600),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Bank Details:',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                            if (profile.bankName != null)
                              pw.Text('Bank: ${profile.bankName}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.accountNumber != null)
                              pw.Text('A/c No: ${profile.accountNumber}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.ifscCode != null)
                              pw.Text('IFSC: ${profile.ifscCode}',
                                  style: const pw.TextStyle(fontSize: 8)),
                            if (profile.bankBranch != null)
                              pw.Text('Branch: ${profile.bankBranch}',
                                  style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                    ),
                  pw.SizedBox(width: 8),
                  // Terms & Conditions
                  if (profile.termsAndConditions != null)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey600),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Terms & Conditions:',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(profile.termsAndConditions!,
                                style: const pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              pw.Spacer(),

              // ══════════════════════════════════════════════════════════════
              // PAYMENT & SIGNATURE
              // ══════════════════════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'Payment Mode: ${invoice.paymentMode.name.toUpperCase()}',
                          style: const pw.TextStyle(fontSize: 9)),
                      if (invoice.doctorName != null)
                        pw.Text('Prescribed By: Dr. ${invoice.doctorName}',
                            style: const pw.TextStyle(fontSize: 8)),
                      if (invoice.pharmacistPinApprovedBy != null)
                        pw.Text(
                            'Dispensed by: ${invoice.pharmacistPinApprovedBy}',
                            style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 30),
                      pw.Container(
                          width: 120, height: 0.7, color: PdfColors.grey800),
                      pw.SizedBox(height: 2),
                      pw.Text(
                          profile.authorizedSignatory ?? 'Authorised Signatory',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('for ${profile.pharmacyName}',
                          style: const pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business — Powered by ${AppConfig.appName}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Legacy method - kept for backward compatibility
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
    // Call the new enhanced TAX INVOICE template
    return generateTaxInvoicePdf(invoice, profile: profile);
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

  // ── GST Summary by Rate (for GST BILL) ────────────────────────────────────
  static pw.Widget _buildGstSummaryByRate(InvoiceModel invoice) {
    final Map<double, _GstRateRow> rateMap = {};
    for (final item in invoice.items) {
      rateMap.putIfAbsent(
          item.taxPercent,
          () => _GstRateRow(
                rate: item.taxPercent,
                taxableValue: 0,
                cgst: 0,
                sgst: 0,
              ));
      rateMap[item.taxPercent]!.taxableValue += item.taxableValue;
      rateMap[item.taxPercent]!.cgst += item.cgst;
      rateMap[item.taxPercent]!.sgst += item.sgst;
    }

    // Sort by rate
    final sortedRates = rateMap.keys.toList()..sort();

    return pw.TableHelper.fromTextArray(
      headers: ['GST Rate', 'Taxable Value', 'CGST Amt', 'SGST Amt', 'Total Tax'],
      data: sortedRates.map((rate) {
        final r = rateMap[rate]!;
        return [
          '${r.rate.toStringAsFixed(0)}%',
          '₹${r.taxableValue.toStringAsFixed(2)}',
          '₹${r.cgst.toStringAsFixed(2)}',
          '₹${r.sgst.toStringAsFixed(2)}',
          '₹${(r.cgst + r.sgst).toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
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
    String templateType = 'tax_invoice', // 'tax_invoice' or 'gst_bill'
  }) async {
    final Uint8List pdfBytes;
    
    if (templateType == 'gst_bill') {
      pdfBytes = await generateGstBillPdf(invoice, profile: profile);
    } else {
      pdfBytes = await generateTaxInvoicePdf(invoice, profile: profile);
    }
    
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

class _GstRateRow {
  final double rate;
  double taxableValue;
  double cgst;
  double sgst;

  _GstRateRow({
    required this.rate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
  });
}
