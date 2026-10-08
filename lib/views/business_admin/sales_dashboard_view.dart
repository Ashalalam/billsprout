import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/invoice_model.dart';
import '../../providers/accounting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/subscription/subscription_status_widget.dart';

class SalesDashboardView extends StatefulWidget {
  const SalesDashboardView({super.key});

  @override
  State<SalesDashboardView> createState() => _SalesDashboardViewState();
}

class _SalesDashboardViewState extends State<SalesDashboardView> {
  String _period = 'Today'; // Today | This Week | This Month | All Time

  @override
  void initState() {
    super.initState();
    // Refresh sales data when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounting = Provider.of<AccountingProvider>(context, listen: false);
      accounting.refreshSalesData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounting = Provider.of<AccountingProvider>(context);
    final inventory  = Provider.of<InventoryProvider>(context);
    final tt = Theme.of(context).textTheme;

    final invoices = _filteredInvoices(accounting.salesInvoices);

    // -- Computed KPIs --------------------------------------------------------
    final totalRevenue  = invoices.fold<double>(0, (s, i) => s + i.grandTotal);
    final totalGst      = invoices.fold<double>(0, (s, i) => s + i.totalTax);
    final totalInvoices = invoices.length;
    final avgOrderValue = totalInvoices > 0 ? totalRevenue / totalInvoices : 0.0;

    // -- Payment mode breakdown -----------------------------------------------
    final Map<String, double> paymentBreakdown = {};
    for (final inv in invoices) {
      final key = inv.paymentMode.name.toUpperCase();
      paymentBreakdown[key] = (paymentBreakdown[key] ?? 0) + inv.grandTotal;
    }

    // -- Top selling products --------------------------------------------------
    final Map<String, double> productSales = {};
    for (final inv in invoices) {
      for (final item in inv.items) {
        final name = item.product.name;
        productSales[name] =
            (productSales[name] ?? 0) + item.lineTotal;
      }
    }
    final topProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topProducts.take(5).toList();

    // -- Hourly/daily bar chart data -------------------------------------------
    final barData = _buildBarData(invoices);

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SingleChildScrollView(
        padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Subscription Status -----------------------------------------
            const SubscriptionStatusWidget(),
            const SizedBox(height: 16),
            
            // -- Header ------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Dashboard',
                        style: tt.headlineLarge?.copyWith(
                            color: AppTheme.primaryBlue)),
                    Text(
                      'Real-time sales performance & revenue analytics',
                      style: tt.bodyMedium
                          ?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
                // Period filter
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Today', 'This Week', 'This Month', 'All Time']
                        .map((p) => _PeriodBtn(
                              label: p,
                              active: _period == p,
                              onTap: () => setState(() => _period = p),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // -- KPI Cards ----------------------------------------------------
            LayoutBuilder(builder: (ctx, cons) {
              final cols = cons.maxWidth < 500 ? 2 : 4;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cons.maxWidth < 500 ? 1.6 : 2.0,
                children: [
                  _KpiCard(
                    label: 'Total Revenue',
                    value: '?${_fmt(totalRevenue)}',
                    icon: Icons.currency_rupee,
                    color: AppTheme.primaryBlue,
                    sub: _period,
                  ),
                  _KpiCard(
                    label: 'Total Invoices',
                    value: '$totalInvoices',
                    icon: Icons.receipt_long,
                    color: AppTheme.successGreen,
                    sub: 'Bills raised',
                  ),
                  _KpiCard(
                    label: 'GST Collected',
                    value: '?${_fmt(totalGst)}',
                    icon: Icons.account_balance,
                    color: AppTheme.accentOrange,
                    sub: 'Output tax',
                  ),
                  _KpiCard(
                    label: 'Avg. Order Value',
                    value: '?${_fmt(avgOrderValue)}',
                    icon: Icons.trending_up,
                    color: const Color(0xFF7C3AED),
                    sub: 'Per invoice',
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),

            // -- Charts row ---------------------------------------------------
            LayoutBuilder(builder: (ctx, cons) {
              final isNarrow = cons.maxWidth < Bp.mobile;
              final charts = [
                // Bar chart — revenue over time
                Expanded(
                  flex: 3,
                  child: _SectionCard(
                    title: 'Revenue Over Time',
                    subtitle: _period,
                    child: SizedBox(
                      height: 200,
                      child: barData.isEmpty
                          ? _emptyChart('Make a sale to see revenue chart')
                          : BarChart(BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: barData.isEmpty
                                  ? 1
                                  : barData
                                          .map((e) => e.toY)
                                          .reduce((a, b) =>
                                              a > b ? a : b) *
                                      1.3,
                              barGroups: barData
                                  .asMap()
                                  .entries
                                  .map((e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: e.value.toY,
                                            color: AppTheme.primaryBlue,
                                            width: 16,
                                            borderRadius:
                                                const BorderRadius
                                                    .vertical(
                                              top: Radius.circular(4),
                                            ),
                                          ),
                                        ],
                                      ))
                                  .toList(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, _) =>
                                        Text(
                                      barData[v.toInt()].label,
                                      style: tt.labelSmall,
                                    ),
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    getTitlesWidget: (v, _) => Text(
                                      '?${v.toInt()}',
                                      style: tt.labelSmall,
                                    ),
                                    interval: barData.isEmpty
                                        ? 1
                                        : barData
                                                .map((e) => e.toY)
                                                .reduce((a, b) =>
                                                    a > b ? a : b) /
                                            4,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                              ),
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) =>
                                    FlLine(
                                  color: Colors.grey.shade100,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (g, gi, rod, ri) =>
                                      BarTooltipItem(
                                    '?${rod.toY.toStringAsFixed(0)}',
                                    TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          tt.labelMedium?.fontSize ?? 12,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                    ),
                  ),
                ),

                SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),

                // Pie chart — payment breakdown
                Expanded(
                  flex: 2,
                  child: _SectionCard(
                    title: 'Payment Methods',
                    subtitle: '${paymentBreakdown.length} modes',
                    child: SizedBox(
                      height: 200,
                      child: paymentBreakdown.isEmpty
                          ? _emptyChart('No payment data yet')
                          : _PaymentPieChart(breakdown: paymentBreakdown),
                    ),
                  ),
                ),
              ];

              return isNarrow
                  ? Column(children: charts)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: charts);
            }),
            const SizedBox(height: 20),

            // -- Bottom row: Top products + Recent invoices --------------------
            LayoutBuilder(builder: (ctx, cons) {
              final isNarrow = cons.maxWidth < Bp.mobile;
              final widgets = [
                // Top selling products
                Expanded(
                  flex: 2,
                  child: _SectionCard(
                    title: 'Top Selling Products',
                    subtitle: 'By revenue',
                    child: top5.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No sales recorded yet.',
                                style: tt.bodyMedium?.copyWith(
                                    color: AppTheme.textMuted)),
                          )
                        : Column(
                            children:
                                top5.asMap().entries.map((entry) {
                              final rank  = entry.key + 1;
                              final name  = entry.value.key;
                              final rev   = entry.value.value;
                              final pct   = totalRevenue > 0
                                  ? rev / totalRevenue
                                  : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6),
                                child: Row(
                                  children: [
                                    // Rank badge
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: rank == 1
                                            ? AppTheme.accentOrange
                                                .withOpacity(0.15)
                                            : AppTheme.primaryBlue
                                                .withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('$rank',
                                            style: tt.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: rank == 1
                                                    ? AppTheme.accentOrange
                                                    : AppTheme.primaryBlue)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: tt.labelMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          const SizedBox(height: 3),
                                          LinearProgressIndicator(
                                            value: pct,
                                            backgroundColor:
                                                Colors.grey.shade100,
                                            color: AppTheme.primaryBlue,
                                            minHeight: 4,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('?${_fmt(rev)}',
                                        style: tt.labelMedium?.copyWith(
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),

                SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),

                // Recent invoices
                Expanded(
                  flex: 3,
                  child: _SectionCard(
                    title: 'Recent Invoices',
                    subtitle: '${invoices.length} records',
                    action: invoices.isEmpty
                        ? null
                        : TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.download, size: 14),
                            label: Text('Export',
                                style: tt.labelMedium?.copyWith(
                                    color: AppTheme.primaryBlue)),
                          ),
                    child: invoices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No invoices yet.\nGo to POS Billing to make your first sale.',
                                  textAlign: TextAlign.center,
                                  style: tt.bodyMedium?.copyWith(
                                      color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount:
                                invoices.length > 10 ? 10 : invoices.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: AppTheme.dividerColor),
                            itemBuilder: (ctx, i) {
                              // newest first
                              final inv =
                                  invoices[invoices.length - 1 - i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: inv.containsRestrictedDrugs
                                      ? AppTheme.errorRed.withOpacity(0.1)
                                      : AppTheme.primaryBlue
                                          .withOpacity(0.08),
                                  child: Icon(
                                    inv.containsRestrictedDrugs
                                        ? Icons.security
                                        : Icons.receipt,
                                    size: 16,
                                    color: inv.containsRestrictedDrugs
                                        ? AppTheme.errorRed
                                        : AppTheme.primaryBlue,
                                  ),
                                ),
                                title: Text(
                                  '${inv.invoiceNumber}  •  ${inv.customerName}',
                                  style: tt.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${_timeAgo(inv.timestamp)}  •  '
                                  '${inv.paymentMode.name.toUpperCase()}  •  '
                                  '${inv.items.length} item${inv.items.length == 1 ? '' : 's'}',
                                  style: tt.labelSmall,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '?${inv.grandTotal.toStringAsFixed(2)}',
                                      style: tt.labelLarge?.copyWith(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: inv.isSynced
                                            ? AppTheme.successGreen
                                                .withOpacity(0.1)
                                            : AppTheme.warningAmber
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        inv.isSynced ? '? Synced' : '? Local',
                                        style: tt.labelSmall?.copyWith(
                                          color: inv.isSynced
                                              ? AppTheme.successGreen
                                              : AppTheme.warningAmber,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ];

              return isNarrow
                  ? Column(children: widgets)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widgets);
            }),
            const SizedBox(height: 20),

            // -- Low stock alert -----------------------------------------------
            Builder(builder: (ctx) {
              final lowStock = inventory.products
                  .where((p) => p.totalStock < 20)
                  .toList();
              if (lowStock.isEmpty) return const SizedBox.shrink();
              return _SectionCard(
                title: '? Low Stock Alert',
                subtitle: '${lowStock.length} product(s) below 20 units',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lowStock
                      .map((p) => Chip(
                            avatar: Icon(Icons.medication,
                                size: 14,
                                color: p.totalStock == 0
                                    ? AppTheme.errorRed
                                    : AppTheme.warningAmber),
                            label: Text(
                              '${p.name} — ${p.totalStock} left',
                              style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: p.totalStock == 0
                                ? AppTheme.errorRed.withOpacity(0.08)
                                : AppTheme.warningAmber.withOpacity(0.08),
                            side: BorderSide(
                              color: p.totalStock == 0
                                  ? AppTheme.errorRed.withOpacity(0.4)
                                  : AppTheme.warningAmber.withOpacity(0.4),
                            ),
                          ))
                      .toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // -- Helpers ----------------------------------------------------------------
  List<InvoiceModel> _filteredInvoices(List<InvoiceModel> all) {
    final now = DateTime.now();
    return all.where((inv) {
      switch (_period) {
        case 'Today':
          return inv.timestamp.year == now.year &&
              inv.timestamp.month == now.month &&
              inv.timestamp.day == now.day;
        case 'This Week':
          final diff = now.difference(inv.timestamp).inDays;
          return diff <= 7;
        case 'This Month':
          return inv.timestamp.year == now.year &&
              inv.timestamp.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  List<_BarPoint> _buildBarData(List<InvoiceModel> invoices) {
    if (invoices.isEmpty) return [];
    if (_period == 'Today') {
      // Group by hour 0-23
      final Map<int, double> byHour = {};
      for (final inv in invoices) {
        final h = inv.timestamp.hour;
        byHour[h] = (byHour[h] ?? 0) + inv.grandTotal;
      }
      if (byHour.isEmpty) return [];
      return byHour.entries
          .map((e) => _BarPoint('${e.key}h', e.value))
          .toList()
        ..sort((a, b) => int.parse(a.label.replaceAll('h', ''))
            .compareTo(int.parse(b.label.replaceAll('h', ''))));
    } else {
      // Group by day
      final Map<String, double> byDay = {};
      for (final inv in invoices) {
        final key =
            '${inv.timestamp.day}/${inv.timestamp.month}';
        byDay[key] = (byDay[key] ?? 0) + inv.grandTotal;
      }
      if (byDay.isEmpty) return [];
      return byDay.entries
          .map((e) => _BarPoint(e.key, e.value))
          .toList();
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _emptyChart(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Payment Pie Chart
// -----------------------------------------------------------------------------
class _PaymentPieChart extends StatelessWidget {
  final Map<String, double> breakdown;
  const _PaymentPieChart({required this.breakdown});

  static const _colors = [
    AppTheme.primaryBlue,
    AppTheme.accentOrange,
    AppTheme.successGreen,
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = breakdown.values.fold<double>(0, (s, v) => s + v);
    final entries = breakdown.entries.toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 32,
              sections: entries.asMap().entries.map((e) {
                final pct = e.value.value / total * 100;
                return PieChartSectionData(
                  color: _colors[e.key % _colors.length],
                  value: e.value.value,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colors[e.key % _colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value.key,
                          style: tt.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('?${e.value.value.toStringAsFixed(0)}',
                          style: tt.labelSmall
                              ?.copyWith(color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Shared small widgets
// -----------------------------------------------------------------------------
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: tt.labelSmall
                      ?.copyWith(color: AppTheme.textMuted)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: tt.headlineSmall?.copyWith(
                  color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: tt.labelSmall),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: tt.labelSmall
                              ?.copyWith(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Divider(height: 14, color: AppTheme.dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: active ? Colors.white : AppTheme.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BarPoint {
  final String label;
  final double toY;
  const _BarPoint(this.label, this.toY);
}
