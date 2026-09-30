import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../providers/pos_provider.dart';
import '../../utils/pin_hasher.dart';
import '../../views/subscription/subscription_plans_view.dart';
import '../../views/public/downloads_view.dart';
import '../../views/public/demo_request_form.dart';
import '../../widgets/subscription/subscription_status_widget.dart';
import 'pharmacist_management_tab.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryBlue,
              tabs: const [
                Tab(icon: Icon(Icons.badge), text: 'Pharmacists'),
                Tab(icon: Icon(Icons.security), text: 'Device PIN'),
                Tab(icon: Icon(Icons.store), text: 'Branch Management'),
                Tab(icon: Icon(Icons.workspace_premium), text: 'Subscription'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const PharmacistManagementTab(),
                _PharmacistPinTab(),
                _BranchManagementTab(),
                _SubscriptionManagementTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Pharmacist PIN Management
// ─────────────────────────────────────────────────────────────────────────────
class _PharmacistPinTab extends StatefulWidget {
  @override
  State<_PharmacistPinTab> createState() => _PharmacistPinTabState();
}

class _PharmacistPinTabState extends State<_PharmacistPinTab> {
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl     = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool _obscureCurrent  = true;
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    setState(() { _error = null; _success = null; });

    final current = _currentPinCtrl.text.trim();
    final newPin  = _newPinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPin.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = 'New PIN and Confirm PIN do not match.');
      return;
    }
    final formatError = PinHasher.validateFormat(newPin);
    if (formatError != null) {
      setState(() => _error = formatError);
      return;
    }

    final ok = await AppConfig.setPharmacistPin(
        currentPin: current, newPin: newPin);

    if (ok) {
      _currentPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmCtrl.clear();
      setState(() =>
          _success = '✅ Pharmacist PIN updated. Use the new PIN from now on.');
    } else {
      // Deliberately does not echo the stored PIN.
      setState(() => _error = 'Incorrect current PIN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.security, color: AppTheme.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Pharmacist Security PIN',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This PIN is required to authorize dispensing of Schedule H, '
                  'Schedule H1, and Narcotic medicines at the POS checkout.\n\n'
                  'Only authorized pharmacists should know this PIN.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.accentOrange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppConfig.isUsingDefaultPin
                              ? 'This device is still using the shipped default '
                                  'PIN. Change it before dispensing.'
                              : 'A custom PIN is set. It is stored as a salted '
                                  'hash and cannot be displayed.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Change PIN form
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Pharmacist PIN',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 16),

                // Current PIN
                TextField(
                  controller: _currentPinCtrl,
                  obscureText: _obscureCurrent,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    prefixIcon: const Icon(Icons.lock_outline),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // New PIN
                TextField(
                  controller: _newPinCtrl,
                  obscureText: _obscureNew,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'New PIN (4–6 digits)',
                    prefixIcon: const Icon(Icons.lock_reset),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm PIN
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN',
                    prefixIcon: const Icon(Icons.lock),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  onSubmitted: (_) => _changePin(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PIN must be 4–6 digits. Use a number only the dispensing '
                  'pharmacist knows.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),

                // Error / success
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.errorRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.errorRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppTheme.errorRed, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppTheme.successGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppTheme.successGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_success!,
                              style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue),
                    onPressed: _changePin,
                    icon: const Icon(Icons.save),
                    label: const Text('Update Pharmacist PIN'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Branch Management
// ─────────────────────────────────────────────────────────────────────────────
class _BranchManagementTab extends StatefulWidget {
  @override
  State<_BranchManagementTab> createState() => _BranchManagementTabState();
}

class _BranchManagementTabState extends State<_BranchManagementTab> {
  final _newBranchCtrl = TextEditingController();

  @override
  void dispose() {
    _newBranchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<PosProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Store Branches',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 4),
          const Text(
            'Each branch is selectable at POS checkout. '
            'The selected branch appears on the printed invoice.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          // Add new branch
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newBranchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Branch Name',
                    hintText: 'e.g. Airport Road Branch',
                    prefixIcon: Icon(Icons.add_business),
                  ),
                  onSubmitted: (_) => _addBranch(pos),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _addBranch(pos),
                icon: const Icon(Icons.add),
                label: const Text('Add Branch'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Existing branches
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: pos.branches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final b = pos.branches[i];
                  final isActive = pos.branch == b;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? AppTheme.primaryBlue
                          : AppTheme.primaryBlue.withValues(alpha: 0.1),
                      child: Icon(Icons.store,
                          color:
                              isActive ? Colors.white : AppTheme.primaryBlue,
                          size: 20),
                    ),
                    title: Text(b,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppTheme.primaryBlue
                                : AppTheme.textDark)),
                    trailing: isActive
                        ? Chip(
                            label: const Text('Active'),
                            backgroundColor: AppTheme.successGreen
                                .withValues(alpha: 0.1),
                            labelStyle: const TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          )
                        : TextButton(
                            onPressed: () => pos.setBranch(b),
                            child: const Text('Set Active'),
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

  void _addBranch(PosProvider pos) {
    final name = _newBranchCtrl.text.trim();
    if (name.isEmpty) return;
    pos.addBranch(name);
    _newBranchCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Branch "$name" added!'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Subscription Management
// ─────────────────────────────────────────────────────────────────────────────
class _SubscriptionManagementTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.workspace_premium,
                        color: AppTheme.primaryBlue, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Subscription Management',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Manage your LifeSprout subscription, view plan details, and upgrade your account.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Current subscription status
          const SubscriptionStatusWidget(),

          const SizedBox(height: 32),

          // Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // View all plans
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.card_giftcard, color: Colors.white),
                    ),
                    title: const Text('View All Plans'),
                    subtitle: const Text('Compare features and pricing'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionPlansView(),
                        ),
                      );
                    },
                  ),

                  const Divider(),

                  // Download software
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.download, color: Colors.white),
                    ),
                    title: const Text('Download Software'),
                    subtitle: const Text('Get the latest desktop version'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const DownloadsView(),
                        ),
                      );
                    },
                  ),

                  const Divider(),

                  // Request demo
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.video_call, color: Colors.white),
                    ),
                    title: const Text('Book a Demo'),
                    subtitle: const Text('Schedule a personalized walkthrough'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: const DemoRequestForm(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Support information
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.help_outline, color: AppTheme.textMuted),
                      SizedBox(width: 8),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'For subscription inquiries, billing questions, or plan upgrades, '
                    'contact our support team:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.email, size: 16, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text('support@lifesprout.com',
                          style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.phone, size: 16, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text('+91 1800-XXX-XXXX',
                          style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500)),
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
}
