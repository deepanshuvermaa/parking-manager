import 'package:shared_preferences/shared_preferences.dart';
import '../providers/simplified_auth_provider.dart';

class AdminService {
  static const String _deletionCodeKey = 'deletion_code';
  static const String _defaultDeletionCode = 'DELETE123'; // Default code

  /// Get the current deletion code
  static Future<String> getDeletionCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deletionCodeKey) ?? _defaultDeletionCode;
    } catch (e) {
      return _defaultDeletionCode;
    }
  }

  /// Set a new deletion code (admin only)
  static Future<bool> setDeletionCode(String newCode, String adminPassword) async {
    try {
      // Validate admin password
      if (adminPassword != 'Dv12062001@') {
        return false;
      }

      // Validate new code
      if (newCode.isEmpty || newCode.length < 6) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deletionCodeKey, newCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset deletion code to default (super admin only)
  static Future<bool> resetDeletionCode(String adminPassword) async {
    try {
      if (adminPassword != 'Dv12062001@') {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deletionCodeKey, _defaultDeletionCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate deletion code
  static Future<bool> validateDeletionCode(String code) async {
    try {
      final currentCode = await getDeletionCode();
      return code == currentCode;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can delete items (admin or super admin)
  static bool canDeleteItems(SimplifiedAuthProvider authProvider) {
    return authProvider.isAdmin || authProvider.isSuperAdmin;
  }

  /// Get admin permissions
  static Map<String, bool> getAdminPermissions(SimplifiedAuthProvider authProvider) {
    final isAdmin = authProvider.isAdmin;
    final isSuperAdmin = authProvider.isSuperAdmin;

    return {
      'canDelete': isAdmin || isSuperAdmin,
      'canEditSettings': isAdmin || isSuperAdmin,
      'canManageUsers': isSuperAdmin,
      'canResetDeletionCode': isSuperAdmin,
      'canSetDeviceLimits': isSuperAdmin,
      'canViewAllReports': isAdmin || isSuperAdmin,
      'canExportData': isAdmin || isSuperAdmin,
    };
  }

  /// Log admin action for audit trail
  static Future<void> logAdminAction(
    String action,
    String itemType,
    String itemId,
    String adminUserId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Get existing audit log
      final existingLog = prefs.getStringList('admin_audit_log') ?? [];

      // Add new entry
      final logEntry = '$timestamp|$action|$itemType|$itemId|$adminUserId';
      existingLog.add(logEntry);

      // Keep only last 100 entries
      if (existingLog.length > 100) {
        existingLog.removeRange(0, existingLog.length - 100);
      }

      await prefs.setStringList('admin_audit_log', existingLog);
    } catch (e) {
      // Log error but don't fail the operation
      print('Failed to log admin action: $e');
    }
  }

  /// Get admin audit log
  static Future<List<Map<String, String>>> getAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logEntries = prefs.getStringList('admin_audit_log') ?? [];

      return logEntries.map((entry) {
        final parts = entry.split('|');
        if (parts.length >= 5) {
          return {
            'timestamp': parts[0],
            'action': parts[1],
            'itemType': parts[2],
            'itemId': parts[3],
            'adminUserId': parts[4],
          };
        }
        return <String, String>{};
      }).where((entry) => entry.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear audit log (super admin only)
  static Future<bool> clearAuditLog(String adminPassword) async {
    try {
      if (adminPassword != 'Dv12062001@') {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_audit_log');
      return true;
    } catch (e) {
      return false;
    }
  }
}