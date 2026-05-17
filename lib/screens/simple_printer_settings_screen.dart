import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:usb_serial/usb_serial.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/desktop_printer_service.dart';
import '../services/platform_printer_service.dart';
import '../services/usb_thermal_printer_service.dart';
import '../services/receipt_service.dart';
import '../utils/constants.dart';
import 'usb_debug_log_screen.dart';

class SimplePrinterSettingsScreen extends StatefulWidget {
  const SimplePrinterSettingsScreen({super.key});

  @override
  State<SimplePrinterSettingsScreen> createState() =>
      _SimplePrinterSettingsScreenState();
}

class _SimplePrinterSettingsScreenState
    extends State<SimplePrinterSettingsScreen> {
  List<BluetoothDevice> _availableDevices = [];
  List<Printer> _desktopPrinters = [];
  List<UsbDevice> _usbDevices = [];
  bool _isScanning = false;
  bool _isScanningUsb = false;
  bool _autoConnect = true;
  String? _connectedDeviceName;
  String? _savedDeviceName;
  String? _selectedDesktopPrinter;
  String _printerConnectionType = 'bluetooth'; // 'bluetooth' or 'usb'

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnectionStatus();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _loadDesktopPrinters();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnect = prefs.getBool('printer_auto_connect') ?? true;
      _savedDeviceName = prefs.getString('printer_name');
      _printerConnectionType = prefs.getString('printer_connection_type') ?? 'bluetooth';
    });
  }

  Future<void> _savePrinterConnectionType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_connection_type', type);
    setState(() {
      _printerConnectionType = type;
    });
  }

  void _checkConnectionStatus() {
    setState(() {
      _connectedDeviceName = SimpleBluetoothService.connectedDeviceName;
    });
  }

  Future<void> _loadDesktopPrinters() async {
    try {
      final printers = await DesktopPrinterService.getAvailablePrinters();
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _desktopPrinters = printers;
        _selectedDesktopPrinter = prefs.getString('desktop_printer_name');
      });
    } catch (e) {
      print('Error loading desktop printers: $e');
    }
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
              content: Text('Connected to ${device.name}'),
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
    if (_printerConnectionType == 'usb') {
      await UsbThermalPrinterService.disconnect();
    } else {
      await SimpleBluetoothService.disconnect();
    }
    _checkConnectionStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
        ),
      );
    }
  }

  // USB Printer Methods
  Future<void> _scanForUsbPrinters() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('USB printing is only available on Android'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isScanningUsb = true;
      _usbDevices.clear();
    });

    try {
      final devices = await UsbThermalPrinterService.scanDevices();
      setState(() {
        _usbDevices = devices;
      });

      if (devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No USB printers found. Please connect via USB OTG cable'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning USB devices: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanningUsb = false;
        });
      }
    }
  }

  Future<void> _connectToUsbPrinter(UsbDevice device) async {
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
                Text('Connecting to USB printer...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final connected = await UsbThermalPrinterService.connectToDevice(device);
      Navigator.pop(context); // Close loading dialog

      if (connected) {
        setState(() {
          _connectedDeviceName = device.productName ?? 'USB Printer';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.productName ?? "USB Printer"}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to connect to USB printer');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('USB connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build categorized USB device list with grouping
  List<Widget> _buildCategorizedUsbDeviceList() {
    List<Widget> widgets = [];

    // Group devices by category
    final knownPrinters = _usbDevices.where((d) => UsbThermalPrinterService.getDeviceCategory(d) == 'known').toList();
    final printerDevices = _usbDevices.where((d) => UsbThermalPrinterService.getDeviceCategory(d) == 'printer').toList();
    final otherDevices = _usbDevices.where((d) => UsbThermalPrinterService.getDeviceCategory(d) == 'other').toList();

    // Known thermal printer brands
    if (knownPrinters.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4, left: 8),
          child: Text(
            '⭐ Known Thermal Printer Brands',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      );
      widgets.addAll(knownPrinters.map((device) => _buildUsbDeviceCard(device, Colors.green)));
    }

    // Devices with "printer" in name
    if (printerDevices.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4, left: 8),
          child: Text(
            '✅ Printer Devices',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
      );
      widgets.addAll(printerDevices.map((device) => _buildUsbDeviceCard(device, Colors.blue)));
    }

    // Other USB devices
    if (otherDevices.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4, left: 8),
          child: Text(
            '⚠️ Other USB Devices (May work - try at your own risk)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ),
      );
      widgets.addAll(otherDevices.map((device) => _buildUsbDeviceCard(device, Colors.orange)));
    }

    return widgets;
  }

  /// Build individual USB device card
  Widget _buildUsbDeviceCard(UsbDevice device, Color accentColor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accentColor,
          child: const Icon(Icons.usb, color: Colors.white, size: 20),
        ),
        title: Text(
          device.productName ?? 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'VID: ${device.vid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????'}, '
          'PID: ${device.pid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToUsbPrinter(device),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Connect',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _testPrint() async {
    // Check platform-specific connection status
    final isConnected = Platform.isAndroid || Platform.isIOS
        ? SimpleBluetoothService.isConnected
        : (_selectedDesktopPrinter != null && _selectedDesktopPrinter!.isNotEmpty);

    if (!isConnected) {
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
      final success = await PlatformPrinterService.printText(receipt);

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
      body: SafeArea(
        child: SingleChildScrollView(
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

            // Printer Type Selector (Android only - Choose between Bluetooth and USB)
            if (Platform.isAndroid) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings_input_composite, color: AppColors.primary, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Printer Connection Type',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Row(
                                children: [
                                  Icon(Icons.bluetooth, size: 20),
                                  SizedBox(width: 8),
                                  Text('Bluetooth'),
                                ],
                              ),
                              value: 'bluetooth',
                              groupValue: _printerConnectionType,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                if (value != null) {
                                  _savePrinterConnectionType(value);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Row(
                                children: [
                                  Icon(Icons.usb, size: 20),
                                  SizedBox(width: 8),
                                  Text('USB'),
                                ],
                              ),
                              value: 'usb',
                              groupValue: _printerConnectionType,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                if (value != null) {
                                  _savePrinterConnectionType(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // USB Printer Section (Android only - when USB is selected)
            if (Platform.isAndroid && _printerConnectionType == 'usb') ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.usb, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'USB Thermal Printers',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isScanningUsb ? null : _scanForUsbPrinters,
                            icon: _isScanningUsb
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.search, color: Colors.white),
                            label: Text(
                              _isScanningUsb ? 'Scanning...' : 'Scan',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_usbDevices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No USB devices found. Connect your printer via USB OTG cable and tap Scan.'),
                        )
                      else
                        Column(
                          children: _buildCategorizedUsbDeviceList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Desktop Printer Selection (Windows/Mac/Linux only)
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Desktop Printer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_desktopPrinters.isEmpty)
                        const Text('No printers found. Please check your system printers.')
                      else
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Printer',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedDesktopPrinter,
                          items: _desktopPrinters.map((printer) {
                            return DropdownMenuItem(
                              value: printer.name,
                              child: Text(printer.name),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              final printer = _desktopPrinters.firstWhere((p) => p.name == value);
                              await DesktopPrinterService.selectPrinter(printer);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('desktop_printer_name', value);
                              setState(() {
                                _selectedDesktopPrinter = value;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected printer: $value'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadDesktopPrinters,
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectedDesktopPrinter != null ? _testPrint : null,
                              icon: const Icon(Icons.print, color: Colors.white),
                              label: const Text('Test Print', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                        final isConnected = device.name == _connectedDeviceName;
                        final isPrinter = SimpleBluetoothService.isPrinterDevice(device.name);
                        return Card(
                          elevation: isPrinter ? 4 : 1,
                          color: isConnected
                              ? AppColors.primary.withOpacity(0.1)
                              : isPrinter
                                  ? Colors.blue.shade50
                                  : null,
                          child: ListTile(
                            leading: Icon(
                              isPrinter ? Icons.print : Icons.bluetooth,
                              color: isConnected
                                  ? AppColors.primary
                                  : isPrinter
                                      ? Colors.blue
                                      : Colors.grey,
                              size: isPrinter ? 32 : 24,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (device.name == null || device.name!.isEmpty)
                                        ? 'Unknown Device'
                                        : device.name!,
                                    style: TextStyle(
                                      fontWeight: isPrinter ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isPrinter)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'PRINTER',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              device.address.toString(),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: isConnected
                                ? const Chip(
                                    label: Text('Connected'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _connectToPrinter(device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPrinter ? AppColors.primary : null,
                                    ),
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
      ),
      floatingActionButton: Platform.isAndroid
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UsbDebugLogScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('USB Debug'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}