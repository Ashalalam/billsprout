import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/supabase_service.dart';

/// Public pricing plans, read from the world-readable `pricing_plans` table.
class PricingSection extends StatefulWidget {
  const PricingSection({super.key});

  @override
  State<PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<PricingSection> {
  List<Map<String, dynamic>> _plans = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await SupabaseService().fetchPricingPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = SupabaseService.describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue),
        ),
        const SizedBox(height: 4),
        const Text(
          'One-time licence per store. GST applicable as shown.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          // An error here must not take the marketing page down with it.
          _notice(
            icon: Icons.cloud_off,
            color: AppTheme.warningAmber,
            text: 'Pricing could not be loaded right now. $_error',
            action: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          )
        else if (_plans.isEmpty)
          _notice(
            icon: Icons.info_outline,
            color: AppTheme.textMuted,
            text: 'Pricing is being updated. Please request a demo for a quote.',
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _plans.map(_planCard).toList(),
          ),
      ],
    );
  }

  Widget _notice({
    required IconData icon,
    required Color color,
    required String text,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color)),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final name = plan['plan_name'] as String? ?? 'Plan';
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final gstApplicable = plan['gst_applicable'] as bool? ?? true;
    final gstPercent = (plan['gst_percent'] as num?)?.toDouble() ?? 18;
    final features = (plan['features'] as List?)?.cast<dynamic>() ?? const [];
    final isFeatured = (plan['display_order'] as int? ?? 0) == 1;

    return SizedBox(
      width: 280,
      child: Card(
        elevation: isFeatured ? 6 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isFeatured ? AppTheme.accentOrange : Colors.grey.shade300,
            width: isFeatured ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('RECOMMENDED',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              if (isFeatured) const SizedBox(height: 10),
              Text(name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue)),
              const SizedBox(height: 10),
              Text('₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Text(
                gstApplicable
                    ? '+ ${gstPercent.toStringAsFixed(0)}% GST'
                    : 'GST included',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted),
              ),
              const Divider(height: 24),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check,
                            size: 14, color: AppTheme.successGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('$f',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
