import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/receipt_service.dart';
import '../utils/constants.dart';

class SimplePrinterSettingsScreen extends StatefulWidget {
  const SimplePrinterSettingsScreen({super.key});

  @override
  State<SimplePrinterSettingsScreen> createState() =>
      _SimplePrinterSettingsScreenState();
}

class _SimplePrinterSettingsScreenState
    extends State<SimplePrinterSettingsScreen> {
  List<BluetoothDevice> _availableDevices = [];
  bool _isScanning = false;
  bool _autoConnect = true;
  String? _connectedDeviceName;
  String? _savedDeviceName;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnectionStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnect = prefs.getBool('printer_auto_connect') ?? true;
      _savedDeviceName = prefs.getString('printer_name');
    });
  }

  void _checkConnectionStatus() {
    setState(() {
      _connectedDeviceName = SimpleBluetoothService.connectedDeviceName;
    });
  }

  Future<void> _scanForPrinters() async {
    setState(() {
      _isScanning = true;
      _availableDevices.clear();
    });

    try {
      // Request permissions first
      final permissionResult = await SimpleBluetoothService.requestPermissions();
      if (!permissionResult['granted']) {
        final errors = permissionResult['errors'] as Map<String, String>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bluetooth permissions required: ${errors.values.join(', ')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if Bluetooth is available
      final isAvailable = await SimpleBluetoothService.isBluetoothAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please turn on Bluetooth'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Scan for devices
      final devices = await SimpleBluetoothService.scanForDevices();
      setState(() {
        _availableDevices = devices;
      });

      if (devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printers found. Make sure your printer is on and in pairing mode'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to printer...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final connected = await SimpleBluetoothService.connectToDevice(device);
      Navigator.pop(context); // Close loading dialog

      if (connected) {
        _checkConnectionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.platformName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to connect');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    await SimpleBluetoothService.disconnect();
    _checkConnectionStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    if (!SimpleBluetoothService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer connected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final receipt = ReceiptService.generateTestReceipt();
      final success = await SimpleBluetoothService.printReceipt(receipt);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test receipt printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printer_auto_connect', _autoConnect);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Printer Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanForPrinters,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              elevation: 2,
              color: _connectedDeviceName != null ? Colors.green[50] : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _connectedDeviceName != null
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: _connectedDeviceName != null
                              ? Colors.green
                              : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _connectedDeviceName != null
                                    ? 'Connected'
                                    : 'Not Connected',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_connectedDeviceName != null)
                                Text(
                                  _connectedDeviceName!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                        if (_connectedDeviceName != null)
                          ElevatedButton(
                            onPressed: _disconnectPrinter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Disconnect',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    if (_connectedDeviceName != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _testPrint,
                          icon: const Icon(Icons.print, color: Colors.white),
                          label: const Text(
                            'Print Test Receipt',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Auto-connect to printer'),
                      subtitle: const Text(
                          'Automatically connect to last used printer'),
                      value: _autoConnect,
                      onChanged: (value) {
                        setState(() {
                          _autoConnect = value;
                        });
                        _saveSettings();
                      },
                    ),
                    if (_savedDeviceName != null) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Last Used Printer'),
                        subtitle: Text(_savedDeviceName!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Available Printers Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Printers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isScanning)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_availableDevices.isEmpty && !_isScanning) ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.print_disabled,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No printers found',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isScanning ? null : _scanForPrinters,
                              icon: const Icon(Icons.search, color: Colors.white),
                              label: const Text(
                                'Scan for Printers',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...(_availableDevices.map((device) {
                        final isConnected = device.platformName == _connectedDeviceName;
                        return Card(
                          color: isConnected
                              ? AppColors.primary.withOpacity(0.1)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.print,
                              color: isConnected ? AppColors.primary : null,
                            ),
                            title: Text(
                              device.platformName.isEmpty
                                  ? 'Unknown Device'
                                  : device.platformName,
                            ),
                            subtitle: Text(device.remoteId.toString()),
                            trailing: isConnected
                                ? const Chip(
                                    label: Text('Connected'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _connectToPrinter(device),
                                    child: const Text('Connect'),
                                  ),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isScanning ? null : _scanForPrinters,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Scan Again'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Instructions Card
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('1. Turn on your Bluetooth thermal printer'),
                    SizedBox(height: 4),
                    Text('2. Make sure Bluetooth is enabled on your phone'),
                    SizedBox(height: 4),
                    Text('3. Put your printer in pairing mode if needed'),
                    SizedBox(height: 4),
                    Text('4. Tap "Scan for Printers" to find devices'),
                    SizedBox(height: 4),
                    Text('5. Select and connect to your printer'),
                    SizedBox(height: 4),
                    Text('6. Print a test receipt to verify'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}