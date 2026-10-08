import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../config/app_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, _) {
        Color badgeColor;
        String statusText;
        IconData statusIcon;

        switch (syncService.networkState) {
          case NetworkState.online:
            badgeColor = AppTheme.successGreen;
            statusText = 'Online (Supabase Cloud)';
            statusIcon = Icons.cloud_done;
            break;
          case NetworkState.offline:
            badgeColor = AppTheme.warningAmber;
            statusText = 'Offline Queue (${syncService.pendingSyncCount} pending)';
            statusIcon = Icons.cloud_off;
            break;
          case NetworkState.syncing:
            badgeColor = Colors.blue;
            statusText = 'Syncing Local Queue...';
            statusIcon = Icons.sync;
            break;
        }

        return InkWell(
          onTap: () => _showSyncControlDialog(context, syncService),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: badgeColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSyncControlDialog(BuildContext context, SyncService syncService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hybrid Sync & Connectivity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Mode: ${syncService.networkState.name.toUpperCase()}'),
            SizedBox(height: 8),
            Text('Pending Offline Transactions: ${syncService.pendingSyncCount}'),
            SizedBox(height: 16),
            Text(
              'BillSprout automatically queues all POS transactions offline during internet drops and replays them to Supabase PostgreSQL upon reconnection.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              syncService.toggleNetworkMode();
              Navigator.pop(ctx);
            },
            child: Text(syncService.isOnline ? 'Simulate Offline Outage' : 'Restore Online Network'),
          ),
          if (syncService.pendingSyncCount > 0)
            ElevatedButton(
              onPressed: () {
                syncService.triggerManualSync();
                Navigator.pop(ctx);
              },
              child: const Text('Force Cloud Sync'),
            ),
        ],
      ),
    );
  }
}
