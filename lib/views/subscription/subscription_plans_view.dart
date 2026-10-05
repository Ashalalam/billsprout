import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import 'payment_page.dart';

/// Displays available subscription plans for pharmacy owners to choose from
/// after business registration. Shows Basic, Professional, and Enterprise tiers
/// with pricing, features, and selection buttons.
class SubscriptionPlansView extends StatefulWidget {
  const SubscriptionPlansView({super.key});

  @override
  State<SubscriptionPlansView> createState() => _SubscriptionPlansViewState();
}

class _SubscriptionPlansViewState extends State<SubscriptionPlansView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];
  String? _errorMessage;
  String? _selectedPlanId;
  String _selectedCurrency = 'INR'; // Default to Indian Rupees
  String _selectedBillingCycle = 'yearly'; // 'monthly' or 'yearly'

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .order('price_monthly', ascending: true);

      setState(() {
        _plans = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load subscription plans: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPlan(String planId) async {
    setState(() {
      _selectedPlanId = planId;
    });

    // Find the selected plan
    final selectedPlan = _plans.firstWhere((plan) => plan['id'] == planId);

    // Navigate to payment page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(plan: selectedPlan),
        ),
      ).then((_) {
        // Reset selection when coming back
        setState(() {
          _selectedPlanId = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Subscription Plan'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadPlans,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      const Text(
                        'Select the perfect plan for your pharmacy',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All plans include 7-day free trial. Cancel anytime.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Currency and Billing Cycle Selectors
                      Row(
                        children: [
                          // Currency Selector
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Currency',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('🇮🇳 INR (₹)'),
                                            value: 'INR',
                                            groupValue: _selectedCurrency,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedCurrency = value!;
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('🌎 USD (\$)'),
                                            value: 'USD',
                                            groupValue: _selectedCurrency,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedCurrency = value!;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Billing Cycle Selector
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Billing Cycle',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('Monthly'),
                                            value: 'monthly',
                                            groupValue: _selectedBillingCycle,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedBillingCycle = value!;
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('Yearly'),
                                            subtitle: const Text(
                                              'Save 10%',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 11,
                                              ),
                                            ),
                                            value: 'yearly',
                                            groupValue: _selectedBillingCycle,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedBillingCycle = value!;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Renewal Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.celebration, color: Colors.green[700], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '🎉 Renewal Discount: Annual renewals get 50% OFF! '
                                'First year at full price, renewals at half price.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Plans Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Responsive layout: 1 column on mobile, 3 columns on desktop
                          final isDesktop = constraints.maxWidth > 900;
                          if (isDesktop) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _plans
                                  .map((plan) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: _buildPlanCard(plan),
                                        ),
                                      ))
                                  .toList(),
                            );
                          } else {
                            return Column(
                              children: _plans
                                  .map((plan) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 16.0),
                                        child: _buildPlanCard(plan),
                                      ))
                                  .toList(),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planId = plan['id'] as String;
    final planName = plan['plan_name'] as String;
    final planCode = plan['plan_code'] as String;
    
    // Get prices based on selected currency and billing cycle
    final priceMonthly = _selectedCurrency == 'INR' 
        ? (plan['price_monthly'] as num? ?? 0)
        : (plan['price_monthly_usd'] as num? ?? 0);
    final priceYearly = _selectedCurrency == 'INR'
        ? (plan['price_yearly'] as num?)
        : (plan['price_yearly_usd'] as num?);
    final renewalYearly = _selectedCurrency == 'INR'
        ? (plan['renewal_yearly'] as num?)
        : (plan['renewal_yearly_usd'] as num?);
    
    final currencySymbol = _selectedCurrency == 'INR' ? '₹' : '\$';
    final maxUsers = plan['max_users'] as int?;
    final maxBranches = plan['max_branches'] as int?;
    final features = plan['features'] as List<dynamic>? ?? [];

    // Determine if this is the recommended plan (Professional)
    final isRecommended = planCode == 'professional';
    
    // Calculate display price based on billing cycle
    final displayPrice = _selectedBillingCycle == 'monthly' 
        ? priceMonthly 
        : (priceYearly ?? priceMonthly * 12);
    final perMonth = _selectedBillingCycle == 'yearly' 
        ? (priceYearly != null ? priceYearly / 12 : priceMonthly)
        : priceMonthly;

    return Card(
      elevation: isRecommended ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended
            ? BorderSide(color: AppTheme.primaryBlue, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recommended Badge
            if (isRecommended)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
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
            if (isRecommended) const SizedBox(height: 12),

            // Plan Name
            Text(
              planName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            if (_selectedBillingCycle == 'monthly') ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencySymbol,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayPrice.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    ' /month',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Yearly pricing
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencySymbol,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayPrice.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    ' /year',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$currencySymbol${perMonth.toStringAsFixed(0)}/month (billed annually)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Savings Badge
            if (priceYearly != null && _selectedBillingCycle == 'yearly') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  'Save ${(((priceMonthly * 12 - priceYearly) / (priceMonthly * 12)) * 100).toStringAsFixed(0)}% vs monthly',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            
            // Renewal Pricing Notice
            if (renewalYearly != null && _selectedBillingCycle == 'yearly') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.autorenew, size: 16, color: Colors.orange[900]),
                        const SizedBox(width: 4),
                        Text(
                          'Renewal Price',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${renewalYearly.toStringAsFixed(0)}/year (50% OFF)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'After first year',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Limits
            if (maxUsers != null)
              _buildFeatureItem(
                  '👥 Up to ${maxUsers == 999 ? 'Unlimited' : maxUsers} user${maxUsers > 1 ? 's' : ''}'),
            if (maxBranches != null)
              _buildFeatureItem(
                  '🏢 Up to ${maxBranches == 999 ? 'Unlimited' : maxBranches} branch${maxBranches > 1 ? 'es' : ''}'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Features List
            ...features
                .map((feature) => _buildFeatureItem('✓ ${feature.toString()}')),

            const SizedBox(height: 24),

            // Select Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPlanId == planId
                    ? null
                    : () => _selectPlan(planId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecommended
                      ? AppTheme.primaryBlue
                      : AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _selectedPlanId == planId
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isRecommended ? 'Get Started' : 'Select Plan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
