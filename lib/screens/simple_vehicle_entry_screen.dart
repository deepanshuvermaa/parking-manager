import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_vehicle_service.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/receipt_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SimpleVehicleEntryScreen extends StatefulWidget {
  final String token;

  const SimpleVehicleEntryScreen({super.key, required this.token});

  @override
  State<SimpleVehicleEntryScreen> createState() => _SimpleVehicleEntryScreenState();
}

class _SimpleVehicleEntryScreenState extends State<SimpleVehicleEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedVehicleType = 'Car';
  bool _isLoading = false;

  // Get vehicle types
  final List<String> _vehicleTypes = SimpleVehicleService.getVehicleTypes();

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine owner info in notes if provided
      String? notes = _notesController.text.trim();
      if (_ownerNameController.text.isNotEmpty) {
        notes = 'Owner: ${_ownerNameController.text}';
        if (_ownerPhoneController.text.isNotEmpty) {
          notes += ', Phone: ${_ownerPhoneController.text}';
        }
        if (_notesController.text.isNotEmpty) {
          notes += '\n${_notesController.text}';
        }
      }

      print('Attempting to add vehicle...');
      print('Token available: ${widget.token.isNotEmpty}');
      print('Vehicle Number: ${_vehicleNumberController.text}');
      print('Vehicle Type: $_selectedVehicleType');

      final vehicle = await SimpleVehicleService.addVehicle(
        token: widget.token,
        vehicleNumber: _vehicleNumberController.text,
        vehicleType: _selectedVehicleType,
        notes: notes,
      );

      if (vehicle != null) {
        if (mounted) {
          // Check if auto-print is enabled
          final prefs = await SharedPreferences.getInstance();
          final autoPrint = prefs.getBool('auto_print') ?? true;

          // Auto-print BEFORE showing dialog if enabled and printer is connected
          if (autoPrint && SimpleBluetoothService.isConnected) {
            await _printReceipt(vehicle);
          }

          // Show success dialog with ticket details
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Vehicle Entry Successful'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Ticket ID', vehicle.ticketId ?? 'N/A'),
                  _buildDetailRow('Vehicle', vehicle.vehicleNumber),
                  _buildDetailRow('Type', vehicle.vehicleType),
                  _buildDetailRow('Entry Time', Helpers.formatDateTime(vehicle.entryTime)),
                  _buildDetailRow('Hourly Rate', '₹${vehicle.hourlyRate?.toStringAsFixed(2) ?? '0.00'}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Please give this ticket to the customer.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                if (SimpleBluetoothService.isConnected)
                  TextButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                    onPressed: () async {
                      await _printReceipt(vehicle);
                    },
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to dashboard
                  },
                  child: const Text('Done'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another'),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _resetForm();
                  },
                ),
              ],
            ),
          );
        }
      } else {
        print('Vehicle add failed - returned null');
        if (mounted) {
          // Show detailed error message
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Vehicle Entry Failed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to add vehicle. Possible reasons:'),
                  const SizedBox(height: 8),
                  Text('• Check your internet connection'),
                  Text('• Server might be unavailable'),
                  Text('• Your session might have expired'),
                  const SizedBox(height: 12),
                  Text(
                    'Vehicle: ${_vehicleNumberController.text}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Vehicle add exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

  void _resetForm() {
    _vehicleNumberController.clear();
    _ownerNameController.clear();
    _ownerPhoneController.clear();
    _notesController.clear();
    setState(() {
      _selectedVehicleType = 'Car';
    });
  }

  Future<void> _printReceipt(dynamic vehicle) async {
    try {
      // Generate receipt
      final receipt = await ReceiptService.generateEntryReceipt(vehicle);

      // Print receipt
      final success = await SimpleBluetoothService.printReceipt(receipt);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rates = SimpleVehicleService.getDefaultRate(_selectedVehicleType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Entry'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vehicle details card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Vehicle Number
                        TextFormField(
                          controller: _vehicleNumberController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Number *',
                            hintText: 'e.g., MH12AB1234',
                            prefixIcon: Icon(Icons.directions_car),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter vehicle number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Vehicle Type
                        DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Type *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: _vehicleTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedVehicleType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rate information card
                Card(
                  elevation: 2,
                  color: AppColors.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rate Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Hourly Rate:'),
                            Text(
                              '₹${rates['hourly'].toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Minimum Charge:'),
                            Text(
                              '₹${rates['minimum'].toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Free Minutes:'),
                            Text(
                              '${rates['freeMinutes']} min',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Owner details card (optional)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Owner Details (Optional)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Owner Name
                        TextFormField(
                          controller: _ownerNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Owner Phone
                        TextFormField(
                          controller: _ownerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                            hintText: 'Any special instructions...',
                            prefixIcon: Icon(Icons.note),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Processing...' : 'Add Vehicle Entry',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}