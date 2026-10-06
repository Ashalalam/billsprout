import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Shipping and Exchange Policy page
class ShippingExchangeView extends StatelessWidget {
  const ShippingExchangeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping and Exchange'),
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
                  'Shipping and Exchange Policy',
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

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_download, color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'BillSprout is a digital software product delivered electronically. No physical shipping is involved.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                _buildSection(
                  '1. Digital Product Delivery',
                  'BillSprout is a cloud-based software solution and license management system:\n\n'
                  '• Instant Access: Upon successful payment, your license key is generated immediately\n'
                  '• Digital Download: Software can be downloaded from your account dashboard\n'
                  '• No Physical Shipping: There are no physical products to ship\n'
                  '• Email Delivery: License key and download links sent to your registered email\n'
                  '• Global Availability: Accessible worldwide with an internet connection',
                ),

                _buildSection(
                  '2. Software Delivery Process',
                  'After purchase, you will receive:\n\n'
                  '1. Order Confirmation: Immediate email with order details\n'
                  '2. License Key: Unique activation code for your subscription\n'
                  '3. Download Links: Access to the latest software version\n'
                  '4. Installation Guide: Step-by-step setup instructions\n'
                  '5. Support Resources: Documentation and video tutorials\n\n'
                  'Delivery Time: Instant (within seconds of payment confirmation)',
                ),

                _buildSection(
                  '3. Access to Your Account',
                  'You can access your BillSprout account and software:\n\n'
                  '• Online Portal: Log in at any time from any device\n'
                  '• Desktop Application: Download and install on Windows, Mac, or Linux\n'
                  '• Mobile Access: Available on Android and iOS devices\n'
                  '• Multi-Device: Use on multiple devices as per your subscription plan\n'
                  '• Cloud Sync: Data synchronized across all your devices',
                ),

                _buildSection(
                  '4. License Key Issues',
                  'If you experience issues with your license key:\n\n'
                  '• Not Received: Check spam/junk folder first\n'
                  '• Lost Key: Retrieve from your account dashboard under "My License"\n'
                  '• Invalid Key: Contact support with your order ID\n'
                  '• Activation Problems: Our support team will assist within 24 hours\n'
                  '• Multiple Devices: Each plan has a specific device limit',
                ),

                _buildSection(
                  '5. Plan Exchange/Upgrade',
                  'You can exchange or upgrade your subscription plan:\n\n'
                  '• Upgrade Anytime: Switch to a higher plan immediately\n'
                  '• Downgrade: Change to a lower plan at the end of current billing cycle\n'
                  '• Feature Access: Upgraded features available instantly\n'
                  '• Pro-rated Billing: Pay only the difference when upgrading\n'
                  '• No Exchange Fee: Plan changes are free of charge',
                ),

                _buildSection(
                  '6. Version Updates',
                  'Software updates are delivered automatically:\n\n'
                  '• Free Updates: All bug fixes and minor updates included\n'
                  '• Major Versions: Included in active subscription\n'
                  '• Auto-Update: Optional automatic update installation\n'
                  '• Manual Download: Available from your account dashboard\n'
                  '• Beta Access: Professional and Enterprise plans get early access',
                ),

                _buildSection(
                  '7. Data Migration',
                  'For customers switching from other systems:\n\n'
                  '• Free Data Import: Assistance with importing your existing data\n'
                  '• Supported Formats: CSV, Excel, XML, and custom formats\n'
                  '• Migration Support: Professional and Enterprise plans include migration assistance\n'
                  '• Training Included: Get trained on using BillSprout effectively\n'
                  '• No Data Loss: We ensure complete and accurate data transfer',
                ),

                _buildSection(
                  '8. Hardware Requirements',
                  'Minimum system requirements:\n\n'
                  '• Operating System: Windows 10+, macOS 10.14+, Linux (Ubuntu 18.04+)\n'
                  '• Processor: Intel Core i3 or equivalent\n'
                  '• RAM: 4GB minimum, 8GB recommended\n'
                  '• Storage: 500MB free space\n'
                  '• Internet: Broadband connection for cloud sync\n'
                  '• Browser: Chrome 90+, Firefox 88+, Safari 14+, Edge 90+',
                ),

                _buildSection(
                  '9. Technical Support',
                  'Comprehensive support included:\n\n'
                  '• Email Support: Available for all plans\n'
                  '• Priority Support: Professional and Enterprise plans\n'
                  '• Phone/WhatsApp: Enterprise plan customers\n'
                  '• Response Time: Within 24 hours (1 hour for Enterprise)\n'
                  '• Knowledge Base: Extensive self-help documentation\n'
                  '• Video Tutorials: Step-by-step guides',
                ),

                _buildSection(
                  '10. Subscription Transfers',
                  'Transferring your subscription:\n\n'
                  '• Account Transfer: Contact support to transfer ownership\n'
                  '• Business Sale: Subscription can be transferred to new owner\n'
                  '• Name Change: Update account details anytime\n'
                  '• Email Change: Primary email can be updated\n'
                  '• Verification Required: Identity verification for security',
                ),

                _buildSection(
                  '11. Lost Access Recovery',
                  'If you lose access to your account:\n\n'
                  '• Password Reset: Use "Forgot Password" feature\n'
                  '• Email Recovery: Sent to registered email\n'
                  '• Account Lockout: Contact support for assistance\n'
                  '• Backup Codes: Save backup codes for emergency access\n'
                  '• Two-Factor Auth: Can be reset by support team',
                ),

                _buildSection(
                  '12. Contact for Delivery Issues',
                  'For any delivery or access issues:\n\n'
                  'Email: Support@billsprout.online\n'
                  'Technical Support: info@lifesproutcare.com\n'
                  'WhatsApp: +44 7747 571513\n\n'
                  'Include your order ID and account email for faster resolution.',
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
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Instant delivery, hassle-free upgrades, and lifetime support. Your success is our priority.',
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
