import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_logger.dart';

class SimpleBluetoothService {
  static BluetoothConnection? _connection;
  static BluetoothDevice? _connectedDevice;
  static StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  static bool _isDiscovering = false;

  /// Drains the RFCOMM input stream. flutter_bluetooth_serial pushes every byte
  /// the printer sends over an EventChannel whether or not anyone listens. With
  /// no subscriber those events queue on the platform channel and starve it —
  /// on low-end POS hardware that delays/never delivers TextInput.show, so the
  /// soft keyboard stops opening. We subscribe purely to discard.
  static StreamSubscription<Uint8List>? _inputDrain;

  /// Serialises writes so two receipts can never interleave on the socket.
  static Future<void> _writeChain = Future<void>.value();

  /// A stalled RFCOMM socket must never hang a bill submit. Every write is
  /// bounded; on timeout we tear the socket down so the next print reconnects.
  static const Duration printTimeout = Duration(seconds: 8);
  static const Duration connectTimeout = Duration(seconds: 10);

  // Printer settings
  static const String PREF_PRINTER_MAC = 'printer_mac_address';
  static const String PREF_PRINTER_NAME = 'printer_name';
  static const String PREF_AUTO_CONNECT = 'printer_auto_connect';

  // Get Bluetooth instance
  static FlutterBluetoothSerial get _bluetooth => FlutterBluetoothSerial.instance;

  /// Request Bluetooth permissions (simple check)
  static Future<Map<String, dynamic>> requestPermissions() async {
    DebugLogger.log('=== BLUETOOTH PERMISSION CHECK ===');
    Map<String, String> errors = {};

    try {
      // Check if Bluetooth is available
      final isAvailable = await _bluetooth.isAvailable ?? false;
      if (!isAvailable) {
        return {
          'granted': false,
          'errors': {'bluetooth': 'Bluetooth not available on this device'},
        };
      }

      // Check if Bluetooth is enabled
      final isEnabled = await _bluetooth.isEnabled ?? false;
      if (!isEnabled) {
        return {
          'granted': false,
          'errors': {'bluetooth': 'Please turn on Bluetooth'},
        };
      }

      // Request Bluetooth permissions for Android 12+
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();

      // CRITICAL: Location permission required for Bluetooth scanning on Android
      // This is mandatory - Android won't allow device discovery without it
      final location = await Permission.location.request();

      if (!bluetoothScan.isGranted) {
        errors['bluetoothScan'] = 'Bluetooth Scan permission required';
      }

      if (!bluetoothConnect.isGranted) {
        errors['bluetoothConnect'] = 'Bluetooth Connect permission required';
      }

      if (!location.isGranted) {
        errors['location'] = 'Location permission required for Bluetooth scanning';
      }

      if (errors.isNotEmpty) {
        if (await Permission.bluetoothScan.isPermanentlyDenied ||
            await Permission.bluetoothConnect.isPermanentlyDenied ||
            await Permission.location.isPermanentlyDenied) {
          errors['settings'] = 'Please enable all permissions in app settings';
        }

        return {
          'granted': false,
          'errors': errors,
        };
      }

      DebugLogger.log('✅ All permissions granted (Bluetooth + Location)');
      return {
        'granted': true,
        'errors': {},
      };
    } catch (e) {
      DebugLogger.log('❌ Permission check error: $e');
      return {
        'granted': false,
        'errors': {'error': 'Permission error: $e'},
      };
    }
  }

