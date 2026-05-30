import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/debug_logger.dart';
import 'local_database_service.dart';
import 'taxi_booking_service.dart';
import '../models/simple_vehicle.dart';

class ExportImportService {
  static const String BACKUP_DIR = 'ParkEase_Backups';
  static const String CURRENT_BACKUP = 'current_backup.json';
  static const String HOURLY_DIR = 'hourly_snapshots';
  static const String MANUAL_DIR = 'manual_backups';
  static const String LAST_BACKUP_TIME_KEY = 'last_auto_backup_time';
  static const String LAST_BACKUP_RECORD_COUNT_KEY = 'last_backup_record_count';
  static const String AUTO_BACKUP_ENABLED_KEY = 'auto_backup_enabled';

  /// Get backup directory on device - uses Downloads folder to survive uninstall
  static Future<Directory> getBackupDirectory() async {
    Directory appDocDir;

    if (Platform.isAndroid) {
      // Use Downloads/ParkEase_Backups/ - survives app uninstall
      final downloadsDir = Directory('/storage/emulated/0/Download/$BACKUP_DIR');
      if (await _requestStoragePermission()) {
        appDocDir = downloadsDir;
      } else {
        // Fallback to external storage (scoped, deleted on uninstall)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          appDocDir = Directory('${externalDir.path}/$BACKUP_DIR');
        } else {
          appDocDir = Directory('${(await getApplicationDocumentsDirectory()).path}/$BACKUP_DIR');
        }
      }
    } else {
      appDocDir = Directory('${(await getApplicationDocumentsDirectory()).path}/$BACKUP_DIR');
    }

    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }

    return appDocDir;
  }

  /// Request storage permission for writing to Downloads
  static Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    // Android 11+ uses MANAGE_EXTERNAL_STORAGE, below uses WRITE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    // Try manage external storage first (Android 11+)
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback to regular storage permission
    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Export all app data (settings + vehicle data + taxi bookings)
  static Future<Map<String, dynamic>> exportAllData({String? userToken}) async {
    final prefs = await SharedPreferences.getInstance();

    // Get all SharedPreferences keys
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> exportData = {
      'export_version': '2.0', // Version 2.0 includes database data
      'export_date': DateTime.now().toIso8601String(),
      'app_name': 'Go2-Parking',
    };

    // Export all settings
    final Map<String, dynamic> settings = {};
    for (final key in allKeys) {
      // Skip backup-related keys to avoid circular references
      if (key.startsWith('last_backup') || key == AUTO_BACKUP_ENABLED_KEY) {
        continue;
      }

      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    exportData['settings'] = settings;

    // Export all vehicles from local database
    try {
      final vehicles = await LocalDatabaseService.getVehicles();
      exportData['vehicles'] = vehicles.map((v) => {
        'id': v.id,
        'vehicle_number': v.vehicleNumber,
        'vehicle_type': v.vehicleType,
        'entry_time': v.entryTime.toIso8601String(),
        'exit_time': v.exitTime?.toIso8601String(),
        'amount': v.amount,
        'status': v.status,
        'ticket_id': v.ticketId,
        'hourly_rate': v.hourlyRate,
        'minimum_rate': v.minimumRate,
        'notes': v.notes,
        'duration_minutes': v.durationMinutes,
        'from_location': v.fromLocation,
        'to_location': v.toLocation,
      }).toList();

      DebugLogger.log('📦 Exported ${vehicles.length} vehicles');
    } catch (e) {
      DebugLogger.log('⚠️ Failed to export vehicles: $e');
      exportData['vehicles'] = [];
    }

    // Export all taxi bookings (if user is logged in)
    if (userToken != null && userToken.isNotEmpty) {
      try {
        final result = await TaxiBookingService.getBookings(userToken);
        final bookings = result['bookings'] as List;
        exportData['taxi_bookings'] = bookings.map((b) => {
          'id': b.id,
          'user_id': b.userId,
          'ticket_number': b.ticketNumber,
          'booking_date': b.bookingDate.toIso8601String(),
          'customer_name': b.customerName,
          'customer_mobile': b.customerMobile,
          'vehicle_name': b.vehicleName,
          'vehicle_number': b.vehicleNumber,
          'from_location': b.fromLocation,
          'to_location': b.toLocation,
          'fare_amount': b.fareAmount,
          'start_time': b.startTime?.toIso8601String(),
          'end_time': b.endTime?.toIso8601String(),
          'status': b.status,
          'remarks_1': b.remarks1,
          'remarks_2': b.remarks2,
          'remarks_3': b.remarks3,
          'driver_name': b.driverName,
          'driver_mobile': b.driverMobile,
        }).toList();

        DebugLogger.log('📦 Exported ${bookings.length} taxi bookings');
      } catch (e) {
        DebugLogger.log('⚠️ Failed to export taxi bookings: $e');
        exportData['taxi_bookings'] = [];
      }
    } else {
      exportData['taxi_bookings'] = [];
    }

    final totalRecords = (exportData['vehicles'] as List).length +
                        (exportData['taxi_bookings'] as List).length +
                        settings.length;

    DebugLogger.log('📦 Export completed: $totalRecords total records exported');
    exportData['total_records'] = totalRecords;

    return exportData;
  }

  /// Perform hourly auto-backup (incremental)
  static Future<bool> performHourlyBackup({String? userToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(AUTO_BACKUP_ENABLED_KEY) ?? true;

      if (!enabled) {
        DebugLogger.log('⏭️ Auto-backup disabled, skipping');
        return false;
      }

      DebugLogger.log('🔄 Starting hourly auto-backup...');

      // Get backup directory
      final backupDir = await getBackupDirectory();

      // Create hourly snapshots directory
      final hourlyDir = Directory('${backupDir.path}/$HOURLY_DIR');
      if (!await hourlyDir.exists()) {
        await hourlyDir.create(recursive: true);
      }

      // Export all data
      final exportData = await exportAllData(userToken: userToken);

      // Save as current backup (always latest)
      final currentBackupFile = File('${backupDir.path}/$CURRENT_BACKUP');
      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);
      await currentBackupFile.writeAsString(jsonString);

      // Save hourly snapshot with timestamp
      final timestamp = DateTime.now();
      final hourlyFileName = 'backup_${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}-00.json';
      final hourlyFile = File('${hourlyDir.path}/$hourlyFileName');
      await hourlyFile.writeAsString(jsonString);

      // Cleanup old hourly backups (keep only last 24 hours)
      await _cleanupOldBackups(hourlyDir);

      // Update last backup metadata
      await prefs.setString(LAST_BACKUP_TIME_KEY, timestamp.toIso8601String());
      await prefs.setInt(LAST_BACKUP_RECORD_COUNT_KEY, exportData['total_records'] as int);

      DebugLogger.log('✅ Hourly backup completed: ${exportData['total_records']} records');
      return true;
    } catch (e) {
      DebugLogger.log('❌ Hourly backup failed: $e');
      return false;
    }
  }

  /// Cleanup old backups (keep last 7 days)
  static Future<void> _cleanupOldBackups(Directory hourlyDir) async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(days: 7));

      final files = await hourlyDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await file.delete();
            DebugLogger.log('🗑️ Deleted old backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      DebugLogger.log('⚠️ Cleanup failed: $e');
    }
  }

  /// Get last backup info
  static Future<Map<String, dynamic>?> getLastBackupInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupTime = prefs.getString(LAST_BACKUP_TIME_KEY);
      final lastRecordCount = prefs.getInt(LAST_BACKUP_RECORD_COUNT_KEY);

      if (lastBackupTime == null) {
        return null;
      }

      return {
        'last_backup_time': lastBackupTime,
        'last_record_count': lastRecordCount ?? 0,
        'backup_exists': await _doesCurrentBackupExist(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Check if current backup file exists
  static Future<bool> _doesCurrentBackupExist() async {
    try {
      final backupDir = await getBackupDirectory();
      final currentBackupFile = File('${backupDir.path}/$CURRENT_BACKUP');
      return await currentBackupFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Restore from last auto-backup
  static Future<Map<String, dynamic>> restoreFromAutoBackup() async {
    try {
      final backupDir = await getBackupDirectory();
      final currentBackupFile = File('${backupDir.path}/$CURRENT_BACKUP');

      if (!await currentBackupFile.exists()) {
        return {'success': false, 'error': 'No backup file found'};
      }

      // Read and parse backup file
      final jsonString = await currentBackupFile.readAsString();
      final Map<String, dynamic> importData = json.decode(jsonString);

      return await _restoreData(importData);
    } catch (e) {
      DebugLogger.log('❌ Restore from auto-backup failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Export data to JSON file and share (manual backup)
  static Future<bool> exportToFile({String? userToken}) async {
    try {
      // Get export data
      final exportData = await exportAllData(userToken: userToken);

      // Get backup directory
      final backupDir = await getBackupDirectory();

      // Create manual backups directory
      final manualDir = Directory('${backupDir.path}/$MANUAL_DIR');
      if (!await manualDir.exists()) {
        await manualDir.create(recursive: true);
      }

      // Convert to JSON string
      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      // Save to manual backups
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'manual_backup_$timestamp.json';
      final filePath = '${manualDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonString);

      DebugLogger.log('✅ Manual backup created: $filePath');

      // Share the file
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Go2-Parking Manual Backup',
        text: 'Manual backup created on ${DateTime.now().toString().split('.')[0]}\n${exportData['total_records']} records',
      );

      return result.status == ShareResultStatus.success ||
             result.status == ShareResultStatus.dismissed;
    } catch (e) {
      DebugLogger.log('❌ Manual export failed: $e');
      return false;
    }
  }

  /// Import data from file
  static Future<Map<String, dynamic>> importFromFile() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'error': 'No file selected'};
      }

      // Read file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // Parse JSON
      final Map<String, dynamic> importData = json.decode(jsonString);

      return await _restoreData(importData);
    } catch (e) {
      DebugLogger.log('❌ Import failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Internal method to restore data
  static Future<Map<String, dynamic>> _restoreData(Map<String, dynamic> importData) async {
    try {
      // Validate format
      if (!importData.containsKey('export_version') ||
          !importData.containsKey('settings')) {
        return {'success': false, 'error': 'Invalid backup file format'};
      }

      int imported = 0;

      // Restore settings
      final prefs = await SharedPreferences.getInstance();
      final settings = importData['settings'] as Map<String, dynamic>;

      for (final entry in settings.entries) {
        final key = entry.key;
        final value = entry.value;

        try {
          if (value is String) {
            await prefs.setString(key, value);
            imported++;
          } else if (value is int) {
            await prefs.setInt(key, value);
            imported++;
          } else if (value is double) {
            await prefs.setDouble(key, value);
            imported++;
          } else if (value is bool) {
            await prefs.setBool(key, value);
            imported++;
          } else if (value is List<String>) {
            await prefs.setStringList(key, value);
            imported++;
          }
        } catch (e) {
          DebugLogger.log('⚠️ Failed to import key $key: $e');
        }
      }

      // Restore vehicles
      int vehiclesRestored = 0;
      if (importData.containsKey('vehicles')) {
        final vehiclesData = importData['vehicles'] as List;

        for (final vehicleJson in vehiclesData) {
          try {
            final vehicle = SimpleVehicle(
              id: vehicleJson['id'],
              vehicleNumber: vehicleJson['vehicle_number'],
              vehicleType: vehicleJson['vehicle_type'],
              entryTime: DateTime.parse(vehicleJson['entry_time']),
              exitTime: vehicleJson['exit_time'] != null
                  ? DateTime.parse(vehicleJson['exit_time'])
                  : null,
              amount: vehicleJson['amount'],
              status: vehicleJson['status'],
              ticketId: vehicleJson['ticket_id'],
              hourlyRate: vehicleJson['hourly_rate'],
              minimumRate: vehicleJson['minimum_rate'],
              notes: vehicleJson['notes'],
              durationMinutes: vehicleJson['duration_minutes'],
              fromLocation: vehicleJson['from_location'],
              toLocation: vehicleJson['to_location'],
            );

            await LocalDatabaseService.saveVehicle(vehicle, synced: false);
            vehiclesRestored++;
          } catch (e) {
            DebugLogger.log('⚠️ Failed to restore vehicle: $e');
          }
        }
      }

      DebugLogger.log('✅ Restore completed: $imported settings, $vehiclesRestored vehicles');

      return {
        'success': true,
        'imported_count': imported,
        'vehicles_restored': vehiclesRestored,
        'export_date': importData['export_date'],
        'total_records': importData['total_records'] ?? (imported + vehiclesRestored),
      };
    } catch (e) {
      DebugLogger.log('❌ Restore failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Clear all app data (factory reset)
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      DebugLogger.log('🗑️ All app data cleared');
      return true;
    } catch (e) {
      DebugLogger.log('❌ Clear data failed: $e');
      return false;
    }
  }

  /// Enable/disable auto-backup
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AUTO_BACKUP_ENABLED_KEY, enabled);
  }

  /// Check if auto-backup is enabled
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AUTO_BACKUP_ENABLED_KEY) ?? true;
  }

  /// Create a simple backup file and return its path
  static Future<String?> createBackup() async {
    try {
      final exportData = await exportAllData();
      final backupDir = await getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${backupDir.path}/go2parking_backup_$timestamp.json');
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(exportData));
      return file.path;
    } catch (e) {
      DebugLogger.log('❌ createBackup failed: $e');
      return null;
    }
  }

  /// Restore from a backup file path
  static Future<bool> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final jsonString = await file.readAsString();
      final importData = json.decode(jsonString) as Map<String, dynamic>;
      final result = await _restoreData(importData);
      return result['success'] == true;
    } catch (e) {
      DebugLogger.log('❌ restoreBackup failed: $e');
      return false;
    }
  }

  /// Get backup info without importing
  static Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = json.decode(jsonString);

      return {
        'version': data['export_version'],
        'date': data['export_date'],
        'app_name': data['app_name'],
        'total_records': data['total_records'] ?? 0,
        'settings_count': (data['settings'] as Map).length,
        'vehicles_count': (data['vehicles'] as List? ?? []).length,
        'taxi_bookings_count': (data['taxi_bookings'] as List? ?? []).length,
      };
    } catch (e) {
      return null;
    }
  }

  /// List all hourly backups
  static Future<List<Map<String, dynamic>>> listHourlyBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      final hourlyDir = Directory('${backupDir.path}/$HOURLY_DIR');

      if (!await hourlyDir.exists()) {
        return [];
      }

      final files = await hourlyDir.list().where((f) => f is File && f.path.endsWith('.json')).toList();
      final backups = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final info = await getBackupInfo(file.path);

          if (info != null) {
            backups.add({
              'path': file.path,
              'name': file.path.split(Platform.pathSeparator).last,
              'modified': stat.modified.toIso8601String(),
              'size': stat.size,
              ...info,
            });
          }
        }
      }

      // Sort by modification time (newest first)
      backups.sort((a, b) => b['modified'].compareTo(a['modified']));

      return backups;
    } catch (e) {
      DebugLogger.log('❌ Failed to list hourly backups: $e');
      return [];
    }
  }
}
