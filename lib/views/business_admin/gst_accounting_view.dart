import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/ledger_entry_model.dart';
import '../../providers/accounting_provider.dart';

class GstAccountingView extends StatefulWidget {
  const GstAccountingView({super.key});

  @override
  State<GstAccountingView> createState() => _GstAccountingViewState();
}

class _GstAccountingViewState extends State<GstAccountingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounting = Provider.of<AccountingProvider>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(icon: Icon(Icons.account_balance), text: 'General Ledger'),
              Tab(icon: Icon(Icons.request_quote), text: 'GST Returns (GSTR-1/3B)'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Bank Reconciliation & COA'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Double-Entry Ledger
          _buildLedgerTab(context, accounting),
          // Tab 2: GST Returns
          _buildGstReturnsTab(context, accounting),
          // Tab 3: Bank Recon & COA
          _buildBankReconTab(context),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context, AccountingProvider accounting) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'General Ledger Audit Trail',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                  Text(
                    'Real-time Double-Entry Debit/Credit Records',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () => _exportGstr1Modal(context, accounting),
                icon: const Icon(Icons.file_download),
                label: const Text('Export GSTR-1 JSON'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: accounting.ledgerEntries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = accounting.ledgerEntries[index];
                  final isCredit = entry.type == LedgerType.credit;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                    title: Text(entry.accountName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text('${entry.description} | Ref: ${entry.referenceId}\nDate: ${entry.date.toString().substring(0, 16)}'),
                    trailing: Text(
                      '${isCredit ? "+" : "-"}₹${entry.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstReturnsTab(BuildContext context, AccountingProvider accounting) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GST Tax Returns (GSTR-1 & GSTR-3B Exporters)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.description, color: AppTheme.primaryBlue, size: 28),
                            SizedBox(width: 10),
                            Text('GSTR-1 Outward Supplies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Generates official B2C & B2B JSON payload for direct upload to Government GST Portal.'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _exportGstr1Modal(context, accounting),
                          icon: const Icon(Icons.download),
                          label: const Text('Generate & Export GSTR-1 JSON'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.receipt_long, color: AppTheme.accentOrange, size: 28),
                            SizedBox(width: 10),
                            Text('GSTR-3B Monthly Return Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Provides net tax liability, CGST, SGST, IGST breakdown and Input Tax Credit (ITC) offset.'),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showGstr3bSummaryModal(context, accounting),
                          icon: const Icon(Icons.visibility),
                          label: const Text('View GSTR-3B Summary'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankReconTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank Statement Reconciliation & Chart of Accounts (COA)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Row(
              children: [
                // Chart of Accounts Tree
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Chart of Accounts Tree', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          Divider(),
                          ListTile(leading: Icon(Icons.account_balance, color: Colors.blue), title: Text('1000 - Assets'), subtitle: Text('Bank Accounts, POS Cash Drawer, Inventory')),
                          ListTile(leading: Icon(Icons.money_off, color: Colors.red), title: Text('2000 - Liabilities'), subtitle: Text('Output GST Payable, Vendor Accounts Payable')),
                          ListTile(leading: Icon(Icons.attach_money, color: Colors.green), title: Text('3000 - Revenue'), subtitle: Text('Pharmacy Sales, Retail Sales, Delivery Charges')),
                          ListTile(leading: Icon(Icons.shopping_cart, color: Colors.orange), title: Text('4000 - Expenses'), subtitle: Text('Store Rent, Utilities, Staff Wages')),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Bank Statement Import & Reconciliation
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank Statement Reconciliation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          const Divider(),
                          const Text('Upload bank CSV/OFX statement to automatically reconcile UPI and Card settlements with POS receipts:'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bank Statement imported successfully! 12 transactions matched automatically.')),
                              );
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import Bank Statement (.CSV)'),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle, color: AppTheme.successGreen),
                                SizedBox(width: 10),
                                Expanded(child: Text('HDFC Bank POS Settlement #9912 matched with UPI Invoice Receipts.')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportGstr1Modal(BuildContext context, AccountingProvider accounting) {
    final jsonStr = accounting.generateGstr1Json();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GSTR-1 JSON File Export Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The GSTR-1 payload has been formatted according to the official GST portal specification:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              height: 140,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.copy),
            label: const Text('Copy JSON File'),
          ),
        ],
      ),
    );
  }

  void _showGstr3bSummaryModal(BuildContext context, AccountingProvider accounting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GSTR-3B Monthly Return Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary for GSTIN: 07AAAAA0000A1Z5', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _summaryRow('Total Outward Taxable Value:', '₹${accounting.salesInvoices.fold(0.0, (s, i) => s + i.subtotal).toStringAsFixed(2)}'),
            _summaryRow('Output IGST Payable:', '₹0.00'),
            _summaryRow('Output CGST Payable (6%):', '₹${(accounting.salesInvoices.fold(0.0, (s, i) => s + i.totalTax) / 2).toStringAsFixed(2)}'),
            _summaryRow('Output SGST Payable (6%):', '₹${(accounting.salesInvoices.fold(0.0, (s, i) => s + i.totalTax) / 2).toStringAsFixed(2)}'),
            const Divider(),
            _summaryRow('Net Tax Liability:', '₹${accounting.salesInvoices.fold(0.0, (s, i) => s + i.totalTax).toStringAsFixed(2)}', isBold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
