import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/export_import_service.dart';
import 'vehicle_rates_management_screen.dart';

class SimpleSettingsScreen extends StatefulWidget {
  final String token;

  const SimpleSettingsScreen({super.key, required this.token});

  @override
  State<SimpleSettingsScreen> createState() => _SimpleSettingsScreenState();
}

class _SimpleSettingsScreenState extends State<SimpleSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Business settings
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _gstNumberController = TextEditingController();

  // Receipt settings
  final _receiptHeaderController = TextEditingController();
  final _receiptFooterController = TextEditingController();

  bool _isLoading = false;
  bool _autoPrint = true;
  bool _autoPrintExit = true;
  bool _autoConnectPrinter = true;
  int _paperWidth = 32; // 32 for 2", 48 for 3"

  // Bill format customization
  bool _showBusinessName = true;
  bool _showBusinessAddress = true;
  bool _showBusinessPhone = true;
  bool _showGstNumber = true;
  bool _showReceiptHeader = true;
  bool _showReceiptFooter = true;
  bool _showRateInfo = true;
  bool _showNotes = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _gstNumberController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _businessNameController.text = prefs.getString('business_name') ?? 'My Parking Business';
      _businessAddressController.text = prefs.getString('business_address') ?? '';
      _businessPhoneController.text = prefs.getString('business_phone') ?? '';
      _gstNumberController.text = prefs.getString('gst_number') ?? '';
      _receiptHeaderController.text = prefs.getString('receipt_header') ?? 'Welcome to our parking';
      _receiptFooterController.text = prefs.getString('receipt_footer') ?? 'Thank you for parking with us!';
      _autoPrint = prefs.getBool('auto_print') ?? false;
      _autoPrintExit = prefs.getBool('auto_print_exit') ?? false;
      _autoConnectPrinter = prefs.getBool(SimpleBluetoothService.PREF_AUTO_CONNECT) ?? true;
      _paperWidth = prefs.getInt('paper_width') ?? 32;

      // Load bill format settings
      _showBusinessName = prefs.getBool('bill_show_business_name') ?? true;
      _showBusinessAddress = prefs.getBool('bill_show_business_address') ?? true;
      _showBusinessPhone = prefs.getBool('bill_show_business_phone') ?? true;
      _showGstNumber = prefs.getBool('bill_show_gst_number') ?? true;
      _showReceiptHeader = prefs.getBool('bill_show_receipt_header') ?? true;
      _showReceiptFooter = prefs.getBool('bill_show_receipt_footer') ?? true;
      _showRateInfo = prefs.getBool('bill_show_rate_info') ?? true;
      _showNotes = prefs.getBool('bill_show_notes') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save business settings
      await prefs.setString('business_name', _businessNameController.text);
      await prefs.setString('business_address', _businessAddressController.text);
      await prefs.setString('business_phone', _businessPhoneController.text);
      await prefs.setString('gst_number', _gstNumberController.text);

      // Save receipt settings
      await prefs.setString('receipt_header', _receiptHeaderController.text);
      await prefs.setString('receipt_footer', _receiptFooterController.text);
      await prefs.setBool('auto_print', _autoPrint);
      await prefs.setBool('auto_print_exit', _autoPrintExit);
      await prefs.setBool(SimpleBluetoothService.PREF_AUTO_CONNECT, _autoConnectPrinter);
      await prefs.setInt('paper_width', _paperWidth);

      // Save bill format settings
      await prefs.setBool('bill_show_business_name', _showBusinessName);
      await prefs.setBool('bill_show_business_address', _showBusinessAddress);
      await prefs.setBool('bill_show_business_phone', _showBusinessPhone);
      await prefs.setBool('bill_show_gst_number', _showGstNumber);
      await prefs.setBool('bill_show_receipt_header', _showReceiptHeader);
      await prefs.setBool('bill_show_receipt_footer', _showReceiptFooter);
      await prefs.setBool('bill_show_rate_info', _showRateInfo);
      await prefs.setBool('bill_show_notes', _showNotes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showBluetoothScanDialog() async {
    // Check permissions first
    final permissionResult = await SimpleBluetoothService.requestPermissions();

    if (!permissionResult['granted']) {
      final errors = permissionResult['errors'] as Map<String, String>;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following permissions are required:'),
              const SizedBox(height: 8),
              ...errors.values.map((error) => Text('• $error')),
              const SizedBox(height: 16),
              if (errors.containsKey('settings'))
                const Text(
                  'Please go to app settings and enable all permissions.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (errors.containsKey('settings'))
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
          ],
        ),
      );
      return;
    }

    // Check if Bluetooth is on
    if (!await SimpleBluetoothService.isBluetoothAvailable()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bluetooth Required'),
          content: const Text('Please turn on Bluetooth to scan for printers.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Scanning for Devices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Discovering nearby Bluetooth devices...'),
            const SizedBox(height: 8),
            Text(
              'This may take up to 15 seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );

    try {
      final devices = await SimpleBluetoothService.scanForDevices();
      Navigator.pop(context); // Close scanning dialog

      if (devices.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Devices Found'),
            content: const Text('No Bluetooth printers were found. Make sure your printer is turned on and in pairing mode.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show device selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Found ${devices.length} Device(s)'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final deviceName = device.name ?? 'Unknown Device';
                final isPaired = device.isBonded;
                final isPrinter = SimpleBluetoothService.isPrinterDevice(deviceName);

                return Card(
                  color: isPrinter ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: Icon(
                      isPrinter ? Icons.print : Icons.bluetooth,
                      color: isPrinter ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      deviceName,
                      style: TextStyle(
                        fontWeight: isPrinter ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.address),
                        if (isPaired)
                          const Text(
                            '✓ Already Paired',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: isPrinter
                        ? const Chip(
                            label: Text('Printer', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.blue,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(context); // Close selection dialog

                      // Show connecting dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text('Connecting to $deviceName...'),
                            ],
                          ),
                        ),
                      );

                      final connected = await SimpleBluetoothService.connectToDevice(device);
                      Navigator.pop(context); // Close connecting dialog

                      if (connected) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Connected to $deviceName'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to connect to $deviceName'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close scanning dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scan Error'),
          content: Text('Error: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportData() async {
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
                Text('Creating backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await ExportImportService.exportToFile();
      Navigator.pop(context); // Close loading dialog

      if (success && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup file has been created and shared.'),
                SizedBox(height: 8),
                Text(
                  'Save this file in a safe location. You can use it to restore all your settings and data later.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Import Backup'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will replace ALL current settings with the imported data.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Current settings will be overwritten. Continue?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
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
                Text('Importing backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await ExportImportService.importFromFile();
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result['imported_count']} settings restored successfully!'),
                const SizedBox(height: 8),
                if (result['export_date'] != null)
                  Text(
                    'Backup date: ${result['export_date'].toString().split('T')[0]}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Please restart the app to see all changes.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadSettings(); // Reload settings
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Information
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'Business Name',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter business name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _businessAddressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Business Address',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _businessPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gstNumberController,
                        decoration: const InputDecoration(
                          labelText: 'GST Number (Optional)',
                          prefixIcon: Icon(Icons.receipt),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt Settings
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiptHeaderController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Header Text',
                          prefixIcon: Icon(Icons.text_fields),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiptFooterController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Footer Text',
                          prefixIcon: Icon(Icons.text_fields),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Auto-Print Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Printer must be connected for auto-print to work',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: _autoPrint ? Colors.green.shade50 : Colors.grey.shade50,
                        child: SwitchListTile(
                          title: const Text(
                            'Auto-print on Vehicle Entry',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Print receipt automatically when vehicle enters'),
                          value: _autoPrint,
                          onChanged: (value) {
                            setState(() {
                              _autoPrint = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: _autoPrintExit ? Colors.green.shade50 : Colors.grey.shade50,
                        child: SwitchListTile(
                          title: const Text(
                            'Auto-print on Vehicle Exit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Print receipt automatically when vehicle exits'),
                          value: _autoPrintExit,
                          onChanged: (value) {
                            setState(() {
                              _autoPrintExit = value;
                            });
                          },
                        ),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Paper Width',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<int>(
                              title: const Text('2 inch (32 chars)'),
                              subtitle: const Text('Standard thermal'),
                              value: 32,
                              groupValue: _paperWidth,
                              onChanged: (value) {
                                setState(() {
                                  _paperWidth = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<int>(
                              title: const Text('3 inch (48 chars)'),
                              subtitle: const Text('Wider paper'),
                              value: 48,
                              groupValue: _paperWidth,
                              onChanged: (value) {
                                setState(() {
                                  _paperWidth = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Bill Format Customization',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose which fields to show on receipts and reports',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Business Name'),
                        subtitle: const Text('Show business name on bills'),
                        value: _showBusinessName,
                        onChanged: (value) {
                          setState(() => _showBusinessName = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Business Address'),
                        subtitle: const Text('Show address on bills'),
                        value: _showBusinessAddress,
                        onChanged: (value) {
                          setState(() => _showBusinessAddress = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Business Phone'),
                        subtitle: const Text('Show phone number on bills'),
                        value: _showBusinessPhone,
                        onChanged: (value) {
                          setState(() => _showBusinessPhone = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('GST Number'),
                        subtitle: const Text('Show GST number on exit bills'),
                        value: _showGstNumber,
                        onChanged: (value) {
                          setState(() => _showGstNumber = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Receipt Header'),
                        subtitle: const Text('Show welcome message'),
                        value: _showReceiptHeader,
                        onChanged: (value) {
                          setState(() => _showReceiptHeader = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Receipt Footer'),
                        subtitle: const Text('Show thank you message'),
                        value: _showReceiptFooter,
                        onChanged: (value) {
                          setState(() => _showReceiptFooter = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Rate Information'),
                        subtitle: const Text('Show hourly rate and minimum charge'),
                        value: _showRateInfo,
                        onChanged: (value) {
                          setState(() => _showRateInfo = value ?? true);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Notes Field'),
                        subtitle: const Text('Show notes section if present'),
                        value: _showNotes,
                        onChanged: (value) {
                          setState(() => _showNotes = value ?? true);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bluetooth Printer Settings
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bluetooth Printer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (SimpleBluetoothService.isConnected)
                        ListTile(
                          leading: const Icon(Icons.bluetooth_connected, color: Colors.blue),
                          title: Text('Connected to ${SimpleBluetoothService.connectedDeviceName}'),
                          trailing: TextButton(
                            onPressed: () async {
                              await SimpleBluetoothService.disconnect();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Printer disconnected')),
                              );
                            },
                            child: const Text('Disconnect'),
                          ),
                        )
                      else
                        Column(
                          children: [
                            const ListTile(
                              leading: Icon(Icons.bluetooth_disabled, color: Colors.grey),
                              title: Text('No printer connected'),
                              subtitle: Text('Tap below to scan and connect'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showBluetoothScanDialog(),
                              icon: const Icon(Icons.bluetooth_searching),
                              label: const Text('Scan for Printers'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Auto-connect to printer'),
                        subtitle: const Text('Automatically connect on app start'),
                        value: _autoConnectPrinter,
                        onChanged: (value) {
                          setState(() {
                            _autoConnectPrinter = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Vehicle Rates - Navigate to management screen
              Card(
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehicleRatesManagementScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.local_atm, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vehicle Rates',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage pricing for different vehicle types',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Backup & Restore
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.backup, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Backup & Restore',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Export all your settings and data as a backup file, or restore from a previous backup.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _exportData,
                              icon: const Icon(Icons.download, color: Colors.white),
                              label: const Text(
                                'Export Backup',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _importData,
                              icon: const Icon(Icons.upload, color: Colors.white),
                              label: const Text(
                                'Import Backup',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Save All Settings',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }
}