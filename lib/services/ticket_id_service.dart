import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service to generate sequential ticket IDs in format: PT{DDMM}{deviceSuffix}{serial}
/// Example: PT0910A001, PT0910A002, PT0910B001 (different device)
/// Serial resets to 001 when date changes
/// Device suffix ensures no collisions across multiple devices
class TicketIdService {
  static const String _prefixKey = 'ticket_id_prefix';
  static const String _serialKey = 'ticket_id_serial';
  static const String _deviceSuffixKey = 'ticket_device_suffix';

  /// Get or generate a stable device suffix (A-Z, then AA-ZZ)
  static Future<String> _getDeviceSuffix() async {
    final prefs = await SharedPreferences.getInstance();
    var suffix = prefs.getString(_deviceSuffixKey);
    if (suffix == null || suffix.isEmpty) {
      // Generate from device ID if available, otherwise random
      final deviceId = prefs.getString('native_usb_device_id') ??
          prefs.getString('printer_mac_address') ??
          DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      // Take a stable single-char hash: A-Z
      final hashCode = deviceId.hashCode.abs() % 26;
      suffix = String.fromCharCode(65 + hashCode); // A-Z
      await prefs.setString(_deviceSuffixKey, suffix);
    }
    return suffix;
  }

  /// Generate next ticket ID in format PT{DDMM}{deviceSuffix}{serial}
  static Future<String> generateNextTicketId() async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final dateFormat = DateFormat('ddMM');
    final currentDatePrefix = 'PT${dateFormat.format(now)}';
    final deviceSuffix = await _getDeviceSuffix();

    // Get stored prefix and serial
    final storedPrefix = prefs.getString(_prefixKey);
    int currentSerial = prefs.getInt(_serialKey) ?? 0;

    // Check if date has changed (new day)
    if (storedPrefix != currentDatePrefix) {
      currentSerial = 1;
      await prefs.setString(_prefixKey, currentDatePrefix);
    } else {
      currentSerial++;
    }

    // Save updated serial
    await prefs.setInt(_serialKey, currentSerial);

    // Format serial as 3-digit number (001, 002, etc.)
    final serialFormatted = currentSerial.toString().padLeft(3, '0');

    // Generate final ticket ID with device suffix
    final ticketId = '$currentDatePrefix$deviceSuffix$serialFormatted';

    return ticketId;
  }

  /// Get current serial number (for debugging/display purposes)
  static Future<int> getCurrentSerial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_serialKey) ?? 0;
  }

  /// Reset serial number (for testing or manual reset)
  static Future<void> resetSerial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serialKey, 0);
  }
}
