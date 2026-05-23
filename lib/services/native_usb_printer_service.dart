import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usb_debug_logger.dart';

/// Native USB Printer Service for Android
/// Communicates with UsbPrinterChannel.kt via MethodChannel
/// Supports USB Printer Class (class 7) and known thermal printer vendors
class NativeUsbPrinterService {
  static const platform = MethodChannel('com.go2billing.parkease/usb_printer');
  static final UsbDebugLogger _logger = UsbDebugLogger();

  static bool _isConnected = false;
  static String? _connectedDeviceName;
  static Map<String, dynamic>? _connectedDeviceInfo;

  static const String _prefDeviceId = 'native_usb_device_id';
  static const String _prefDeviceName = 'native_usb_device_name';
  static const String _prefAutoConnect = 'native_usb_auto_connect';

  // Getters
  static bool get isConnected => _isConnected;
  static String? get connectedDeviceName => _connectedDeviceName;
  static Map<String, dynamic>? get connectedDeviceInfo => _connectedDeviceInfo;

  /// List available USB printers
  static Future<List<Map<String, dynamic>>> getDevices() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await platform.invokeMethod('listDevices');
      final devices = (result as List).map((d) => Map<String, dynamic>.from(d)).toList();
      _logger.info('Found ${devices.length} USB printer(s)');
      return devices;
    } catch (e) {
      _logger.error('Error listing USB devices: $e');
      return [];
    }
  }

  /// Check if we have permission for a device
  static Future<bool> hasPermission(int deviceId) async {
    try {
      return await platform.invokeMethod('hasPermission', {'deviceId': deviceId}) == true;
    } catch (e) {
      _logger.error('Permission check failed: $e');
      return false;
    }
  }

  /// Request USB permission for a device
  static Future<bool> requestPermission(int deviceId) async {
    try {
      return await platform.invokeMethod('requestPermission', {'deviceId': deviceId}) == true;
    } catch (e) {
      _logger.error('Permission request failed: $e');
      return false;
    }
  }

  /// Connect to a USB printer by device ID
  static Future<bool> connect(int deviceId, {String? deviceName}) async {
    try {
      // Request permission first
      final hasPerm = await hasPermission(deviceId);
      if (!hasPerm) {
        final granted = await requestPermission(deviceId);
        if (!granted) {
          _logger.error('USB permission denied');
          return false;
        }
      }

      // Connect
      final success = await platform.invokeMethod('connect', {'deviceId': deviceId}) == true;
      if (success) {
        _isConnected = true;
        _connectedDeviceName = deviceName ?? 'USB Printer';

        // Get device info
        final info = await platform.invokeMethod('getConnectedDevice');
        if (info != null) {
          _connectedDeviceInfo = Map<String, dynamic>.from(info);
          _connectedDeviceName = _connectedDeviceInfo?['productName'] as String? ?? deviceName ?? 'USB Printer';
        }

        // Save for auto-connect
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefDeviceId, deviceId);
        await prefs.setString(_prefDeviceName, _connectedDeviceName ?? '');

        _logger.info('✅ Connected to: $_connectedDeviceName');
      }
      return success;
    } catch (e) {
      _logger.error('Connect failed: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from current printer
  static Future<void> disconnect() async {
    try {
      await platform.invokeMethod('disconnect');
    } catch (_) {}
    _isConnected = false;
    _connectedDeviceName = null;
    _connectedDeviceInfo = null;
    _logger.info('Disconnected');
  }

  /// Print raw text (converts to bytes internally)
  static Future<bool> printText(String text) async {
    if (!_isConnected) {
      _logger.error('Not connected');
      return false;
    }
    try {
      // Send as UTF-8 bytes with ESC/POS init and cut commands
      final bytes = <int>[
        0x1B, 0x40, // ESC @ - Initialize printer
        ...text.codeUnits,
        0x0A, 0x0A, 0x0A, // Feed 3 lines
        0x1D, 0x56, 0x00, // GS V 0 - Full cut
      ];
      final success = await platform.invokeMethod('printBytes', {'bytes': Uint8List.fromList(bytes)}) == true;
      if (success) _logger.info('✅ Printed ${text.length} chars');
      return success;
    } catch (e) {
      _logger.error('Print failed: $e');
      return false;
    }
  }

  /// Print raw bytes (for ESC/POS formatted data)
  static Future<bool> printBytes(Uint8List bytes) async {
    if (!_isConnected) return false;
    try {
      return await platform.invokeMethod('printBytes', {'bytes': bytes}) == true;
    } catch (e) {
      _logger.error('Print bytes failed: $e');
      return false;
    }
  }

  /// Print test receipt
  static Future<bool> printTestReceipt() async {
    const test = '''
================================
        TEST RECEIPT
================================
  Go2-Parking USB Printer
  Connection: OK
  Date: ${''} 
================================
  If you can read this,
  your printer is working!
================================


''';
    return await printText(test);
  }

  /// Auto-connect to last saved printer
  static Future<bool> autoConnect() async {
    if (!Platform.isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoConnect = prefs.getBool(_prefAutoConnect) ?? true;
      if (!autoConnect) return false;

      final savedId = prefs.getInt(_prefDeviceId);
      if (savedId == null) return false;

      final devices = await getDevices();
      final found = devices.where((d) => d['deviceId'] == savedId).firstOrNull;
      if (found == null) return false;

      return await connect(savedId, deviceName: found['productName'] as String?);
    } catch (e) {
      _logger.error('Auto-connect failed: $e');
      return false;
    }
  }
}
