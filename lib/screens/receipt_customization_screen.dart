import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ReceiptCustomizationScreen extends StatefulWidget {
  const ReceiptCustomizationScreen({super.key});

  @override
  State<ReceiptCustomizationScreen> createState() => _ReceiptCustomizationScreenState();
}

class _ReceiptCustomizationScreenState extends State<ReceiptCustomizationScreen> {
  bool _isLoading = false;

  // Business Information
  bool _businessNameBold = true;
  double _businessNameSize = 1.0;
  bool _businessAddressBold = false;
  double _businessAddressSize = 1.0;
  bool _businessPhoneBold = false;
  double _businessPhoneSize = 1.0;

  // Ticket Information
  bool _ticketIdBold = true;
  double _ticketIdSize = 1.5;

  // Vehicle Information
  bool _vehicleNumberBold = true;
  double _vehicleNumberSize = 1.5;
  bool _vehicleTypeBold = true;
  double _vehicleTypeSize = 1.0;

  // Travel Details
  bool _travelHeaderBold = true;
  double _travelHeaderSize = 1.25;
  bool _travelFromBold = false;
  double _travelFromSize = 1.0;
  bool _travelToBold = false;
  double _travelToSize = 1.0;

  // Amount
  bool _amountBold = true;
  double _amountSize = 1.5;

  // Available sizes
  final List<double> _availableSizes = [1.0, 1.2, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Business Information
      _businessNameBold = prefs.getBool('receipt_business_name_bold') ?? true;
      _businessNameSize = prefs.getDouble('receipt_business_name_size') ?? 1.0;
      _businessAddressBold = prefs.getBool('receipt_business_address_bold') ?? false;
      _businessAddressSize = prefs.getDouble('receipt_business_address_size') ?? 1.0;
      _businessPhoneBold = prefs.getBool('receipt_business_phone_bold') ?? false;
      _businessPhoneSize = prefs.getDouble('receipt_business_phone_size') ?? 1.0;

      // Ticket Information
      _ticketIdBold = prefs.getBool('receipt_ticket_id_bold') ?? true;
      _ticketIdSize = prefs.getDouble('receipt_ticket_id_size') ?? 1.5;

      // Vehicle Information
      _vehicleNumberBold = prefs.getBool('receipt_vehicle_number_bold') ?? true;
      _vehicleNumberSize = prefs.getDouble('receipt_vehicle_number_size') ?? 1.5;
      _vehicleTypeBold = prefs.getBool('receipt_vehicle_type_bold') ?? true;
      _vehicleTypeSize = prefs.getDouble('receipt_vehicle_type_size') ?? 1.0;

      // Travel Details
      _travelHeaderBold = prefs.getBool('receipt_travel_header_bold') ?? true;
      _travelHeaderSize = prefs.getDouble('receipt_travel_header_size') ?? 1.25;
      _travelFromBold = prefs.getBool('receipt_travel_from_bold') ?? false;
      _travelFromSize = prefs.getDouble('receipt_travel_from_size') ?? 1.0;
      _travelToBold = prefs.getBool('receipt_travel_to_bold') ?? false;
      _travelToSize = prefs.getDouble('receipt_travel_to_size') ?? 1.0;

      // Amount
      _amountBold = prefs.getBool('receipt_amount_bold') ?? true;
      _amountSize = prefs.getDouble('receipt_amount_size') ?? 1.5;

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Business Information
      await prefs.setBool('receipt_business_name_bold', _businessNameBold);
      await prefs.setDouble('receipt_business_name_size', _businessNameSize);
      await prefs.setBool('receipt_business_address_bold', _businessAddressBold);
      await prefs.setDouble('receipt_business_address_size', _businessAddressSize);
      await prefs.setBool('receipt_business_phone_bold', _businessPhoneBold);
      await prefs.setDouble('receipt_business_phone_size', _businessPhoneSize);

      // Ticket Information
      await prefs.setBool('receipt_ticket_id_bold', _ticketIdBold);
      await prefs.setDouble('receipt_ticket_id_size', _ticketIdSize);

      // Vehicle Information
      await prefs.setBool('receipt_vehicle_number_bold', _vehicleNumberBold);
      await prefs.setDouble('receipt_vehicle_number_size', _vehicleNumberSize);
      await prefs.setBool('receipt_vehicle_type_bold', _vehicleTypeBold);
      await prefs.setDouble('receipt_vehicle_type_size', _vehicleTypeSize);

      // Travel Details
      await prefs.setBool('receipt_travel_header_bold', _travelHeaderBold);
      await prefs.setDouble('receipt_travel_header_size', _travelHeaderSize);
      await prefs.setBool('receipt_travel_from_bold', _travelFromBold);
      await prefs.setDouble('receipt_travel_from_size', _travelFromSize);
      await prefs.setBool('receipt_travel_to_bold', _travelToBold);
      await prefs.setDouble('receipt_travel_to_size', _travelToSize);

      // Amount
      await prefs.setBool('receipt_amount_bold', _amountBold);
      await prefs.setDouble('receipt_amount_size', _amountSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      // Business Information
      _businessNameBold = true;
      _businessNameSize = 1.0;
      _businessAddressBold = false;
      _businessAddressSize = 1.0;
      _businessPhoneBold = false;
      _businessPhoneSize = 1.0;

      // Ticket Information
      _ticketIdBold = true;
      _ticketIdSize = 1.5;

      // Vehicle Information
      _vehicleNumberBold = true;
      _vehicleNumberSize = 1.5;
      _vehicleTypeBold = true;
      _vehicleTypeSize = 1.0;

      // Travel Details
      _travelHeaderBold = true;
      _travelHeaderSize = 1.25;
      _travelFromBold = false;
      _travelFromSize = 1.0;
      _travelToBold = false;
      _travelToSize = 1.0;

      // Amount
      _amountBold = true;
      _amountSize = 1.5;
    });

