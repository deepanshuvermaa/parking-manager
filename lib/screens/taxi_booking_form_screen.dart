import 'package:flutter/material.dart';
import '../models/taxi_booking.dart';
import '../services/taxi_booking_service.dart';
import '../utils/constants.dart';

/// Taxi Booking Form Screen
/// Create or edit taxi booking with all 13 fields
class TaxiBookingFormScreen extends StatefulWidget {
  final String token;
  final TaxiBooking? booking; // Null for new booking

  const TaxiBookingFormScreen({
    super.key,
    required this.token,
    this.booking,
  });

  @override
  State<TaxiBookingFormScreen> createState() => _TaxiBookingFormScreenState();
}

class _TaxiBookingFormScreenState extends State<TaxiBookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers for all fields
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerMobileController;
  late final TextEditingController _vehicleNameController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _fromLocationController;
  late final TextEditingController _toLocationController;
  late final TextEditingController _fareController;
  late final TextEditingController _remarks1Controller;
  late final TextEditingController _remarks2Controller;
  late final TextEditingController _remarks3Controller;
  late final TextEditingController _driverNameController;
  late final TextEditingController _driverMobileController;

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;

    _customerNameController = TextEditingController(text: booking?.customerName ?? '');
    _customerMobileController = TextEditingController(text: booking?.customerMobile ?? '');
    _vehicleNameController = TextEditingController(text: booking?.vehicleName ?? '');
    _vehicleNumberController = TextEditingController(text: booking?.vehicleNumber ?? '');
    _fromLocationController = TextEditingController(text: booking?.fromLocation ?? '');
    _toLocationController = TextEditingController(text: booking?.toLocation ?? '');
    _fareController = TextEditingController(text: booking?.fareAmount.toString() ?? '');
    _remarks1Controller = TextEditingController(text: booking?.remarks1 ?? '');
    _remarks2Controller = TextEditingController(text: booking?.remarks2 ?? '');
    _remarks3Controller = TextEditingController(text: booking?.remarks3 ?? '');
    _driverNameController = TextEditingController(text: booking?.driverName ?? '');
    _driverMobileController = TextEditingController(text: booking?.driverMobile ?? '');
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _fareController.dispose();
    _remarks1Controller.dispose();
    _remarks2Controller.dispose();
    _remarks3Controller.dispose();
    _driverNameController.dispose();
    _driverMobileController.dispose();
    super.dispose();
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final bookingData = {
        'customerName': _customerNameController.text.trim(),
        'customerMobile': _customerMobileController.text.trim(),
        'vehicleName': _vehicleNameController.text.trim(),
        'vehicleNumber': _vehicleNumberController.text.trim().toUpperCase(),
        'fromLocation': _fromLocationController.text.trim(),
        'toLocation': _toLocationController.text.trim(),
        'fareAmount': double.parse(_fareController.text.trim()),
        'remarks1': _remarks1Controller.text.trim().isEmpty ? null : _remarks1Controller.text.trim(),
        'remarks2': _remarks2Controller.text.trim().isEmpty ? null : _remarks2Controller.text.trim(),
        'remarks3': _remarks3Controller.text.trim().isEmpty ? null : _remarks3Controller.text.trim(),
        'driverName': _driverNameController.text.trim(),
        'driverMobile': _driverMobileController.text.trim(),
      };

      if (widget.booking == null) {
        // Create new booking
        await TaxiBookingService.createBooking(widget.token, bookingData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Update existing booking
        await TaxiBookingService.updateBooking(
          widget.token,
          widget.booking!.id,
          bookingData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.booking != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Booking' : 'New Booking'),
        backgroundColor: const Color(0xFFFFA726),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Section
            _buildSectionHeader('Customer Details', Icons.person),
            _buildTextField(
              controller: _customerNameController,
              label: 'Customer Name *',
              icon: Icons.person_outline,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _customerMobileController,
              label: 'Customer Mobile *',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Trip Details Section
            _buildSectionHeader('Trip Details', Icons.route),
            _buildTextField(
              controller: _fromLocationController,
              label: 'From (Pickup Location) *',
              icon: Icons.trip_origin,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _toLocationController,
              label: 'To (Drop Location) *',
              icon: Icons.location_on,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _fareController,
              label: 'Fare Amount (₹) *',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v?.trim().isEmpty == true) return 'Required';
                if (double.tryParse(v!) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Vehicle Section
            _buildSectionHeader('Vehicle Details', Icons.directions_car),
            _buildTextField(
              controller: _vehicleNameController,
              label: 'Vehicle Name/Type *',
              icon: Icons.local_taxi,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _vehicleNumberController,
              label: 'Vehicle Number *',
              icon: Icons.confirmation_number,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Driver Section
            _buildSectionHeader('Driver Details', Icons.badge),
            _buildTextField(
              controller: _driverNameController,
              label: 'Driver Name *',
              icon: Icons.person_pin,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _driverMobileController,
              label: 'Driver Mobile *',
              icon: Icons.phone_android,
              keyboardType: TextInputType.phone,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Remarks Section
            _buildSectionHeader('Remarks (Optional)', Icons.notes),
            _buildTextField(
              controller: _remarks1Controller,
              label: 'Remark 1',
              icon: Icons.note,
              maxLines: 2,
            ),
            _buildTextField(
              controller: _remarks2Controller,
              label: 'Remark 2',
              icon: Icons.note,
              maxLines: 2,
            ),
            _buildTextField(
              controller: _remarks3Controller,
              label: 'Remark 3',
              icon: Icons.note,
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveBooking,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Update Booking' : 'Create Booking')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA726),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFA726)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFA726),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }
}
