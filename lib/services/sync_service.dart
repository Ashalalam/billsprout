import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_model.dart';
import '../providers/auth_provider.dart';
import 'offline_queue_service.dart';
import 'supabase_service.dart';

enum NetworkState { online, offline, syncing }

class SyncService extends ChangeNotifier {
  final AuthProvider authProvider;
  
  NetworkState _networkState = NetworkState.online;
  final List<InvoiceModel> _offlineQueue = [];
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  NetworkState get networkState => _networkState;
  int get pendingSyncCount => _offlineQueue.length;
  bool get isOnline => _networkState == NetworkState.online;

  SyncService({required this.authProvider}) {
    _init();
  }

  Future<void> _init() async {
    // Restore queue that survived an app restart
    final persisted = await OfflineQueueService.loadQueue();
    if (persisted.isNotEmpty) {
      _offlineQueue.addAll(persisted);
      notifyListeners();
      debugPrint('[Sync] Restored ${persisted.length} queued invoices from disk');
    }

    // Watch real network connectivity
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Check current state immediately
    final result = await Connectivity().checkConnectivity();
    _onConnectivityChanged(result);

    // Fallback periodic sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_networkState == NetworkState.online && _offlineQueue.isNotEmpty) {
        triggerManualSync();
      }
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final wasOffline = _networkState == NetworkState.offline;
    _networkState =
        hasConnection ? NetworkState.online : NetworkState.offline;
    notifyListeners();

    // Auto-sync when we come back online
    if (hasConnection && wasOffline && _offlineQueue.isNotEmpty) {
      triggerManualSync();
    }
  }

  /// Queue an invoice for sync. If online, write to Supabase immediately.
  /// If offline, persist to disk and queue in memory.
  Future<void> queueInvoiceForSync(InvoiceModel invoice) async {
    if (_networkState == NetworkState.offline) {
      _offlineQueue.add(invoice);
      await OfflineQueueService.enqueue(invoice);
      notifyListeners();
      debugPrint('[Sync] Queued offline: ${invoice.invoiceNumber}');
    } else {
      await _cloudWrite(invoice);
    }
  }

  /// Flush the entire offline queue to Supabase.
  Future<void> triggerManualSync() async {
    if (_offlineQueue.isEmpty) return;
    
    final tenantId = authProvider.tenantId;
    final branchId = authProvider.branchId;
    final userId = authProvider.userId;
    
    if (tenantId == null || branchId == null || userId.isEmpty) {
      debugPrint('[Sync] Cannot sync: missing tenant/branch/user context');
      return;
    }
    
    _networkState = NetworkState.syncing;
    notifyListeners();
    debugPrint('[Sync] Starting sync of ${_offlineQueue.length} invoices...');

    final toSync = List<InvoiceModel>.from(_offlineQueue);
    try {
      await SupabaseService().upsertInvoiceBatch(
        toSync,
        tenantId: tenantId,
        branchId: branchId,
        createdBy: userId,
      );
      _offlineQueue.clear();
      await OfflineQueueService.clearQueue();
      debugPrint('[Sync] Cloud sync complete ✓');
    } on PostgrestException catch (e) {
      debugPrint('[Sync] Supabase error: ${e.message}');
      // Keep items in queue — will retry on next cycle
    } catch (e) {
      debugPrint('[Sync] Sync error: $e');
    } finally {
      _networkState = NetworkState.online;
      notifyListeners();
    }
  }

  /// Simulate going offline for demo/testing purposes.
  void toggleNetworkMode() {
    if (_networkState == NetworkState.online) {
      _networkState = NetworkState.offline;
    } else {
      _networkState = NetworkState.online;
      if (_offlineQueue.isNotEmpty) triggerManualSync();
    }
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<void> _cloudWrite(InvoiceModel invoice) async {
    final tenantId = authProvider.tenantId;
    final branchId = authProvider.branchId;
    final userId = authProvider.userId;
    
    // Check if we have valid auth context - if not, skip cloud write
    if (tenantId == null || tenantId.isEmpty || branchId == null || branchId.isEmpty) {
      debugPrint('[Sync] Skipping cloud write: missing tenant/branch context');
      return;
    }
    
    final effectiveUserId = userId.isNotEmpty ? userId : 'user_demo_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      await SupabaseService().upsertInvoice(
        invoice,
        tenantId: tenantId,
        branchId: branchId,
        createdBy: effectiveUserId,
      );
      debugPrint('[Sync] ✅ Written to cloud: ${invoice.invoiceNumber}');
    } on PostgrestException catch (e) {
      // Supabase error (e.g. RLS denied) — queue locally
      debugPrint('[Sync] Cloud write failed (${e.message}), queuing locally');
      _offlineQueue.add(invoice);
      await OfflineQueueService.enqueue(invoice);
      notifyListeners();
    } catch (e) {
      // Network error — go offline and queue
      debugPrint('[Sync] Network error: $e — switching to offline mode');
      _networkState = NetworkState.offline;
      _offlineQueue.add(invoice);
      await OfflineQueueService.enqueue(invoice);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
