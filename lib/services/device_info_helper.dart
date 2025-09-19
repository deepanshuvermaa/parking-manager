import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static String? _cachedDeviceId;

  /// Get a unique device identifier
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedDeviceId = prefs.getString('device_id');
      
      if (savedDeviceId != null) {
        _cachedDeviceId = savedDeviceId;
        return savedDeviceId;
      }

      String deviceId = await _generateDeviceId();
      await prefs.setString('device_id', deviceId);
      _cachedDeviceId = deviceId;
      
      return deviceId;
    } catch (e) {
      // Fallback to timestamp-based ID if device info fails
      final fallbackId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceId = fallbackId;
      return fallbackId;
    }
  }

  /// Generate a unique device ID based on device characteristics
  static Future<String> _generateDeviceId() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidDeviceId();
      } else if (Platform.isIOS) {
        return await _getIOSDeviceId();
      } else {
        return _generateFallbackId();
      }
    } catch (e) {
      return _generateFallbackId();
    }
  }

  /// Get Android device ID
  static Future<String> _getAndroidDeviceId() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    
    // Combine multiple identifiers for uniqueness
    final identifiers = [
      androidInfo.id,
      androidInfo.model,
      androidInfo.manufacturer,
      androidInfo.brand,
      androidInfo.device,
    ].where((id) => id.isNotEmpty).join('_');
    
    // Hash the combined identifiers for privacy
    final bytes = utf8.encode(identifiers);
    final digest = sha256.convert(bytes);
    
    return 'android_${digest.toString().substring(0, 16)}';
  }

  /// Get iOS device ID
  static Future<String> _getIOSDeviceId() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;
    
    // Use identifierForVendor which is unique per app installation
    final identifier = iosInfo.identifierForVendor ?? _generateFallbackId();
    
    return 'ios_${identifier.replaceAll('-', '').substring(0, 16)}';
  }

  /// Generate fallback ID when device info is unavailable
  static String _generateFallbackId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'fallback_${timestamp}_$random';
  }

  /// Get device information for display purposes
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidInfo();
      } else if (Platform.isIOS) {
        return await _getIOSInfo();
      } else {
        return {
          'platform': Platform.operatingSystem,
          'model': 'Unknown',
          'version': 'Unknown',
        };
      }
    } catch (e) {
      return {
        'platform': Platform.operatingSystem,
        'model': 'Unknown',
        'version': 'Unknown',
        'error': e.toString(),
      };
    }
  }

  /// Get Android device information
  static Future<Map<String, String>> _getAndroidInfo() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    
    return {
      'platform': 'Android',
      'model': androidInfo.model,
      'manufacturer': androidInfo.manufacturer,
      'brand': androidInfo.brand,
      'version': androidInfo.version.release,
      'sdkInt': androidInfo.version.sdkInt.toString(),
      'device': androidInfo.device,
      'product': androidInfo.product,
    };
  }

  /// Get iOS device information
  static Future<Map<String, String>> _getIOSInfo() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;
    
    return {
      'platform': 'iOS',
      'model': iosInfo.model ?? 'Unknown',
      'name': iosInfo.name ?? 'Unknown',
      'systemName': iosInfo.systemName ?? 'iOS',
      'systemVersion': iosInfo.systemVersion ?? 'Unknown',
      'localizedModel': iosInfo.localizedModel ?? 'Unknown',
    };
  }

  /// Check if device is physical or emulator
  static Future<bool> isPhysicalDevice() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.isPhysicalDevice;
      }
      return true; // Assume physical device for other platforms
    } catch (e) {
      return true;
    }
  }

  /// Get platform-specific identifiers
  static Future<Map<String, String?>> getPlatformIdentifiers() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return {
          'id': androidInfo.id,
          'fingerprint': androidInfo.fingerprint,
          'device': androidInfo.device,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return {
          'identifierForVendor': iosInfo.identifierForVendor,
          'utsname.machine': iosInfo.utsname.machine,
        };
      }
      return {};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Clear cached device ID (useful for testing)
  static void clearCache() {
    _cachedDeviceId = null;
  }

  /// Reset device ID (will generate a new one on next call)
  static Future<void> resetDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_id');
      _cachedDeviceId = null;
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get device display name for UI
  static Future<String> getDeviceDisplayName() async {
    try {
      final deviceInfo = await getDeviceInfo();
      
      if (Platform.isAndroid) {
        return '${deviceInfo['brand']} ${deviceInfo['model']}';
      } else if (Platform.isIOS) {
        return deviceInfo['name'] ?? 'iOS Device';
      }
      
      return '${deviceInfo['platform']} Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Get app installation time (approximate)
  static Future<DateTime?> getAppInstallTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? installTimeStr = prefs.getString('app_install_time');
      
      if (installTimeStr != null) {
        return DateTime.parse(installTimeStr);
      }
      
      // First time - save current time as install time
      final installTime = DateTime.now();
      await prefs.setString('app_install_time', installTime.toIso8601String());
      return installTime;
    } catch (e) {
      return null;
    }
  }
}