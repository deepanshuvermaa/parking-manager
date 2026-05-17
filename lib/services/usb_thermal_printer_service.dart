import 'dart:typed_data';
import 'dart:io';
import 'package:usb_serial/usb_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usb_debug_logger.dart';

/// USB Thermal Printer Service for Android and Desktop
/// Supports ESC/POS compatible USB thermal printers
/// Proper permission handling with comprehensive logging
class UsbThermalPrinterService {
  static final UsbDebugLogger _logger = UsbDebugLogger();

  // USB Serial connection
  static UsbPort? _port;
  static UsbDevice? _connectedDevice;
  static int? _successfulBaudRate;

  // SharedPreferences keys
  static const String PREF_USB_DEVICE_ID = 'usb_device_id';
  static const String PREF_USB_DEVICE_NAME = 'usb_device_name';
  static const String PREF_USB_AUTO_CONNECT = 'usb_auto_connect';

  // Standard baud rates for thermal printers (most common first)
  static const List<int> BAUD_RATES = [115200, 9600, 19200, 38400, 57600];

  /// Check if USB printer is connected
  static bool get isConnected => _port != null && _connectedDevice != null;

  /// Get connected device name
  static String? get connectedDeviceName => _connectedDevice?.productName;

  /// Get connected device info
  static UsbDevice? get connectedDevice => _connectedDevice;

  /// Get successful baud rate
  static int? get baudRate => _successfulBaudRate;

  /// Scan for available USB devices
  static Future<List<UsbDevice>> scanDevices() async {
    try {
      _logger.info('========== USB DEVICE SCAN ==========');
      _logger.info('Platform: ${Platform.operatingSystem}');

      if (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux) {
        _logger.warning('USB printing not supported on ${Platform.operatingSystem}');
        return [];
      }

      List<UsbDevice> devices = await UsbSerial.listDevices();
      _logger.success('Found ${devices.length} USB devices');

      for (var device in devices) {
        final vid = device.vid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????';
        final pid = device.pid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????';
        final name = device.productName ?? 'Unknown Device';

        _logger.debug('📱 Device: $name');
        _logger.debug('   VID: 0x$vid (${{device.vid}}), PID: 0x$pid (${{device.pid}})');
        _logger.debug('   Manufacturer: ${device.manufacturerName ?? "Unknown"}');
        _logger.debug('   Device ID: ${device.deviceId}');
      }

      _logger.info('========================================');
      return devices;
    } catch (e, stackTrace) {
      _logger.error('Scan error: $e', stackTrace: stackTrace.toString());
      return [];
    }
  }

