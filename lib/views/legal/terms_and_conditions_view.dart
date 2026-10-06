import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Terms and Conditions page
class TermsAndConditionsView extends StatelessWidget {
  const TermsAndConditionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
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
                  'Terms and Conditions',
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
                  '1. Acceptance of Terms',
                  'By accessing and using LifeSprout Care\'s BillSprout software ("the Service"), you accept and agree to be bound by the terms and conditions of this agreement. If you do not agree to these terms, please do not use the Service.',
                ),

                _buildSection(
                  '2. License Grant',
                  'Subject to your compliance with these Terms, LifeSprout Care grants you a limited, non-exclusive, non-transferable, revocable license to use the BillSprout software for your business purposes in accordance with the subscription plan you have purchased.',
                ),

                _buildSection(
                  '3. Subscription Plans',
                  'BillSprout is offered through various subscription plans (Basic, Professional, Enterprise). Each plan includes specific features and usage limits as described on our pricing page. You may upgrade or downgrade your plan at any time, subject to availability and pricing at the time of change.',
                ),

                _buildSection(
                  '4. Payment Terms',
                  'Subscription fees are billed in advance on a monthly or annual basis. All fees are non-refundable except as required by law or as explicitly stated in our Cancellation and Refund policy. You are responsible for providing accurate billing information and maintaining valid payment methods.',
                ),

                _buildSection(
                  '5. User Responsibilities',
                  'You are responsible for:\n'
                  '• Maintaining the confidentiality of your account credentials\n'
                  '• All activities that occur under your account\n'
                  '• Ensuring that your use of the Service complies with all applicable laws and regulations\n'
                  '• The accuracy and legality of all data you input into the system\n'
                  '• Maintaining appropriate backups of your data',
                ),

                _buildSection(
                  '6. Prohibited Uses',
                  'You agree not to:\n'
                  '• Use the Service for any illegal purpose\n'
                  '• Attempt to gain unauthorized access to any part of the Service\n'
                  '• Interfere with or disrupt the Service or servers\n'
                  '• Reverse engineer, decompile, or disassemble the software\n'
                  '• Resell or redistribute the Service without authorization\n'
                  '• Remove or modify any proprietary notices',
                ),

                _buildSection(
                  '7. Data Privacy and Security',
                  'We take data privacy seriously. Your use of the Service is also governed by our Privacy Policy. We implement industry-standard security measures to protect your data, but we cannot guarantee absolute security. You are responsible for maintaining the security of your account credentials.',
                ),

                _buildSection(
                  '8. Intellectual Property',
                  'All rights, title, and interest in and to the Service, including all software, text, media, and other content available through the Service, are and will remain the exclusive property of LifeSprout Care and its licensors. You may not use our trademarks without prior written consent.',
                ),

                _buildSection(
                  '9. Service Availability',
                  'We strive to maintain 99.9% uptime but do not guarantee uninterrupted access to the Service. We may modify, suspend, or discontinue any aspect of the Service at any time. We will provide advance notice of significant changes where reasonably possible.',
                ),

                _buildSection(
                  '10. Limitation of Liability',
                  'To the maximum extent permitted by law, LifeSprout Care shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses.',
                ),

                _buildSection(
                  '11. Indemnification',
                  'You agree to indemnify and hold harmless LifeSprout Care and its officers, directors, employees, and agents from any claims, losses, damages, liabilities, including legal fees and expenses, arising out of your use or misuse of the Service, violation of these Terms, or infringement of any intellectual property or other rights.',
                ),

                _buildSection(
                  '12. Termination',
                  'We may terminate or suspend your access to the Service immediately, without prior notice, for any breach of these Terms. Upon termination, your right to use the Service will immediately cease. You may cancel your subscription at any time through your account settings.',
                ),

                _buildSection(
                  '13. Governing Law',
                  'These Terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions. Any disputes arising from these Terms or your use of the Service shall be subject to the exclusive jurisdiction of the courts in India.',
                ),

                _buildSection(
                  '14. Changes to Terms',
                  'We reserve the right to modify these Terms at any time. We will notify users of any material changes via email or through the Service. Your continued use of the Service after such modifications constitutes acceptance of the updated Terms.',
                ),

                _buildSection(
                  '15. Contact Information',
                  'If you have any questions about these Terms, please contact us at:\n\n'
                  'Email: info@lifesproutcare.com\n'
                  'Support: Support@billsprout.online\n'
                  'WhatsApp: +44 7747 571513',
                ),

                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'By using BillSprout, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
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
