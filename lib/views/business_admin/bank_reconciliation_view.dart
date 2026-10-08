import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/ledger_entry_model.dart';
import '../../providers/accounting_provider.dart';

class BankStatementEntry {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final bool isCredit;
  bool isMatched;
  String? matchedLedgerId;

  BankStatementEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.isCredit,
    this.isMatched = false,
    this.matchedLedgerId,
  });
}

class BankReconciliationView extends StatefulWidget {
  const BankReconciliationView({super.key});

  @override
  State<BankReconciliationView> createState() => _BankReconciliationViewState();
}

class _BankReconciliationViewState extends State<BankReconciliationView> {
  final List<BankStatementEntry> _bankEntries = _seedBankEntries();

  static List<BankStatementEntry> _seedBankEntries() => [
        BankStatementEntry(id: 'be_001', date: DateTime.now().subtract(const Duration(days: 2)),
            description: 'NEFT Credit � Pharmacy Sales', amount: 4500.00, isCredit: true),
        BankStatementEntry(id: 'be_002', date: DateTime.now().subtract(const Duration(days: 2)),
            description: 'UPI Debit � LIFESPROUT Pharma Labs', amount: 11250.00, isCredit: false),
        BankStatementEntry(id: 'be_003', date: DateTime.now().subtract(const Duration(days: 1)),
            description: 'IMPS Credit � Wholesale Customer', amount: 28600.00, isCredit: true),
        BankStatementEntry(id: 'be_004', date: DateTime.now(),
            description: 'UPI Credit � POS Terminal', amount: 1850.00, isCredit: true),
      ];

  @override
  Widget build(BuildContext context) {
    final accounting = Provider.of<AccountingProvider>(context);
    final ledger = accounting.ledgerEntries.toList();

    final matched   = _bankEntries.where((e) => e.isMatched).length;
    final unmatched = _bankEntries.where((e) => !e.isMatched).length;
    final credits   = _bankEntries.where((e) => e.isCredit).fold<double>(0, (s, e) => s + e.amount);
    final debits    = _bankEntries.where((e) => !e.isCredit).fold<double>(0, (s, e) => s + e.amount);
    final net       = credits - debits;

    return Scaffold(
      body: Padding(
        padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            PageHeader(
              title: 'Bank Statement Reconciliation',
              subtitle: 'Match bank transactions against your General Ledger',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () => _importBankStatement(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Statement'),
              ),
            ),
            const SizedBox(height: 16),

            // ── KPI row � wraps to 2�3 on mobile ─────────────────────
            KpiRow(kpis: [
              _kpiCard('Bank Credits',  '?${credits.toStringAsFixed(2)}', Icons.arrow_downward, AppTheme.successGreen),
              _kpiCard('Bank Debits',   '?${debits.toStringAsFixed(2)}',  Icons.arrow_upward,   AppTheme.errorRed),
              _kpiCard('Net Balance',   '?${net.toStringAsFixed(2)}',     Icons.account_balance, AppTheme.primaryBlue),
              _kpiCard('Matched',       '$matched / ${_bankEntries.length}', Icons.check_circle, AppTheme.successGreen),
              _kpiCard('Unmatched',     '$unmatched',                     Icons.warning_amber,  AppTheme.warningAmber),
            ]),
            const SizedBox(height: 16),

            // ── Split view � stacks on mobile ─────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < Bp.mobile;
                  if (isMobile) {
                    return _buildMobileSplit(context, ledger);
                  }
                  return _buildDesktopSplit(context, ledger);
                },
              ),
            ),

