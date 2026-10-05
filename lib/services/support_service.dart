import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/invoice_model.dart';

class SupportService {
  static Future<void> openWhatsApp({String? text}) async {
    final String encodedText = Uri.encodeComponent(text ?? 'Hello LIFESPROUT Care Team, I would like to inquire about BillSprout ERP.');
    final Uri url = Uri.parse('${AppConfig.whatsappLink}?text=$encodedText');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch WhatsApp URL: $url');
    }
  }

  static Future<void> sendEmail({required String recipientEmail, String? subject, String? body}) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Could not launch Email app');
    }
  }

  static Future<void> shareInvoiceWhatsApp(InvoiceModel invoice) async {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *BILLSPROUT INVOICE RECEIPT*');
    buffer.writeln('🏢 *${AppConfig.companyName}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('Invoice No: ${invoice.invoiceNumber}');
    buffer.writeln('Customer: ${invoice.customerName}');
    buffer.writeln('Date: ${invoice.timestamp.day}/${invoice.timestamp.month}/${invoice.timestamp.year}');
    buffer.writeln('--------------------------------');
    for (var item in invoice.items) {
      buffer.writeln('• ${item.product.name} (Batch: ${item.batch.batchNumber})');
      // Use quantityDisplay to show compound quantities like "2 Strips + 5 Tablets"
      buffer.writeln('   ${item.quantityDisplay} @ ₹${item.unitPrice.toStringAsFixed(2)} = ₹${item.lineTotal.toStringAsFixed(2)}');
      if (item.freeQuantity > 0) {
        buffer.writeln('   (+ ${item.freeQuantity} FREE)');
      }
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Grand Total: ₹${invoice.grandTotal.toStringAsFixed(2)}');
    buffer.writeln('Payment Mode: ${invoice.paymentMode.name.toUpperCase()}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Thank you for choosing Lifesprout Care! 🌟');
    buffer.writeln('For Support: ${AppConfig.whatsappSupportNumber} | ${AppConfig.customerCareEmail}');

    final String encodedText = Uri.encodeComponent(buffer.toString());
    final Uri url = Uri.parse('https://wa.me/${invoice.customerPhone.replaceAll(RegExp(r'\D'), '')}?text=$encodedText');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