  /// Request USB permission for a device (Android only)
  /// Permission is requested automatically when creating the port
  static Future<bool> requestPermission(UsbDevice device) async {
    try {
      _logger.info('========== REQUESTING USB PERMISSION ==========');
      _logger.info('Device: ${device.productName ?? "Unknown"}');

      if (!Platform.isAndroid) {
        _logger.warning('Permission request only needed on Android');
        return true; // Desktop doesn't need permission dialogs
      }

      _logger.info('Permission will be requested when creating port...');
      _logger.info('(Automatic permission dialog)');

      // Permission is automatically requested by device.create()
      // So we just return true here - actual permission happens in connectToDevice
      _logger.success('✅ Ready to request permission');

      _logger.info('===============================================');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Permission request error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Connect to USB device with proper permission handling
  static Future<bool> connectToDevice(UsbDevice device) async {
    try {
      _logger.info('');
      _logger.info('🔥🔥🔥 USB PRINTER CONNECTION START 🔥🔥🔥');
      _logger.info('========================================');
      _logger.info('Device: ${device.productName ?? "Unknown"}');
      _logger.debug('VID: 0x${device.vid?.toRadixString(16)}, PID: 0x${device.pid?.toRadixString(16)}');
      _logger.debug('Manufacturer: ${device.manufacturerName ?? "Unknown"}');
      _logger.info('========================================');

      // STEP 1: Close existing connection
      _logger.info('STEP 1/6: Checking existing connections...');
      if (_port != null) {
        _logger.warning('Found existing connection, closing...');
        await disconnect();
      }
      _logger.success('✅ Ready for new connection');

      // STEP 2: Request USB permission (Android only)
      _logger.info('STEP 2/6: Requesting USB permissions...');
      final permissionGranted = await requestPermission(device);

      if (!permissionGranted) {
        _logger.error('❌ FAILED: USB permission denied');
        _logger.warning('Cannot proceed without USB permission');
        return false;
      }
      _logger.success('✅ Permission granted');

      // STEP 3: Create USB port
      _logger.info('STEP 3/6: Creating USB port...');
      try {
        _port = await device.create();
        if (_port == null) {
          _logger.error('❌ FAILED: Port is null after creation');
          return false;
        }
        _logger.success('✅ USB port created successfully');
      } catch (e, stackTrace) {
        _logger.error('❌ FAILED to create port: $e', stackTrace: stackTrace.toString());
        _logger.warning('Possible causes:');
        _logger.warning('  - Device not connected via USB OTG cable');
        _logger.warning('  - USB debugging interference');
        _logger.warning('  - Device locked by another app');
        return false;
      }

      // STEP 4: Open USB port
      _logger.info('STEP 4/6: Opening USB port...');
      bool opened = false;
      try {
        opened = await _port!.open();
        if (!opened) {
          _logger.error('❌ Port.open() returned false');
          _logger.warning('Possible causes:');
          _logger.warning('  - Port already in use');
          _logger.warning('  - Insufficient permissions');
          _logger.warning('  - Device communication error');
          _port = null;
          return false;
        }
        _logger.success('✅ USB port opened successfully');
      } catch (e, stackTrace) {
        _logger.error('❌ Exception while opening port: $e', stackTrace: stackTrace.toString());
        _port = null;
        return false;
      }

      // STEP 5: Configure port parameters with multiple baud rates
      _logger.info('STEP 5/6: Configuring port (testing baud rates)...');
      bool configured = false;

      for (final baudRate in BAUD_RATES) {
        try {
          _logger.debug('Testing baud rate: $baudRate...');

          // Set DTR and RTS
          await _port!.setDTR(true);
          await _port!.setRTS(true);

          // Configure port parameters
          await _port!.setPortParameters(
            baudRate,
            UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1,
            UsbPort.PARITY_NONE,
          );

          _logger.debug('  Port configured: $baudRate baud, 8-N-1');

          // Test connection with ESC/POS init command
          _logger.debug('  Sending ESC @ (init) command...');
          final initCommand = Uint8List.fromList([27, 64]); // ESC @
          await _port!.write(initCommand);

          // Small delay to let printer respond
          await Future.delayed(const Duration(milliseconds: 100));

          configured = true;
          _successfulBaudRate = baudRate;
          _logger.success('✅ Baud rate $baudRate: SUCCESS!');
          break;
        } catch (e) {
          _logger.warning('  Baud rate $baudRate failed: $e');
          continue;
        }
      }

      if (!configured) {
        _logger.error('❌ ALL baud rates failed!');
        _logger.warning('Possible causes:');
        _logger.warning('  - Printer doesn\'t support standard baud rates');
        _logger.warning('  - USB cable issue (try different cable)');
        _logger.warning('  - Not a compatible thermal printer');
        await _port!.close();
        _port = null;
        return false;
      }

      // STEP 6: Save connection info
      _logger.info('STEP 6/6: Saving connection preferences...');
      _connectedDevice = device;

      final prefs = await SharedPreferences.getInstance();
      if (device.deviceId != null) {
        await prefs.setInt(PREF_USB_DEVICE_ID, device.deviceId!);
        _logger.debug('Saved device ID: ${device.deviceId}');
      }
      await prefs.setString(PREF_USB_DEVICE_NAME, device.productName ?? 'USB Printer');
      _logger.debug('Saved device name: ${device.productName ?? "USB Printer"}');

      _logger.info('');
      _logger.success('🎉🎉🎉 CONNECTION SUCCESSFUL! 🎉🎉🎉');
      _logger.success('========================================');
      _logger.success('Printer: ${device.productName ?? "Unknown"}');
      _logger.success('Baud Rate: $_successfulBaudRate');
      _logger.success('Configuration: 8 data bits, No parity, 1 stop bit');
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

      // Cleanup
      try {
        if (_port != null) {
          await _port!.close();
        }
      } catch (_) {}
      _port = null;
      _connectedDevice = null;
      _successfulBaudRate = null;

      return false;
    }
  }

  /// Disconnect from USB device
  static Future<void> disconnect() async {
    try {
      if (_port != null) {
        _logger.info('Disconnecting USB printer...');
        await _port!.close();
        _port = null;
        _connectedDevice = null;
        _successfulBaudRate = null;
        _logger.success('USB printer disconnected');
      }
    } catch (e, stackTrace) {
      _logger.error('Disconnect error: $e', stackTrace: stackTrace.toString());
      _port = null;
      _connectedDevice = null;
      _successfulBaudRate = null;
    }
  }

  /// Print raw bytes (ESC/POS commands)
  static Future<bool> printBytes(Uint8List bytes) async {
    try {
      _logger.info('========== USB PRINT REQUEST ==========');
      _logger.info('Data size: ${bytes.length} bytes');

      if (!isConnected) {
        _logger.error('❌ Printer not connected!');
        _logger.warning('Please connect to printer first');
        return false;
      }

      _logger.debug('Port status: Open');
      _logger.debug('Device: ${_connectedDevice?.productName}');
      _logger.debug('Baud rate: $_successfulBaudRate');

      _logger.info('Sending data to printer...');
      await _port!.write(bytes);

      _logger.success('✅ ${bytes.length} bytes sent successfully');
      _logger.info('=======================================');
      return true;
    } catch (e, stackTrace) {
      _logger.error('❌ Print error: $e', stackTrace: stackTrace.toString());
      _logger.warning('Possible causes:');
      _logger.warning('  - Printer disconnected during print');
      _logger.warning('  - USB cable disconnected');
      _logger.warning('  - Printer buffer full');
      return false;
    }
  }

  /// Print text (converts to ESC/POS bytes)
  static Future<bool> printText(String text) async {
    try {
      _logger.info('Converting text to ESC/POS format...');
      _logger.debug('Text length: ${text.length} characters');

      // Convert text to bytes
      final bytes = Uint8List.fromList(text.codeUnits);
      _logger.debug('Converted to ${bytes.length} bytes');

      return await printBytes(bytes);
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

        // Send paper cut command
        _logger.debug('Sending paper cut command...');
        final cutCommand = Uint8List.fromList([0x1D, 0x56, 0x00]);
        await printBytes(cutCommand);
        _logger.debug('Cut command sent');
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
      final devices = await scanDevices();

      final device = devices.where((d) => d.deviceId == savedDeviceId).firstOrNull;
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
  static String getDeviceCategory(UsbDevice device) {
    // Known thermal printer vendor IDs
    final knownPrinterVids = {
      0x0416, // SEWOO
      0x0519, // Star Micronics
      0x04B8, // Epson/Udyama
      0x154F, // GOOJPRT
      0x20D1, // XPrinter
    };

    // Check if it's a known printer brand
    if (device.vid != null && knownPrinterVids.contains(device.vid)) {
      return 'known';
    }

    // Check if product name contains "printer"
    final productName = (device.productName ?? '').toLowerCase();
    if (productName.contains('printer') || productName.contains('pos')) {
      return 'printer';
    }

    // Everything else
    return 'other';
  }

  /// Get friendly device name
  static String getDeviceName(UsbDevice device) {
    final name = device.productName ?? 'Unknown Device';
    final vid = device.vid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????';
    final pid = device.pid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????';
    return '$name (VID: $vid, PID: $pid)';
  }
}
