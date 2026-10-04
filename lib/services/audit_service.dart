import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// AuditService logs security-sensitive actions for compliance and security monitoring.
/// 
/// Logs are stored in the audit_logs table with:
/// - Who performed the action (user_id, user_role)
/// - What was done (action, details)
/// - When it happened (timestamp)
/// - Where (tenant_id for multi-tenant isolation)
/// 
/// Usage:
/// ```dart
/// await AuditService.log(
///   action: 'user_login',
///   userId: auth.userId,
///   userRole: auth.currentUser!.role.name,
///   tenantId: auth.tenantId,
///   details: {'email': email, 'ip_address': ipAddress},
/// );
/// ```
class AuditService {
  /// Logs an action to the audit_logs table
  static Future<void> log({
    required String action,
    required String userId,
    required String userRole,
    String? tenantId,
    Map<String, dynamic>? details,
    String? resourceType,
    String? resourceId,
  }) async {
    // Skip audit logging in demo mode
    if (!AppConfig.supabaseConfigured) {
      if (kDebugMode) {
        print('[Audit] Demo mode: $action by $userId ($userRole)');
      }
      return;
    }

    try {
      final client = Supabase.instance.client;
      
      await client.from('audit_logs').insert({
        'user_id': userId,
        'user_role': userRole,
        'tenant_id': tenantId,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'details': details,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'ip_address': await _getClientIP(),
      });

      if (kDebugMode) {
        print('[Audit] Logged: $action by $userId ($userRole)');
      }
    } catch (e) {
      // Don't fail the operation if audit logging fails
      // But log the error for monitoring
      if (kDebugMode) {
        print('[Audit] Error logging action: $e');
      }
    }
  }

  /// Log authentication events
  static Future<void> logAuth({
    required String action,
    required String userId,
    required String userRole,
    String? tenantId,
    String? email,
    bool success = true,
    String? errorMessage,
  }) async {
    await log(
      action: action,
      userId: userId,
      userRole: userRole,
      tenantId: tenantId,
      details: {
        'email': email,
        'success': success,
        if (errorMessage != null) 'error': errorMessage,
      },
    );
  }

  /// Log data access events (for sensitive data like customer info, financial records)
  static Future<void> logDataAccess({
    required String action,
    required String userId,
    required String userRole,
    String? tenantId,
    required String resourceType,
    required String resourceId,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: action,
      userId: userId,
      userRole: userRole,
      tenantId: tenantId,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details,
    );
  }

  /// Log admin actions (for privileged operations)
  static Future<void> logAdminAction({
    required String action,
    required String userId,
    required String userRole,
    String? tenantId,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: action,
      userId: userId,
      userRole: userRole,
      tenantId: tenantId,
      details: {
        'description': description,
        ...?details,
      },
    );
  }

  /// Log security events (failed auth, permission denied, etc.)
  static Future<void> logSecurityEvent({
    required String action,
    required String userId,
    required String userRole,
    String? tenantId,
    required String severity,  // 'low', 'medium', 'high', 'critical'
    required String description,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: action,
      userId: userId,
      userRole: userRole,
      tenantId: tenantId,
      details: {
        'severity': severity,
        'description': description,
        ...?details,
      },
    );
  }

  /// Attempt to get client IP address (returns null if not available)
  static Future<String?> _getClientIP() async {
    // In Flutter web, we can't easily get client IP
    // This would need to be passed from backend or proxy
    return null;
  }
}

/// Common audit action constants
class AuditActions {
  // Authentication
  static const String userLogin = 'user_login';
  static const String userLogout = 'user_logout';
  static const String loginFailed = 'login_failed';
  static const String sessionExpired = 'session_expired';
  static const String roleRevalidated = 'role_revalidated';
  
  // Authorization
  static const String accessDenied = 'access_denied';
  static const String unauthorizedAttempt = 'unauthorized_attempt';
  static const String roleChanged = 'role_changed';
  
  // Data Access
  static const String dataViewed = 'data_viewed';
  static const String dataExported = 'data_exported';
  static const String sensitiveDataAccessed = 'sensitive_data_accessed';
  
  // Admin Actions
  static const String userCreated = 'user_created';
  static const String userUpdated = 'user_updated';
  static const String userDeleted = 'user_deleted';
  static const String userRoleChanged = 'user_role_changed';
  static const String userDeactivated = 'user_deactivated';
  static const String tenantCreated = 'tenant_created';
  static const String tenantUpdated = 'tenant_updated';
  static const String settingsChanged = 'settings_changed';
  
  // Business Operations
  static const String saleCompleted = 'sale_completed';
  static const String saleVoided = 'sale_voided';
  static const String inventoryAdjusted = 'inventory_adjusted';
  static const String priceChanged = 'price_changed';
  static const String prescriptionFilled = 'prescription_filled';
  
  // Security Events
  static const String suspiciousActivity = 'suspicious_activity';
  static const String multipleLoginAttempts = 'multiple_login_attempts';
  static const String privilegeEscalation = 'privilege_escalation_attempt';
  static const String dataIntegrityViolation = 'data_integrity_violation';
}
