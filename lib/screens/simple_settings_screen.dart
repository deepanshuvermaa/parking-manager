import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
  bool _is3Inch = false;
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('business_name') ?? '';
      _addressCtrl.text = prefs.getString('business_address') ?? '';
      _phoneCtrl.text = prefs.getString('business_phone') ?? '';
      _is3Inch = prefs.getBool('paper_3inch') ?? false;
      _autoPrint = prefs.getBool('auto_print') ?? false;
    });
  }

  Future<void> _saveField(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: Go2Spacing.xl, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Go2Colors.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Go2Colors.surface,
        border: Border.all(color: Go2Colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(Go2Radius.md),
      ),
      child: Column(children: children),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String prefKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: ctrl,
        onEditingComplete: () => _saveField(prefKey, ctrl.text),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _navTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: Go2Colors.textSecondary),
      title: Text(title, style: const TextStyle(color: Go2Colors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Go2Colors.textHint),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: Go2Colors.canvas,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Go2Colors.surface),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Go2Spacing.lg),
        children: [
          // Business Info
          _sectionTitle('Business Info'),
          _card([
            const SizedBox(height: 8),
            _field('Business Name', _nameCtrl, 'business_name'),
            _field('Address', _addressCtrl, 'business_address'),
            _field('Phone', _phoneCtrl, 'business_phone'),
            const SizedBox(height: 8),
          ]),

          // Parking Rates
          _sectionTitle('Parking Rates'),
          _card([
            _navTile('Manage Vehicle Rates', Icons.two_wheeler, () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const VehicleRatesManagementScreen(),
              ));
            }),
          ]),

          // Receipt Settings
          _sectionTitle('Receipt Settings'),
          _card([
            SwitchListTile(
              dense: true,
              activeColor: Go2Colors.primary,
              title: const Text('3-inch Paper', style: TextStyle(color: Go2Colors.textPrimary)),
              subtitle: Text(_is3Inch ? '3-inch' : '2-inch', style: const TextStyle(color: Go2Colors.textSecondary)),
              value: _is3Inch,
              onChanged: (v) {
                setState(() => _is3Inch = v);
                _saveBool('paper_3inch', v);
              },
            ),
            SwitchListTile(
              dense: true,
              activeColor: Go2Colors.primary,
              title: const Text('Auto Print', style: TextStyle(color: Go2Colors.textPrimary)),
              value: _autoPrint,
              onChanged: (v) {
                setState(() => _autoPrint = v);
                _saveBool('auto_print', v);
              },
            ),
            _navTile('Customize Receipt', Icons.receipt_long, () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ReceiptCustomizationScreen(),
              ));
            }),
          ]),

          // Printer
          _sectionTitle('Printer'),
          _card([
            _navTile('Printer Settings', Icons.print, () {
              Navigator.pushNamed(context, '/printer');
            }),
          ]),

          // Account
          _sectionTitle('Account'),
          _card([
            ListTile(
              dense: true,
              leading: const Icon(Icons.person, size: 20, color: Go2Colors.textSecondary),
              title: Text(auth.userName.isNotEmpty ? auth.userName : 'User', style: const TextStyle(color: Go2Colors.textPrimary)),
              subtitle: Text(auth.userRole, style: const TextStyle(color: Go2Colors.textSecondary)),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, size: 20, color: Go2Colors.error),
              title: const Text('Logout', style: TextStyle(color: Go2Colors.error)),
              onTap: () {
                auth.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
            ),
          ]),
          const SizedBox(height: 80), // Extra space so logout isn't hidden behind system nav
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
}
