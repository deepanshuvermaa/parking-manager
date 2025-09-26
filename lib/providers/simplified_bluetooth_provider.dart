import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

class SimplifiedBluetoothProvider extends ChangeNotifier {
  final List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _bluetoothOn = false;
  bool _hasPermissions = false;
  Timer? _scanTimer;
  int _scanSeconds = 0;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;
  String? _lastError;

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get bluetoothOn => _bluetoothOn;
  bool get hasPermissions => _hasPermissions;
  int get scanSeconds => _scanSeconds;
  String? get lastError => _lastError;
  bool get isConnected => _connectedDevice != null;

  SimplifiedBluetoothProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔵 Initializing Bluetooth...');

    // Check if Bluetooth is supported
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      _lastError = 'Bluetooth not supported on this device';
      notifyListeners();
      return;
    }

    // Listen to Bluetooth state changes
    _stateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _bluetoothOn = state == BluetoothAdapterState.on;
      notifyListeners();
    });

    // Check current state
    final state = await FlutterBluePlus.adapterState.first;
    _bluetoothOn = state == BluetoothAdapterState.on;

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        final device = result.device;
        if (!_devices.contains(device)) {
          _devices.add(device);
          notifyListeners();
        }
      }
    });

    // Load previously connected printer
    await _loadSavedPrinter();

    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    print('📱 Requesting Bluetooth permissions...');

    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        print('Android SDK: ${androidInfo.version.sdkInt}');

        if (androidInfo.version.sdkInt >= 31) {
          // Android 12+
          final bluetoothScan = await Permission.bluetoothScan.request();
          final bluetoothConnect = await Permission.bluetoothConnect.request();

          _hasPermissions = bluetoothScan.isGranted && bluetoothConnect.isGranted;

          if (!_hasPermissions) {
            _lastError = 'Bluetooth permissions denied';
          }
        } else {
          // Older Android
          final location = await Permission.locationWhenInUse.request();
          _hasPermissions = location.isGranted;

          if (!_hasPermissions) {
            _lastError = 'Location permission required for Bluetooth scanning';
          }
        }
      } else {
        // iOS
        _hasPermissions = true;
      }
    } catch (e) {
      _lastError = 'Permission error: $e';
      _hasPermissions = false;
    }

    notifyListeners();
    return _hasPermissions;
  }

  Future<void> turnOnBluetooth() async {
    print('🔵 Requesting to turn on Bluetooth...');

    try {
      await FlutterBluePlus.turnOn();

      // Wait for state change
      await Future.delayed(Duration(seconds: 2));

      final state = await FlutterBluePlus.adapterState.first;
      _bluetoothOn = state == BluetoothAdapterState.on;

      if (_bluetoothOn) {
        print('✅ Bluetooth is ON');
      } else {
        _lastError = 'Please turn on Bluetooth in settings';
      }
    } catch (e) {
      _lastError = 'Error: $e';
    }

    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    if (!_bluetoothOn) {
      _lastError = 'Please turn on Bluetooth first';
      notifyListeners();
      return;
    }

    if (!_hasPermissions) {
      _lastError = 'Please grant permissions first';
      notifyListeners();
      return;
    }

    print('🔍 Starting Bluetooth scan for 30 seconds...');

    _devices.clear();
    _isScanning = true;
    _scanSeconds = 0;
    _lastError = null;
    notifyListeners();

    try {
      // Start scan with 30 second timeout
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 30),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Start timer to show progress
      _scanTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        _scanSeconds++;
        notifyListeners();

        if (_scanSeconds >= 30) {
          stopScan();
        }
      });
    } catch (e) {
      _lastError = 'Scan error: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    print('⏹️ Stopping scan...');

    _scanTimer?.cancel();
    _scanTimer = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop scan error: $e');
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print('📱 Connecting to ${device.name.isEmpty ? device.id : device.name}...');

      // Disconnect from current device if any
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      // Connect to new device
      await device.connect(timeout: Duration(seconds: 10));

      _connectedDevice = device;

      // Save printer for auto-connect
      await _savePrinter(device);

      // Discover services
      final services = await device.discoverServices();
      print('✅ Connected! Services: ${services.length}');

      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Connection failed: $e';
      print('❌ Connection failed: $e');
      notifyListeners();
    }
  }

  Future<void> disconnectDevice({bool forgetPrinter = false}) async {
    if (_connectedDevice == null) return;

    try {
      await _connectedDevice!.disconnect();
      print('✅ Disconnected from ${_connectedDevice!.name}');
      _connectedDevice = null;

      // Only clear saved printer if explicitly requested
      if (forgetPrinter) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('printer_id');
        await prefs.remove('printer_name');
        print('🗑️ Forgot saved printer');
      }

      notifyListeners();
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  Future<bool> ensurePrinterReady() async {
    if (!_bluetoothOn) {
      _lastError = 'Bluetooth is off';
      return false;
    }

    if (_connectedDevice == null) {
      _lastError = 'No printer connected';
      return false;
    }

    return true;
  }

  void printText(String text) {
    printReceipt(text);
  }

  Future<void> printReceipt(String receiptData) async {
    if (_connectedDevice == null) {
      _lastError = 'No printer connected';
      notifyListeners();
      return;
    }

    try {
      print('🖨️ Printing receipt...');

      // Find the correct service and characteristic for printing
      final services = await _connectedDevice!.discoverServices();

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          // Check if this characteristic supports writing
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            // Convert receipt data to bytes
            final bytes = receiptData.codeUnits;

            // Write data in smaller chunks to avoid buffer overflow
            const chunkSize = 200; // Reduced from 512 to avoid the 244 byte limit
            for (int i = 0; i < bytes.length; i += chunkSize) {
              final chunk = bytes.sublist(i, (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize);

              await characteristic.write(
                chunk,
                withoutResponse: characteristic.properties.writeWithoutResponse,
              );

              // Small delay between chunks to ensure printer processes data
              await Future.delayed(Duration(milliseconds: 100));
            }

            print('✅ Receipt printed successfully');
            return;
          }
        }
      }

      _lastError = 'No writable characteristic found';
    } catch (e) {
      _lastError = 'Print failed: $e';
      print('❌ Print error: $e');
    }

    notifyListeners();
  }

  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_id', device.id.toString());
    await prefs.setString('printer_name', device.name);
    print('💾 Saved printer: ${device.name} (${device.id})');
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    final printerName = prefs.getString('printer_name');

    if (printerId != null && printerId.isNotEmpty) {
      print('💾 Found saved printer: $printerName ($printerId)');

      // First check if already connected
      try {
        final connectedDevices = await FlutterBluePlus.connectedDevices;
        for (var device in connectedDevices) {
          if (device.id.toString() == printerId) {
            _connectedDevice = device;
            print('✅ Already connected to saved printer');
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        print('Error checking connected devices: $e');
      }

      // If not connected, try to auto-reconnect
      print('🔄 Attempting to auto-reconnect to saved printer...');
      await _autoReconnectToPrinter(printerId, printerName ?? 'Saved Printer');
    }
  }

  Future<void> _autoReconnectToPrinter(String printerId, String printerName) async {
    try {
      // Ensure Bluetooth is on and permissions granted
      if (!_bluetoothOn) {
        print('⚠️ Bluetooth is off, cannot auto-reconnect');
        return;
      }

      // Start a short scan to find the saved printer
      print('🔍 Scanning for saved printer...');

      // Clear devices list for fresh scan
      _devices.clear();

      // Create a completer to wait for the device to be found
      final deviceFound = Completer<BluetoothDevice?>();

      // Listen to scan results
      StreamSubscription? scanSub;
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.id.toString() == printerId) {
            print('🎯 Found saved printer in scan!');
            deviceFound.complete(result.device);
            scanSub?.cancel();
            break;
          }
        }
      });

      // Start scan with timeout
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Wait for device or timeout
      final device = await deviceFound.future.timeout(
        Duration(seconds: 11),
        onTimeout: () => null,
      );

      // Stop scan
      await FlutterBluePlus.stopScan();
      scanSub?.cancel();

      if (device != null) {
        print('📱 Reconnecting to ${device.name.isEmpty ? device.id : device.name}...');

        // Connect to the device
        await device.connect(timeout: Duration(seconds: 10));
        _connectedDevice = device;

        print('✅ Auto-reconnected to saved printer!');
        notifyListeners();
      } else {
        print('⚠️ Saved printer not found during scan');
      }
    } catch (e) {
      print('❌ Auto-reconnect failed: $e');
      _lastError = 'Could not reconnect to saved printer';
    }
  }

  // Manual reconnect method for users
  Future<bool> reconnectToSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    final printerName = prefs.getString('printer_name');

    if (printerId != null && printerId.isNotEmpty) {
      print('🔄 Manual reconnect requested for: $printerName');
      await _autoReconnectToPrinter(printerId, printerName ?? 'Saved Printer');
      return _connectedDevice != null;
    } else {
      _lastError = 'No saved printer found';
      notifyListeners();
      return false;
    }
  }

  // Check if we have a saved printer
  Future<bool> hasSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    return printerId != null && printerId.isNotEmpty;
  }

  // Get saved printer info
  Future<Map<String, String>?> getSavedPrinterInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    final printerName = prefs.getString('printer_name');

    if (printerId != null && printerId.isNotEmpty) {
      return {
        'id': printerId,
        'name': printerName ?? 'Unknown Printer',
      };
    }
    return null;
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}