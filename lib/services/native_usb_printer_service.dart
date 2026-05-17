import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'usb_debug_logger.dart';
import 'escpos_formatter_service.dart';

/// Native USB Printer Service for Android
/// Uses platform channels to communicate with Android's UsbManager API
/// Supports ALL USB printer classes (not just CDC ACM serial)
class NativeUsbPrinterService {
  static const platform = MethodChannel('com.go2billing.parkease/usb_printer');
  static final UsbDebugLogger _logger = UsbDebugLogger();

  static bool _isConnected = false;
  static String? _connectedDeviceName;
  static Map<String, dynamic>? _connectedDeviceInfo;

  // SharedPreferences keys
  static const String PREF_USB_DEVICE_ID = 'native_usb_device_id';
  static const String PREF_USB_DEVICE_NAME = 'native_usb_device_name';
  static const String PREF_USB_AUTO_CONNECT = 'native_usb_auto_connect';

  /// Check if connected
  static bool get isConnected => _isConnected;

  /// Get connected device name
  static String? get connectedDeviceName => _connectedDeviceName;

  /// Get connected device info
  static Map<String, dynamic>? get connectedDeviceInfo => _connectedDeviceInfo;

  /// List all USB devices
  static Future<List<Map<String, dynamic>>> listDevices() async {
    if (!Platform.isAndroid) {
      _logger.warning('Native USB only available on Android');
      return [];
    }

    try {
      _logger.info('========== SCANNING USB DEVICES (NATIVE) ==========');
      _logger.info('Using Android UsbManager API');

      final List<dynamic> devices = await platform.invokeMethod('listDevices');
      final deviceList = devices
          .cast<Map<Object?, Object?>>()
          .map((d) => d.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      _logger.success('Found ${deviceList.length} USB devices');

      for (var device in deviceList) {
        final vid = (device['vendorId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
        final pid = (device['productId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');

        _logger.debug('📱 Device: ${device['productName']}');
        _logger.debug('   VID: 0x$vid (${device['vendorId']}), PID: 0x$pid (${device['productId']})');
        _logger.debug('   Manufacturer: ${device['manufacturerName']}');
        _logger.debug('   Class: ${device['deviceClass']}, Subclass: ${device['deviceSubclass']}');
        _logger.debug('   Interfaces: ${device['interfaceCount']}');
      }

      _logger.info('==================================================');
      return deviceList;
    } catch (e, stackTrace) {
      _logger.error('Failed to list devices: $e', stackTrace: stackTrace.toString());
      return [];
    }
  }

  /// Check if we have permission for a device
  static Future<bool> hasPermission(int deviceId) async {
    if (!Platform.isAndroid) return false;

    try {
      final bool hasPermission = await platform.invokeMethod('hasPermission', {
        'deviceId': deviceId,
      });
      return hasPermission;
    } catch (e) {
      _logger.error('Failed to check permission: $e');
      return false;
    }
  }

  /// Request permission for device
  static Future<bool> requestPermission(int deviceId) async {
    if (!Platform.isAndroid) return false;

    try {
      _logger.info('========== REQUESTING USB PERMISSION ==========');
      _logger.info('Device ID: $deviceId');
      _logger.info('This will show Android\'s permission dialog...');

      final bool granted = await platform.invokeMethod('requestPermission', {
        'deviceId': deviceId,
      });

      if (granted) {
        _logger.success('✅ Permission granted by user');
      } else {
        _logger.error('❌ Permission denied by user');
        _logger.warning('User must grant USB permission to continue');
      }

      _logger.info('===============================================');
      return granted;
    } catch (e, stackTrace) {
      _logger.error('Permission request failed: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Connect to USB device
  static Future<bool> connectToDevice(Map<String, dynamic> device) async {
    if (!Platform.isAndroid) {
      _logger.error('Native USB only available on Android');
      return false;
    }

    try {
      _logger.info('');
      _logger.info('🔥🔥🔥 NATIVE USB PRINTER CONNECTION START 🔥🔥🔥');
      _logger.info('========================================');
      _logger.info('Device: ${device['productName']}');
      _logger.info('Manufacturer: ${device['manufacturerName']}');
      final vid = (device['vendorId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
      final pid = (device['productId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
      _logger.info('VID: 0x$vid, PID: 0x$pid');
      _logger.info('Class: ${device['deviceClass']}, Subclass: ${device['deviceSubclass']}');
      _logger.info('========================================');

      final deviceId = device['deviceId'] as int;

      // STEP 1: Check if already connected
      if (_isConnected) {
        _logger.warning('Already connected to a device, disconnecting...');
        await disconnect();
      }

      // STEP 2: Check/request permission
      _logger.info('STEP 1/3: Checking USB permission...');
      bool hasPermission = await NativeUsbPrinterService.hasPermission(deviceId);

      if (!hasPermission) {
        _logger.warning('Permission not granted, requesting...');
        hasPermission = await requestPermission(deviceId);

        if (!hasPermission) {
          _logger.error('❌ FAILED: Permission denied');
          return false;
        }
      }

      _logger.success('✅ Permission granted');

      // STEP 3: Connect to device
      _logger.info('STEP 2/3: Opening USB connection...');

      final bool connected = await platform.invokeMethod('connect', {
        'deviceId': deviceId,
      });

      if (!connected) {
        _logger.error('❌ FAILED: Connection failed');
        _logger.warning('Possible causes:');
        _logger.warning('  - Device locked by another app');
        _logger.warning('  - USB cable issue');
        _logger.warning('  - Device not responding');
        return false;
      }

      _logger.success('✅ USB connection opened');

      // STEP 4: Save connection info
      _logger.info('STEP 3/3: Saving connection info...');

      _isConnected = true;
      _connectedDeviceName = device['productName'] as String?;
      _connectedDeviceInfo = device;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PREF_USB_DEVICE_ID, deviceId);
      await prefs.setString(PREF_USB_DEVICE_NAME, device['productName'] ?? 'USB Printer');

      _logger.success('✅ Connection info saved');
      _logger.info('');
      _logger.success('🎉🎉🎉 CONNECTION SUCCESSFUL! 🎉🎉🎉');
      _logger.success('========================================');
      _logger.success('Printer: ${device['productName'] ?? "Unknown"}');
      _logger.success('Status: READY TO PRINT');
      _logger.success('========================================');
      _logger.info('');

      return true;
    } catch (e, stackTrace) {
      _logger.error('');
      _logger.error('💥💥💥 CRITICAL CONNECTION ERROR 💥💥💥');
      _logger.error('========================================');
      _logger.error('Error: $e', stackTrace: stackTrace.toString());
      _logger.error('========================================');
      _logger.error('');

      _isConnected = false;
      _connectedDeviceName = null;
      _connectedDeviceInfo = null;

      return false;
    }
  }

  /// Disconnect from USB device
  static Future<void> disconnect() async {
    if (!Platform.isAndroid) return;

    try {
      _logger.info('Disconnecting from USB device...');

      await platform.invokeMethod('disconnect');

      _isConnected = false;
      _connectedDeviceName = null;
      _connectedDeviceInfo = null;

      _logger.success('USB device disconnected');
    } catch (e, stackTrace) {
      _logger.error('Disconnect error: $e', stackTrace: stackTrace.toString());

      // Force cleanup anyway
      _isConnected = false;
      _connectedDeviceName = null;
      _connectedDeviceInfo = null;
    }
  }

  /// Check connection status
  static Future<bool> checkConnection() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool connected = await platform.invokeMethod('isConnected');
      _isConnected = connected;
      return connected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Print raw bytes
  static Future<bool> printBytes(Uint8List bytes) async {
    if (!Platform.isAndroid) {
      _logger.error('Native USB only available on Android');
      return false;
    }

    try {
      _logger.info('========== USB PRINT REQUEST ==========');
      _logger.info('Data size: ${bytes.length} bytes');

      if (!_isConnected) {
        _logger.error('❌ Printer not connected!');
        _logger.warning('Please connect to printer first');
        return false;
      }

      _logger.debug('Device: $_connectedDeviceName');
      _logger.info('Sending data to printer...');

      final bool success = await platform.invokeMethod('printBytes', {
        'bytes': bytes,
      });

      if (success) {
        _logger.success('✅ ${bytes.length} bytes sent successfully');
        _logger.info('=======================================');
        return true;
      } else {
        _logger.error('❌ Print failed');
        _logger.warning('Possible causes:');
        _logger.warning('  - Printer disconnected during print');
        _logger.warning('  - USB cable disconnected');
        _logger.warning('  - Printer buffer full');
        _logger.info('=======================================');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('❌ Print error: $e', stackTrace: stackTrace.toString());
      _logger.info('=======================================');
      return false;
    }
  }

  /// Print text (converts to ESC/POS bytes)
  static Future<bool> printText(String text) async {
    try {
      _logger.info('Converting text to ESC/POS format...');
      _logger.debug('Text length: ${text.length} characters');

      final List<int> bytes = [];

      // ESC @ - Initialize printer
      bytes.addAll([27, 64]);

      // Add text as bytes
      bytes.addAll(text.codeUnits);

      // Line feeds
      bytes.addAll([10, 10, 10]);

      // Paper cut command (if supported) - GS V 0
      bytes.addAll([29, 86, 0]);

      _logger.debug('Converted to ${bytes.length} bytes (with ESC/POS commands)');

      return await printBytes(Uint8List.fromList(bytes));
    } catch (e, stackTrace) {
      _logger.error('Text conversion error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Print ESC/POS formatted receipt
  static Future<bool> printReceipt(List<int> escPosBytes) async {
    try {
      _logger.info('========== RECEIPT PRINT ==========');
      _logger.info('Receipt size: ${escPosBytes.length} bytes');
      _logger.debug('Contains ESC/POS commands: Yes');

      final bytes = Uint8List.fromList(escPosBytes);
      final success = await printBytes(bytes);

      if (success) {
        _logger.success('✅ Receipt printed successfully');
      } else {
        _logger.error('❌ Receipt print failed');
      }

      _logger.info('===================================');
      return success;
    } catch (e, stackTrace) {
      _logger.error('Receipt print error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Auto-connect to saved device
  static Future<bool> autoConnect() async {
    if (!Platform.isAndroid) return false;

    try {
      _logger.info('Attempting auto-connect...');

      final prefs = await SharedPreferences.getInstance();
      final autoConnect = prefs.getBool(PREF_USB_AUTO_CONNECT) ?? false;

      if (!autoConnect) {
        _logger.debug('Auto-connect is disabled');
        return false;
      }

      final savedDeviceId = prefs.getInt(PREF_USB_DEVICE_ID);
      if (savedDeviceId == null) {
        _logger.warning('No saved device ID');
        return false;
      }

      _logger.info('Looking for saved device (ID: $savedDeviceId)...');
      final devices = await listDevices();

      final device = devices.where((d) => d['deviceId'] == savedDeviceId).firstOrNull;
      if (device == null) {
        _logger.warning('Saved device not found');
        return false;
      }

      _logger.info('Found saved device, connecting...');
      return await connectToDevice(device);
    } catch (e, stackTrace) {
      _logger.error('Auto-connect error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Enable/disable auto-connect
  static Future<void> setAutoConnect(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PREF_USB_AUTO_CONNECT, enabled);
    _logger.info('Auto-connect ${enabled ? "enabled" : "disabled"}');
  }

  /// Get device category for UI grouping
  static String getDeviceCategory(Map<String, dynamic> device) {
    // Known thermal printer vendor IDs
    final knownPrinterVids = {
      0x0416, // SEWOO
      0x0519, // Star Micronics
      0x04B8, // Epson/Udyama
      0x154F, // GOOJPRT
      0x20D1, // XPrinter
    };

    final vendorId = device['vendorId'] as int?;

    // Check if it's a known printer brand
    if (vendorId != null && knownPrinterVids.contains(vendorId)) {
      return 'known';
    }

    // Check if product name contains "printer"
    final productName = (device['productName'] as String? ?? '').toLowerCase();
    if (productName.contains('printer') || productName.contains('pos')) {
      return 'printer';
    }

    // Check USB device class (7 = Printer)
    final deviceClass = device['deviceClass'] as int?;
    if (deviceClass == 7) {
      return 'printer';
    }

    // Everything else
    return 'other';
  }

  /// Get friendly device name
  static String getDeviceName(Map<String, dynamic> device) {
    final name = device['productName'] ?? 'Unknown Device';
    final vid = (device['vendorId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
    final pid = (device['productId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$name (VID: $vid, PID: $pid)';
  }

  /// Print parking receipt using ESC/POS formatter
  static Future<bool> printParkingReceipt({
    required String businessName,
    required String vehicleNumber,
    required DateTime entryTime,
    DateTime? exitTime,
    required double amount,
    String? receiptNo,
    String? parkingSlot,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      _logger.info('========== PRINTING PARKING RECEIPT ==========');
      _logger.info('Generating ESC/POS formatted receipt...');

      final bytes = await EscPosFormatterService.formatParkingReceipt(
        businessName: businessName,
        vehicleNumber: vehicleNumber,
        entryTime: entryTime,
        exitTime: exitTime,
        amount: amount,
        receiptNo: receiptNo,
        parkingSlot: parkingSlot,
        paperSize: paperSize,
      );

      _logger.success('✅ ESC/POS receipt generated (${bytes.length} bytes)');
      return await printReceipt(bytes);
    } catch (e, stackTrace) {
      _logger.error('Parking receipt error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Print test receipt using ESC/POS formatter
  static Future<bool> printTestReceipt({
    String businessName = 'Test Business',
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      _logger.info('========== PRINTING TEST RECEIPT ==========');
      _logger.info('Generating ESC/POS formatted test receipt...');

      final bytes = await EscPosFormatterService.formatTestReceipt(
        businessName: businessName,
        paperSize: paperSize,
      );

      _logger.success('✅ ESC/POS test receipt generated (${bytes.length} bytes)');
      return await printReceipt(bytes);
    } catch (e, stackTrace) {
      _logger.error('Test receipt error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }
}
