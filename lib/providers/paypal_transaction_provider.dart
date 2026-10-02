import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/paypal_transaction_model.dart';

/// PayPal Transaction Provider
/// 
/// Manages PayPal transaction tracking and history.
/// Stores transactions locally for audit and reconciliation.
class PayPalTransactionProvider extends ChangeNotifier {
  final List<PayPalTransaction> _transactions = [];
  bool _isLoading = false;

  List<PayPalTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  /// Get transactions for a specific invoice
  List<PayPalTransaction> getTransactionsForInvoice(String invoiceNumber) {
    return _transactions
        .where((t) => t.invoiceNumber == invoiceNumber)
        .toList();
  }

  /// Get pending transactions
  List<PayPalTransaction> get pendingTransactions {
    return _transactions
        .where((t) => t.status == PayPalTransactionStatus.pending)
        .toList();
  }

  /// Get completed transactions
  List<PayPalTransaction> get completedTransactions {
    return _transactions
        .where((t) => t.status == PayPalTransactionStatus.completed)
        .toList();
  }

  /// Get failed transactions
  List<PayPalTransaction> get failedTransactions {
    return _transactions
        .where((t) => t.status == PayPalTransactionStatus.failed)
        .toList();
  }

  /// Get total amount of completed transactions
  double get totalCompletedAmount {
    return completedTransactions.fold(
      0.0,
      (sum, txn) => sum + txn.amount,
    );
  }

  PayPalTransactionProvider() {
    _loadTransactions();
  }

  /// Load transactions from SharedPreferences
  Future<void> _loadTransactions() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString('paypal_transactions');

      if (transactionsJson != null) {
        final List<dynamic> decoded = json.decode(transactionsJson);
        _transactions.clear();
        _transactions.addAll(
          decoded.map((json) => PayPalTransaction.fromJson(json)).toList(),
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PayPal] Error loading transactions: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save transactions to SharedPreferences
  Future<void> _saveTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = json.encode(
        _transactions.map((t) => t.toJson()).toList(),
      );
      await prefs.setString('paypal_transactions', transactionsJson);
    } catch (e) {
      debugPrint('[PayPal] Error saving transactions: $e');
    }
  }

  /// Create a new pending transaction
  Future<PayPalTransaction> createTransaction({
    required String invoiceNumber,
    required double amount,
    String currency = 'USD',
  }) async {
    final transaction = PayPalTransaction.pending(
      invoiceNumber: invoiceNumber,
      amount: amount,
      currency: currency,
    );

    _transactions.add(transaction);
    await _saveTransactions();
    notifyListeners();

    debugPrint('[PayPal] Transaction created: ${transaction.id}');
    return transaction;
  }

  /// Mark transaction as completed
  Future<void> completeTransaction(
    String transactionId, {
    String? paypalOrderId,
    String? paypalTransactionId,
    String? payerEmail,
    String? payerName,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      debugPrint('[PayPal] Transaction not found: $transactionId');
      return;
    }

    final updated = _transactions[index].markCompleted(
      paypalOrderId: paypalOrderId,
      paypalTransactionId: paypalTransactionId,
      payerEmail: payerEmail,
      payerName: payerName,
    );

    _transactions[index] = updated;
    await _saveTransactions();
    notifyListeners();

    debugPrint('[PayPal] Transaction completed: $transactionId');
  }

  /// Mark transaction as failed
  Future<void> failTransaction(String transactionId, String errorMessage) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      debugPrint('[PayPal] Transaction not found: $transactionId');
      return;
    }

    final updated = _transactions[index].markFailed(errorMessage);
    _transactions[index] = updated;
    await _saveTransactions();
    notifyListeners();

    debugPrint('[PayPal] Transaction failed: $transactionId - $errorMessage');
  }

  /// Mark transaction as cancelled
  Future<void> cancelTransaction(String transactionId) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      debugPrint('[PayPal] Transaction not found: $transactionId');
      return;
    }

    final updated = _transactions[index].markCancelled();
    _transactions[index] = updated;
    await _saveTransactions();
    notifyListeners();

    debugPrint('[PayPal] Transaction cancelled: $transactionId');
  }

  /// Clear old transactions (cleanup)
  Future<void> clearOldTransactions({int daysToKeep = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    final before = _transactions.length;
    _transactions.removeWhere((t) => 
      t.status.isFinal && t.completedAt != null && t.completedAt!.isBefore(cutoffDate)
    );
    
    if (_transactions.length < before) {
      await _saveTransactions();
      notifyListeners();
      debugPrint('[PayPal] Cleared ${before - _transactions.length} old transactions');
    }
  }

  /// Clear all transactions (use with caution)
  Future<void> clearAllTransactions() async {
    _transactions.clear();
    await _saveTransactions();
    notifyListeners();
    debugPrint('[PayPal] All transactions cleared');
  }

  /// Export transactions to JSON (for backup/reporting)
  String exportTransactionsJson() {
    return json.encode(_transactions.map((t) => t.toJson()).toList());
  }

  /// Import transactions from JSON (for backup restore)
  Future<void> importTransactionsJson(String jsonString) async {
    try {
      final List<dynamic> decoded = json.decode(jsonString);
      final imported = decoded.map((json) => PayPalTransaction.fromJson(json)).toList();
      
      _transactions.clear();
      _transactions.addAll(imported);
      
      await _saveTransactions();
      notifyListeners();
      
      debugPrint('[PayPal] Imported ${imported.length} transactions');
    } catch (e) {
      debugPrint('[PayPal] Error importing transactions: $e');
      rethrow;
    }
  }

  /// Get transaction statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_transactions': _transactions.length,
      'pending': pendingTransactions.length,
      'completed': completedTransactions.length,
      'failed': failedTransactions.length,
      'total_amount': totalCompletedAmount,
      'average_amount': completedTransactions.isEmpty 
          ? 0.0 
          : totalCompletedAmount / completedTransactions.length,
    };
  }
}
