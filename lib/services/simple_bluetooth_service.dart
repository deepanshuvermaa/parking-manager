import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_logger.dart';

class SimpleBluetoothService {
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _writeCharacteristic;
  static StreamSubscription? _scanSubscription;
  static bool _isScanning = false;

  // Printer settings
  static const String PREF_PRINTER_MAC = 'printer_mac_address';
  static const String PREF_PRINTER_NAME = 'printer_name';
  static const String PREF_AUTO_CONNECT = 'printer_auto_connect';

  // Simplified Bluetooth check - just verify it's ON
  static Future<Map<String, dynamic>> requestPermissions() async {
    DebugLogger.log('=== SIMPLIFIED BLUETOOTH CHECK ===');

    try {
      final isOn = await isBluetoothAvailable();

      if (isOn) {
        DebugLogger.log('Bluetooth is ON and ready');
        return {
          'granted': true,
          'errors': {},
        };
      } else {
        DebugLogger.log('Bluetooth is OFF');
        return {
          'granted': false,
          'errors': {'bluetooth': 'Please turn on Bluetooth'},
        };
      }
    } catch (e) {
      DebugLogger.log('Bluetooth check error: $e');
      return {
        'granted': false,
        'errors': {'error': 'Bluetooth error: $e'},
      };
    }
  }

  // Check if Bluetooth is available and on
  static Future<bool> isBluetoothAvailable() async {
    try {
      final isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) return false;

      final isOn = await FlutterBluePlus.adapterState.first;
      return isOn == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  // Check if device is likely a printer based on name
  static bool isPrinterDevice(String deviceName) {
    if (deviceName.isEmpty) return false;

    final printerKeywords = [
      'printer', 'print', 'thermal', 'pos', 'receipt',
      'bt', 'rp', 'escpos', 'mini', 'mobile printer',
      'goojprt', 'xprinter', 'epson', 'star', 'citizen'
    ];

    final lowerName = deviceName.toLowerCase();
    return printerKeywords.any((keyword) => lowerName.contains(keyword));
  }

  // Simplified device scan - let flutter_blue_plus handle permissions
  static Future<List<BluetoothDevice>> scanForDevices() async {
    DebugLogger.log('=== STARTING SIMPLIFIED BLUETOOTH SCAN ===');

    if (!await isBluetoothAvailable()) {
      throw Exception('Bluetooth is not available or turned off');
    }

    final devices = <BluetoothDevice>[];
    final deviceIds = <String>{};

    try {
      // Get already connected devices
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        if (!deviceIds.contains(device.remoteId.toString())) {
          devices.add(device);
          deviceIds.add(device.remoteId.toString());
          DebugLogger.log('Found connected device: ${device.platformName}');
        }
      }

      // Start scanning for new devices
      _isScanning = true;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName.isNotEmpty &&
              !deviceIds.contains(result.device.remoteId.toString())) {
            devices.add(result.device);
            deviceIds.add(result.device.remoteId.toString());
            DebugLogger.log('Found device: ${result.device.platformName}');
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _scanSubscription?.cancel();

      DebugLogger.log('Scan complete. Found ${devices.length} devices');

      // Sort devices: Printers first, then alphabetically
      devices.sort((a, b) {
        final aIsPrinter = isPrinterDevice(a.platformName);
        final bIsPrinter = isPrinterDevice(b.platformName);

        if (aIsPrinter && !bIsPrinter) return -1;
        if (!aIsPrinter && bIsPrinter) return 1;
        return a.platformName.compareTo(b.platformName);
      });

      return devices;
    } catch (e) {
      DebugLogger.log('Scan error: $e');
      _isScanning = false;
      _scanSubscription?.cancel();
      rethrow;
    }
  }

  // Connect to a specific device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect from any existing device
      if (_connectedDevice != null && _connectedDevice != device) {
        await _connectedDevice!.disconnect();
      }

      // Connect to new device
      await device.connect(autoConnect: false);
      _connectedDevice = device;

      // Discover services
      final services = await device.discoverServices();

      // Find the write characteristic
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            _writeCharacteristic = char;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      if (_writeCharacteristic == null) {
        throw Exception('No write characteristic found on printer');
      }

      // Save printer details
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_PRINTER_MAC, device.remoteId.toString());
      await prefs.setString(PREF_PRINTER_NAME, device.platformName);

      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  // Disconnect from current device
  static Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
    }
  }

  // Check if connected
  static bool get isConnected => _connectedDevice != null && _writeCharacteristic != null;

  // Get connected device info
  static String? get connectedDeviceName => _connectedDevice?.platformName;

  // Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(PREF_PRINTER_MAC);
      final autoConnect = prefs.getBool(PREF_AUTO_CONNECT) ?? true;

      if (!autoConnect || savedMac == null) return false;

      // Scan for devices
      final devices = await scanForDevices();

      // Find saved device
      for (final device in devices) {
        if (device.remoteId.toString() == savedMac) {
          return await connectToDevice(device);
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Print text data
  static Future<bool> printText(String text) async {
    if (!isConnected || _writeCharacteristic == null) {
      throw Exception('No printer connected');
    }

    try {
      // Convert text to bytes
      final bytes = Uint8List.fromList(text.codeUnits);

      // Split into chunks if needed (most printers have a limit)
      const chunkSize = 100;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);

        if (_writeCharacteristic!.properties.writeWithoutResponse) {
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
        } else {
          await _writeCharacteristic!.write(chunk);
        }

        // Small delay between chunks
        await Future.delayed(const Duration(milliseconds: 50));
      }

      return true;
    } catch (e) {
      print('Print error: $e');
      return false;
    }
  }

  // Print formatted receipt
  static Future<bool> printReceipt(String receipt) async {
    // Add ESC/POS commands for better formatting
    final formattedReceipt = _formatWithESCPOS(receipt);
    return await printText(formattedReceipt);
  }

  // Format text with ESC/POS commands
  static String _formatWithESCPOS(String text) {
    // ESC/POS commands
    const String ESC = '\x1B';
    const String GS = '\x1D';
    const String INIT = '$ESC@'; // Initialize printer
    const String ALIGN_CENTER = '${ESC}a1'; // Center align
    const String ALIGN_LEFT = '${ESC}a0'; // Left align
    const String BOLD_ON = '${ESC}E1'; // Bold on
    const String BOLD_OFF = '${ESC}E0'; // Bold off
    const String DOUBLE_HEIGHT = '$GS!1'; // Double height
    const String NORMAL_SIZE = '$GS!0'; // Normal size
    const String CUT_PAPER = '${GS}V0'; // Cut paper
    const String LINE_FEED = '\n';

    // Format the receipt with ESC/POS commands
    String formatted = INIT;

    // Split text into lines and process each
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.contains('=====')) {
        formatted += '$LINE_FEED$line$LINE_FEED';
      } else if (line.contains('PARKEASE') || line.contains('RECEIPT')) {
        formatted += '$ALIGN_CENTER$DOUBLE_HEIGHT$BOLD_ON$line$BOLD_OFF$NORMAL_SIZE$ALIGN_LEFT$LINE_FEED';
      } else if (line.contains('Total:') || line.contains('Amount:')) {
        formatted += '$BOLD_ON$line$BOLD_OFF$LINE_FEED';
      } else {
        formatted += '$line$LINE_FEED';
      }
    }

    // Add paper feed and cut
    formatted += '$LINE_FEED$LINE_FEED$LINE_FEED$CUT_PAPER';

    return formatted;
  }
}