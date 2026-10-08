import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../services/support_service.dart';

class SupportContactModal extends StatelessWidget {
  const SupportContactModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SupportContactModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Image.asset(
            'assets/images/lifesprout_logo.png',
            height: 60,
            errorBuilder: (_, __, ___) => Icon(Icons.medical_services, size: 50, color: AppTheme.primaryBlue),
          ),
          SizedBox(height: 12),
          Text(
            'LIFESPROUT Care Support Desk',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const Text(
            'BillSprout ERP Technical & Operational Assistance',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const Divider(height: 24),

          // WhatsApp Action Box
          Card(
            color: const Color(0xFFE8F5E9),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFA5D6A7)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: Text(
                'WhatsApp Support & Leads Desk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                AppConfig.whatsappSupportNumber,
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
              ),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => SupportService.openWhatsApp(),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Chat Now'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Technical Support Email
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.mark_email_read, color: AppTheme.primaryBlue),
            ),
            title: const Text('Technical Support Email'),
            subtitle: const Text(AppConfig.technicalSupportEmail),
            onTap: () => SupportService.sendEmail(
              recipientEmail: AppConfig.technicalSupportEmail,
              subject: 'Technical Support Request - BillSprout ERP',
            ),
          ),

          // Customer Care Email
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(Icons.email, color: AppTheme.accentOrange),
            ),
            title: const Text('Customer Care Email'),
            subtitle: const Text(AppConfig.customerCareEmail),
            onTap: () => SupportService.sendEmail(
              recipientEmail: AppConfig.customerCareEmail,
              subject: 'Customer Care Inquiry - Lifesprout Care',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
