import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';

/// Public downloads page for LifeSprout software
class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _latestVersion;
  List<Map<String, dynamic>> _downloads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch latest version
      final versionResponse = await _supabase
          .from('software_versions')
          .select()
          .eq('is_latest', true)
          .eq('is_active', true)
          .single();

      _latestVersion = versionResponse;

      // Fetch downloads for latest version
      final downloadsResponse = await _supabase
          .from('software_downloads')
          .select()
          .eq('version_id', _latestVersion!['id'])
          .eq('is_active', true)
          .order('platform');

      _downloads = List<Map<String, dynamic>>.from(downloadsResponse as List);

      Logger.info('Loaded ${_downloads.length} downloads for version ${_latestVersion!['version_number']}');
    } catch (e) {
      Logger.error('Error loading downloads', error: e);
      _error = 'Failed to load downloads. Please try again later.';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download LifeSprout'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildDownloadsView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDownloads,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsView() {
    if (_latestVersion == null || _downloads.isEmpty) {
      return const Center(
        child: Text('No downloads available at this time.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              _buildHeader(),
              
              const SizedBox(height: 48),
              
              // Downloads grid
              _buildDownloadsGrid(),
              
              const SizedBox(height: 48),
              
              // Release notes
              _buildReleaseNotes(),
              
              const SizedBox(height: 48),
              
              // System requirements
              _buildSystemRequirements(),
              
              const SizedBox(height: 48),
              
              // Installation instructions
              _buildInstallationInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final versionNumber = _latestVersion!['version_number'] as String;
    final versionName = _latestVersion!['version_name'] as String?;
    final releaseDate = DateTime.parse(_latestVersion!['release_date'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Download LifeSprout',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'v$versionNumber${versionName != null ? ' - $versionName' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Released: ${releaseDate.day}/${releaseDate.month}/${releaseDate.year}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Smart pharmacy management system with POS, inventory tracking, and GST-compliant billing.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsGrid() {
    // Group downloads by platform
    final windowsDownloads = _downloads.where((d) => d['platform'] == 'windows').toList();
    final macDownloads = _downloads.where((d) => d['platform'] == 'mac').toList();
    final linuxDownloads = _downloads.where((d) => d['platform'] == 'linux').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Platform',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            if (windowsDownloads.isNotEmpty)
              _buildPlatformCard(
                'Windows',
                Icons.desktop_windows,
                Colors.blue,
                windowsDownloads,
              ),
            if (macDownloads.isNotEmpty)
              _buildPlatformCard(
                'macOS',
                Icons.apple,
                Colors.grey[700]!,
                macDownloads,
              ),
            if (linuxDownloads.isNotEmpty)
              _buildPlatformCard(
                'Linux',
                Icons.computer,
                Colors.orange,
                linuxDownloads,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformCard(
    String platform,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> downloads,
  ) {
    return Card(
      elevation: 4,
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(width: 16),
                Text(
                  platform,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...downloads.map((download) => _buildDownloadButton(download)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(Map<String, dynamic> download) {
    final architecture = download['architecture'] as String?;
    final fileSizeBytes = download['file_size_bytes'] as int?;
    final fileSize = fileSizeBytes != null ? _formatFileSize(fileSizeBytes) : 'Unknown size';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _downloadFile(download),
          icon: const Icon(Icons.download),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                architecture != null ? '$architecture (${architecture.toUpperCase()})' : 'Download',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                fileSize,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseNotes() {
    final releaseNotes = _latestVersion!['release_notes'] as String?;
    if (releaseNotes == null || releaseNotes.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Release Notes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              releaseNotes,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemRequirements() {
    final minOsVersion = _latestVersion!['min_os_version'] as Map<String, dynamic>?;
    if (minOsVersion == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Requirements',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (minOsVersion['windows'] != null)
              _buildRequirementRow('Windows', minOsVersion['windows']),
            if (minOsVersion['mac'] != null)
              _buildRequirementRow('macOS', minOsVersion['mac']),
            if (minOsVersion['linux'] != null)
              _buildRequirementRow('Linux', minOsVersion['linux']),
            const SizedBox(height: 12),
            const Text(
              '• Minimum 4GB RAM recommended\n'
              '• 500MB free disk space\n'
              '• Internet connection for sync (offline mode available)',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String platform, String version) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$platform: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(version),
        ],
      ),
    );
  }

  Widget _buildInstallationInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Installation Instructions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Windows:\n'
              '1. Download the .exe installer\n'
              '2. Run the installer and follow the setup wizard\n'
              '3. Launch LifeSprout from the Start menu\n\n'
              'macOS:\n'
              '1. Download the .dmg file\n'
              '2. Open the .dmg and drag LifeSprout to Applications\n'
              '3. Launch from Applications or Launchpad\n\n'
              'Linux:\n'
              '1. Download the AppImage file\n'
              '2. Make it executable: chmod +x LifeSprout-*.AppImage\n'
              '3. Run the AppImage\n\n'
              'For support, contact us at support@lifesprout.com',
              style: TextStyle(fontSize: 14, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _downloadFile(Map<String, dynamic> download) async {
    final url = download['download_url'] as String;
    final fileName = download['file_name'] as String;

    try {
      // Log the download
      await _logDownload(download['id'] as String, download['version_id'] as String);

      // Launch download URL
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading $fileName...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not launch download URL');
      }
    } catch (e) {
      Logger.error('Download error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logDownload(String downloadId, String versionId) async {
    try {
      final user = _supabase.auth.currentUser;
      
      await _supabase.from('download_logs').insert({
        'download_id': downloadId,
        'version_id': versionId,
        'tenant_id': user?.userMetadata?['tenant_id'],
        'user_id': user?.id,
        'platform': _detectPlatform(),
      });
      
      Logger.info('Download logged successfully');
    } catch (e) {
      Logger.error('Failed to log download', error: e);
      // Don't block download if logging fails
    }
  }

  String _detectPlatform() {
    // Simple platform detection
    final userAgent = '';
    if (userAgent.contains('Windows')) return 'windows';
    if (userAgent.contains('Mac')) return 'mac';
    if (userAgent.contains('Linux')) return 'linux';
    return 'unknown';
  }
}
