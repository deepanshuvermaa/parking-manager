import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PrinterDevice {
  final String id;
  final String name;
  final bool isConnected;
  final BluetoothDevice? device;
  final int? rssi;

  PrinterDevice({
    required this.id,
    required this.name,
    this.isConnected = false,
    this.device,
    this.rssi,
  });
}

class BluetoothProvider with ChangeNotifier {
  List<PrinterDevice> _devices = [];
  PrinterDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _isPrinting = false;
  bool _isInitialized = false;
  bool _hasPermissions = false;
  String _lastError = '';
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _stateSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<bool>? _scanCompleteSubscription;  // Add separate subscription for scan complete
  BluetoothCharacteristic? _writeCharacteristic;
  final Map<String, PrinterDevice> _discoveredDevices = {};
  Timer? _autoScanTimer;

  List<PrinterDevice> get devices => _devices;
  PrinterDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isConnected => _connectedDevice != null;
  bool get isPrinting => _isPrinting;
  bool get isInitialized => _isInitialized;
  bool get hasPermissions => _hasPermissions;
  String get lastError => _lastError;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('BluetoothProvider already initialized');
      return;
    }

    try {
      _lastError = '';

      // Request permissions first with better handling
      _hasPermissions = await _requestPermissions();

      if (!_hasPermissions) {
        _lastError = 'Bluetooth permissions not granted. Please enable in settings.';
        notifyListeners();
        return;
      }

      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        _lastError = 'Bluetooth not supported on this device';
        debugPrint(_lastError);
        notifyListeners();
        return;
      }

      // Monitor Bluetooth adapter state
      _stateSubscription = FlutterBluePlus.adapterState.listen((state) {
        _isBluetoothEnabled = state == BluetoothAdapterState.on;

        if (state == BluetoothAdapterState.on) {
          debugPrint('Bluetooth is ON');
        } else {
          debugPrint('Bluetooth is OFF or unavailable: $state');
          _devices.clear();
          _connectedDevice = null;
        }

        notifyListeners();
      });

      // Monitor scanning state
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        notifyListeners();
      });

      // Check initial state
      final state = await FlutterBluePlus.adapterState.first;
      _isBluetoothEnabled = state == BluetoothAdapterState.on;

      // Turn on Bluetooth if it's off (Android only)
      if (state != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      _isInitialized = true;
      notifyListeners();

      // Auto-scan for devices after initialization
      if (_isBluetoothEnabled && _devices.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          startScan(timeout: const Duration(seconds: 10));
        });
      }
    } catch (e) {
      _lastError = 'Bluetooth initialization failed: $e';
      debugPrint(_lastError);
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      debugPrint('=== BLUETOOTH PERMISSION CHECK ===');

      // Check Android SDK version
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        debugPrint('Android SDK: ${androidInfo.version.sdkInt}');

        // For Android 12+ (SDK 31+), check new Bluetooth permissions
        if (androidInfo.version.sdkInt >= 31) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();

          bool granted = statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
                        statuses[Permission.bluetoothConnect] == PermissionStatus.granted;

          debugPrint('Bluetooth permissions (Android 12+): $granted');
          debugPrint('Scan: ${statuses[Permission.bluetoothScan]}, Connect: ${statuses[Permission.bluetoothConnect]}');

          if (!granted) {
            _lastError = 'Please grant Bluetooth permissions in Settings';
            return false;
          }
          return true;
        } else {
          // For older Android versions
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetooth,
            Permission.location,
          ].request();

          bool granted = (statuses[Permission.bluetooth] == PermissionStatus.granted ||
                         statuses[Permission.bluetooth] == null) && // null means not required
                        statuses[Permission.location] == PermissionStatus.granted;

          debugPrint('Bluetooth permissions (Android <12): $granted');

          if (!granted) {
            _lastError = 'Please grant Bluetooth and Location permissions';
            return false;
          }
          return true;
        }
      }

      // For iOS or other platforms
      return true;
    } catch (e) {
      debugPrint('Permission request error: $e');
      _lastError = 'Failed to request permissions: $e';
      return false;
    }
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 20)}) async {
    if (_isScanning) {
      debugPrint('Already scanning');
      return;
    }

    if (!_isBluetoothEnabled) {
      debugPrint('Bluetooth is not enabled');
      // Try to turn on Bluetooth
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(seconds: 2));

      // Check again
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        return;
      }
    }

    try {
      _discoveredDevices.clear();
      _devices.clear();
      _isScanning = true;  // Set scanning state to true
      notifyListeners();

      debugPrint('Starting Bluetooth scan...');

      // Set scan settings for better discovery
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        continuousUpdates: true,
        continuousDivisor: 1,
      );

      // Listen to scan results
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _processScanResult(result);
        }
        _updateDevicesList();
        notifyListeners();
      });

      // Also check already connected devices
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      for (BluetoothDevice device in connectedDevices) {
        String deviceName = await _getDeviceName(device);
        String deviceId = device.remoteId.toString();

        if (!_discoveredDevices.containsKey(deviceId)) {
          _discoveredDevices[deviceId] = PrinterDevice(
            id: deviceId,
            name: deviceName,
            device: device,
            isConnected: true,
          );
        }
      }
      _updateDevicesList();

      // Cancel any existing scan complete listener to prevent duplicates
      _scanCompleteSubscription?.cancel();

      // Wait for scan to actually run and give minimum scan time
      await Future.delayed(const Duration(seconds: 2));

      // Listen for scan complete with proper subscription management
      _scanCompleteSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _isScanning) {
          debugPrint('Scan completed, found ${_devices.length} devices');
          _isScanning = false;
          notifyListeners();
        }
      });

      // Ensure minimum scan duration
      Future.delayed(const Duration(seconds: 5), () {
        if (_isScanning && _devices.isEmpty) {
          debugPrint('No devices found after 5 seconds, continuing scan...');
        }
      });

    } catch (e) {
      debugPrint('Scan error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  void _processScanResult(ScanResult result) {
    String deviceId = result.device.remoteId.toString();

    // Skip if already discovered
    if (_discoveredDevices.containsKey(deviceId)) {
      // Update RSSI if device already exists
      var existingDevice = _discoveredDevices[deviceId]!;
      _discoveredDevices[deviceId] = PrinterDevice(
        id: existingDevice.id,
        name: existingDevice.name,
        device: existingDevice.device,
        rssi: result.rssi,
        isConnected: existingDevice.isConnected,
      );
      return;
    }

    // Get device name from various sources
    String deviceName = '';

    // Try platform name first
    if (result.device.platformName.isNotEmpty) {
      deviceName = result.device.platformName;
    }
    // Try advertisement name
    else if (result.advertisementData.advName.isNotEmpty) {
      deviceName = result.advertisementData.advName;
    }
    // Try local name from advertisement
    else if (result.advertisementData.localName.isNotEmpty) {
      deviceName = result.advertisementData.localName;
    }
    // Use device ID as fallback
    else {
      deviceName = 'Device ${deviceId.substring(deviceId.length - 5)}';
    }

    // Check if it might be a printer based on name or service UUIDs
    bool isPrinter = _isPrinterDevice(deviceName, result.advertisementData.serviceUuids);

    // Add to discovered devices
    _discoveredDevices[deviceId] = PrinterDevice(
      id: deviceId,
      name: deviceName,
      device: result.device,
      rssi: result.rssi,
    );

    debugPrint('Discovered device: $deviceName (${deviceId}) RSSI: ${result.rssi}');
  }

  bool _isPrinterDevice(String name, List<Guid> serviceUuids) {
    // Common printer keywords
    List<String> printerKeywords = [
      'printer', 'print', 'thermal', 'pos', 'esc',
      'epson', 'star', 'bixolon', 'zebra', 'brother',
      'hp', 'canon', 'bluetooth printer', 'bt printer',
      'gprinter', 'xprinter', 'munbyn', 'rongta'
    ];

    String lowerName = name.toLowerCase();
    bool hasKeyword = printerKeywords.any((keyword) => lowerName.contains(keyword));

    // Common printer service UUIDs
    List<String> printerServiceUuids = [
      '18f0', // Serial Port Profile
      '1101', // Serial Port
      '18a0', // Print
      'e0ff', // Some thermal printers
    ];

    bool hasServiceUuid = serviceUuids.any((uuid) {
      String uuidStr = uuid.toString().toLowerCase();
      return printerServiceUuids.any((printerUuid) => uuidStr.contains(printerUuid));
    });

    return hasKeyword || hasServiceUuid;
  }

  void _updateDevicesList() {
    // Sort devices by signal strength and printer likelihood
    var sortedDevices = _discoveredDevices.values.toList();

    sortedDevices.sort((a, b) {
      // Connected devices first
      if (a.isConnected && !b.isConnected) return -1;
      if (!a.isConnected && b.isConnected) return 1;

      // Printers next
      bool aIsPrinter = _isPrinterDevice(a.name, []);
      bool bIsPrinter = _isPrinterDevice(b.name, []);
      if (aIsPrinter && !bIsPrinter) return -1;
      if (!aIsPrinter && bIsPrinter) return 1;

      // Then by signal strength
      int aRssi = a.rssi ?? -100;
      int bRssi = b.rssi ?? -100;
      return bRssi.compareTo(aRssi);
    });

    _devices = sortedDevices;
  }

  Future<String> _getDeviceName(BluetoothDevice device) async {
    try {
      // Try to get name from platform
      if (device.platformName.isNotEmpty) {
        return device.platformName;
      }

      // Try to connect and get name from GATT
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 2));
      }

      List<BluetoothService> services = await device.discoverServices();
      await device.disconnect();

      // Return platform name if available after connection
      if (device.platformName.isNotEmpty) {
        return device.platformName;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }

    return 'Unknown Device';
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _scanCompleteSubscription?.cancel();  // Cancel scan complete listener too
      _scanCompleteSubscription = null;
      debugPrint('Bluetooth scan stopped');
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }
  }

  Future<bool> connectToDevice(PrinterDevice device) async {
    try {
      if (device.device == null) {
        debugPrint('Device object is null');
        return false;
      }

      // Disconnect from current device if any
      if (_connectedDevice != null && _connectedDevice!.id != device.id) {
        await disconnect();
      }

      debugPrint('Connecting to ${device.name}...');

      // Connect to the device
      await device.device!.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      debugPrint('Connected to ${device.name}, discovering services...');

      // Discover services
      List<BluetoothService> services = await device.device!.discoverServices();

      debugPrint('Found ${services.length} services');

      // Find the write characteristic
      _writeCharacteristic = null;
      for (BluetoothService service in services) {
        debugPrint('Service: ${service.uuid}');

        for (BluetoothCharacteristic char in service.characteristics) {
          debugPrint('  Characteristic: ${char.uuid} - Write: ${char.properties.write}, WriteNoResponse: ${char.properties.writeWithoutResponse}');

          // Look for writable characteristics
          if (char.properties.write || char.properties.writeWithoutResponse) {
            _writeCharacteristic = char;
            debugPrint('Found writable characteristic: ${char.uuid}');
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      if (_writeCharacteristic == null) {
        debugPrint('No writable characteristic found');
      }

      _connectedDevice = PrinterDevice(
        id: device.id,
        name: device.name,
        isConnected: true,
        device: device.device,
      );

      // Update device in list
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        _devices[index] = _connectedDevice!;
      }

      debugPrint('Successfully connected to ${device.name}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_connectedDevice?.device != null) {
        await _connectedDevice!.device!.disconnect();
        debugPrint('Disconnected from ${_connectedDevice!.name}');
      }

      if (_connectedDevice != null) {
        // Update device in list
        final index = _devices.indexWhere((d) => d.id == _connectedDevice!.id);
        if (index != -1) {
          _devices[index] = PrinterDevice(
            id: _connectedDevice!.id,
            name: _connectedDevice!.name,
            isConnected: false,
            device: _connectedDevice!.device,
          );
        }
      }

      _connectedDevice = null;
      _writeCharacteristic = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  Future<bool> printText(String text) async {
    if (!isConnected || _writeCharacteristic == null) {
      debugPrint('Not connected or no write characteristic');
      return false;
    }

    try {
      _isPrinting = true;
      notifyListeners();

      // Convert text to bytes with ESC/POS commands
      List<int> bytes = _formatTextForPrinter(text);

      // Send data in chunks
      const chunkSize = 512;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await _writeCharacteristic!.write(
          bytes.sublist(i, end),
          withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint('Successfully printed text');
      _isPrinting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Print error: $e');
      _isPrinting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> printReceipt(Map<String, dynamic> receiptData) async {
    if (!isConnected || _writeCharacteristic == null) {
      debugPrint('Not connected or no write characteristic');
      return false;
    }

    try {
      _isPrinting = true;
      notifyListeners();

      // Build ESC/POS commands for receipt
      List<int> bytes = [];

      // Initialize printer
      bytes.addAll([0x1B, 0x40]); // ESC @ - Initialize

      // Set alignment to center
      bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Center align

      // Bold on
      bytes.addAll([0x1B, 0x45, 0x01]); // ESC E 1 - Bold on

      // Company name
      bytes.addAll('PARKEASE MANAGER\n'.codeUnits);

      // Bold off
      bytes.addAll([0x1B, 0x45, 0x00]); // ESC E 0 - Bold off

      // Line separator
      bytes.addAll('================================\n'.codeUnits);

      // Set alignment to left
      bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Left align

      // Receipt details
      bytes.addAll('Vehicle: ${receiptData['vehicleNumber'] ?? 'N/A'}\n'.codeUnits);
      bytes.addAll('Type: ${receiptData['vehicleType'] ?? 'N/A'}\n'.codeUnits);

      if (receiptData['entryTime'] != null && receiptData['entryTime'].toString().isNotEmpty) {
        bytes.addAll('Entry: ${receiptData['entryTime']}\n'.codeUnits);
      }

      if (receiptData['exitTime'] != null && receiptData['exitTime'].toString().isNotEmpty) {
        bytes.addAll('Exit: ${receiptData['exitTime']}\n'.codeUnits);
      }

      if (receiptData['duration'] != null && receiptData['duration'].toString().isNotEmpty) {
        bytes.addAll('Duration: ${receiptData['duration']}\n'.codeUnits);
      }

      // Line separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Amount with double height
      if (receiptData['amount'] != null && receiptData['amount'] != '0.00') {
        bytes.addAll([0x1B, 0x21, 0x10]); // ESC ! n - Double height
        bytes.addAll('Amount: ₹${receiptData['amount']}\n'.codeUnits);
        bytes.addAll([0x1B, 0x21, 0x00]); // ESC ! 0 - Normal
      }

      // Line separator
      bytes.addAll('================================\n'.codeUnits);

      // Center align for thank you
      bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Center align
      bytes.addAll('Thank You!\n'.codeUnits);
      bytes.addAll('================================\n'.codeUnits);

      // Feed and cut
      bytes.addAll([0x0A, 0x0A, 0x0A]); // Line feeds
      bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 - Full cut

      // Send data in chunks
      const chunkSize = 512;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await _writeCharacteristic!.write(
          bytes.sublist(i, end),
          withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint('Successfully printed receipt');
      _isPrinting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Print receipt error: $e');
      _isPrinting = false;
      notifyListeners();
      return false;
    }
  }

  List<int> _formatTextForPrinter(String text) {
    List<int> bytes = [];

    // Initialize printer
    bytes.addAll([0x1B, 0x40]); // ESC @ - Initialize

    // Add text
    bytes.addAll(text.codeUnits);

    // Line feed
    bytes.add(0x0A);

    // Feed and cut
    bytes.addAll([0x0A, 0x0A, 0x0A]); // Line feeds
    bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 - Full cut

    return bytes;
  }

  Future<void> connectToDefaultPrinter() async {
    if (_devices.isNotEmpty) {
      // Try to connect to the first printer-like device
      for (var device in _devices) {
        if (_isPrinterDevice(device.name, [])) {
          bool connected = await connectToDevice(device);
          if (connected) {
            debugPrint('Connected to default printer: ${device.name}');
            break;
          }
        }
      }

      // If no printer found, connect to first device
      if (!isConnected && _devices.isNotEmpty) {
        await connectToDevice(_devices.first);
      }
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    if (_connectedDevice?.device != null) {
      _connectedDevice!.device!.disconnect();
    }
    super.dispose();
  }

  // Add method to retry initialization with better error handling
  Future<bool> retryInitialization() async {
    _isInitialized = false;
    _lastError = '';
    await initialize();
    return _isInitialized;
  }

  // Add method to ensure printer is ready
  Future<bool> ensurePrinterReady() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isBluetoothEnabled) {
      _lastError = 'Bluetooth is not enabled';
      return false;
    }

    if (!isConnected) {
      // Try to connect to default printer or first available
      if (_devices.isNotEmpty) {
        await connectToDefaultPrinter();
      } else {
        // Scan for devices
        await startScan(timeout: const Duration(seconds: 5));
        if (_devices.isNotEmpty) {
          await connectToDefaultPrinter();
        }
      }
    }

    return isConnected;
  }
}