  /// Check if Bluetooth is available and enabled
  static Future<bool> isBluetoothAvailable() async {
    try {
      final isAvailable = await _bluetooth.isAvailable ?? false;
      final isEnabled = await _bluetooth.isEnabled ?? false;
      return isAvailable && isEnabled;
    } catch (e) {
      DebugLogger.log('Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Enable Bluetooth (prompts user)
  static Future<bool> enableBluetooth() async {
    try {
      final result = await _bluetooth.requestEnable();
      return result ?? false;
    } catch (e) {
      DebugLogger.log('Error enabling Bluetooth: $e');
      return false;
    }
  }

  /// Get list of already paired/bonded devices
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    DebugLogger.log('=== GETTING PAIRED DEVICES ===');

    try {
      final bondedDevices = await _bluetooth.getBondedDevices();
      DebugLogger.log('Found ${bondedDevices.length} paired devices');

      for (var device in bondedDevices) {
        DebugLogger.log('Paired: ${device.name ?? "Unknown"} (${device.address})');
      }

      return bondedDevices;
    } catch (e) {
      DebugLogger.log('❌ Error getting paired devices: $e');
      return [];
    }
  }

  /// Scan for ALL nearby Bluetooth devices (paired and unpaired)
  static Future<List<BluetoothDevice>> scanForDevices() async {
    DebugLogger.log('=== STARTING BLUETOOTH DISCOVERY ===');

    if (!await isBluetoothAvailable()) {
      throw Exception('Bluetooth is not available or turned off');
    }

    final devices = <BluetoothDevice>[];
    final deviceAddresses = <String>{};
    final completer = Completer<List<BluetoothDevice>>();

    try {
      // First, get already paired devices
      final pairedDevices = await getPairedDevices();
      for (var device in pairedDevices) {
        devices.add(device);
        deviceAddresses.add(device.address);
      }

      // Start discovery for new devices
      _isDiscovering = true;
      DebugLogger.log('Starting device discovery...');

      _discoverySubscription = _bluetooth.startDiscovery().listen(
        (result) {
          // Add each discovered device
          if (!deviceAddresses.contains(result.device.address)) {
            devices.add(result.device);
            deviceAddresses.add(result.device.address);

            final name = result.device.name ?? 'Unknown Device';
            final rssi = result.rssi;
            DebugLogger.log('📡 Found: $name (${result.device.address}) RSSI: $rssi');
          }
        },
        onDone: () {
          _isDiscovering = false;
          _discoverySubscription?.cancel();
          DebugLogger.log('✅ Discovery complete. Found ${devices.length} devices total');

          // Sort: Paired first, then by name
          devices.sort((a, b) {
            if (a.isBonded && !b.isBonded) return -1;
            if (!a.isBonded && b.isBonded) return 1;

            final aName = a.name ?? 'Unknown Device';
            final bName = b.name ?? 'Unknown Device';
            return aName.compareTo(bName);
          });

          completer.complete(devices);
        },
        onError: (error) {
          _isDiscovering = false;
          _discoverySubscription?.cancel();
          DebugLogger.log('❌ Discovery error: $error');
          completer.completeError(error);
        },
      );

      // Wait for discovery to complete (max 15 seconds)
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _isDiscovering = false;
          _discoverySubscription?.cancel();
          DebugLogger.log('⏱️ Discovery timeout. Found ${devices.length} devices');
          return devices;
        },
      );
    } catch (e) {
      _isDiscovering = false;
      _discoverySubscription?.cancel();
      DebugLogger.log('❌ Scan error: $e');
      rethrow;
    }
  }

  /// Stop ongoing discovery
  static Future<void> stopDiscovery() async {
    if (_isDiscovering) {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      _isDiscovering = false;
      DebugLogger.log('Discovery stopped');
    }
  }

  /// Connect to a specific device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    DebugLogger.log('=== CONNECTING TO DEVICE ===');
    DebugLogger.log('Device: ${device.name ?? "Unknown"} (${device.address})');

    try {
      // Disconnect from any existing connection
      await disconnect();

      // Connect to the device
      _connection = await BluetoothConnection.toAddress(device.address)
          .timeout(connectTimeout);
      _connectedDevice = device;

      // Drain the input stream. Printers emit status bytes unprompted; if
      // nothing consumes them they pile up on the platform channel and block
      // unrelated channel traffic (notably the keyboard show request).
      _inputDrain = _connection!.input?.listen(
        (_) {},
        onError: (e) {
          DebugLogger.log('Bluetooth input error: $e');
          _handleSocketLoss();
        },
        onDone: () {
          DebugLogger.log('Bluetooth socket closed by peer');
          _handleSocketLoss();
        },
        cancelOnError: true,
      );

      DebugLogger.log('✅ Connected successfully!');

      // Save printer details
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_PRINTER_MAC, device.address);
      await prefs.setString(PREF_PRINTER_NAME, device.name ?? 'Unknown Device');

