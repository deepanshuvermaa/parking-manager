import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _gstPercentageController = TextEditingController();

  bool _enableGST = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _gstNumberController.dispose();
    _gstPercentageController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final settings = context.read<SettingsProvider>().settings;
    _businessNameController.text = settings.businessName;
    _businessAddressController.text = settings.businessAddress;
    _businessPhoneController.text = settings.businessPhone;
    _gstNumberController.text = settings.gstNumber;
    _gstPercentageController.text = settings.gstPercentage.toString();
    _enableGST = settings.enableGST;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Business Settings'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl + 80,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBusinessInfoSection(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildGSTSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Information',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _businessAddressController,
              decoration: const InputDecoration(
                labelText: 'Business Address *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter business address';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _businessPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGSTSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GST Settings',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Enable GST'),
              subtitle: const Text('Include GST in receipts and calculations'),
              value: _enableGST,
              onChanged: (value) {
                setState(() {
                  _enableGST = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_enableGST) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _gstNumberController,
                decoration: const InputDecoration(
                  labelText: 'GST Number *',
                  prefixIcon: Icon(Icons.receipt),
                  border: OutlineInputBorder(),
                  hintText: '22AAAAA0000A1Z5',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: _enableGST
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter GST number';
                        }
                        if (value.length != 15) {
                          return 'GST number must be 15 characters';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _gstPercentageController,
                decoration: const InputDecoration(
                  labelText: 'GST Percentage *',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                validator: _enableGST
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter GST percentage';
                        }
                        final percentage = double.tryParse(value);
                        if (percentage == null || percentage < 0 || percentage > 100) {
                          return 'Please enter a valid percentage (0-100)';
                        }
                        return null;
                      }
                    : null,
              ),
            ],
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
              onPressed: _isLoading ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all business settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _businessNameController.text = 'ParkEase Parking';
                _businessAddressController.text = '123 Main Street, City';
                _businessPhoneController.text = '+91 9876543210';
                _gstNumberController.text = '';
                _gstPercentageController.text = '18.0';
                _enableGST = false;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      final currentSettings = settingsProvider.settings;

      final newSettings = currentSettings.copyWith(
        businessName: _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        businessPhone: _businessPhoneController.text.trim(),
        enableGST: _enableGST,
        gstNumber: _enableGST ? _gstNumberController.text.trim() : '',
        gstPercentage: _enableGST ? double.parse(_gstPercentageController.text) : 18.0,
      );

      await settingsProvider.updateSettings(newSettings);

      if (mounted) {
        Helpers.showSnackBar(context, 'Business settings saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to save settings: $e', isError: true);
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