    await _saveSettings();
  }

  Widget _buildFieldCustomizer({
    required String label,
    required bool bold,
    required double size,
    required Function(bool) onBoldChanged,
    required Function(double?) onSizeChanged,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Bold Toggle
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Icon(Icons.format_bold, size: 20),
                      const SizedBox(width: 8),
                      const Text('Bold'),
                      const Spacer(),
                      Switch(
                        value: bold,
                        onChanged: onBoldChanged,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Size Dropdown
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Icon(Icons.format_size, size: 20),
                      const SizedBox(width: 8),
                      const Text('Size:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: size,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableSizes.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text('${s}x'),
                            );
                          }).toList(),
                          onChanged: onSizeChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Receipt Customization'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _resetToDefaults,
            tooltip: 'Reset to Defaults',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Customize how each field appears on your receipt. Choose size and bold formatting for each element.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Business Information Section
                  _buildSection(
                    'Business Information',
                    [
                      _buildFieldCustomizer(
                        label: 'Business Name',
                        bold: _businessNameBold,
                        size: _businessNameSize,
                        onBoldChanged: (value) => setState(() => _businessNameBold = value),
                        onSizeChanged: (value) => setState(() => _businessNameSize = value ?? 1.0),
                      ),
                      _buildFieldCustomizer(
                        label: 'Business Address',
                        bold: _businessAddressBold,
                        size: _businessAddressSize,
                        onBoldChanged: (value) => setState(() => _businessAddressBold = value),
                        onSizeChanged: (value) => setState(() => _businessAddressSize = value ?? 1.0),
                      ),
                      _buildFieldCustomizer(
                        label: 'Business Phone',
                        bold: _businessPhoneBold,
                        size: _businessPhoneSize,
                        onBoldChanged: (value) => setState(() => _businessPhoneBold = value),
                        onSizeChanged: (value) => setState(() => _businessPhoneSize = value ?? 1.0),
                      ),
                    ],
                  ),

                  // Ticket Information Section
                  _buildSection(
                    'Ticket Information',
                    [
                      _buildFieldCustomizer(
                        label: 'Ticket ID',
                        bold: _ticketIdBold,
                        size: _ticketIdSize,
                        onBoldChanged: (value) => setState(() => _ticketIdBold = value),
                        onSizeChanged: (value) => setState(() => _ticketIdSize = value ?? 1.5),
                      ),
                    ],
                  ),

                  // Vehicle Information Section
                  _buildSection(
                    'Vehicle Information',
                    [
                      _buildFieldCustomizer(
                        label: 'Vehicle Number',
                        bold: _vehicleNumberBold,
                        size: _vehicleNumberSize,
                        onBoldChanged: (value) => setState(() => _vehicleNumberBold = value),
                        onSizeChanged: (value) => setState(() => _vehicleNumberSize = value ?? 1.5),
                      ),
                      _buildFieldCustomizer(
                        label: 'Vehicle Type',
                        bold: _vehicleTypeBold,
                        size: _vehicleTypeSize,
                        onBoldChanged: (value) => setState(() => _vehicleTypeBold = value),
                        onSizeChanged: (value) => setState(() => _vehicleTypeSize = value ?? 1.0),
                      ),
                    ],
                  ),

                  // Travel Details Section
                  _buildSection(
                    'Travel Details',
                    [
                      _buildFieldCustomizer(
                        label: 'Travel Details Header',
                        bold: _travelHeaderBold,
                        size: _travelHeaderSize,
                        onBoldChanged: (value) => setState(() => _travelHeaderBold = value),
                        onSizeChanged: (value) => setState(() => _travelHeaderSize = value ?? 1.25),
                      ),
                      _buildFieldCustomizer(
                        label: 'From Location',
                        bold: _travelFromBold,
                        size: _travelFromSize,
                        onBoldChanged: (value) => setState(() => _travelFromBold = value),
                        onSizeChanged: (value) => setState(() => _travelFromSize = value ?? 1.0),
                      ),
                      _buildFieldCustomizer(
                        label: 'To Location',
                        bold: _travelToBold,
                        size: _travelToSize,
                        onBoldChanged: (value) => setState(() => _travelToBold = value),
                        onSizeChanged: (value) => setState(() => _travelToSize = value ?? 1.0),
                      ),
                    ],
                  ),

                  // Amount Section
                  _buildSection(
                    'Payment Information',
                    [
                      _buildFieldCustomizer(
                        label: 'Total Amount',
                        bold: _amountBold,
                        size: _amountSize,
                        onBoldChanged: (value) => setState(() => _amountBold = value),
                        onSizeChanged: (value) => setState(() => _amountSize = value ?? 1.5),
                      ),
                    ],
                  ),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Receipt Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
