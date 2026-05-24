import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../services/settings_sync_service.dart';
import '../services/export_import_service.dart';
import '../theme/app_theme.dart';
import 'receipt_customization_screen.dart';
import 'vehicle_rates_management_screen.dart';

class SimpleSettingsScreen extends StatefulWidget {
  final String token;
  const SimpleSettingsScreen({super.key, required this.token});

  @override
  State<SimpleSettingsScreen> createState() => _SimpleSettingsScreenState();
}

class _SimpleSettingsScreenState extends State<SimpleSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _autoPrint = true;
  bool _autoPrintExit = true;
  bool _showQr = true;
  int _paperWidth = 32;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = p.getString('business_name') ?? '';
      _addressCtrl.text = p.getString('business_address') ?? '';
      _phoneCtrl.text = p.getString('business_phone') ?? '';
      _gstCtrl.text = p.getString('gst_number') ?? '';
      _upiCtrl.text = p.getString('upi_vpa') ?? '';
      _autoPrint = p.getBool('auto_print') ?? true;
      _autoPrintExit = p.getBool('auto_print_exit') ?? true;
      _showQr = p.getBool('bill_show_qr_code') ?? true;
      _paperWidth = p.getInt('paper_width') ?? 32;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('business_name', _nameCtrl.text.trim());
    await p.setString('business_address', _addressCtrl.text.trim());
    await p.setString('business_phone', _phoneCtrl.text.trim());
    await p.setString('gst_number', _gstCtrl.text.trim());
    await p.setString('upi_vpa', _upiCtrl.text.trim());
    await p.setBool('auto_print', _autoPrint);
    await p.setBool('auto_print_exit', _autoPrintExit);
    await p.setBool('bill_show_qr_code', _showQr);
    await p.setInt('paper_width', _paperWidth);
    SettingsSyncService.syncToBackend(widget.token);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Settings saved'), backgroundColor: Go2Colors.success, duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_rounded, size: 18, color: _saved ? Go2Colors.success : Go2Colors.primary),
            label: Text(_saved ? 'Saved' : 'Save', style: TextStyle(color: _saved ? Go2Colors.success : Go2Colors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Info
          _section('Business Info'),
          _card([
            _input('Business Name', _nameCtrl, Icons.store_rounded),
            _input('Address', _addressCtrl, Icons.location_on_outlined),
            _input('Phone', _phoneCtrl, Icons.phone_outlined, keyboard: TextInputType.phone),
            _input('GST Number', _gstCtrl, Icons.receipt_outlined),
            _input('UPI ID (for QR payments)', _upiCtrl, Icons.qr_code_rounded),
          ]),

          // Printing
          _section('Printing'),
          _card([
            SwitchListTile(
              dense: true, activeColor: Go2Colors.primary,
              title: const Text('Auto-print on Entry'),
              subtitle: const Text('Print receipt when vehicle is parked'),
              value: _autoPrint,
              onChanged: (v) { setState(() => _autoPrint = v); _save(); },
            ),
            const Divider(height: 1),
            SwitchListTile(
              dense: true, activeColor: Go2Colors.primary,
              title: const Text('Auto-print on Exit'),
              subtitle: const Text('Print receipt when vehicle exits'),
              value: _autoPrintExit,
              onChanged: (v) { setState(() => _autoPrintExit = v); _save(); },
            ),
            const Divider(height: 1),
            SwitchListTile(
              dense: true, activeColor: Go2Colors.primary,
              title: const Text('Show QR/Ticket on Receipt'),
              subtitle: const Text('Ticket ID for scanning at exit'),
              value: _showQr,
              onChanged: (v) { setState(() => _showQr = v); _save(); },
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              title: const Text('Paper Width'),
              subtitle: Text(_paperWidth == 32 ? '2-inch (58mm)' : '3-inch (80mm)'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 32, label: Text('2"', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 48, label: Text('3"', style: TextStyle(fontSize: 12))),
                ],
                selected: {_paperWidth},
                onSelectionChanged: (v) { setState(() => _paperWidth = v.first); _save(); },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            const Divider(height: 1),
            _nav('Printer Connection', Icons.print_rounded, () => Navigator.pushNamed(context, '/printer')),
            _nav('Customize Receipt', Icons.receipt_long_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptCustomizationScreen()))),
          ]),

          // Rates
          _section('Vehicle Rates'),
          _card([
            _nav('Manage Rates', Icons.currency_rupee_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRatesManagementScreen()))),
          ]),

          // Backup
          _section('Data Backup'),
          _card([
            ListTile(
              dense: true,
              leading: const Icon(Icons.backup_rounded, size: 20, color: Go2Colors.primary),
              title: const Text('Create Backup'),
              subtitle: const Text('Save all data to device storage'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Go2Colors.textHint),
              onTap: () async {
                final path = await ExportImportService.createBackup();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(path != null ? '✓ Backup saved' : 'Backup failed'),
                    backgroundColor: path != null ? Go2Colors.success : Go2Colors.error,
                  ));
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.restore_rounded, size: 20, color: Go2Colors.primary),
              title: const Text('Restore Backup'),
              subtitle: const Text('Import data from backup file'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Go2Colors.textHint),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
                if (result != null && result.files.single.path != null) {
                  final success = await ExportImportService.restoreBackup(result.files.single.path!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success ? '✓ Data restored' : 'Restore failed'),
                      backgroundColor: success ? Go2Colors.success : Go2Colors.error,
                    ));
                  }
                }
              },
            ),
          ]),

          // Account
          _section('Account'),
          _card([
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_rounded, size: 20),
              title: Text(auth.userName.isNotEmpty ? auth.userName : 'Admin'),
              subtitle: Text('${auth.userRole} • ${auth.userEmail}'),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout_rounded, size: 20, color: Go2Colors.error),
              title: const Text('Logout', style: TextStyle(color: Go2Colors.error)),
              onTap: () { auth.logout(); Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false); },
            ),
          ]),
          const SizedBox(height: 24),

          // Save button - prominent
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save All Settings', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Go2Colors.textHint, letterSpacing: 0.8)),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(color: Go2Colors.surface, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(children: children),
  );

  Widget _input(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: TextField(controller: ctrl, keyboardType: keyboard, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), isDense: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Go2Colors.primary.withValues(alpha: 0.3))))),
  );

  Widget _nav(String title, IconData icon, VoidCallback onTap) => ListTile(
    dense: true, leading: Icon(icon, size: 20, color: Go2Colors.primary),
    title: Text(title), trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Go2Colors.textHint), onTap: onTap,
  );

  @override
  void dispose() { _nameCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose(); _gstCtrl.dispose(); _upiCtrl.dispose(); super.dispose(); }
}
