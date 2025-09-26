import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final _ticketPrefixController = TextEditingController();
  final _footerTextController = TextEditingController();
  bool _showQRCode = false;
  bool _showLogo = false;
  bool _printDuplicate = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _ticketPrefixController.dispose();
    _footerTextController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final settings = context.read<SettingsProvider>().settings;
    _ticketPrefixController.text = settings.ticketIdPrefix;
    _footerTextController.text = 'Thank you for parking with us!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Receipt Settings'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildTicketSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildReceiptCustomization(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPreview(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ticket ID Settings',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _ticketPrefixController,
              decoration: const InputDecoration(
                labelText: 'Ticket ID Prefix',
                hintText: 'PKE, PARK, etc.',
                helperText: 'This will appear before the ticket number (e.g., PKE0001)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCustomization() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receipt Customization',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Show QR Code'),
              subtitle: const Text('Add QR code to receipts for quick verification'),
              value: _showQRCode,
              onChanged: (value) {
                setState(() {
                  _showQRCode = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Show Business Logo'),
              subtitle: const Text('Add your business logo to receipts'),
              value: _showLogo,
              onChanged: (value) {
                setState(() {
                  _showLogo = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Print Duplicate Copy'),
              subtitle: const Text('Automatically print a second copy'),
              value: _printDuplicate,
              onChanged: (value) {
                setState(() {
                  _printDuplicate = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _footerTextController,
              decoration: const InputDecoration(
                labelText: 'Footer Message',
                hintText: 'Thank you message or terms',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
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
                  'Receipt Preview',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _printSampleReceipt,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Sample'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: Colors.grey[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_showLogo) ...[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Consumer<SettingsProvider>(
                    builder: (context, settingsProvider, _) {
                      return Column(
                        children: [
                          Text(
                            settingsProvider.settings.businessName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppFontSize.md,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            settingsProvider.settings.businessAddress,
                            style: const TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Ph: ${settingsProvider.settings.businessPhone}',
                            style: const TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(),
                  const Text(
                    'PARKING RECEIPT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  const Divider(),
                  Text('Ticket ID: ${_ticketPrefixController.text}0001'),
                  const Text('Vehicle: UP01AB1234'),
                  const Text('Type: Four Wheeler'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Entry: ${"26/12/2023 10:30 AM"}'),
                  const Text('Exit: ${"26/12/2023 12:45 PM"}'),
                  const Text('Duration: 2h 15m'),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Amount Paid: ${context.read<SettingsProvider>().formatCurrency(45.00)}'),
                  if (_showQRCode) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                  const Divider(),
                  Text(
                    _footerTextController.text.isEmpty
                        ? 'Thank you for parking with us!'
                        : _footerTextController.text,
                    style: const TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _resetToDefaults,
              child: const Text('Reset'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _ticketPrefixController.text = 'PKE';
      _footerTextController.text = 'Thank you for parking with us!';
      _showQRCode = false;
      _showLogo = false;
      _printDuplicate = false;
    });
  }

  Future<void> _saveSettings() async {
    try {
      // Here you would typically save to a database or settings provider
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Helpers.showSnackBar(context, 'Receipt settings saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to save settings: $e', isError: true);
      }
    }
  }

  void _printSampleReceipt() {
    Helpers.showSnackBar(context, 'Sample receipt would be printed to connected printer');
  }
}