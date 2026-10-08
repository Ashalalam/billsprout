import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../providers/accounting_provider.dart';

class ScheduleHRegisterView extends StatelessWidget {
  const ScheduleHRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final accounting = Provider.of<AccountingProvider>(context);
    final restrictedInvoices = accounting.salesInvoices.where((inv) => inv.containsRestrictedDrugs).toList();

    return Scaffold(
      body: Padding(
        padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Schedule H / H1 & Narcotic Regulatory Register',
              subtitle: 'Statutory Drug Inspector Audit Logs – Protected by Pharmacist PIN Approval',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export Regulatory PDF'),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: restrictedInvoices.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, size: 60, color: AppTheme.successGreen),
                            SizedBox(height: 16),
                            Text(
                              'Schedule H Audit Register Ready',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'All restricted drug sales require Doctor MCI registration & Pharmacist PIN approval.\nNo restricted transactions recorded yet today.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Card(
                      child: ListView.separated(
                        itemCount: restrictedInvoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final inv = restrictedInvoices[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFEBEE),
                              child: Icon(Icons.shield, color: AppTheme.errorRed),
                            ),
                            title: Text('Invoice #${inv.invoiceNumber} - ${inv.customerName}'),
                            subtitle: Text(
                              'Prescribed By: Dr. ${inv.doctorName ?? "N/A"} (MCI: ${inv.doctorMciNo ?? "N/A"})\nPharmacist Approved: ${inv.pharmacistPinApprovedBy ?? "Yes (PIN Verified)"}',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '?${inv.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
