import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../widgets/patient_dashboard_card.dart';
import '../widgets/recent_purchases_widget.dart';
import '../widgets/prescription_upload_widget.dart';
import '../widgets/medicine_search_widget.dart';
import '../widgets/refill_requests_widget.dart';
import '../widgets/health_profile_widget.dart';
import '../widgets/appointments_widget.dart';

class CustomerPortalView extends StatefulWidget {
  const CustomerPortalView({super.key});

  @override
  State<CustomerPortalView> createState() => _CustomerPortalViewState();
}

class _CustomerPortalViewState extends State<CustomerPortalView> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Load customer data when portal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      customerProvider.loadCustomerPurchaseHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final customer = Provider.of<CustomerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_pharmacy, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient Portal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Welcome, ${auth.currentUser?.name ?? 'Patient'}',
                  style: const TextStyle(fontSize: 12, opacity: 0.8),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showProfile(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(context, customer),
          _buildPurchaseHistory(context, customer),
          _buildPrescriptions(context, customer),
          _buildMedicineSearch(context, customer),
          _buildRefills(context, customer),
          _buildHealthProfile(context, customer),
          _buildAppointments(context, customer),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Purchases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Prescriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Medicines',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.refresh),
            label: 'Refills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, CustomerProvider customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: PatientDashboardCard(
                  title: 'Active Prescriptions',
                  value: '3',
                  icon: Icons.medication,
                  color: Colors.green,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PatientDashboardCard(
                  title: 'Pending Refills',
                  value: '1',
                  icon: Icons.refresh,
                  color: Colors.orange,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PatientDashboardCard(
                  title: 'Total Purchases',
                  value: customer.purchaseHistory.length.toString(),
                  icon: Icons.shopping_cart,
                  color: AppTheme.primaryBlue,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PatientDashboardCard(
                  title: 'Appointments',
                  value: '2',
                  icon: Icons.calendar_today,
                  color: Colors.purple,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildQuickActionCard(
                'Upload Prescription',
                Icons.upload_file,
                Colors.blue,
                () => _uploadPrescription(context),
              ),
              _buildQuickActionCard(
                'Order Medicine',
                Icons.add_shopping_cart,
                Colors.green,
                () => setState(() => _selectedIndex = 3),
              ),
              _buildQuickActionCard(
                'Request Refill',
                Icons.autorenew,
                Colors.orange,
                () => _requestRefill(context),
              ),
              _buildQuickActionCard(
                'Book Appointment',
                Icons.calendar_month,
                Colors.purple,
                () => _bookAppointment(context),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          RecentPurchasesWidget(customer: customer),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseHistory(BuildContext context, CustomerProvider customer) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purchase History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'View all your past medicine purchases and prescriptions',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: customer.isLoading
              ? const Center(child: CircularProgressIndicator())
              : customer.purchaseHistory.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No purchases yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          Text('Your purchase history will appear here', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: customer.purchaseHistory.length,
                      itemBuilder: (context, index) {
                        final purchase = customer.purchaseHistory[index];
                        return _buildPurchaseCard(purchase);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> purchase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice #${purchase['invoice_number']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${purchase['total_amount'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateTime.parse(purchase['invoice_date']).toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (purchase['sale_items'] != null && (purchase['sale_items'] as List).isNotEmpty)
              ...[(purchase['sale_items'] as List).take(3).map((item) => 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${item['product_name']} (${item['quantity']} units)'),
                ),
              )],
            if ((purchase['sale_items'] as List).length > 3)
              Text('... and ${(purchase['sale_items'] as List).length - 3} more items'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptions(BuildContext context, CustomerProvider customer) {
    return PrescriptionUploadWidget();
  }

  Widget _buildMedicineSearch(BuildContext context, CustomerProvider customer) {
    return MedicineSearchWidget();
  }

  Widget _buildRefills(BuildContext context, CustomerProvider customer) {
    return RefillRequestsWidget();
  }

  Widget _buildHealthProfile(BuildContext context, CustomerProvider customer) {
    return HealthProfileWidget();
  }

  Widget _buildAppointments(BuildContext context, CustomerProvider customer) {
    return AppointmentsWidget();
  }

  void _uploadPrescription(BuildContext context) {
    setState(() => _selectedIndex = 2);
  }

  void _requestRefill(BuildContext context) {
    setState(() => _selectedIndex = 4);
  }

  void _bookAppointment(BuildContext context) {
    setState(() => _selectedIndex = 6);
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.medication, color: Colors.green),
              title: const Text('Prescription Ready'),
              subtitle: const Text('Your Metformin prescription is ready for pickup'),
              trailing: const Text('2h ago'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Appointment Reminder'),
              subtitle: const Text('Consultation with Dr. Smith tomorrow at 10 AM'),
              trailing: const Text('1d ago'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProfile(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${auth.currentUser?.name ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Email: ${auth.currentUser?.email ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Phone: ${auth.currentUser?.phone ?? 'N/A'}'),
            const SizedBox(height: 8),
            const Text('Patient ID: PAT-001'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
