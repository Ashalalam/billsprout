import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../common/support_contact_modal.dart';
import '../public/demo_request_form.dart';
import '../public/pricing_section.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserRole _selectedRole = UserRole.businessAdmin;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Sign-in fields
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Register fields (Customer only)
  bool _showRegister = false;
  final _regNameCtrl    = TextEditingController();
  final _regPhoneCtrl   = TextEditingController();
  final _regEmailCtrl   = TextEditingController();
  final _regPasswordCtrl    = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _obscureRegPassword = true;
  bool _obscureConfirm     = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _onRoleSelected(UserRole role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _successMessage = null;
      _showRegister = false;
      _emailCtrl.clear();
      _passwordCtrl.clear();
    });
  }

  // â”€â”€ Sign In â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _handleLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!AppConfig.supabaseConfigured) {
      await Future.delayed(const Duration(milliseconds: 500));
      auth.login(email: email, role: _selectedRole);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await auth.signInWithSupabase(
        email: email,
        password: password,
        role: _selectedRole,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // â”€â”€ Customer Register â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _handleRegister() async {
    final name     = _regNameCtrl.text.trim();
    final phone    = _regPhoneCtrl.text.trim();
    final email    = _regEmailCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    final confirm  = _regConfirmCtrl.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() =>
          _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.registerCustomer(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      // If no exception thrown and still mounted the user is logged in
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        // "check your email" means registration succeeded but needs confirmation
        if (msg.toLowerCase().contains('check your email') ||
            msg.toLowerCase().contains('confirm')) {
          setState(() {
            _successMessage =
                'âœ… Account created! Check your email to confirm, then sign in.';
            _showRegister = false;
            _emailCtrl.text = email;
          });
        } else {
          setState(() => _errorMessage = msg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: context.isMobile ? _narrowLayout() : _wideLayout(),
    );
  }

  // â”€â”€ Desktop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _HeroPanel(
              onSupportTap: () => SupportContactModal.show(context)),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _mainForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Mobile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _narrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.primaryBlue,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Image.asset(
                    'assets/images/lifesprout_logo.png',
                    height: 44,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.medical_services,
                        size: 44,
                        color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConfig.appName,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('Smart ERP & POS Billing',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.headset_mic,
                      color: AppTheme.accentOrange),
                  onPressed: () => SupportContactModal.show(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _mainForm(),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Main form â€” switches between Sign In and Register â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _mainForm() {
    // When Customer is selected and register mode is on, show register form
    final isCustomer = _selectedRole == UserRole.customer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portal Access',
          style: TextStyle(
            fontSize: context.isMobile ? 22 : 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Select your portal and sign in.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),

        // â”€â”€ Role cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _RoleCard(
          role: UserRole.businessAdmin,
          title: 'Business Admin & Staff',
          subtitle: 'POS Â· FEFO Stock Â· GST Â· Regulatory',
          icon: Icons.store,
          selectedRole: _selectedRole,
          onTap: _onRoleSelected,
        ),
        const SizedBox(height: 10),
        _RoleCard(
          role: UserRole.superAdmin,
          title: 'Super Admin Portal',
          subtitle: 'Global Tenants Â· Metrics Â· OTA Releases',
          icon: Icons.admin_panel_settings,
          selectedRole: _selectedRole,
          onTap: _onRoleSelected,
        ),
        const SizedBox(height: 10),
        _RoleCard(
          role: UserRole.customer,
          title: 'Customer / Patient Portal',
          subtitle: 'Invoice History Â· Refill Reminders Â· Rx Upload',
          icon: Icons.person_pin,
          selectedRole: _selectedRole,
          onTap: _onRoleSelected,
        ),
        const SizedBox(height: 24),

        // â”€â”€ Sign In / Register tab strip (Customer portal only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (isCustomer) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _tabBtn(
                    label: 'Sign In',
                    icon: Icons.login,
                    active: !_showRegister,
                    onTap: () => setState(() {
                      _showRegister = false;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                  ),
                ),
                Expanded(
                  child: _tabBtn(
                    label: 'Create Account',
                    icon: Icons.person_add,
                    active: _showRegister,
                    onTap: () => setState(() {
                      _showRegister = true;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // â”€â”€ Form area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (isCustomer && _showRegister)
          _registerForm()
        else
          _signInForm(),

        // â”€â”€ Feedback messages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _feedbackBanner(
              _errorMessage!, AppTheme.errorRed, Icons.error_outline),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 12),
          _feedbackBanner(
              _successMessage!, AppTheme.successGreen, Icons.check_circle_outline),
        ],

        // â”€â”€ Demo hint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (!AppConfig.supabaseConfigured) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.accentOrange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo mode â€” enter any credentials to proceed.',
                    style: TextStyle(
                        color: AppTheme.accentOrange,
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: () => SupportContactModal.show(context),
            icon: const Icon(Icons.help_outline, size: 16),
            label: const Text(
              'Need Help? Contact Lifesprout Care Support',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _showPublicPage(
                  title: 'Request a Demo',
                  child: const DemoRequestForm(),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('Request a Demo',
                    style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _showPublicPage(
                  title: 'Pricing',
                  child: const PricingSection(),
                ),
                icon: const Icon(Icons.sell_outlined, size: 16),
                label: const Text('View Pricing',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Both public surfaces are unauthenticated, so they open as plain dialogs
  /// from the login screen rather than behind a route guard.
  void _showPublicPage({required String title, required Widget child}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Sign In form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _signInForm() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Sign In â€” ${_portalLabel(_selectedRole)}',
                    style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Register form (Customer portal) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _registerForm() {
    return Column(
      children: [
        // Name
        TextField(
          controller: _regNameCtrl,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            hintText: 'e.g. John Doe',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),

        // Phone
        TextField(
          controller: _regPhoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            hintText: '+44 7700 900000',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),

        // Email
        TextField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),

        // Password
        TextField(
          controller: _regPasswordCtrl,
          obscureText: _obscureRegPassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password *',
            hintText: 'Min 6 characters',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscureRegPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(
                  () => _obscureRegPassword = !_obscureRegPassword),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm password
        TextField(
          controller: _regConfirmCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleRegister(),
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            hintText: 'Re-enter password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Terms note
        const Text(
          'By creating an account you agree to LIFESPROUT Care\'s '
          'terms of service and privacy policy.',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen),
            onPressed: _isLoading ? null : _handleRegister,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add),
            label: const Text('Create Patient Account',
                style: TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),

        // Already have account link
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _showRegister = false;
              _errorMessage = null;
              _regEmailCtrl.text.isNotEmpty
                  ? _emailCtrl.text = _regEmailCtrl.text
                  : null;
            }),
            child: const Text(
              'Already have an account? Sign In â†’',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _tabBtn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active
                    ? AppTheme.primaryBlue
                    : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppTheme.primaryBlue : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackBanner(String msg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String _portalLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.customer:
        return 'Patient Portal';
      default:
        return 'Business Portal';
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Hero panel (desktop left side)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _HeroPanel extends StatelessWidget {
  final VoidCallback onSupportTap;
  const _HeroPanel({required this.onSupportTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryBlue,
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/lifesprout_logo.png',
              height: 72,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.medical_services,
                  size: 64,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(AppConfig.appName,
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            const Text(
              'Smart ERP & Fast POS Billing System\nby LIFESPROUT Care',
              style: TextStyle(
                  fontSize: 14, color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 28),
            _bullet(Icons.offline_bolt,
                'Hybrid Offline-to-Online Zero Latency Engine'),
            _bullet(Icons.medication,
                'FEFO Batch Selection & Schedule H/H1 Regulatory Logs'),
            _bullet(Icons.receipt_long,
                'Dual Thermal & PDF Printing + WhatsApp Receipt Sharing'),
            _bullet(Icons.system_update,
                'Over-The-Air (OTA) Enterprise Updates'),
            _bullet(Icons.cloud_sync,
                'Supabase PostgreSQL Real-time Cloud Sync'),
            const SizedBox(height: 28),
            if (!AppConfig.supabaseConfigured)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.accentOrange.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.accentOrange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DEMO MODE â€” configure Supabase credentials in AppConfig.',
                        style: TextStyle(
                            color: AppTheme.accentOrange,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onSupportTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.headset_mic, color: AppTheme.accentOrange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Support: ${AppConfig.whatsappSupportNumber}\n'
                        '${AppConfig.technicalSupportEmail}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Role selector card
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _RoleCard extends StatelessWidget {
  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final UserRole selectedRole;
  final void Function(UserRole) onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedRole == role;
    return InkWell(
      onTap: () => onTap(role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? AppTheme.primaryBlue
                  : Colors.grey.shade200,
              child: Icon(icon,
                  color: isSelected ? Colors.white : Colors.grey.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.textDark)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected
                    ? AppTheme.primaryBlue
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
