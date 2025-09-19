import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _isLoading = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Printer Settings'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDevices,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading && !_hasInitialized
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing Bluetooth...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl + 60,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConnectionStatus(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPrintSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAvailableDevices(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTestPrint(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Status',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: bluetoothProvider.isBluetoothEnabled
                            ? AppColors.success
                            : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      bluetoothProvider.isBluetoothEnabled
                          ? 'Bluetooth Enabled'
                          : 'Bluetooth Disabled',
                      style: TextStyle(
                        color: bluetoothProvider.isBluetoothEnabled
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (bluetoothProvider.connectedDevice != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.print, color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected to:',
                                style: TextStyle(
                                  fontSize: AppFontSize.sm,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                bluetoothProvider.connectedDevice!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _disconnectPrinter,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.warning),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'No printer connected',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrintSettings() {
    return Consumer2<SettingsProvider, BluetoothProvider>(
      builder: (context, settingsProvider, bluetoothProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Print Settings',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  title: const Text('Auto Print Receipts'),
                  subtitle: const Text('Automatically print receipts after checkout'),
                  value: settingsProvider.settings.autoPrint,
                  onChanged: (value) {
                    settingsProvider.updateAutoPrint(value);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Default Printer'),
                  subtitle: Text(
                    bluetoothProvider.connectedDevice?.name ?? 'None selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: bluetoothProvider.devices.isNotEmpty
                      ? _showPrinterSelectionDialog
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableDevices() {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Devices',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: bluetoothProvider.isScanning ? null : _scanForDevices,
                      icon: bluetoothProvider.isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(bluetoothProvider.isScanning ? 'Scanning...' : 'Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!bluetoothProvider.isBluetoothEnabled)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bluetooth_disabled, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Please enable Bluetooth to scan for printers',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final bluetoothProvider = context.read<BluetoothProvider>();
                            await bluetoothProvider.retryInitialization();
                            if (bluetoothProvider.isBluetoothEnabled) {
                              _scanForDevices();
                            }
                          },
                          child: const Text('Enable'),
                        ),
                      ],
                    ),
                  )
                else if (bluetoothProvider.devices.isEmpty && !bluetoothProvider.isScanning)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFontSize.lg,
                            ),
                          ),
                          Text(
                            'Tap scan to search for printers',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFontSize.sm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bluetoothProvider.devices.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = bluetoothProvider.devices[index];
                      final isConnected = device.isConnected;

                      return ListTile(
                        leading: Icon(
                          isConnected ? Icons.print : Icons.print_outlined,
                          color: isConnected ? AppColors.success : AppColors.textSecondary,
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          isConnected ? 'Connected' : 'Available',
                          style: TextStyle(
                            color: isConnected ? AppColors.success : AppColors.textSecondary,
                          ),
                        ),
                        trailing: isConnected
                            ? const Icon(Icons.check_circle, color: AppColors.success)
                            : OutlinedButton(
                                onPressed: () => _connectToDevice(device),
                                child: const Text('Connect'),
                              ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestPrint() {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test Print',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Print a test receipt to verify your printer is working correctly.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: bluetoothProvider.isConnected && !_isLoading
                        ? _printTestReceipt
                        : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(_isLoading ? 'Printing...' : 'Print Test Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initializeBluetooth() async {
    if (_hasInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bluetoothProvider = context.read<BluetoothProvider>();
      await bluetoothProvider.initialize();
      _hasInitialized = true;

      // Auto-scan if Bluetooth is enabled and no devices found
      if (bluetoothProvider.isBluetoothEnabled && bluetoothProvider.devices.isEmpty) {
        await _scanForDevices();
      }
    } catch (e) {
      debugPrint('Failed to initialize Bluetooth: $e');
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to initialize Bluetooth. Please check permissions.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDevices() async {
    await _scanForDevices();
  }

  Future<void> _scanForDevices() async {
    final bluetoothProvider = context.read<BluetoothProvider>();

    if (!bluetoothProvider.hasPermissions) {
      final hasPermissions = await bluetoothProvider.retryInitialization();
      if (!hasPermissions) {
        if (mounted) {
          Helpers.showSnackBar(context, 'Please grant Bluetooth permissions in settings', isError: true);
        }
        return;
      }
    }

    if (!bluetoothProvider.isBluetoothEnabled) {
      Helpers.showSnackBar(context, 'Please enable Bluetooth first', isError: true);
      return;
    }

    try {
      await bluetoothProvider.startScan(timeout: const Duration(seconds: 15));

      if (bluetoothProvider.devices.isEmpty && mounted) {
        Helpers.showSnackBar(context, 'No printers found. Make sure your printer is on and in pairing mode.');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to scan for devices: $e', isError: true);
      }
    }
  }

  Future<void> _connectToDevice(PrinterDevice device) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bluetoothProvider = context.read<BluetoothProvider>();
      final success = await bluetoothProvider.connectToDevice(device);

      if (success) {
        final settingsProvider = context.read<SettingsProvider>();
        await settingsProvider.updatePrimaryPrinter(device.id);

        if (mounted) {
          Helpers.showSnackBar(context, 'Connected to ${device.name}');
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(context, 'Failed to connect to ${device.name}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Connection error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    await bluetoothProvider.disconnect();

    if (mounted) {
      Helpers.showSnackBar(context, 'Printer disconnected');
    }
  }

  void _showPrinterSelectionDialog() {
    final bluetoothProvider = context.read<BluetoothProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: bluetoothProvider.devices.map((device) {
            return ListTile(
              leading: Icon(
                device.isConnected ? Icons.print : Icons.print_outlined,
                color: device.isConnected ? AppColors.success : AppColors.textSecondary,
              ),
              title: Text(device.name),
              subtitle: Text(device.isConnected ? 'Connected' : 'Available'),
              onTap: () async {
                Navigator.pop(context);
                if (!device.isConnected) {
                  await _connectToDevice(device);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _printTestReceipt() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bluetoothProvider = context.read<BluetoothProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      final testReceipt = '''
${settingsProvider.settings.businessName}
${settingsProvider.settings.businessAddress}
Ph: ${settingsProvider.settings.businessPhone}

==============================
TEST PRINT
==============================
Date: ${Helpers.formatDateTime(DateTime.now())}
Printer: ${bluetoothProvider.connectedDevice?.name ?? 'Unknown'}

This is a test print to verify
that your printer is working
correctly.

==============================
Test completed successfully!
==============================
''';

      final success = await bluetoothProvider.printText(testReceipt);

      if (mounted) {
        if (success) {
          Helpers.showSnackBar(context, 'Test receipt printed successfully');
        } else {
          Helpers.showSnackBar(context, 'Failed to print test receipt', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Print error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}