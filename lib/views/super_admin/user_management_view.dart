import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/logger.dart';

/// Super Admin - User Management & Access Control
class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('users')
          .select('''
            *,
            tenant_subscriptions(
              id,
              plan_id,
              status,
              start_date,
              end_date,
              subscription_plans(plan_name)
            )
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(result);
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load users', error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _filterStatus == null ||
          (user['is_active'] == (_filterStatus == 'active'));
      
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, 
                        color: AppTheme.primaryBlue, size: 32),
                    const SizedBox(width: 12),
                    const Text(
                      'User Management & Access Control',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadUsers,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _filterStatus,
                      hint: const Text('Filter Status'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Users')),
                        DropdownMenuItem(value: 'active', child: Text('Active Only')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspended Only')),
                      ],
                      onChanged: (value) => setState(() => _filterStatus = value),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Users',
                    '${_users.length}',
                    Icons.people,
                    AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Active Users',
                    '${_users.where((u) => u['is_active'] == true).length}',
                    Icons.check_circle,
                    AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Suspended',
                    '${_users.where((u) => u['is_active'] == false).length}',
                    Icons.block,
                    AppTheme.errorRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'With Subscription',
                    '${_users.where((u) => u['tenant_subscriptions'] != null).length}',
                    Icons.workspace_premium,
                    AppTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] == true;
    final subscription = user['tenant_subscriptions'];
    final hasPaid = subscription != null && subscription is List && subscription.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isActive 
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.errorRed.withValues(alpha: 0.1),
                  child: Icon(
                    isActive ? Icons.person : Icons.person_off,
                    color: isActive ? AppTheme.successGreen : AppTheme.errorRed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user['name'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                                  : AppTheme.errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'SUSPENDED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? AppTheme.successGreen : AppTheme.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (user['phone'] != null && user['phone'].toString().isNotEmpty)
                        Text(
                          user['phone'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasPaid) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentOrange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              size: 16,
                              color: AppTheme.accentOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              subscription[0]['subscription_plans']?['plan_name'] ?? 'Subscribed',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showDownloadDialog(user),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'No Subscription',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleUserStatus(user),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    label: Text(isActive ? 'Suspend Access' : 'Activate Access'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? AppTheme.errorRed : AppTheme.successGreen,
                      side: BorderSide(
                        color: isActive ? AppTheme.errorRed : AppTheme.successGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserDetails(user),
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final currentStatus = user['is_active'] == true;
    final newStatus = !currentStatus;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus ? 'Activate User?' : 'Suspend User?'),
        content: Text(
          newStatus
              ? 'This will allow ${user['name']} to access the software.'
              : 'This will prevent ${user['name']} from accessing the software.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.successGreen : AppTheme.errorRed,
            ),
            child: Text(newStatus ? 'Activate' : 'Suspend'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;
      await client
          .from('users')
          .update({'is_active': newStatus})
          .eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'User activated successfully'
                  : 'User suspended successfully',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      Logger.error('Failed to update user status', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final subscription = user['tenant_subscriptions'];
    final hasPaid = subscription != null && subscription is List && subscription.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Text(user['name'] ?? 'User Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Name', user['name'] ?? 'N/A'),
              _detailRow('Email', user['email'] ?? 'N/A'),
              _detailRow('Phone', user['phone'] ?? 'N/A'),
              _detailRow('Role', user['role'] ?? 'N/A'),
              _detailRow(
                'Status',
                user['is_active'] == true ? 'Active' : 'Suspended',
              ),
              const Divider(),
              if (hasPaid) ...[
                const Text(
                  'Subscription Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Plan',
                  subscription[0]['subscription_plans']?['plan_name'] ?? 'N/A',
                ),
                _detailRow('Status', subscription[0]['status'] ?? 'N/A'),
                _detailRow(
                  'Start Date',
                  subscription[0]['start_date'] ?? 'N/A',
                ),
                _detailRow('End Date', subscription[0]['end_date'] ?? 'N/A'),
              ] else
                const Text(
                  'No active subscription',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDownloadDialog(Map<String, dynamic> user) {
    const downloadUrl = 'https://github.com/Ashalalam/billsprout/releases';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: AppTheme.primaryBlue),
            SizedBox(width: 12),
            Text('Software Download'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Download link for: ${user['name']}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      downloadUrl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: downloadUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Download link copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: User must be active to download and use the software.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Download Page'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
