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
                  child: const Text('Save Settings'),
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
      
      if (mounted) {
        Helpers.showSnackBar(context, 'Advanced settings saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to save settings: $e', isError: true);
      }
    }
  }
}