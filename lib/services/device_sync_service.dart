import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import 'api_service.dart';
import 'device_info_helper.dart';

class DeviceSyncService {
  static const String _deviceInfoKey = 'device_info';
  static const String _syncTimestampKey = 'last_sync_timestamp';
  static const String _allowedDevicesKey = 'allowed_device_count';

  /// Register current device with the backend
  static Future<bool> registerDevice() async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();
      final deviceName = await DeviceInfoHelper.getDeviceName();

      final deviceInfo = DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: DeviceInfoHelper.getCurrentPlatform(),
        lastSeen: DateTime.now(),
        isActive: true,
      );

      // Save device info locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceInfoKey, jsonEncode(deviceInfo.toJson()));

      // Register with backend
      final response = await ApiService.registerDevice(deviceInfo.toJson());
      return response != null;
    } catch (e) {
      print('Device registration error: $e');
      return false;
    }
  }

  /// Check if current device is allowed to login
  static Future<bool> isDeviceAllowed(String userId) async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();
      final response = await ApiService.checkDevicePermission(userId, deviceId);

      if (response != null && response['success'] == true) {
        final data = response['data'];
        final isAllowed = data['isAllowed'] ?? false;
        final maxDevices = data['maxDevices'] ?? 1;
        final currentDevices = data['currentDevices'] ?? 0;

        // Store device limits locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_allowedDevicesKey, maxDevices);

        return isAllowed;
      }

      return false;
    } catch (e) {
      print('Device permission check error: $e');
      // Allow login if check fails (offline mode)
      return true;
    }
  }

  /// Sync data across devices
  static Future<bool> syncDataAcrossDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_syncTimestampKey);

      // Get data to sync
      final localData = await _getLocalSyncData();

      // Send to backend
      final response = await ApiService.syncDeviceData(localData);

      if (response != null && response['success'] == true) {
        // Update local data with server data
        final serverData = response['data'];
        await _updateLocalDataFromServer(serverData);

        // Update sync timestamp
        await prefs.setString(_syncTimestampKey, DateTime.now().toIso8601String());

        return true;
      }

      return false;
    } catch (e) {
      print('Data sync error: $e');
      return false;
    }
  }

  /// Get local data that needs to be synced
  static Future<Map<String, dynamic>> _getLocalSyncData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'deviceId': await DeviceInfoHelper.getDeviceId(),
      'timestamp': DateTime.now().toIso8601String(),
      'settings': prefs.getString('settings'),
      'vehicleData': prefs.getString('cached_vehicles'),
      'lastSyncTime': prefs.getString(_syncTimestampKey),
    };
  }

  /// Update local data from server response
  static Future<void> _updateLocalDataFromServer(Map<String, dynamic> serverData) async {
    final prefs = await SharedPreferences.getInstance();

    if (serverData['settings'] != null) {
      await prefs.setString('settings', jsonEncode(serverData['settings']));
    }

    if (serverData['vehicleData'] != null) {
      await prefs.setString('cached_vehicles', jsonEncode(serverData['vehicleData']));
    }

    // Update other sync-able data here
  }

  /// Force logout from all other devices (admin function)
  static Future<bool> logoutAllOtherDevices() async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();
      final response = await ApiService.logoutOtherDevices(deviceId);
      return response != null && response['success'] == true;
    } catch (e) {
      print('Logout other devices error: $e');
      return false;
    }
  }

  /// Get device sync status
  static Future<Map<String, dynamic>?> getDeviceSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_syncTimestampKey);
      final maxDevices = prefs.getInt(_allowedDevicesKey) ?? 1;

      final response = await ApiService.getDeviceStatus();

      if (response != null && response['success'] == true) {
        final data = response['data'];
        return {
          'lastSync': lastSync,
          'maxDevices': maxDevices,
          'currentDevices': data['activeDevices'] ?? 0,
          'deviceList': data['devices'] ?? [],
          'needsSync': _needsSync(lastSync),
        };
      }

      return null;
    } catch (e) {
      print('Get device status error: $e');
      return null;
    }
  }

  /// Check if data needs to be synced
  static bool _needsSync(String? lastSyncString) {
    if (lastSyncString == null) return true;

    try {
      final lastSync = DateTime.parse(lastSyncString);
      final now = DateTime.now();
      final difference = now.difference(lastSync);

      // Sync if last sync was more than 5 minutes ago
      return difference.inMinutes > 5;
    } catch (e) {
      return true;
    }
  }

  /// Check if user has admin privileges
  static Future<bool> isAdminUser(String userId) async {
    try {
      final response = await ApiService.checkAdminStatus(userId);
      return response != null &&
             response['success'] == true &&
             response['data']['isAdmin'] == true;
    } catch (e) {
      print('Admin check error: $e');
      return false;
    }
  }
}