import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';

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

    // TODO: Navigate to PayPal payment page
    // For now, show a placeholder dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Integration Pending'),
          content: const Text(
            'PayPal payment integration will be implemented in the next step. '
            'You have selected a plan successfully.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedPlanId = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
    final priceMonthly = plan['price_monthly'] as num;
    final priceYearly = plan['price_yearly'] as num?;
    final currency = plan['currency'] as String? ?? 'INR';
    final maxUsers = plan['max_users'] as int?;
    final maxBranches = plan['max_branches'] as int?;
    final features = plan['features'] as List<dynamic>? ?? [];

    // Determine if this is the recommended plan (Professional)
    final isRecommended = planCode == 'professional';

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency == 'INR' ? '₹' : '\$',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  priceMonthly.toStringAsFixed(0),
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

            if (priceYearly != null) ...[
              const SizedBox(height: 4),
              Text(
                'or ${currency == 'INR' ? '₹' : '\$'}${priceYearly.toStringAsFixed(0)}/year (Save ${(((priceMonthly * 12 - priceYearly) / (priceMonthly * 12)) * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Limits
            if (maxUsers != null)
              _buildFeatureItem(
                  '👥 Up to $maxUsers user${maxUsers > 1 ? 's' : ''}'),
            if (maxBranches != null)
              _buildFeatureItem(
                  '🏢 Up to $maxBranches branch${maxBranches > 1 ? 'es' : ''}'),

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
