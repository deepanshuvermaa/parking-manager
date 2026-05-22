import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ReceiptCustomizationScreen extends StatefulWidget {
  const ReceiptCustomizationScreen({super.key});

  @override
  State<ReceiptCustomizationScreen> createState() => _ReceiptCustomizationScreenState();
}

class _ReceiptCustomizationScreenState extends State<ReceiptCustomizationScreen> {
  bool _showBusinessName = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showGST = false;
  bool _showRateInfo = true;
  bool _showQRCode = true;
  bool _showNotes = false;
  bool _showHeader = true;
  bool _showFooter = true;
  bool _is3Inch = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _showBusinessName = p.getBool('bill_show_business_name') ?? true;
      _showAddress = p.getBool('bill_show_business_address') ?? true;
      _showPhone = p.getBool('bill_show_phone') ?? true;
      _showGST = p.getBool('bill_show_gst') ?? false;
      _showRateInfo = p.getBool('bill_show_rate_info') ?? true;
      _showQRCode = p.getBool('bill_show_qr_code') ?? true;
      _showNotes = p.getBool('bill_show_notes') ?? false;
      _showHeader = p.getBool('bill_show_header') ?? true;
      _showFooter = p.getBool('bill_show_footer') ?? true;
      _is3Inch = p.getBool('bill_paper_3inch') ?? false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      color: Go2Colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Go2Radius.md),
        side: const BorderSide(color: Go2Colors.divider, width: 0.5),
      ),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary,
            )),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, String key, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, color: Go2Colors.textSecondary)),
      value: value,
      activeTrackColor: Go2Colors.primary.withValues(alpha: 0.5),
      activeThumbColor: Go2Colors.primary,
      dense: true,
      onChanged: (v) {
        onChanged(v);
        _save(key, v);
      },
    );
  }

  Widget _buildPreview() {
    final w = _is3Inch ? 42 : 32;
    final lines = <String>[];
    if (_showHeader) lines.add('--- PARKING RECEIPT ---'.padLeft((w + 22) ~/ 2).padRight(w));
    if (_showBusinessName) lines.add(_center('ParkEase Parking', w));
    if (_showAddress) lines.add(_center('123 Main Road', w));
    if (_showPhone) lines.add(_center('Ph: 9876543210', w));
    if (_showGST) lines.add(_center('GST: 22AAAAA0000A1Z5', w));
    lines.add('-' * w);
    lines.add('Vehicle: KA01AB1234');
    lines.add('Type:    Car');
    lines.add('In:      22/05/2026 10:00');
    if (_showRateInfo) lines.add('Rate:    Rs.30/hr');
    lines.add('-' * w);
    if (_showNotes) lines.add('Note: Park at own risk');
    if (_showQRCode) lines.add(_center('[QR CODE]', w));
    if (_showFooter) lines.add(_center('Thank you! Visit again', w));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Go2Colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(Go2Radius.md),
      ),
      child: Text(
        lines.join('\n'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Go2Colors.textPrimary),
      ),
    );
  }

  String _center(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final pad = (width - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Go2Colors.canvas,
      appBar: AppBar(title: const Text('Receipt Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildCard('Header Settings', [
            _toggle('Show Business Name', _showBusinessName, 'bill_show_business_name',
                (v) => setState(() => _showBusinessName = v)),
            _toggle('Show Address', _showAddress, 'bill_show_business_address',
                (v) => setState(() => _showAddress = v)),
            _toggle('Show Phone', _showPhone, 'bill_show_phone',
                (v) => setState(() => _showPhone = v)),
            _toggle('Show GST Number', _showGST, 'bill_show_gst',
                (v) => setState(() => _showGST = v)),
          ]),
          _buildCard('Receipt Content', [
            _toggle('Show Rate Info', _showRateInfo, 'bill_show_rate_info',
                (v) => setState(() => _showRateInfo = v)),
            _toggle('Show QR Code', _showQRCode, 'bill_show_qr_code',
                (v) => setState(() => _showQRCode = v)),
            _toggle('Show Notes', _showNotes, 'bill_show_notes',
                (v) => setState(() => _showNotes = v)),
            _toggle('Show Receipt Header', _showHeader, 'bill_show_header',
                (v) => setState(() => _showHeader = v)),
            _toggle('Show Receipt Footer', _showFooter, 'bill_show_footer',
                (v) => setState(() => _showFooter = v)),
          ]),
          _buildCard('Text Formatting', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('2-inch')),
                  ButtonSegment(value: true, label: Text('3-inch')),
                ],
                selected: {_is3Inch},
                onSelectionChanged: (v) {
                  setState(() => _is3Inch = v.first);
                  _save('bill_paper_3inch', v.first);
                },
              ),
            ),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Preview', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary,
            )),
          ),
          _buildPreview(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
