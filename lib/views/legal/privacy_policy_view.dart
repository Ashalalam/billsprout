import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Privacy Policy page
class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                  'Privacy Policy',
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
                  '1. Introduction',
                  'LifeSprout Care ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our BillSprout software and services. Please read this policy carefully.',
                ),

                _buildSection(
                  '2. Information We Collect',
                  'We collect information that you provide directly to us, including:\n\n'
                  '• Account Information: Name, email address, phone number, business details\n'
                  '• Business Data: Inventory records, customer information, sales transactions, invoices\n'
                  '• Payment Information: Payment method details, billing address (processed securely through third-party payment providers)\n'
                  '• Usage Data: How you interact with our Service, features used, time spent\n'
                  '• Technical Data: IP address, browser type, device information, operating system',
                ),

                _buildSection(
                  '3. How We Use Your Information',
                  'We use the collected information for:\n\n'
                  '• Providing and maintaining the Service\n'
                  '• Processing your transactions and managing your subscription\n'
                  '• Sending you technical notices, updates, and support messages\n'
                  '• Responding to your comments and questions\n'
                  '• Analyzing usage patterns to improve our Service\n'
                  '• Detecting and preventing fraud and abuse\n'
                  '• Complying with legal obligations',
                ),

                _buildSection(
                  '4. Data Storage and Security',
                  'Your data is stored securely on cloud servers with industry-standard encryption. We implement appropriate technical and organizational measures to protect your data against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
                ),

                _buildSection(
                  '5. Data Retention',
                  'We retain your information for as long as your account is active or as needed to provide you services. We will retain and use your information as necessary to comply with our legal obligations, resolve disputes, and enforce our agreements. You can request deletion of your data at any time.',
                ),

                _buildSection(
                  '6. Sharing of Information',
                  'We do not sell your personal information. We may share your information only in the following circumstances:\n\n'
                  '• With Service Providers: Payment processors (Razorpay, PayPal), cloud hosting providers, and analytics services\n'
                  '• For Legal Reasons: When required by law, court order, or government request\n'
                  '• Business Transfers: In connection with a merger, sale, or acquisition\n'
                  '• With Your Consent: When you explicitly authorize us to share your information',
                ),

                _buildSection(
                  '7. Third-Party Services',
                  'Our Service integrates with third-party services:\n\n'
                  '• Razorpay: For payment processing (governed by Razorpay\'s privacy policy)\n'
                  '• PayPal: For payment processing (governed by PayPal\'s privacy policy)\n'
                  '• Supabase: For cloud hosting and database services\n\n'
                  'These third parties have their own privacy policies, and we encourage you to review them.',
                ),

                _buildSection(
                  '8. Your Privacy Rights',
                  'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate or incomplete data\n'
                  '• Request deletion of your data\n'
                  '• Object to processing of your data\n'
                  '• Request data portability\n'
                  '• Withdraw consent at any time\n\n'
                  'To exercise these rights, please contact us at info@lifesproutcare.com',
                ),

                _buildSection(
                  '9. Cookies and Tracking',
                  'We use cookies and similar tracking technologies to track activity on our Service and hold certain information. Cookies are files with small amounts of data that are stored on your device. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent.',
                ),

                _buildSection(
                  '10. Data Protection for Healthcare',
                  'As pharmacy management software, we handle sensitive healthcare-related information. We implement additional safeguards to protect this data and comply with applicable healthcare data protection regulations. We do not access or use your patient data for any purpose other than providing the Service.',
                ),

                _buildSection(
                  '11. Children\'s Privacy',
                  'Our Service is not intended for users under the age of 18. We do not knowingly collect personal information from children under 18. If you become aware that a child has provided us with personal information, please contact us.',
                ),

                _buildSection(
                  '12. International Data Transfers',
                  'Your information may be transferred to and maintained on servers located outside of your jurisdiction where data protection laws may differ. By using our Service, you consent to such transfers.',
                ),

                _buildSection(
                  '13. Changes to Privacy Policy',
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically.',
                ),

                _buildSection(
                  '14. Contact Us',
                  'If you have questions about this Privacy Policy or our data practices, please contact us:\n\n'
                  'Email: info@lifesproutcare.com\n'
                  'Support: Support@billsprout.online\n'
                  'WhatsApp: +44 7747 571513\n\n'
                  'Data Protection Officer: info@lifesproutcare.com',
                ),

                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your privacy is important to us. We are committed to protecting your data and being transparent about our practices.',
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
