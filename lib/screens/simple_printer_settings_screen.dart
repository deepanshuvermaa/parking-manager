import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/platform_printer_service.dart';
import '../services/native_usb_printer_service.dart';
import '../services/desktop_printer_service.dart';
import '../theme/app_theme.dart';

class SimplePrinterSettingsScreen extends StatefulWidget {
  const SimplePrinterSettingsScreen({super.key});
  @override
  State<SimplePrinterSettingsScreen> createState() => _SimplePrinterSettingsScreenState();
}

class _SimplePrinterSettingsScreenState extends State<SimplePrinterSettingsScreen> {
  bool _isScanning = false;
  bool _autoConnect = true;
  String _connectionType = 'bluetooth';
  List<BluetoothDevice> _bluetoothDevices = [];
  List<Map<String, dynamic>> _usbDevices = [];
  List<dynamic> _desktopPrinters = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (Platform.isWindows) _loadDesktopPrinters();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnect = prefs.getBool('printer_auto_connect') ?? true;
      _connectionType = prefs.getString('printer_connection_type') ?? 'bluetooth';
    });
  }

  Future<void> _saveAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printer_auto_connect', value);
    setState(() => _autoConnect = value);
  }

  Future<void> _saveConnectionType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_connection_type', type);
    setState(() => _connectionType = type);
  }

  Future<void> _scanBluetooth() async {
    setState(() => _isScanning = true);
    try {
      final result = await SimpleBluetoothService.requestPermissions();
      if (result['granted'] != true) {
        _showSnack('Bluetooth permissions required', isError: true);
        return;
      }
      final devices = await SimpleBluetoothService.scanForDevices();
      setState(() => _bluetoothDevices = devices);
    } catch (e) {
      _showSnack('Scan failed: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _scanUsb() async {
    setState(() => _isScanning = true);
    try {
      final devices = await NativeUsbPrinterService.listDevices();
      setState(() => _usbDevices = devices);
    } catch (e) {
      _showSnack('USB scan failed: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectBluetooth(BluetoothDevice device) async {
    final success = await SimpleBluetoothService.connectToDevice(device);
    _showSnack(success ? 'Connected to ${device.name}' : 'Connection failed', isError: !success);
    setState(() {});
  }

  Future<void> _connectUsb(Map<String, dynamic> device) async {
    final success = await NativeUsbPrinterService.connectToDevice(device);
    _showSnack(success ? 'Connected to ${device['productName']}' : 'Connection failed', isError: !success);
    setState(() {});
  }

  Future<void> _loadDesktopPrinters() async {
    final printers = await DesktopPrinterService.getAvailablePrinters();
    setState(() => _desktopPrinters = printers);
  }

  Future<void> _selectDesktopPrinter(dynamic printer) async {
    await DesktopPrinterService.selectPrinter(printer);
    _showSnack('Printer selected: ${printer.name}');
    setState(() {});
  }

  Future<void> _testPrint() async {
    final success = await PlatformPrinterService.printTest();
    _showSnack(success ? 'Test print sent' : 'Test print failed', isError: !success);
  }

  Future<void> _disconnect() async {
    await PlatformPrinterService.disconnect();
    _showSnack('Disconnected');
    setState(() {});
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Go2Colors.error : Go2Colors.success,
    ));
  }

  bool get _isConnected {
    if (Platform.isAndroid) {
      return _connectionType == 'usb'
          ? NativeUsbPrinterService.isConnected
          : SimpleBluetoothService.isConnected;
    }
    return false;
  }

  String? get _connectedName {
    if (Platform.isAndroid) {
      return _connectionType == 'usb'
          ? NativeUsbPrinterService.connectedDeviceName
          : SimpleBluetoothService.connectedDeviceName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Go2Colors.canvas,
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        children: [
          _buildStatusCard(),
          const SizedBox(height: Go2Spacing.lg),
          if (Platform.isAndroid) ...[
            _buildBluetoothSection(),
            const SizedBox(height: Go2Spacing.lg),
            _buildUsbSection(),
          ],
          if (Platform.isWindows) _buildWindowsSection(),
          if (!Platform.isAndroid && !Platform.isWindows) _buildWindowsSection(),
          const SizedBox(height: Go2Spacing.lg),
          _buildSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final connected = _isConnected;
    final name = _connectedName;
    return Container(
      padding: const EdgeInsets.all(Go2Spacing.lg),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: connected ? Go2Colors.success : Go2Colors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Go2Spacing.sm),
          Expanded(child: Text(
            connected ? name ?? 'Connected' : 'Not connected',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Go2Colors.textPrimary),
          )),
        ]),
        if (connected) ...[
          const SizedBox(height: Go2Spacing.md),
          Row(children: [
            OutlinedButton(onPressed: _testPrint, child: const Text('Test Print')),
            const SizedBox(width: Go2Spacing.sm),
            TextButton(
              onPressed: _disconnect,
              style: TextButton.styleFrom(foregroundColor: Go2Colors.error),
              child: const Text('Disconnect'),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildBluetoothSection() {
    return _sectionCard(
      title: 'Bluetooth Printers',
      icon: Icons.bluetooth,
      children: [
        _scanButton(onPressed: _scanBluetooth, label: 'Scan for Printers', icon: Icons.search),
        ..._bluetoothDevices.map((d) => ListTile(
          dense: true, contentPadding: EdgeInsets.zero,
          title: Text(d.name ?? 'Unknown', style: const TextStyle(fontSize: 14)),
          subtitle: Text(d.address, style: const TextStyle(fontSize: 12, color: Go2Colors.textHint)),
          trailing: TextButton(onPressed: () => _connectBluetooth(d), child: const Text('Connect')),
        )),
      ],
    );
  }

  Widget _buildUsbSection() {
    return _sectionCard(
      title: 'USB Printers',
      icon: Icons.usb,
      children: [
        _scanButton(onPressed: _scanUsb, label: 'Scan USB Devices', icon: Icons.usb),
        ..._usbDevices.map((d) => ListTile(
          dense: true, contentPadding: EdgeInsets.zero,
          title: Text(d['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
          subtitle: Text('VID: ${d['vendorId']} PID: ${d['productId']}',
              style: const TextStyle(fontSize: 12, color: Go2Colors.textHint)),
          trailing: TextButton(onPressed: () => _connectUsb(d), child: const Text('Connect')),
        )),
      ],
    );
  }

  Widget _buildWindowsSection() {
    return _sectionCard(
      title: 'System Printers',
      icon: Icons.print,
      children: [
        _scanButton(onPressed: _loadDesktopPrinters, label: 'Refresh Printers', icon: Icons.refresh),
        ..._desktopPrinters.map((p) => ListTile(
          dense: true, contentPadding: EdgeInsets.zero,
          title: Text(p.name, style: const TextStyle(fontSize: 14)),
          subtitle: p.isDefault
              ? const Text('Default', style: TextStyle(fontSize: 12, color: Go2Colors.success))
              : null,
          trailing: TextButton(onPressed: () => _selectDesktopPrinter(p), child: const Text('Select')),
        )),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return _sectionCard(
      title: 'Settings',
      icon: Icons.settings,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-connect on app start', style: TextStyle(fontSize: 14)),
          value: _autoConnect,
          activeTrackColor: Go2Colors.primary,
          onChanged: _saveAutoConnect,
        ),
        if (Platform.isAndroid) ...[
          const Divider(height: 1, color: Go2Colors.divider),
          const SizedBox(height: Go2Spacing.sm),
          Row(children: [
            const Text('Connection type:', style: TextStyle(fontSize: 14)),
            const Spacer(),
            Flexible(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bluetooth', label: Text('BT', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'usb', label: Text('USB', style: TextStyle(fontSize: 11))),
                ],
                selected: {_connectionType},
                onSelectionChanged: (v) => _saveConnectionType(v.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _scanButton({required VoidCallback onPressed, required String label, required IconData icon}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isScanning ? null : onPressed,
        icon: _isScanning
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(_isScanning ? 'Scanning...' : label),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(Go2Spacing.lg),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: Go2Colors.primary),
          const SizedBox(width: Go2Spacing.sm),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
        ]),
        const SizedBox(height: Go2Spacing.md),
        ...children,
      ]),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Go2Colors.surface,
    borderRadius: BorderRadius.circular(Go2Radius.md),
    border: Border.all(color: Go2Colors.divider),
  );
}
