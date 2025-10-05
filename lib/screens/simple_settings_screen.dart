import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../services/simple_bluetooth_service.dart';

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

  // Rate settings
  final Map<String, Map<String, double>> _vehicleRates = {
    'Car': {'hourly': 20.0, 'minimum': 20.0, 'freeMinutes': 15},
    'Bike': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 10},
    'Scooter': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 10},
    'SUV': {'hourly': 30.0, 'minimum': 30.0, 'freeMinutes': 15},
    'Van': {'hourly': 25.0, 'minimum': 25.0, 'freeMinutes': 15},
    'Bus': {'hourly': 50.0, 'minimum': 50.0, 'freeMinutes': 10},
    'Truck': {'hourly': 40.0, 'minimum': 40.0, 'freeMinutes': 10},
    'Auto Rickshaw': {'hourly': 15.0, 'minimum': 15.0, 'freeMinutes': 10},
  };

  bool _isLoading = false;
  bool _autoPrint = true;
  bool _autoConnectPrinter = true;

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
      _autoPrint = prefs.getBool('auto_print') ?? true;
      _autoConnectPrinter = prefs.getBool(SimpleBluetoothService.PREF_AUTO_CONNECT) ?? true;

      // Load saved rates if any
      _vehicleRates.forEach((type, rates) {
        rates['hourly'] = prefs.getDouble('rate_${type}_hourly') ?? rates['hourly']!;
        rates['minimum'] = prefs.getDouble('rate_${type}_minimum') ?? rates['minimum']!;
        rates['freeMinutes'] = prefs.getDouble('rate_${type}_freeMinutes') ?? rates['freeMinutes']!;
      });
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
      await prefs.setBool(SimpleBluetoothService.PREF_AUTO_CONNECT, _autoConnectPrinter);

      // Save rates
      _vehicleRates.forEach((type, rates) async {
        await prefs.setDouble('rate_${type}_hourly', rates['hourly']!);
        await prefs.setDouble('rate_${type}_minimum', rates['minimum']!);
        await prefs.setDouble('rate_${type}_freeMinutes', rates['freeMinutes']!);
      });

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

  void _showRateEditDialog(String vehicleType) {
    final rates = _vehicleRates[vehicleType]!;
    final hourlyController = TextEditingController(text: rates['hourly'].toString());
    final minimumController = TextEditingController(text: rates['minimum'].toString());
    final freeMinutesController = TextEditingController(text: rates['freeMinutes']!.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $vehicleType Rates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hourlyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hourly Rate (₹)',
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minimumController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Charge (₹)',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: freeMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Free Minutes',
                prefixIcon: Icon(Icons.timer),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _vehicleRates[vehicleType] = {
                  'hourly': double.tryParse(hourlyController.text) ?? rates['hourly']!,
                  'minimum': double.tryParse(minimumController.text) ?? rates['minimum']!,
                  'freeMinutes': double.tryParse(freeMinutesController.text) ?? rates['freeMinutes']!,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
        title: const Text('Scanning for Printers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Please wait while scanning for nearby printers...'),
            const SizedBox(height: 8),
            Text(
              'Make sure your printer is turned on',
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
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () async {
                    Navigator.pop(context); // Close selection dialog

                    // Show connecting dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Connecting to printer...'),
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
                          content: Text('Connected to ${device.platformName}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to connect to printer'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
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
      body: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Auto Print Receipt'),
                        subtitle: const Text('Automatically print receipt after vehicle entry'),
                        value: _autoPrint,
                        onChanged: (value) {
                          setState(() {
                            _autoPrint = value;
                          });
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

              // Vehicle Rates
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Rates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._vehicleRates.entries.map((entry) {
                        final type = entry.key;
                        final rates = entry.value;
                        return Card(
                          color: AppColors.primary.withOpacity(0.05),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                type[0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(type),
                            subtitle: Text(
                              'Hourly: ₹${rates['hourly']!.toStringAsFixed(0)} | '
                              'Min: ₹${rates['minimum']!.toStringAsFixed(0)} | '
                              'Free: ${rates['freeMinutes']!.toInt()} min',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showRateEditDialog(type),
                            ),
                          ),
                        );
                      }).toList(),
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
    );
  }
}