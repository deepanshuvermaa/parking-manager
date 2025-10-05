import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android ID as device identifier
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor for iOS
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        // Use computer name for Windows (development)
        return windowsInfo.computerName;
      } else {
        // Fallback for other platforms
        return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      // Fallback device ID if we can't get the real one
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'device_id': androidInfo.id,
          'device_name': '${androidInfo.brand} ${androidInfo.model}',
          'device_type': 'Android',
          'os_version': androidInfo.version.release,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'device_id': iosInfo.identifierForVendor ?? 'unknown',
          'device_name': iosInfo.name,
          'device_type': 'iOS',
          'os_version': iosInfo.systemVersion,
        };
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return {
          'device_id': windowsInfo.computerName,
          'device_name': windowsInfo.computerName,
          'device_type': 'Windows',
          'os_version': windowsInfo.productName,
        };
      } else {
        return {
          'device_id': 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          'device_name': 'Unknown Device',
          'device_type': 'Unknown',
          'os_version': 'Unknown',
        };
      }
    } catch (e) {
      return {
        'device_id': 'error_${DateTime.now().millisecondsSinceEpoch}',
        'device_name': 'Unknown Device',
        'device_type': 'Unknown',
        'os_version': 'Unknown',
      };
    }
  }
}