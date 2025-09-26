import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/simplified_bluetooth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Printer Setup'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SimplifiedBluetoothProvider>(
        builder: (context, bluetooth, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionCard(bluetooth),
                const SizedBox(height: 16),
                _buildSetupSteps(bluetooth),
                const SizedBox(height: 16),
                if (bluetooth.devices.isNotEmpty) _buildDevicesList(bluetooth),
                const SizedBox(height: 16),
                _buildPrintSettings(),
                if (bluetooth.isConnected) ...[
                  const SizedBox(height: 16),
                  _buildTestPrintCard(bluetooth),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionCard(SimplifiedBluetoothProvider bluetooth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  bluetooth.isConnected ? Icons.print : Icons.print_disabled,
                  color: bluetooth.isConnected ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Printer Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bluetooth.isConnected
                            ? 'Connected to ${bluetooth.connectedDevice!.name.isEmpty ? bluetooth.connectedDevice!.id : bluetooth.connectedDevice!.name}'
                            : 'No printer connected',
                        style: TextStyle(
                          color: bluetooth.isConnected ? Colors.green : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (bluetooth.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Connected',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (bluetooth.isConnected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Printer is ready for use',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: bluetooth.disconnectDevice,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            ],
            if (bluetooth.lastError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bluetooth.lastError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
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
  }

  Widget _buildSetupSteps(SimplifiedBluetoothProvider bluetooth) {
    if (bluetooth.isConnected) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setup Your Printer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Follow these steps to connect your Bluetooth printer',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Permissions
            _buildStepItem(
              stepNumber: 1,
              title: 'Grant Permissions',
              subtitle: 'Allow app to use Bluetooth',
              isCompleted: bluetooth.hasPermissions,
              onTap: bluetooth.hasPermissions ? null : bluetooth.requestPermissions,
              icon: Icons.security,
            ),

            const SizedBox(height: 12),

            // Step 2: Bluetooth
            _buildStepItem(
              stepNumber: 2,
              title: 'Enable Bluetooth',
              subtitle: 'Turn on Bluetooth on your device',
              isCompleted: bluetooth.bluetoothOn,
              onTap: bluetooth.bluetoothOn ? null : bluetooth.turnOnBluetooth,
              icon: Icons.bluetooth,
            ),

            const SizedBox(height: 12),

            // Step 3: Scan
            _buildStepItem(
              stepNumber: 3,
              title: 'Find Printers',
              subtitle: bluetooth.isScanning
                  ? 'Scanning... ${bluetooth.scanSeconds}s'
                  : 'Search for nearby printers',
              isCompleted: false,
              isInProgress: bluetooth.isScanning,
              onTap: bluetooth.bluetoothOn && bluetooth.hasPermissions && !bluetooth.isScanning
                  ? bluetooth.startScan
                  : null,
              icon: Icons.search,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isInProgress = false,
    VoidCallback? onTap,
    required IconData icon,
  }) {
    final isActive = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.shade50
              : isActive
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted
                ? Colors.green.shade200
                : isActive
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : isActive
                        ? AppColors.primary
                        : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.green.shade700 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted ? Colors.green.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isInProgress) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (isActive) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList(SimplifiedBluetoothProvider bluetooth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Available Printers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${bluetooth.devices.length} printer(s) found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...bluetooth.devices.map((device) {
              final isConnected = bluetooth.connectedDevice == device;
              final deviceName = device.name.isEmpty ? 'Unknown Printer' : device.name;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConnected ? Colors.green.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green.shade100 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.print,
                      color: isConnected ? Colors.green : Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    deviceName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  subtitle: Text(
                    device.id.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: isConnected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => bluetooth.connectToDevice(device),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Connect'),
                        ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Print Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: settings.settings.autoPrint
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.print,
                          color: settings.settings.autoPrint
                              ? Colors.green
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-print receipts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Automatically print when vehicle exits',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.settings.autoPrint,
                        onChanged: (value) {
                          settings.updateSettings(
                            settings.settings.copyWith(autoPrint: value),
                          );
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestPrintCard(SimplifiedBluetoothProvider bluetooth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Test Your Printer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Print a sample receipt to verify everything works',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _testPrint(bluetooth),
                icon: const Icon(Icons.print),
                label: const Text('Print Sample Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testPrint(SimplifiedBluetoothProvider bluetooth) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final testReceipt = '''
================================
       ${settingsProvider.settings.businessName.toUpperCase()}
================================
Date: ${DateTime.now().toString().substring(0, 19)}
--------------------------------
This is a sample receipt to test
your printer connection.

Vehicle: DEMO-1234
Type: Car
Duration: 2 hours
Amount: ${settingsProvider.formatCurrency(100.00)}
--------------------------------
       Thank you!
       Printer test successful
--------------------------------
  Parkease by Go2-Billingsoftware
================================
''';

    bluetooth.printReceipt(testReceipt);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.print, color: Colors.white),
            SizedBox(width: 8),
            Text('Sample receipt sent to printer'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}