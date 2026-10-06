import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/app_config.dart';

/// Contact Us page
class ContactUsView extends StatelessWidget {
  const ContactUsView({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We\'re here to help! Reach out to us through any of the following channels.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Methods Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                          child: _buildContactCard(
                            icon: Icons.email,
                            title: 'Email Support',
                            subtitle: 'Get help via email',
                            content: AppConfig.customerCareEmail,
                            action: () => _launchEmail(AppConfig.customerCareEmail),
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                          child: _buildContactCard(
                            icon: Icons.support_agent,
                            title: 'Technical Support',
                            subtitle: 'For technical issues',
                            content: AppConfig.technicalSupportEmail,
                            action: () => _launchEmail(AppConfig.technicalSupportEmail),
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                          child: _buildContactCard(
                            icon: Icons.phone,
                            title: 'WhatsApp Support',
                            subtitle: 'Quick chat support',
                            content: AppConfig.whatsappSupportNumber,
                            action: () => _launchUrl(AppConfig.whatsappLink),
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                          child: _buildContactCard(
                            icon: Icons.business,
                            title: 'Business Inquiries',
                            subtitle: 'For partnerships',
                            content: 'info@lifesproutcare.com',
                            action: () => _launchEmail('info@lifesproutcare.com'),
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 32),

                // Office Information
                const Text(
                  'Our Office',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.primaryBlue),
                            const SizedBox(width: 12),
                            Text(
                              AppConfig.companyName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Headquarters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'India',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Business Hours
                const Text(
                  'Business Hours',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildBusinessHourRow('Monday - Friday', '9:00 AM - 6:00 PM IST'),
                        const SizedBox(height: 12),
                        _buildBusinessHourRow('Saturday', '10:00 AM - 4:00 PM IST'),
                        const SizedBox(height: 12),
                        _buildBusinessHourRow('Sunday', 'Closed'),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Email support is available 24/7. We aim to respond within 24 hours.',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Quick Links
                const Text(
                  'Quick Links',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickLink(
                          context,
                          'View Subscription Plans',
                          Icons.card_membership,
                          () => Navigator.pushNamed(context, '/subscription-plans'),
                        ),
                        const Divider(height: 24),
                        _buildQuickLink(
                          context,
                          'My License',
                          Icons.vpn_key,
                          () => Navigator.pushNamed(context, '/my-license'),
                        ),
                        const Divider(height: 24),
                        _buildQuickLink(
                          context,
                          'Terms and Conditions',
                          Icons.description,
                          () => Navigator.pushNamed(context, '/terms-conditions'),
                        ),
                        const Divider(height: 24),
                        _buildQuickLink(
                          context,
                          'Privacy Policy',
                          Icons.privacy_tip,
                          () => Navigator.pushNamed(context, '/privacy-policy'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // FAQ Section
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildFAQ(
                  'How do I activate my license?',
                  'After purchase, you\'ll receive a license key via email. Download BillSprout, install it, and enter the license key when prompted. For detailed instructions, visit your account dashboard.',
                ),
                _buildFAQ(
                  'What payment methods do you accept?',
                  'We accept payments via Razorpay (Credit/Debit cards, UPI, Net Banking, Wallets) and PayPal for international customers.',
                ),
                _buildFAQ(
                  'Can I upgrade my plan later?',
                  'Yes! You can upgrade your subscription plan at any time. The upgrade takes effect immediately, and you\'ll only pay the pro-rated difference.',
                ),
                _buildFAQ(
                  'Do you offer a free trial?',
                  'Yes, we offer a 7-day money-back guarantee. If you\'re not satisfied within the first 7 days, contact us for a full refund.',
                ),
                _buildFAQ(
                  'How do I cancel my subscription?',
                  'You can cancel anytime from your account settings. Your access continues until the end of your current billing period.',
                ),

                const SizedBox(height: 32),

                // Call to Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Still have questions?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Our support team is here to help you succeed',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _launchEmail(AppConfig.customerCareEmail),
                        icon: const Icon(Icons.email),
                        label: const Text('Email Us Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
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

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String content,
    required VoidCallback action,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessHourRow(String day, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 15),
        ),
        Text(
          hours,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLink(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
