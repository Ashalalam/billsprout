import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../views/legal/terms_and_conditions_view.dart';
import '../views/legal/privacy_policy_view.dart';
import '../views/legal/cancellation_refund_view.dart';
import '../views/legal/shipping_exchange_view.dart';
import '../views/legal/contact_us_view.dart';

/// App Footer with legal pages links
/// Required footer with five legal pages: Terms, Privacy, Cancellation, Shipping, Contact
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 16 : 32,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Legal Links Section
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: isNarrow ? 12 : 24,
                  runSpacing: 12,
                  children: [
                    _buildFooterLink(
                      context,
                      'Terms and Conditions',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsAndConditionsView(),
                        ),
                      ),
                    ),
                    _buildFooterDivider(isNarrow),
                    _buildFooterLink(
                      context,
                      'Privacy Policy',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyView(),
                        ),
                      ),
                    ),
                    _buildFooterDivider(isNarrow),
                    _buildFooterLink(
                      context,
                      'Cancellation and Refund',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CancellationRefundView(),
                        ),
                      ),
                    ),
                    _buildFooterDivider(isNarrow),
                    _buildFooterLink(
                      context,
                      'Shipping and Exchange',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShippingExchangeView(),
                        ),
                      ),
                    ),
                    _buildFooterDivider(isNarrow),
                    _buildFooterLink(
                      context,
                      'Contact Us',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsView(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.grey[400]),
                const SizedBox(height: 16),

                // Company Info and Copyright
                Column(
                  children: [
                    Text(
                      '© ${DateTime.now().year} ${AppConfig.companyName}. All rights reserved.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppConfig.appName} ${AppConfig.version}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterDivider(bool isNarrow) {
    if (isNarrow) return const SizedBox.shrink();
    
    return Container(
      height: 16,
      width: 1,
      color: Colors.grey[400],
    );
  }
}
