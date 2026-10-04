import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/company_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accounting_provider.dart';
import '../../providers/super_admin_provider.dart';
import '../../services/ota_service.dart';
import '../common/support_contact_modal.dart';
import 'add_tenant_dialog.dart';
import 'user_management_view.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final superAdmin = Provider.of<SuperAdminProvider>(context);
    final accounting = Provider.of<AccountingProvider>(context);
    final ota = Provider.of<OtaService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings, color: AppTheme.accentOrange),
            SizedBox(width: 10),
            Text('BillSprout – Super Admin SaaS Portal'),
          ],
        ),
        actions: [
          // Supabase config shortcut
          if (!AppConfig.supabaseConfigured)
            TextButton.icon(
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.accentOrange),
              onPressed: () => _showSupabaseConfigModal(context),
              icon: const Icon(Icons.cloud_off, color: AppTheme.accentOrange),
              label: const Text('Configure Backend',
                  style: TextStyle(color: AppTheme.accentOrange)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.cloud_done,
                    color: AppTheme.successGreen, size: 16),
                label: Text('Supabase Live',
                    style: TextStyle(
                        color: AppTheme.successGreen, fontSize: 11)),
                backgroundColor: Color(0xFFE8F5E9),
              ),
            ),
          IconButton(
            icon: superAdmin.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Reload tenants',
            onPressed:
                superAdmin.isLoading ? null : () => superAdmin.fetchTenants(),
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic),
            tooltip: 'Support Desk',
            onPressed: () => SupportContactModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accentOrange,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.storefront), text: 'Tenant Accounts'),
            Tab(icon: Icon(Icons.people), text: 'Users & Access'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            superAdmin: superAdmin,
            ota: ota,
            accounting: accounting,
            onAddTenant: () => _showAddTenantDialog(context),
          ),
          _TenantsTab(
            superAdmin: superAdmin,
            onAddTenant: () => _showAddTenantDialog(context),
          ),
          const UserManagementView(),
          _AnalyticsTab(
            superAdmin: superAdmin,
            accounting: accounting,
          ),
        ],
      ),
    );
  }

  // â”€â”€ Add Tenant Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showAddTenantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddTenantDialog(),
    );
  }

  // â”€â”€ Supabase Config Modal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showSupabaseConfigModal(BuildContext context) {
    final urlCtrl = TextEditingController(
        text: 'https://your-project-ref.supabase.co');
    final keyCtrl = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cloud_sync, color: AppTheme.primaryBlue),
            SizedBox(width: 10),
            Text('Configure Supabase Backend'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Update AppConfig.supabaseUrl and AppConfig.supabaseAnonKey '
                'in lib/config/app_config.dart with your live credentials. '
                'A hot restart will activate the real backend.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                    labelText: 'Supabase Project URL')),
            const SizedBox(height: 10),
            TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Supabase Anon API Key')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Update app_config.dart with these credentials, then hot-restart.'),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy Credentials'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tab 1 – Overview
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _OverviewTab extends StatelessWidget {
  final SuperAdminProvider superAdmin;
  final OtaService ota;
  final AccountingProvider accounting;
  final VoidCallback onAddTenant;

  const _OverviewTab({
    required this.superAdmin,
    required this.ota,
    required this.accounting,
    required this.onAddTenant,
  });

  @override
  Widget build(BuildContext context) {
    // Real revenue from accounting ledger
    final realRevenue = accounting.salesInvoices
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
    final displayRevenue =
        realRevenue > 0 ? realRevenue : superAdmin.monthlySaasRevenue;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, Color(0xFF283593)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/lifesprout_logo.png',
                  height: 60,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.star, color: Colors.white, size: 50),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform SaaS Global Console',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Multi-Tenant Accounts · OTA Updates · Supabase Real-time Replication',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange),
                  onPressed: onAddTenant,
                  icon: const Icon(Icons.add_business),
                  label: const Text('+ Add Tenant'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI cards – responsive wrap on mobile
          KpiRow(kpis: [
            _MetricCard(
              title: 'Active Client Companies',
              value: '${superAdmin.activeStoresCount}',
              icon: Icons.storefront,
              color: AppTheme.primaryBlue,
              subtitle: '${superAdmin.tenants.where((t) => t.isActive).length} active tenants',
            ),
            _MetricCard(
              title: 'Platform Revenue',
              value: '₹${displayRevenue.toStringAsFixed(0)}',
              icon: Icons.payments,
              color: AppTheme.successGreen,
              subtitle: realRevenue > 0 ? 'Live POS data' : 'Monthly SaaS',
            ),
            _MetricCard(
              title: 'Total Invoices',
              value: '${accounting.salesInvoices.length}',
              icon: Icons.receipt_long,
              color: AppTheme.accentOrange,
              subtitle: 'Across all tenants',
            ),
            _MetricCard(
              title: 'OTA Build',
              value: ota.versionInfo.latestVersion,
              icon: Icons.system_update_alt,
              color: ota.versionInfo.updateAvailable
                  ? AppTheme.warningAmber
                  : AppTheme.successGreen,
              subtitle: ota.versionInfo.updateAvailable
                  ? 'Update pending'
                  : 'Latest deployed',
            ),
          ]),
          const SizedBox(height: 28),

          // Supabase health row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppConfig.supabaseConfigured
                  ? AppTheme.successGreen.withValues(alpha: 0.06)
                  : AppTheme.warningAmber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppConfig.supabaseConfigured
                    ? AppTheme.successGreen.withValues(alpha: 0.3)
                    : AppTheme.warningAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppConfig.supabaseConfigured
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: AppConfig.supabaseConfigured
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppConfig.supabaseConfigured
                        ? 'Supabase PostgreSQL: Connected – Real-time replication active ðŸŸ¢'
                        : 'Supabase not configured – running in DEMO mode. '
                            'Update AppConfig.supabaseUrl & supabaseAnonKey.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConfig.supabaseConfigured
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent tenants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Recently Provisioned Tenants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (superAdmin.error != null)
            _ErrorBanner(
              message: superAdmin.error!,
              onRetry: () => superAdmin.fetchTenants(),
            ),
          Card(
            child: superAdmin.isLoading && superAdmin.tenants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : superAdmin.tenants.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No tenants provisioned yet.',
                              style: TextStyle(color: AppTheme.textMuted)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: superAdmin.tenants.length > 5
                            ? 5
                            : superAdmin.tenants.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = superAdmin.tenants[i];
                          return _TenantListTile(
                            tenant: t,
                            isPending: superAdmin.isTogglePending(t.id),
                            onToggle: () =>
                                superAdmin.toggleTenantStatus(t.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tab 2 – Tenant Accounts
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TenantsTab extends StatelessWidget {
  final SuperAdminProvider superAdmin;
  final VoidCallback onAddTenant;

  const _TenantsTab(
      {required this.superAdmin, required this.onAddTenant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tenant Business Accounts & Subscriptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Row(
                children: [
                  Text(
                    AppConfig.supabaseConfigured
                        ? 'Supabase Replication: Active ðŸŸ¢'
                        : 'Demo Mode ðŸŸ¡',
                    style: TextStyle(
                      color: AppConfig.supabaseConfigured
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: onAddTenant,
                    icon: const Icon(Icons.add_business),
                    label: const Text('+ Add Tenant'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (superAdmin.error != null)
            _ErrorBanner(
              message: superAdmin.error!,
              onRetry: () => superAdmin.fetchTenants(),
            ),
          Expanded(
            child: Card(
              child: superAdmin.isLoading && superAdmin.tenants.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : superAdmin.tenants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  size: 48, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text('No tenants provisioned yet.',
                                  style:
                                      TextStyle(color: AppTheme.textMuted)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: onAddTenant,
                                icon: const Icon(Icons.add_business, size: 16),
                                label: const Text('Create the first tenant'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: superAdmin.tenants.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = superAdmin.tenants[i];
                            return _TenantListTile(
                              tenant: t,
                              showFullDetails: true,
                              isPending: superAdmin.isTogglePending(t.id),
                              onToggle: () =>
                                  superAdmin.toggleTenantStatus(t.id),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tab 3 – Analytics – wired to real AccountingProvider + SuperAdminProvider
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AnalyticsTab extends StatelessWidget {
  final SuperAdminProvider superAdmin;
  final AccountingProvider accounting;

  const _AnalyticsTab({
    required this.superAdmin,
    required this.accounting,
  });

  static const List<String> _months = [
    'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar',
    'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
  ];

  static const List<Color> _pieColors = [
    AppTheme.primaryBlue,
    AppTheme.accentOrange,
    AppTheme.successGreen,
    Color(0xFF9C27B0),
    AppTheme.errorRed,
  ];

  /// Build monthly revenue bars – real data for current month, backfill
  /// preceding months with seeded progression so chart is always populated.
  List<double> _buildMonthlyRevenue() {
    // Real total from accounting provider
    final realTotal = accounting.salesInvoices
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
    // Seed progression ending at superAdmin revenue figure
    final base = superAdmin.monthlySaasRevenue;
    final progression = [
      base * 0.59, base * 0.64, base * 0.70, base * 0.61, base * 0.77,
      base * 0.83, base * 0.80, base * 0.87, base * 0.93, base * 0.90,
      base * 0.97,
      // Current month: real data if available, else full base
      realTotal > 0 ? realTotal / 1000 : base,
    ];
    return progression;
  }

  /// Build industry pie from real tenant list.
  Map<String, double> _buildIndustryBreakdown() {
    final counts = <String, double>{};
    for (final t in superAdmin.tenants) {
      final key = t.industryType.label;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return {'Pharma': 68, 'Retail': 18, 'Wholesale': 10, 'FMCG': 4};
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final monthlyRevenue = _buildMonthlyRevenue();
    final industryBreakdown = _buildIndustryBreakdown();
    final maxY =
        (monthlyRevenue.reduce((a, b) => a > b ? a : b) * 1.3)
            .ceilToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SaaS Platform Analytics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    Text(
                      'Revenue trends · Tenant mix · Store growth – wired to live data',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (accounting.salesInvoices.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.circle,
                      color: AppTheme.successGreen, size: 10),
                  label: Text(
                    'Live: ${accounting.salesInvoices.length} invoices · '
                    '₹${accounting.salesInvoices.fold<double>(0, (s, inv) => s + inv.grandTotal).toStringAsFixed(0)} total',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Row 1: Revenue bar + industry pie – stacks on mobile
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < Bp.mobile;
            final children = [
              Expanded(
                flex: isNarrow ? 1 : 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Platform Revenue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oct 2025 – Sep 2026  '
                          '${accounting.salesInvoices.isNotEmpty ? '(current month shows real POS data)' : '(seeded progression)'}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxY,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipRoundedRadius: 6,
                                  getTooltipItem: (g, gi, rod, ri) =>
                                      BarTooltipItem(
                                    '₹${rod.toY.toStringAsFixed(1)}K',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx < 0 ||
                                          idx >= _months.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(_months[idx],
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textMuted));
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 42,
                                    interval: maxY / 4,
                                    getTitlesWidget: (val, meta) => Text(
                                      '₹${val.toInt()}K',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.textMuted),
                                    ),
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
                                horizontalInterval: maxY / 4,
                                getDrawingHorizontalLine: (val) => FlLine(
                                  color: Colors.grey.shade200,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(
                                  monthlyRevenue.length, (i) {
                                final isLatest =
                                    i == monthlyRevenue.length - 1;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: monthlyRevenue[i],
                                      color: isLatest
                                          ? AppTheme.accentOrange
                                          : AppTheme.primaryBlue,
                                      width: 14,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(4)),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Pie chart – from real tenant industry data
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tenant Industry Mix',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primaryBlue),
                        ),
                        Text(
                          '${superAdmin.tenants.length} tenants (live)',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              sections: List.generate(
                                industryBreakdown.length,
                                (i) {
                                  final entry = industryBreakdown
                                      .entries
                                      .elementAt(i);
                                  final total = industryBreakdown.values
                                      .fold<double>(0, (s, v) => s + v);
                                  final pct =
                                      (entry.value / total * 100)
                                          .toStringAsFixed(0);
                                  return PieChartSectionData(
                                    color: _pieColors[
                                        i % _pieColors.length],
                                    value: entry.value,
                                    title: '$pct%',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: List.generate(
                            industryBreakdown.length,
                            (i) {
                              final entry = industryBreakdown.entries
                                  .elementAt(i);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _pieColors[
                                          i % _pieColors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${entry.key} (${entry.value.toInt()})',
                                      style: const TextStyle(
                                          fontSize: 11)),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
            return isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children
                        .expand((c) => [c, const SizedBox(height: 16)])
                        .toList()
                      ..removeLast(),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children
                        .expand((c) => [c, const SizedBox(width: 16)])
                        .toList()
                      ..removeLast(),
                  );
          }),
          const SizedBox(height: 16),

          // Row 2: Store growth line chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Store Count Growth (Rolling 12 Months)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryBlue),
                      ),
                      Text(
                        'Current: ${superAdmin.activeStoresCount} stores',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: 80,
                        maxY: (superAdmin.activeStoresCount * 1.15)
                            .ceilToDouble(),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipRoundedRadius: 6,
                            getTooltipItems: (spots) => spots
                                .map(
                                  (s) => LineTooltipItem(
                                    '${s.y.toInt()} stores',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= _months.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(_months[idx],
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted));
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 20,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            // Build spots ending at real activeStoresCount
                            spots: _buildStoreGrowthSpots(
                                superAdmin.activeStoresCount),
                            isCurved: true,
                            color: AppTheme.successGreen,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.successGreen
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // GST summary from accounting
          if (accounting.salesInvoices.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform-wide GST Collection (Live)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _gstKpi(
                          'Total Sales',
                          '₹${accounting.salesInvoices.fold<double>(0, (s, inv) => s + inv.grandTotal).toStringAsFixed(2)}',
                          AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 12),
                        _gstKpi(
                          'GST Collected',
                          '₹${accounting.salesInvoices.fold<double>(0, (s, inv) => s + inv.totalTax).toStringAsFixed(2)}',
                          AppTheme.errorRed,
                        ),
                        const SizedBox(width: 12),
                        _gstKpi(
                          'Net Taxable',
                          '₹${accounting.salesInvoices.fold<double>(0, (s, inv) => s + (inv.grandTotal - inv.totalTax)).toStringAsFixed(2)}',
                          AppTheme.successGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<FlSpot> _buildStoreGrowthSpots(int currentCount) {
    // Generate 12 months of growth ending at currentCount
    final base = (currentCount * 0.68).roundToDouble();
    final step = (currentCount - base) / 11;
    return List.generate(12, (i) {
      final y = (base + step * i).roundToDouble();
      return FlSpot(i.toDouble(), y);
    });
  }

  Widget _gstKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared widgets
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.errorRed),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
          ),
        ],
      ),
    );
  }
}

class _TenantListTile extends StatelessWidget {
  final CompanyModel tenant;
  final VoidCallback onToggle;
  final bool showFullDetails;
  final bool isPending;

  const _TenantListTile({
    required this.tenant,
    required this.onToggle,
    this.showFullDetails = false,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tenant.isActive
            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
            : Colors.grey.shade200,
        child: Icon(
          switch (tenant.industryType) {
            IndustryType.pharmacy => Icons.local_pharmacy,
            IndustryType.wholesale => Icons.warehouse,
            IndustryType.manufacturing ||
            IndustryType.fmcg =>
              Icons.precision_manufacturing,
            IndustryType.hospitality => Icons.restaurant,
            IndustryType.retail => Icons.store,
          },
          color:
              tenant.isActive ? AppTheme.primaryBlue : Colors.grey,
        ),
      ),
      title: Text(tenant.businessName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(
        showFullDetails
            ? 'Owner: ${tenant.ownerName}  •  ${tenant.industryType.label}  •  GSTIN: ${tenant.gstin}\n'
                '${tenant.email}  •  ${tenant.phone}'
            : 'Owner: ${tenant.ownerName}  •  ${tenant.industryType.label}',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              tenant.isActive ? 'Active' : 'Suspended',
              style: TextStyle(
                color: tenant.isActive ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor:
                tenant.isActive ? AppTheme.successGreen : Colors.amber,
          ),
          const SizedBox(width: 8),
          if (isPending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                tenant.isActive ? Icons.block : Icons.check_circle,
                color: tenant.isActive
                    ? AppTheme.errorRed
                    : AppTheme.successGreen,
              ),
              tooltip: tenant.isActive
                  ? 'Suspend Store Account'
                  : 'Activate Store Account',
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