      return true;
    } catch (e) {
      DebugLogger.log('❌ Connection error: $e');
      _connection = null;
      _connectedDevice = null;
      return false;
    }
  }

  /// Drop local socket state without awaiting anything. Safe to call from a
  /// stream callback or after a timeout, where awaiting close() could itself
  /// hang on the same wedged socket.
  static void _handleSocketLoss() {
    _inputDrain?.cancel();
    _inputDrain = null;
    try {
      _connection?.close();
    } catch (_) {}
    _connection = null;
    _connectedDevice = null;
  }

  /// Disconnect from current device
  static Future<void> disconnect() async {
    try {
      await _inputDrain?.cancel();
      _inputDrain = null;
      if (_connection != null) {
        await _connection!.close().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
        _connection = null;
        _connectedDevice = null;
        DebugLogger.log('Disconnected from device');
      }
    } catch (e) {
      DebugLogger.log('Error disconnecting: $e');
      _handleSocketLoss();
    }
  }

  /// Reconnect to the saved printer if the socket dropped. Returns true when a
  /// usable connection exists. Called before every print so a socket lost while
  /// idle heals silently instead of failing the bill.
  static Future<bool> ensureConnected() async {
    if (isConnected) return true;
    _handleSocketLoss();
    return await autoConnect();
  }

  /// True only while a socket is actually open — which, by design, is now just
  /// the moment of a print. UI should ask [isPrinterConfigured] instead.
  static bool get isConnected => _connection != null && _connection!.isConnected;

  /// True when a printer has been paired and saved, i.e. printing will work.
  /// This is what status UI wants: we no longer hold a socket open between
  /// prints, so a live-socket check would read "disconnected" almost always.
  static Future<bool> isPrinterConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(PREF_PRINTER_MAC);
    return mac != null && mac.isNotEmpty;
  }

  /// Get connected device info
  static String? get connectedDeviceName => _connectedDevice?.name;

  /// Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(PREF_PRINTER_MAC);
      final autoConnect = prefs.getBool(PREF_AUTO_CONNECT) ?? true;

      if (!autoConnect || savedMac == null) return false;

      DebugLogger.log('Auto-connecting to saved device: $savedMac');

      // Get paired devices
      final pairedDevices = await getPairedDevices();

      // Find saved device
      for (final device in pairedDevices) {
        if (device.address == savedMac) {
          return await connectToDevice(device);
        }
      }

      DebugLogger.log('Saved device not found in paired devices');
      return false;
    } catch (e) {
      DebugLogger.log('Auto-connect error: $e');
      return false;
    }
  }

  /// Print raw bytes to connected printer.
  ///
  /// Never throws and never hangs: writes are serialised, bounded by
  /// [printTimeout], and a timeout tears the socket down so the next call
  /// reconnects rather than queueing behind a dead one. Returns false on
  /// failure so callers can save the bill and report the print separately.
  static Future<bool> printBytes(Uint8List bytes) {
    final result = _writeChain.then((_) => _printBytesLocked(bytes));
    // Keep the chain alive even if this write fails.
    _writeChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<bool> _printBytesLocked(Uint8List bytes) async {
    if (!await ensureConnected()) {
      DebugLogger.log('❌ Print aborted: no printer connected');
      return false;
    }

    try {
      _connection!.output.add(bytes);
      await _connection!.output.allSent.timeout(printTimeout);
      // Give the printer a moment to drain its buffer before we tear the
      // socket down, otherwise the tail of a long receipt can be truncated.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return true;
    } on TimeoutException {
      DebugLogger.log('❌ Print timed out after ${printTimeout.inSeconds}s');
      return false;
    } catch (e) {
      DebugLogger.log('❌ Print error: $e');
      return false;
    } finally {
      // ALWAYS drop the socket. flutter_bluetooth_serial's RFCOMM read loop is
      // a busy-wait spin in the plugin's Java layer: an open connection pegs a
      // core at 100% and drags the platform thread to ~55%, which starves the
      // channel that carries TextInput.show — the soft keyboard then never
      // opens. Measured on a Unisoc SC9863A POS handheld. Holding the socket
      // open for the process lifetime is not survivable on this hardware, so
      // we connect per print and release immediately.
      _handleSocketLoss();
    }
  }

  /// Print text data
  static Future<bool> printText(String text) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      return await printBytes(bytes);
    } catch (e) {
      DebugLogger.log('❌ Print error: $e');
      return false;
    }
  }

  /// Print receipt - Receipt Service already handles all formatting
  static Future<bool> printReceipt(String receipt) async {
    // Receipt Service has already formatted the text perfectly with:
    // - centerText() for headers
    // - wrapText() for long text
    // - Proper dividers based on paperWidth
    // Just send it directly to the printer without additional formatting
    return await printText(receipt);
  }

  /// Check if device is likely a printer based on name
  static bool isPrinterDevice(String? deviceName) {
    if (deviceName == null || deviceName.isEmpty) return false;

    final printerKeywords = [
      'printer', 'print', 'thermal', 'pos', 'receipt',
      'bt', 'rp', 'escpos', 'mini', 'mobile printer',
      'goojprt', 'xprinter', 'epson', 'star', 'citizen',
      'bixolon', 'zebra', 'tsc', 'honeywell'
    ];

    final lowerName = deviceName.toLowerCase();
    return printerKeywords.any((keyword) => lowerName.contains(keyword));
  }
}
