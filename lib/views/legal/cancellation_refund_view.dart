import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Cancellation and Refund Policy page
class CancellationRefundView extends StatelessWidget {
  const CancellationRefundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancellation and Refund'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancellation and Refund Policy',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: October 5, 2026',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                _buildSection(
                  '1. Subscription Cancellation',
                  'You may cancel your BillSprout subscription at any time through your account settings or by contacting our support team. Upon cancellation:\n\n'
                  '• Your access to the Service will continue until the end of your current billing period\n'
                  '• You will not be charged for subsequent billing periods\n'
                  '• Your data will be retained for 30 days after cancellation\n'
                  '• You can reactivate your subscription within 30 days without data loss',
                ),

                _buildSection(
                  '2. Refund Eligibility',
                  'We offer refunds under the following circumstances:\n\n'
                  '• 7-Day Money-Back Guarantee: Full refund if you cancel within 7 days of your initial subscription purchase\n'
                  '• Service Unavailability: Pro-rated refund if our Service is unavailable for more than 48 consecutive hours due to technical issues on our end\n'
                  '• Billing Errors: Full refund for any duplicate charges or billing errors\n'
                  '• Downgrade Credits: If you downgrade your plan mid-cycle, unused credits may be applied to future billing',
                ),

                _buildSection(
                  '3. Non-Refundable Items',
                  'The following are non-refundable:\n\n'
                  '• Subscription fees after the 7-day money-back guarantee period\n'
                  '• Partial month subscription fees (except for service unavailability)\n'
                  '• Renewal fees for annual subscriptions (except within 7 days of renewal)\n'
                  '• Add-on services or features purchased separately\n'
                  '• License keys that have been activated and used beyond the trial period',
                ),

                _buildSection(
                  '4. How to Request a Refund',
                  'To request a refund:\n\n'
                  '1. Email us at Support@billsprout.online with your account details\n'
                  '2. Include your order/transaction ID and reason for refund\n'
                  '3. Our support team will review your request within 2-3 business days\n'
                  '4. If approved, refunds will be processed within 5-7 business days\n'
                  '5. Refunds will be credited to your original payment method',
                ),

                _buildSection(
                  '5. Annual Subscription Refunds',
                  'For annual subscriptions:\n\n'
                  '• 7-day money-back guarantee applies from the date of purchase\n'
                  '• After 7 days, annual subscriptions are non-refundable\n'
                  '• You can cancel anytime, but the subscription will remain active until the end of the annual period\n'
                  '• Pro-rated refunds are not available for annual plans except in case of extended service unavailability',
                ),

                _buildSection(
                  '6. Monthly Subscription Refunds',
                  'For monthly subscriptions:\n\n'
                  '• 7-day money-back guarantee applies to first-time subscribers\n'
                  '• No refunds for partial months after the guarantee period\n'
                  '• You can cancel anytime without penalty\n'
                  '• Cancellation takes effect at the end of the current billing cycle',
                ),

                _buildSection(
                  '7. Upgrade and Downgrade Policy',
                  'Plan Changes:\n\n'
                  '• Upgrades: Take effect immediately, and you will be charged the pro-rated difference\n'
                  '• Downgrades: Take effect at the end of your current billing cycle\n'
                  '• No refunds for downgrading mid-cycle, but unused credit may be applied\n'
                  '• Feature restrictions apply immediately upon downgrade confirmation',
                ),

                _buildSection(
                  '8. Payment Disputes',
                  'If you dispute a charge with your bank or payment provider:\n\n'
                  '• Your account may be suspended pending resolution\n'
                  '• We will provide all transaction documentation to resolve the dispute\n'
                  '• If the dispute is resolved in our favor, your account will be reactivated\n'
                  '• If resolved in your favor, we will process a refund and close the account',
                ),

                _buildSection(
                  '9. Service Credits',
                  'In case of service disruptions:\n\n'
                  '• Service unavailable for 24-48 hours: 10% service credit\n'
                  '• Service unavailable for 48-72 hours: 25% service credit\n'
                  '• Service unavailable for 72+ hours: 50% service credit or full refund option\n'
                  '• Credits are automatically applied to your next billing cycle',
                ),

                _buildSection(
                  '10. Refund Processing Time',
                  'Refund timelines:\n\n'
                  '• Credit/Debit Cards: 5-7 business days\n'
                  '• UPI/Net Banking: 3-5 business days\n'
                  '• PayPal: 3-5 business days\n'
                  '• Bank Transfer: 7-10 business days\n\n'
                  'Processing time may vary depending on your financial institution.',
                ),

                _buildSection(
                  '11. Data Retention After Refund',
                  'After a refund is processed:\n\n'
                  '• Your data will be retained for 30 days\n'
                  '• You can export your data during this period\n'
                  '• After 30 days, all data will be permanently deleted\n'
                  '• Reactivation after deletion requires setting up a new account',
                ),

                _buildSection(
                  '12. Exceptions and Special Cases',
                  'We reserve the right to refuse refunds in cases of:\n\n'
                  '• Violation of our Terms and Conditions\n'
                  '• Fraudulent activity or abuse of the Service\n'
                  '• Excessive refund requests indicating abuse\n'
                  '• Account termination due to policy violations',
                ),

                _buildSection(
                  '13. Contact for Refund Inquiries',
                  'For refund requests or questions:\n\n'
                  'Email: Support@billsprout.online\n'
                  'WhatsApp: +44 7747 571513\n'
                  'Customer Care: info@lifesproutcare.com\n\n'
                  'Please include your transaction ID and account email for faster processing.',
                ),

                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We aim to process all refund requests within 2-3 business days. Your satisfaction is important to us.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
