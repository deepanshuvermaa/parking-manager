import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'export_import_service.dart';
import '../utils/debug_logger.dart';

/// Auto Backup Service
/// Manages hourly automatic backups in the background
class AutoBackupService {
  static Timer? _backupTimer;
  static bool _isRunning = false;
  static const Duration BACKUP_INTERVAL = Duration(hours: 1);

  /// Start the auto-backup service
  static Future<void> start({String? userToken}) async {
    if (_isRunning) {
      DebugLogger.log('⚠️ Auto-backup service already running');
      return;
    }

    final enabled = await ExportImportService.isAutoBackupEnabled();
    if (!enabled) {
      DebugLogger.log('⏭️ Auto-backup disabled, not starting service');
      return;
    }

    DebugLogger.log('🚀 Starting auto-backup service (hourly)');

    // Perform initial backup immediately
    await _performBackup(userToken: userToken);

    // Schedule hourly backups
    _backupTimer = Timer.periodic(BACKUP_INTERVAL, (timer) async {
      await _performBackup(userToken: userToken);
    });

    _isRunning = true;
  }

  /// Stop the auto-backup service
  static void stop() {
    if (_backupTimer != null) {
      _backupTimer!.cancel();
      _backupTimer = null;
      _isRunning = false;
      DebugLogger.log('⏹️ Auto-backup service stopped');
    }
  }

  /// Restart the service (useful when settings change)
  static Future<void> restart({String? userToken}) async {
    stop();
    await start(userToken: userToken);
  }

  /// Perform backup
  static Future<void> _performBackup({String? userToken}) async {
    try {
      final enabled = await ExportImportService.isAutoBackupEnabled();
      if (!enabled) {
        DebugLogger.log('⏭️ Auto-backup disabled, stopping service');
        stop();
        return;
      }

      // Check if enough time has passed since last backup
      final prefs = await SharedPreferences.getInstance();
      final lastBackupTimeStr = prefs.getString(ExportImportService.LAST_BACKUP_TIME_KEY);

      if (lastBackupTimeStr != null) {
        final lastBackupTime = DateTime.parse(lastBackupTimeStr);
        final timeSinceLastBackup = DateTime.now().difference(lastBackupTime);

        // Skip if last backup was less than 55 minutes ago (safety margin)
        if (timeSinceLastBackup.inMinutes < 55) {
          DebugLogger.log('⏭️ Skipping backup, last backup was ${timeSinceLastBackup.inMinutes} minutes ago');
          return;
        }
      }

      DebugLogger.log('⏰ Performing scheduled hourly backup...');
      final success = await ExportImportService.performHourlyBackup(userToken: userToken);

      if (success) {
        DebugLogger.log('✅ Scheduled backup completed successfully');
      } else {
        DebugLogger.log('⚠️ Scheduled backup failed');
      }
    } catch (e) {
      DebugLogger.log('❌ Auto-backup error: $e');
    }
  }

  /// Check if service is running
  static bool get isRunning => _isRunning;

  /// Force an immediate backup (manual trigger)
  static Future<bool> forceBackup({String? userToken}) async {
    DebugLogger.log('🔄 Force backup triggered');
    return await ExportImportService.performHourlyBackup(userToken: userToken);
  }
}
