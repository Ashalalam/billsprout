import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../widgets/status_badge.dart';

/// Super Admin view for managing software versions and Business Admin access.
/// Three tabs: Software Versions, Business Admin Access, Download History.
class SoftwareManagementView extends StatefulWidget {
  const SoftwareManagementView({super.key});

  @override
  State<SoftwareManagementView> createState() => _SoftwareManagementViewState();
}

class _SoftwareManagementViewState extends State<SoftwareManagementView>
    with SingleTickerProviderStateMixin {
  final _supabase = SupabaseService();
  late TabController _tabController;

  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _businessAdmins = [];
  List<Map<String, dynamic>> _downloadLogs = [];

  bool _isLoadingVersions = false;
  bool _isLoadingAdmins = false;
  bool _isLoadingLogs = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadVersions(),
      _loadBusinessAdmins(),
      _loadDownloadLogs(),
    ]);
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoadingVersions = true;
      _error = null;
    });
    try {
      final versions = await _supabase.fetchSoftwareVersions();
      setState(() {
        _versions = versions;
        _isLoadingVersions = false;
      });
    } catch (e) {
      setState(() {
        _error = SupabaseService.describeError(e);
        _isLoadingVersions = false;
      });
    }
  }

  Future<void> _loadBusinessAdmins() async {
    setState(() {
      _isLoadingAdmins = true;
      _error = null;
    });
    try {
      final admins = await _supabase.fetchBusinessAdminAccess();
      setState(() {
        _businessAdmins = admins;
        _isLoadingAdmins = false;
      });
    } catch (e) {
      setState(() {
        _error = SupabaseService.describeError(e);
        _isLoadingAdmins = false;
      });
    }
  }

  Future<void> _loadDownloadLogs() async {
    setState(() {
      _isLoadingLogs = true;
      _error = null;
    });
    try {
      final logs = await _supabase.fetchDownloadLogs(limit: 100);
      setState(() {
        _downloadLogs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      setState(() {
        _error = SupabaseService.describeError(e);
        _isLoadingLogs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Software Versions', icon: Icon(Icons.cloud_download)),
            Tab(text: 'Business Admin Access', icon: Icon(Icons.business)),
            Tab(text: 'Download History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVersionsTab(),
          _buildBusinessAdminsTab(),
          _buildDownloadLogsTab(),
        ],
      ),
    );
  }

  // ── Software Versions Tab ───────────────────────────────────────────────
  Widget _buildVersionsTab() {
    if (_isLoadingVersions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadVersions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total Versions: ${_versions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload New Version'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _versions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No software versions uploaded yet'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    final version = _versions[index];
                    return _VersionCard(
                      version: version,
                      onToggleStatus: () => _toggleVersionStatus(version),
                      onSetLatest: () => _setLatestVersion(version),
                      onEdit: () => _showEditDialog(version),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Business Admin Access Tab ────────────────────────────────────────────
  Widget _buildBusinessAdminsTab() {
    if (_isLoadingAdmins) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _businessAdmins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBusinessAdmins,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total Business Admins: ${_businessAdmins.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadBusinessAdmins,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _businessAdmins.isEmpty
              ? const Center(child: Text('No Business Admins found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _businessAdmins.length,
                  itemBuilder: (context, index) {
                    final admin = _businessAdmins[index];
                    return _BusinessAdminCard(
                      admin: admin,
                      onToggleAccess: () => _toggleAccessStatus(admin),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Download History Tab ─────────────────────────────────────────────────
  Widget _buildDownloadLogsTab() {
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _downloadLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDownloadLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Downloads: ${_downloadLogs.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadDownloadLogs,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _downloadLogs.isEmpty
              ? const Center(child: Text('No downloads yet'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date/Time')),
                        DataColumn(label: Text('Business')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Version')),
                        DataColumn(label: Text('Platform')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('IP Address')),
                      ],
                      rows: _downloadLogs.map((log) {
                        final downloadedAt = DateTime.parse(
                          log['downloaded_at'] as String,
                        );
                        final tenant = log['tenant'] as Map<String, dynamic>?;
                        final user = log['user'] as Map<String, dynamic>?;
                        final version =
                            log['version'] as Map<String, dynamic>?;
                        final wasAuthorized = log['was_authorized'] as bool?;

                        return DataRow(cells: [
                          DataCell(Text(
                            DateFormat('MMM dd, yyyy HH:mm')
                                .format(downloadedAt),
                          )),
                          DataCell(Text(
                            tenant?['business_name'] ?? 'Unknown',
                          )),
                          DataCell(Text(
                            user?['full_name'] ?? user?['email'] ?? 'Unknown',
                          )),
                          DataCell(Text(
                            version?['version_number'] ?? 'Unknown',
                          )),
                          DataCell(Text(
                            version?['platform'] ?? 'Unknown',
                          )),
                          DataCell(
                            wasAuthorized == true
                                ? const StatusBadge(
                                    text: 'Authorized',
                                    color: Colors.green,
                                  )
                                : StatusBadge(
                                    text: 'Denied',
                                    color: Colors.red[700]!,
                                  ),
                          ),
                          DataCell(Text(log['ip_address'] ?? 'N/A')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _showUploadDialog() async {
    final formKey = GlobalKey<FormState>();
    String versionNumber = '';
    String platform = 'Windows';
    String? releaseNotes;
    bool isLatest = false;
    PlatformFile? selectedFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload New Software Version'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Version Number',
                      hintText: 'e.g., 1.0.5',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v?.isEmpty == true ? 'Required' : null,
                    onSaved: (v) => versionNumber = v!,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Windows',
                        child: Text('Windows'),
                      ),
                      DropdownMenuItem(value: 'Mac', child: Text('macOS')),
                      DropdownMenuItem(value: 'Linux', child: Text('Linux')),
                      DropdownMenuItem(
                        value: 'Web',
                        child: Text('Web'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => platform = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Release Notes (optional)',
                      hintText: 'Bug fixes, new features...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onSaved: (v) => releaseNotes = v,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Latest Version'),
                    value: isLatest,
                    onChanged: (v) => setDialogState(() => isLatest = v!),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        setDialogState(() => selectedFile = result.files.first);
                      }
                    },
                    icon: const Icon(Icons.file_upload),
                    label: Text(
                      selectedFile == null
                          ? 'Select Software File'
                          : selectedFile!.name,
                    ),
                  ),
                  if (selectedFile != null)
                    Text(
                      'Size: ${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a file'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                formKey.currentState!.save();
                Navigator.pop(context);

                await _uploadSoftware(
                  versionNumber: versionNumber,
                  platform: platform,
                  releaseNotes: releaseNotes,
                  isLatest: isLatest,
                  file: selectedFile!,
                );
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadSoftware({
    required String versionNumber,
    required String platform,
    String? releaseNotes,
    required bool isLatest,
    required PlatformFile file,
  }) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading software...')),
    );

    try {
      // Upload file to storage
      final filePath = await _supabase.uploadSoftwareFile(
        fileName: file.name,
        fileBytes: file.bytes!,
        platform: platform,
      );

      // Create database record
      await _supabase.createSoftwareVersion(
        versionNumber: versionNumber,
        platform: platform,
        filePath: filePath,
        releaseNotes: releaseNotes,
        fileSize: '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB',
        isLatest: isLatest,
      );

      await _loadVersions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Software version uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleVersionStatus(Map<String, dynamic> version) async {
    final currentStatus = version['status'] as String;
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    try {
      await _supabase.updateSoftwareVersion(version['id'] as String, {
        'status': newStatus,
      });
      await _loadVersions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Version status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setLatestVersion(Map<String, dynamic> version) async {
    try {
      // First, unmark all versions for this platform
      final platform = version['platform'] as String;
      final allVersions = _versions.where((v) => v['platform'] == platform);
      for (final v in allVersions) {
        if (v['is_latest'] == true) {
          await _supabase.updateSoftwareVersion(v['id'] as String, {
            'is_latest': false,
          });
        }
      }

      // Then mark this one as latest
      await _supabase.updateSoftwareVersion(version['id'] as String, {
        'is_latest': true,
      });

      await _loadVersions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latest version updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> version) async {
    final formKey = GlobalKey<FormState>();
    String releaseNotes = version['release_notes'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${version['version_number']}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: releaseNotes,
            decoration: const InputDecoration(
              labelText: 'Release Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            onSaved: (v) => releaseNotes = v ?? '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              formKey.currentState!.save();
              Navigator.pop(context);

              try {
                await _supabase.updateSoftwareVersion(
                  version['id'] as String,
                  {'release_notes': releaseNotes},
                );
                await _loadVersions();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Version updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(SupabaseService.describeError(e)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAccessStatus(Map<String, dynamic> admin) async {
    final currentStatus = admin['access_status'] as String;
    final newStatus = currentStatus == 'active' ? 'suspended' : 'active';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus == 'suspended' ? 'Suspend' : 'Activate'} Access?'),
        content: Text(
          newStatus == 'suspended'
              ? 'This will immediately prevent ${admin['tenant_name']} from downloading software and activating licenses.'
              : 'This will restore download and license access for ${admin['tenant_name']}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  newStatus == 'suspended' ? Colors.red : Colors.green,
            ),
            child: Text(newStatus == 'suspended' ? 'Suspend' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.updateTenantAccessStatus(
        tenantId: admin['tenant_id'] as String,
        status: newStatus,
      );
      await _loadBusinessAdmins();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ── Version Card Widget ───────────────────────────────────────────────────
class _VersionCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final VoidCallback onToggleStatus;
  final VoidCallback onSetLatest;
  final VoidCallback onEdit;

  const _VersionCard({
    required this.version,
    required this.onToggleStatus,
    required this.onSetLatest,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final versionNumber = version['version_number'] as String;
    final platform = version['platform'] as String;
    final status = version['status'] as String;
    final isLatest = version['is_latest'] as bool? ?? false;
    final releaseDate = DateTime.parse(version['release_date'] as String);
    final downloadCount = version['download_count'] as int? ?? 0;
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
                          const SizedBox(width: 8),
                          StatusBadge(
                            text: status.toUpperCase(),
                            color: status == 'active' ? Colors.green : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Platform: ${platform.toUpperCase()} • Released: ${DateFormat('MMM dd, yyyy').format(releaseDate)}',
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
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: onEdit,
                      tooltip: 'Edit',
                    ),
                    Text(
                      '$downloadCount downloads',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            if (version['release_notes'] != null) ...[
              const SizedBox(height: 8),
              Text(
                version['release_notes'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(
                    status == 'active' ? Icons.block : Icons.check_circle,
                  ),
                  label: Text(
                    status == 'active' ? 'Deactivate' : 'Activate',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        status == 'active' ? Colors.red[700] : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isLatest)
                  OutlinedButton.icon(
                    onPressed: onSetLatest,
                    icon: const Icon(Icons.star),
                    label: const Text('Set as Latest'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Business Admin Card Widget ─────────────────────────────────────────────
class _BusinessAdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final VoidCallback onToggleAccess;

  const _BusinessAdminCard({
    required this.admin,
    required this.onToggleAccess,
  });

  @override
  Widget build(BuildContext context) {
    final tenantName = admin['tenant_name'] as String;
    final subscriptionStatus = admin['subscription_status'] as String?;
    final licenseStatus = admin['license_status'] as String?;
    final accessStatus = admin['access_status'] as String;
    final canDownload = admin['can_download'] as bool? ?? false;
    final endDate = admin['subscription_end_date'] != null
        ? DateTime.parse(admin['subscription_end_date'] as String)
        : null;

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
                      Text(
                        tenantName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StatusBadge(
                            text: 'Access: ${accessStatus.toUpperCase()}',
                            color: accessStatus == 'active'
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          if (subscriptionStatus != null)
                            StatusBadge(
                              text: 'Sub: ${subscriptionStatus.toUpperCase()}',
                              color: subscriptionStatus == 'active'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          const SizedBox(width: 8),
                          if (licenseStatus != null)
                            StatusBadge(
                              text: 'License: ${licenseStatus.toUpperCase()}',
                              color: licenseStatus == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (endDate != null)
                        Text(
                          'Valid until: ${DateFormat('MMM dd, yyyy').format(endDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      canDownload ? Icons.check_circle : Icons.block,
                      color: canDownload ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    Text(
                      canDownload ? 'Can Download' : 'Cannot Download',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onToggleAccess,
              icon: Icon(
                accessStatus == 'active' ? Icons.block : Icons.check_circle,
              ),
              label: Text(
                accessStatus == 'active' ? 'Suspend Access' : 'Activate Access',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    accessStatus == 'active' ? Colors.red[700] : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
