/// ============================================================================
/// Centralized Pricing Configuration
/// ============================================================================
/// Single source of truth for subscription plan pricing.
/// Supports INR (Indian Rupees) and USD (US Dollars).
/// 
/// IMPORTANT:
/// - INR and USD have SEPARATE pricing values (not converted)
/// - Renewal pricing is 50% of annual price
/// - Renewal is NOT automatic - customer must manually renew
/// ============================================================================

class PricingConfig {
  // Prevent instantiation
  PricingConfig._();

  /// Get pricing for a plan
  static PlanPricing getPricing(String planCode, String currency) {
    final plans = currency == 'USD' ? _usdPricing : _inrPricing;
    return plans[planCode] ?? _inrPricing['basic']!;
  }

  /// Check if currency is supported
  static bool isSupportedCurrency(String currency) {
    return currency == 'INR' || currency == 'USD';
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currency) {
    return currency == 'USD' ? '\$' : '₹';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INR (Indian Rupees) Pricing
  // ══════════════════════════════════════════════════════════════════════════
  static final Map<String, PlanPricing> _inrPricing = {
    'basic': PlanPricing(
      currency: 'INR',
      monthlyPrice: 499.00,
      yearlyPrice: 5388.00,
      renewalYearlyPrice: 2694.00, // 50% of yearly
    ),
    'professional': PlanPricing(
      currency: 'INR',
      monthlyPrice: 1499.00,
      yearlyPrice: 16188.00,
      renewalYearlyPrice: 8094.00, // 50% of yearly
    ),
    'enterprise': PlanPricing(
      currency: 'INR',
      monthlyPrice: 2167.00, // ₹26,000 / 12 months
      yearlyPrice: 26000.00, // Changed from ₹49,999 to ₹26,000
      renewalYearlyPrice: 13000.00, // 50% of yearly = ₹13,000
    ),
  };

  // ══════════════════════════════════════════════════════════════════════════
  // USD (US Dollars) Pricing - SEPARATE from INR
  // ══════════════════════════════════════════════════════════════════════════
  static final Map<String, PlanPricing> _usdPricing = {
    'basic': PlanPricing(
      currency: 'USD',
      monthlyPrice: 9.00,
      yearlyPrice: 97.00,
      renewalYearlyPrice: 48.50, // 50% of yearly
    ),
    'professional': PlanPricing(
      currency: 'USD',
      monthlyPrice: 24.00,
      yearlyPrice: 259.00,
      renewalYearlyPrice: 129.50, // 50% of yearly
    ),
    'enterprise': PlanPricing(
      currency: 'USD',
      monthlyPrice: 35.00,
      yearlyPrice: 350.00,
      renewalYearlyPrice: 175.00, // 50% of yearly
    ),
  };
}

/// Pricing details for a plan in a specific currency
class PlanPricing {
  final String currency;
  final double monthlyPrice;
  final double yearlyPrice;
  final double renewalYearlyPrice; // 50% of yearlyPrice

  const PlanPricing({
    required this.currency,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.renewalYearlyPrice,
  });

  /// Get symbol for this currency
  String get currencySymbol => currency == 'USD' ? '\$' : '₹';

  /// Calculate monthly equivalent for yearly price
  double get yearlyMonthlyEquivalent => yearlyPrice / 12;

  /// Calculate yearly savings vs monthly billing
  double get yearlySavings => (monthlyPrice * 12) - yearlyPrice;

  /// Calculate yearly discount percentage
  double get yearlyDiscountPercent {
    if (monthlyPrice == 0) return 0;
    return (yearlySavings / (monthlyPrice * 12)) * 100;
  }

  /// Calculate renewal savings
  double get renewalSavings => yearlyPrice - renewalYearlyPrice;

  /// Calculate renewal discount percentage (should be 50%)
  double get renewalDiscountPercent {
    if (yearlyPrice == 0) return 0;
    return (renewalSavings / yearlyPrice) * 100;
  }

  /// Get price based on billing cycle
  double getPrice(String billingCycle, {bool isRenewal = false}) {
    if (billingCycle == 'monthly') {
      return monthlyPrice;
    } else {
      return isRenewal ? renewalYearlyPrice : yearlyPrice;
    }
  }

  /// Format price for display
  String formatPrice(double price) {
    return '$currencySymbol${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';
  }

  /// Get formatted monthly price
  String get formattedMonthly => formatPrice(monthlyPrice);

  /// Get formatted yearly price
  String get formattedYearly => formatPrice(yearlyPrice);

  /// Get formatted renewal price
  String get formattedRenewal => formatPrice(renewalYearlyPrice);
}
