import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_plan_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import 'payment_checkout_view.dart';

/// Subscription plans selection view
class SubscriptionPlansView extends StatefulWidget {
  const SubscriptionPlansView({super.key});

  @override
  State<SubscriptionPlansView> createState() => _SubscriptionPlansViewState();
}

class _SubscriptionPlansViewState extends State<SubscriptionPlansView> {
  String _selectedBillingCycle = 'monthly'; // monthly or yearly
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await subscriptionProvider.fetchPlans();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<SubscriptionProvider>(
              builder: (context, subscriptionProvider, _) {
                if (subscriptionProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          subscriptionProvider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPlans,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final plans = subscriptionProvider.plans;
                if (plans.isEmpty) {
                  return const Center(
                    child: Text('No subscription plans available'),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Billing cycle toggle
                      _buildBillingCycleToggle(),
                      
                      const SizedBox(height: 24),
                      
                      // Plans grid
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive layout
                            if (constraints.maxWidth > 1200) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: plans
                                    .map((plan) => Expanded(
                                          child: _buildPlanCard(plan),
                                        ))
                                    .toList(),
                              );
                            } else if (constraints.maxWidth > 600) {
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: plans
                                    .map((plan) => SizedBox(
                                          width: (constraints.maxWidth - 48) / 2,
                                          child: _buildPlanCard(plan),
                                        ))
                                    .toList(),
                              );
                            } else {
                              return Column(
                                children: plans
                                    .map((plan) => Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _buildPlanCard(plan),
                                        ))
                                    .toList(),
                              );
                            }
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Money-back guarantee
                      _buildGuaranteeSection(),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBillingCycleToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Monthly', 'monthly'),
          _buildToggleButton('Yearly (Save up to 17%)', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String value) {
    final isSelected = _selectedBillingCycle == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedBillingCycle = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isPopular = plan.planCode == 'professional';
    final price = _selectedBillingCycle == 'yearly'
        ? plan.priceYearly
        : plan.priceMonthly;
    final effectiveMonthlyPrice = _selectedBillingCycle == 'yearly'
        ? plan.effectiveMonthlyPriceYearly
        : plan.priceMonthly;

    return Card(
      elevation: isPopular ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPopular
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Popular badge
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            if (isPopular) const SizedBox(height: 12),
            
            // Plan name
            Text(
              plan.planName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            if (plan.description != null)
              Text(
                plan.description!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  effectiveMonthlyPrice.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('/month'),
                    if (_selectedBillingCycle == 'yearly')
                      Text(
                        'Billed ₹${price.toStringAsFixed(0)} yearly',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            if (_selectedBillingCycle == 'yearly' && plan.yearlySavings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Save ₹${plan.yearlySavings.toStringAsFixed(0)} per year',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Buy button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Choose ${plan.planName}',
                onPressed: () => _selectPlan(plan),
                backgroundColor: isPopular ? Colors.green : null,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Features list
            ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            
            const SizedBox(height: 16),
            
            // Plan limits
            _buildPlanLimit('Branches', plan.maxBranches),
            _buildPlanLimit('Users', plan.maxUsers),
            _buildPlanLimit('Products', plan.maxProducts),
            _buildPlanLimit('Invoices/Month', plan.maxInvoicesPerMonth),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanLimit(String label, int value) {
    final displayValue = value >= 999999 ? 'Unlimited' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            displayValue,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            '30-Day Money-Back Guarantee',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try LifeSprout risk-free. If you\'re not satisfied, we\'ll refund your payment within 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _selectPlan(SubscriptionPlan plan) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      // Show login/signup dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login or signup to purchase a plan'),
        ),
      );
      return;
    }

    // Navigate to checkout
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentCheckoutView(
          plan: plan,
          billingCycle: _selectedBillingCycle,
        ),
      ),
    );
  }
}
