import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/status_badge.dart';
import 'package:provider/provider.dart';

/// Business Admin view for downloading BillSprout ERP software.
/// Shows subscription status, license info, and authorized downloads.
class SoftwareDownloadView extends StatefulWidget {
  const SoftwareDownloadView({super.key});

  @override
  State<SoftwareDownloadView> createState() => _SoftwareDownloadViewState();
}

class _SoftwareDownloadViewState extends State<SoftwareDownloadView> {
  final _supabase = SupabaseService();

  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _authorization;
  List<Map<String, dynamic>> _versions = [];

  bool _isLoading = false;
  String? _error;
  String? _downloadingVersionId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final tenantId = auth.tenantId;

      if (tenantId == null) {
        throw Exception('No tenant ID found');
      }

      // Load subscription, authorization status, and versions in parallel
      final results = await Future.wait([
        _supabase.fetchCurrentSubscription(tenantId),
        _supabase.checkDownloadAuthorization(tenantId),
        _supabase.fetchSoftwareVersions(),
      ]);

      setState(() {
        _subscription = results[0] as Map<String, dynamic>?;
        _authorization = results[1] as Map<String, dynamic>;
        _versions = (results[2] as List<Map<String, dynamic>>)
            .where((v) => v['status'] == 'active')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = SupabaseService.describeError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubscriptionCard(),
                      const SizedBox(height: 24),
                      _buildAuthorizationCard(),
                      const SizedBox(height: 24),
                      _buildVersionsList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    if (_subscription == null) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'No Active Subscription',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'You need an active subscription to download BillSprout ERP software.',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to subscription/pricing page
                  Navigator.pushNamed(context, '/pricing');
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('View Plans & Subscribe'),
              ),
            ],
          ),
        ),
      );
    }

    final plan = _subscription!['plan'] as Map<String, dynamic>?;
    final status = _subscription!['status'] as String;
    final licenseKey = _subscription!['license_key'] as String?;
    final licenseStatus = _subscription!['license_status'] as String?;
    final endDate = _subscription!['end_date'] != null
        ? DateTime.parse(_subscription!['end_date'] as String)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Your Subscription',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Plan', plan?['plan_name'] ?? 'Unknown'),
            _buildInfoRow(
              'Status',
              status.toUpperCase(),
              badge: StatusBadge(
                text: status.toUpperCase(),
                color: status == 'active' ? Colors.green : Colors.grey,
              ),
            ),
            if (endDate != null)
              _buildInfoRow(
                'Valid Until',
                DateFormat('MMM dd, yyyy').format(endDate),
              ),
            if (licenseKey != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'License Key',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          licenseKey,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: licenseKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('License key copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy License Key',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StatusBadge(
                text: 'License: ${licenseStatus?.toUpperCase() ?? 'UNKNOWN'}',
                color: licenseStatus == 'active' ? Colors.green : Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizationCard() {
    if (_authorization == null) return const SizedBox.shrink();

    final authorized = _authorization!['authorized'] as bool? ?? false;
    final reason = _authorization!['reason'] as String? ?? 'Unknown';

    return Card(
      color: authorized ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  authorized ? Icons.check_circle : Icons.block,
                  color: authorized ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  authorized ? 'Download Authorized' : 'Download Not Authorized',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(reason),
            if (!authorized) ...[
              const SizedBox(height: 16),
              const Text(
                'Please ensure:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Your subscription is active'),
              const Text('• Your payment is verified'),
              const Text('• Your account is not suspended'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/subscriptions');
                },
                icon: const Icon(Icons.payment),
                label: const Text('Manage Subscription'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsList() {
    final authorized = _authorization?['authorized'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Downloads',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (_versions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.download, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No software versions available yet'),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_versions.map((version) => _VersionDownloadCard(
                version: version,
                authorized: authorized,
                isDownloading: _downloadingVersionId == version['id'],
                onDownload: () => _downloadVersion(version),
              ))),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: badge ??
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVersion(Map<String, dynamic> version) async {
    final authorized = _authorization?['authorized'] as bool? ?? false;

    if (!authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not authorized to download software'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _downloadingVersionId = version['id'] as String;
    });

    try {
      final auth = context.read<AuthProvider>();
      final tenantId = auth.tenantId;

      if (tenantId == null) {
        throw Exception('No tenant ID found');
      }

      // Generate authorized download URL
      final downloadUrl = await _supabase.generateDownloadUrl(
        tenantId: tenantId,
        versionId: version['id'] as String,
      );

      // Launch download in browser
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started in your browser'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Could not launch download URL');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingVersionId = null;
        });
      }
    }
  }
}

// ── Version Download Card Widget ──────────────────────────────────────────
class _VersionDownloadCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final bool authorized;
  final bool isDownloading;
  final VoidCallback onDownload;

  const _VersionDownloadCard({
    required this.version,
    required this.authorized,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final versionNumber = version['version_number'] as String;
    final platform = version['platform'] as String;
    final isLatest = version['is_latest'] as bool? ?? false;
    final releaseDate = DateTime.parse(version['release_date'] as String);
    final releaseNotes = version['release_notes'] as String?;
    final fileSize = version['file_size'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            versionNumber,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 8),
                          if (isLatest)
                            const StatusBadge(
                              text: 'LATEST',
                              color: Colors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Platform: ${_formatPlatform(platform)} • Released: ${DateFormat('MMM dd, yyyy').format(releaseDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (fileSize != null)
                        Text(
                          'Size: $fileSize',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Icon(
                  _getPlatformIcon(platform),
                  size: 48,
                  color: Colors.grey,
                ),
              ],
            ),
            if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Release Notes:',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                releaseNotes,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: authorized && !isDownloading ? onDownload : null,
                icon: isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  isDownloading
                      ? 'Preparing Download...'
                      : authorized
                          ? 'Download'
                          : 'Not Authorized',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: authorized ? Colors.green : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'android':
        return 'Android';
      default:
        return platform.toUpperCase();
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      case 'android':
        return Icons.android;
      default:
        return Icons.download;
    }
  }
}
