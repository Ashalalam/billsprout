import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../services/ota_service.dart';
import '../common/support_contact_modal.dart';
import '../common/sync_status_badge.dart';
import 'pos_billing_view.dart';
import 'inventory_view.dart';
import 'schedule_h_register_view.dart';
import 'gst_accounting_view.dart';
import 'stock_transfer_view.dart';
import 'purchase_order_view.dart';
import 'bank_reconciliation_view.dart';
import 'sales_dashboard_view.dart';
import 'settings_view.dart';
import 'near_expiry_view.dart';

class BusinessAdminLayout extends StatefulWidget {
  const BusinessAdminLayout({super.key});

  @override
  State<BusinessAdminLayout> createState() => _BusinessAdminLayoutState();
}

class _BusinessAdminLayoutState extends State<BusinessAdminLayout> {
  int _selectedIndex = 0;
  String _industryMode = 'Pharma Mode';

  static const _destinations = [
    _NavDest(Icons.dashboard_outlined,             'Dashboard'),
    _NavDest(Icons.point_of_sale,                  'POS Billing'),
    _NavDest(Icons.inventory_2_outlined,            'Inventory'),
    _NavDest(Icons.verified_outlined,               'Schedule H'),
    _NavDest(Icons.account_balance_outlined,        'GST'),
    _NavDest(Icons.warning_amber_outlined,          'Near Expiry'),
    _NavDest(Icons.compare_arrows,                  'Transfers'),
    _NavDest(Icons.shopping_bag_outlined,           'Purchase'),
    _NavDest(Icons.account_balance_wallet_outlined, 'Bank Recon'),
    _NavDest(Icons.settings_outlined,               'Settings'),
  ];

  final List<Widget> _views = [
    const SalesDashboardView(),
    const PosBillingView(),
    const InventoryView(),
    const ScheduleHRegisterView(),
    const GstAccountingView(),
    const NearExpiryView(),
    const StockTransferView(),
    const PurchaseOrderView(),
    const BankReconciliationView(),
    const SettingsView(),
  ];

  // Bottom nav only shows 5 items; remaining are in the drawer
  static const _bottomNavCount = 5;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final ota  = Provider.of<OtaService>(context);
    final isMobile = context.isMobile;

    return Scaffold(
      appBar: _appBar(auth, ota, isMobile),
      drawer: isMobile ? _drawer(context, auth) : null,
      bottomNavigationBar: isMobile ? _bottomNav() : null,
      body: isMobile
          ? _views[_selectedIndex]
          : _desktopBody(),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  PreferredSizeWidget _appBar(AuthProvider auth, OtaService ota, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      iconTheme: const IconThemeData(color: AppTheme.primaryBlue),
      title: Row(
        children: [
          Image.asset(
            'assets/images/lifesprout_logo.png',
            height: 40,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.local_pharmacy, color: AppTheme.primaryBlue, size: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMobile ? AppConfig.appName : '${AppConfig.appName} â€” Store Operations',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile)
                  Text(
                    'LIFESPROUT Care | $_industryMode',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const SyncStatusBadge(),
        const SizedBox(width: 2),
        if (ota.versionInfo.updateAvailable)
          IconButton(
            icon: const Icon(Icons.system_update, color: AppTheme.accentOrange),
            tooltip: 'OTA Update Ready',
            onPressed: () => _showOtaModal(ota),
          ),
        if (!isMobile)
          IconButton(
            icon: const Icon(Icons.headset_mic),
            tooltip: 'Support',
            onPressed: () => SupportContactModal.show(context),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          onSelected: (val) {
            if (val == 'logout') auth.logout();
            if (val == 'support') SupportContactModal.show(context);
            if (val == 'industry') _showIndustryPicker();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                '${auth.currentUser?.name ?? ''}\n${auth.currentUser?.roleDisplay ?? ''}',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const PopupMenuDivider(),
            if (isMobile)
              const PopupMenuItem(value: 'industry', child: Text('Switch Industry Mode')),
            const PopupMenuItem(value: 'support', child: Text('Support Desk')),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // â”€â”€ Mobile Drawer (all 7 nav items) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _drawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: AppTheme.primaryBlue,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/lifesprout_logo.png',
                    height: 44,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.local_pharmacy, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.currentUser?.name ?? AppConfig.appName,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    auth.currentUser?.roleDisplay ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // All navigation items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._destinations.asMap().entries.map((e) {
                    final isSelected = _selectedIndex == e.key;
                    final color = e.key == 3 ? AppTheme.errorRed : AppTheme.primaryBlue;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      leading: Icon(
                        e.value.icon,
                        color: isSelected ? color : AppTheme.textMuted,
                      ),
                      title: Text(
                        e.value.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : AppTheme.textDark,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedIndex = e.key);
                        Navigator.pop(context);
                      },
                    );
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.tune, color: AppTheme.primaryBlue),
                    title: const Text('Switch Industry Mode'),
                    onTap: () {
                      Navigator.pop(context);
                      _showIndustryPicker();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.headset_mic),
                    title: const Text('Support Desk'),
                    onTap: () {
                      Navigator.pop(context);
                      SupportContactModal.show(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.errorRed),
                    title: const Text('Logout', style: TextStyle(color: AppTheme.errorRed)),
                    onTap: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Mobile Bottom Nav (first 4 items) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _bottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex < _bottomNavCount ? _selectedIndex : 0,
      onTap: (idx) => setState(() => _selectedIndex = idx),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryBlue,
      unselectedItemColor: AppTheme.textMuted,
      selectedFontSize: 11,
      unselectedFontSize: 10,
      items: _destinations
          .take(_bottomNavCount)
          .map((d) => BottomNavigationBarItem(
                icon: Icon(d.icon),
                label: d.label,
              ))
          .toList(),
    );
  }

  // â”€â”€ Desktop body with NavigationRail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _desktopBody() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          labelType: NavigationRailLabelType.all,
          selectedIconTheme:
              const IconThemeData(color: AppTheme.primaryBlue, size: 24),
          unselectedIconTheme:
              const IconThemeData(color: Colors.grey, size: 20),
          destinations: _destinations
              .asMap()
              .entries
              .map((e) => NavigationRailDestination(
                    icon: Icon(e.value.icon),
                    selectedIcon: Icon(e.value.icon,
                        color: e.key == 2
                            ? AppTheme.errorRed
                            : AppTheme.primaryBlue),
                    label: Text(e.value.label,
                        style: TextStyle(fontSize: 11)),
                  ))
              .toList(),
          trailing: null,
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _views[_selectedIndex]),
      ],
    );
  }

  // â”€â”€ Dialogs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showOtaModal(OtaService ota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt, color: AppTheme.accentOrange),
            SizedBox(width: 10),
            Flexible(child: Text('OTA Update Available')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New: ${ota.versionInfo.latestVersion}  '
                '(Current: ${ota.versionInfo.currentVersion})'),
            const SizedBox(height: 12),
            const Text('Highlights:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(ota.versionInfo.releaseNotes),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
            onPressed: () { ota.applyUpdate(); Navigator.pop(ctx); },
            child: const Text('Apply OTA Patch'),
          ),
        ],
      ),
    );
  }

  void _showIndustryPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Multi-Industry Dynamic Engine'),
        children: [
          'Pharma Mode (Default)',
          'Retail Supermarket',
          'Wholesale Distribution',
          'FMCG & Manufacturing',
          'Restaurant & Hospitality',
        ].map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _industryMode = mode);
              Navigator.pop(ctx);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    mode == _industryMode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(mode)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavDest {
  final IconData icon;
  final String label;
  const _NavDest(this.icon, this.label);
}