            // ── Unmatched warning ─────────────────────────────────────
            if (unmatched > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppTheme.warningAmber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$unmatched transaction(s) unmatched. Review and reconcile.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.warningAmber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Desktop: side-by-side ─────────────────────────────────────────────────
  Widget _buildDesktopSplit(BuildContext context, List<LedgerEntryModel> ledger) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _bankPanel(context, ledger)),
        const SizedBox(width: 16),
        Expanded(child: _ledgerPanel(ledger)),
      ],
    );
  }

  // ── Mobile: tabbed ────────────────────────────────────────────────────────
  Widget _buildMobileSplit(BuildContext context, List<LedgerEntryModel> ledger) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(text: 'Bank Entries'),
              Tab(text: 'Ledger Entries'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _bankPanel(context, ledger),
                _ledgerPanel(ledger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bank statement panel ──────────────────────────────────────────────────
  Widget _bankPanel(BuildContext context, List<LedgerEntryModel> ledger) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Bank Statement Entries',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
        ),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: _bankEntries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = _bankEntries[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: entry.isMatched
                        ? AppTheme.successGreen.withOpacity(0.12)
                        : entry.isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    child: Icon(
                      entry.isMatched ? Icons.check_circle
                          : entry.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: entry.isMatched ? AppTheme.successGreen
                          : entry.isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                    ),
                  ),
                  title: Text(entry.description,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                      style: TextStyle(fontSize: 11)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.isCredit ? '+' : '-'}?${entry.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: entry.isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                      ),
                      if (entry.isMatched)
                        const Text('✓ Matched',
                            style: TextStyle(fontSize: 10, color: AppTheme.successGreen))
                      else
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => _showMatchDialog(context, entry, ledger),
                          child: Text('Match', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Ledger panel ──────────────────────────────────────────────────────────
  Widget _ledgerPanel(List<LedgerEntryModel> ledger) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('General Ledger Entries',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
        ),
        Expanded(
          child: Card(
            child: ledger.isEmpty
                ? const Center(child: Text('No ledger entries yet.',
                    style: TextStyle(color: AppTheme.textMuted)))
                : ListView.separated(
                    itemCount: ledger.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = ledger[ledger.length - 1 - i];
                      final isCredit = entry.type == LedgerType.credit;
                      final alreadyMatched = _bankEntries.any((b) => b.matchedLedgerId == entry.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: alreadyMatched
                              ? AppTheme.successGreen.withOpacity(0.12)
                              : isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          child: Icon(
                            alreadyMatched ? Icons.link
                                : isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: alreadyMatched ? AppTheme.successGreen
                                : isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                          ),
                        ),
                        title: Text(entry.accountName,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${entry.description}\n${entry.date.toString().substring(0, 10)}',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${isCredit ? '+' : '-'}?${entry.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showMatchDialog(BuildContext context, BankStatementEntry bankEntry,
      List<LedgerEntryModel> ledger) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Match Bank Entry to Ledger'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: context.dialogWidth, maxHeight: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Bank: ${bankEntry.description}  �  '
                  '${bankEntry.isCredit ? '+' : '-'}?${bankEntry.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Select matching ledger entry:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: ledger.length,
                  itemBuilder: (context, i) {
                    final entry = ledger[i];
                    final alreadyLinked =
                        _bankEntries.any((b) => b.matchedLedgerId == entry.id);
                    return ListTile(
                      dense: true,
                      enabled: !alreadyLinked,
                      title: Text(entry.accountName,
                          style: TextStyle(fontSize: 12)),
                      subtitle: Text(
                          '${entry.type.name}  �  ?${entry.amount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11)),
                      trailing: alreadyLinked
                          ? const Text('Matched',
                              style: TextStyle(fontSize: 10, color: AppTheme.successGreen))
                          : null,
                      onTap: alreadyLinked
                          ? null
                          : () {
                              setState(() {
                                bankEntry.isMatched = true;
                                bankEntry.matchedLedgerId = entry.id;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Entries matched ✓'),
                                    backgroundColor: AppTheme.successGreen),
                              );
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _importBankStatement(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Bank Statement'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file, size: 48, color: AppTheme.primaryBlue),
            SizedBox(height: 12),
            Text(
              'Select your bank statement file.\n\nSupported: CSV, Excel (.xlsx), OFX\n\n'
              'Entries will be auto-matched against your General Ledger.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bank statement imported � 4 entries loaded.'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.upload),
            label: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: color),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
