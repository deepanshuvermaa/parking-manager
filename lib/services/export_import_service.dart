import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/debug_logger.dart';

class ExportImportService {
  /// Export all app data (settings + vehicle data)
  static Future<Map<String, dynamic>> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get all SharedPreferences keys
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> exportData = {
      'export_version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'app_name': 'Go2-Parking',
    };

    // Export all settings
    final Map<String, dynamic> settings = {};
    for (final key in allKeys) {
      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    exportData['settings'] = settings;

    DebugLogger.log('📦 Export completed: ${settings.length} settings exported');
    return exportData;
  }

  /// Export data to JSON file and share
  static Future<bool> exportToFile() async {
    try {
      // Get export data
      final exportData = await exportAllData();

      // Convert to JSON string
      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'parkease_backup_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonString);

      DebugLogger.log('✅ Export file created: $filePath');

      // Share the file
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Go2-Parking Backup',
        text: 'Backup created on ${DateTime.now().toString().split('.')[0]}',
      );

      return result.status == ShareResultStatus.success ||
             result.status == ShareResultStatus.dismissed;
    } catch (e) {
      DebugLogger.log('❌ Export failed: $e');
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

      // Validate format
      if (!importData.containsKey('export_version') ||
          !importData.containsKey('settings')) {
        return {'success': false, 'error': 'Invalid backup file format'};
      }

      // Restore settings
      final prefs = await SharedPreferences.getInstance();
      final settings = importData['settings'] as Map<String, dynamic>;

      int imported = 0;
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

      DebugLogger.log('✅ Import completed: $imported settings restored');

      return {
        'success': true,
        'imported_count': imported,
        'export_date': importData['export_date'],
      };
    } catch (e) {
      DebugLogger.log('❌ Import failed: $e');
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
        'settings_count': (data['settings'] as Map).length,
      };
    } catch (e) {
      return null;
    }
  }
}
