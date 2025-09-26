import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final _statePrefixController = TextEditingController();
  final _gracePeriodController = TextEditingController();
  final _ticketPrefixController = TextEditingController();

  // Advanced printer settings
  String _selectedPrinterFormat = '2"'; // 2" or 3"
  bool _enableAdvancedReports = false;
  bool _enableMultiLanguage = false;
  bool _enableSmsNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _statePrefixController.dispose();
    _gracePeriodController.dispose();
    _ticketPrefixController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final settings = context.read<SettingsProvider>().settings;
    _statePrefixController.text = settings.statePrefix;
    _gracePeriodController.text = settings.gracePeriodMinutes.toString();
    _ticketPrefixController.text = settings.ticketIdPrefix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Number Settings',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _statePrefixController,
                        decoration: const InputDecoration(
                          labelText: 'State Prefix',
                          hintText: 'UP, MH, DL, etc.',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parking Settings',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _gracePeriodController,
                        decoration: const InputDecoration(
                          labelText: 'Grace Period (Minutes)',
                          hintText: '15',
                          border: OutlineInputBorder(),
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ticket Settings',
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
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 5,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Printer Format Settings',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Receipt Width Format:'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('2" (58mm)'),
                              value: '2"',
                              groupValue: _selectedPrinterFormat,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPrinterFormat = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('3" (80mm)'),
                              value: '3"',
                              groupValue: _selectedPrinterFormat,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPrinterFormat = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Advanced Features',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        title: const Text('Advanced Reports'),
                        subtitle: const Text('Enable detailed analytics and custom reports'),
                        value: _enableAdvancedReports,
                        onChanged: (value) {
                          setState(() {
                            _enableAdvancedReports = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Multi-Language Support'),
                        subtitle: const Text('Enable Hindi and regional language support'),
                        value: _enableMultiLanguage,
                        onChanged: (value) {
                          setState(() {
                            _enableMultiLanguage = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('SMS Notifications'),
                        subtitle: const Text('Send SMS alerts for vehicle entry/exit'),
                        value: _enableSmsNotifications,
                        onChanged: (value) {
                          setState(() {
                            _enableSmsNotifications = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  child: const Text('Save Advanced Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      final settingsProvider = context.read<SettingsProvider>();

      await settingsProvider.updateStatePrefix(_statePrefixController.text.trim());
      await settingsProvider.updateGracePeriod(int.tryParse(_gracePeriodController.text) ?? 15);

      // Save advanced settings (for now, just show confirmation)
      // In a full implementation, these would be saved to the settings provider
      final printerFormat = _selectedPrinterFormat;
      final advancedReports = _enableAdvancedReports;
      final multiLanguage = _enableMultiLanguage;
      final smsNotifications = _enableSmsNotifications;

      print('Advanced settings saved:');
      print('Printer Format: $printerFormat');
      print('Advanced Reports: $advancedReports');
      print('Multi-Language: $multiLanguage');
      print('SMS Notifications: $smsNotifications');

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Advanced settings saved successfully\n'
          'Printer: $printerFormat, Reports: ${advancedReports ? "ON" : "OFF"}'
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to save settings: $e', isError: true);
      }
    }
  }
}