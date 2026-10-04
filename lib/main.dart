import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/accounting_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/company_profile_provider.dart';
import 'providers/pharmacist_provider.dart';
import 'providers/super_admin_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/paypal_config_provider.dart';
import 'providers/paypal_transaction_provider.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'services/ota_service.dart';
import 'middleware/auth_guard.dart';
import 'views/auth/login_view.dart';
import 'views/auth/business_register_view.dart';
import 'views/subscription/subscription_plans_view.dart';
import 'views/super_admin/super_admin_dashboard.dart';
import 'views/business_admin/business_admin_layout.dart';
import 'views/customer/customer_portal_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[BillSprout] Environment variables loaded from .env');
  } catch (e) {
    debugPrint('[BillSprout] Warning: Could not load .env file: $e');
  }

  // Load pharmacist PIN from SharedPreferences
  await AppConfig.loadPin();

  // Initialize Supabase if credentials are configured.
  // Falls back to demo mode when placeholder values are present.
  if (AppConfig.supabaseConfigured) {
    await SupabaseService.initialize();
  } else {
    debugPrint(
      '[BillSprout] Running in DEMO mode — configure AppConfig.supabaseUrl '
      'and AppConfig.supabaseAnonKey to enable real backend.',
    );
  }

  runApp(const BillSproutApp());
}

class BillSproutApp extends StatelessWidget {
  const BillSproutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, InventoryProvider>(
          create: (context) => InventoryProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (_, auth, previous) =>
              (previous ?? InventoryProvider(authProvider: auth))..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AccountingProvider>(
          create: (context) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final provider = AccountingProvider();
            provider.setTenantContext(auth.tenantId, auth.branchId);
            return provider;
          },
          update: (_, auth, previous) {
            final provider = previous ?? AccountingProvider();
            provider.setTenantContext(auth.tenantId, auth.branchId);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, CustomerProvider>(
          create: (context) => CustomerProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (_, auth, previous) =>
              (previous ?? CustomerProvider(auth))..updateAuth(auth),
        ),
        // Supplies the tenant's own name/GSTIN/licence to invoices. Previously
        // unregistered, so anything reading it would have thrown at runtime.
        ChangeNotifierProvider(create: (_) => CompanyProfileProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PharmacistProvider>(
          create: (context) => PharmacistProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (_, auth, previous) =>
              (previous ?? PharmacistProvider(auth))..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => PayPalConfigProvider()),
        ChangeNotifierProvider(create: (_) => PayPalTransactionProvider()),
        ChangeNotifierProxyProvider2<AuthProvider, AccountingProvider, SyncService>(
          create: (context) => SyncService(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
            accountingProvider: Provider.of<AccountingProvider>(context, listen: false),
          ),
          update: (_, auth, accounting, previous) => 
            previous ?? SyncService(authProvider: auth, accountingProvider: accounting),
        ),
        ChangeNotifierProvider(create: (_) => OtaService()),
      ],
      child: MaterialApp(
        title: '${AppConfig.appName} — ${AppConfig.appSubtitle}',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const PortalRouter(),
        routes: {
          '/business-register': (context) => const BusinessRegisterView(),
          '/subscription-plans': (context) => const SubscriptionPlansView(),
        },
      ),
    );
  }
}

class PortalRouter extends StatelessWidget {
  const PortalRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return const LoginView();
    }

    // ✅ SECURITY FIX: Wrap each dashboard with AuthGuard to enforce role-based access
    switch (auth.currentUser!.role) {
      case UserRole.superAdmin:
        return AuthGuard(
          allowedRoles: const [UserRole.superAdmin],
          child: const SuperAdminDashboard(),
        );
        
      case UserRole.businessAdmin:
      case UserRole.pharmacist:
      case UserRole.cashier:
        return AuthGuard(
          allowedRoles: const [
            UserRole.businessAdmin,
            UserRole.pharmacist,
            UserRole.cashier,
          ],
          child: const BusinessAdminLayout(),
        );
        
      case UserRole.customer:
        return AuthGuard(
          allowedRoles: const [UserRole.customer],
          child: const CustomerPortalView(),
        );
    }
  }
}
