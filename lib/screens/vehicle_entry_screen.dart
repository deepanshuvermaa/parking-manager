import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/vehicle.dart';
import '../models/vehicle_type.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class VehicleEntryScreen extends StatefulWidget {
  const VehicleEntryScreen({super.key});

  @override
  State<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends State<VehicleEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  VehicleType? _selectedVehicleType;
  bool _isLoading = false;
  bool _isPrintingReceipt = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Entry'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildVehicleTypeSelector(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildVehicleNumberField(),
                      const SizedBox(height: AppSpacing.md),
                      _buildOwnerNameField(),
                      const SizedBox(height: AppSpacing.md),
                      _buildOwnerPhoneField(),
                      const SizedBox(height: AppSpacing.md),
                      _buildNotesField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildRateInfo(),
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

  Widget _buildVehicleTypeSelector() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Vehicle Type',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 300,
                  child: GridView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: vehicleProvider.vehicleTypes.length,
                    itemBuilder: (context, index) {
                      final type = vehicleProvider.vehicleTypes[index];
                      final isSelected = _selectedVehicleType?.id == type.id;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedVehicleType = type;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                type.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  type.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleNumberField() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle Details',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Number',
                    hintText: '${settingsProvider.settings.statePrefix}01AB1234',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanVehicleNumber,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle number';
                    }
                    if (value.length < 6) {
                      return 'Please enter a valid vehicle number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOwnerNameField() {
    return TextFormField(
      controller: _ownerNameController,
      decoration: const InputDecoration(
        labelText: 'Owner Name (Optional)',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildOwnerPhoneField() {
    return TextFormField(
      controller: _ownerPhoneController,
      decoration: const InputDecoration(
        labelText: 'Phone Number (Optional)',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value != null && value.isNotEmpty && value.length != 10) {
          return 'Please enter a valid 10-digit phone number';
        }
        return null;
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes (Optional)',
        prefixIcon: Icon(Icons.note),
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildRateInfo() {
    if (_selectedVehicleType == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parking Rate',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hourly Rate:',
                  style: const TextStyle(fontSize: AppFontSize.md),
                ),
                Text(
                  Helpers.formatCurrency(_selectedVehicleType!.hourlyRate),
                  style: const TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (_selectedVehicleType!.flatRate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flat Rate:',
                    style: const TextStyle(fontSize: AppFontSize.md),
                  ),
                  Text(
                    Helpers.formatCurrency(_selectedVehicleType!.flatRate!),
                    style: const TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
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
              onPressed: _clearForm,
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addVehicle,
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
                  : _isPrintingReceipt
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Printing Receipt...'),
                          ],
                        )
                      : const Text('Add Vehicle & Print'),
            ),
          ),
        ],
      ),
    );
  }

  void _scanVehicleNumber() {
    // TODO: Implement QR/Barcode scanner
    Helpers.showSnackBar(context, 'QR Scanner not implemented yet');
  }

  void _clearForm() {
    _vehicleNumberController.clear();
    _ownerNameController.clear();
    _ownerPhoneController.clear();
    _notesController.clear();
    setState(() {
      _selectedVehicleType = null;
    });
  }

  Future<void> _addVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleType == null) {
      Helpers.showSnackBar(context, 'Please select a vehicle type', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      // Check if vehicle already exists
      final existingVehicle = vehicleProvider.getVehicleByNumber(_vehicleNumberController.text.trim());
      if (existingVehicle != null) {
        Helpers.showSnackBar(context, 'Vehicle ${existingVehicle.vehicleNumber} is already parked', isError: true);
        return;
      }

      // Generate ticket ID
      final ticketId = '${settingsProvider.settings.ticketIdPrefix}${settingsProvider.settings.nextTicketNumber.toString().padLeft(4, '0')}';

      final vehicle = Vehicle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
        vehicleType: _selectedVehicleType!,
        entryTime: DateTime.now(),
        ownerName: _ownerNameController.text.trim().isEmpty ? null : _ownerNameController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim().isEmpty ? null : _ownerPhoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ticketId: ticketId,
      );

      await vehicleProvider.addVehicle(vehicle);

      // Auto-print receipt - MANDATORY
      bool printSuccess = false;
      if (settingsProvider.settings.autoPrint) {
        setState(() {
          _isPrintingReceipt = true;
        });

        final bluetoothProvider = context.read<BluetoothProvider>();

        try {
          // Ensure printer is ready
          final printerReady = await bluetoothProvider.ensurePrinterReady();

          if (printerReady) {
            printSuccess = await _printTicket(vehicle);
            if (printSuccess && mounted) {
              Helpers.showSnackBar(context, '✓ Receipt printed successfully');
            }
          } else {
            if (mounted) {
              // Show manual print option if auto-print fails
              final shouldPrintManually = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Printer Not Connected'),
                  content: const Text('Unable to connect to printer. Would you like to:\n1. Try again\n2. Continue without printing'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Continue Without Printing'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );

              if (shouldPrintManually == true) {
                final connected = await _connectToPrinter();
                if (connected) {
                  printSuccess = await _printTicket(vehicle);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Print error: $e');
        } finally {
          if (mounted) {
            setState(() {
              _isPrintingReceipt = false;
            });
          }
        }
      }

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Vehicle ${vehicle.vehicleNumber} added successfully' +
              (printSuccess ? ' with receipt' : ''),
        );
        _clearForm();
        Navigator.pop(context);
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to add vehicle: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _connectToPrinter() async {
    final bluetoothProvider = context.read<BluetoothProvider>();

    try {
      setState(() {
        _isPrintingReceipt = true;
      });

      // Use the new ensurePrinterReady method
      final ready = await bluetoothProvider.ensurePrinterReady();

      if (!ready && mounted) {
        // Show error with retry option
        Helpers.showSnackBar(
          context,
          bluetoothProvider.lastError.isNotEmpty
              ? bluetoothProvider.lastError
              : 'Failed to connect to printer',
          isError: true,
        );
      }

      return ready;
    } catch (e) {
      debugPrint('Failed to connect to printer: $e');
      if (mounted) {
        Helpers.showSnackBar(context, 'Printer connection failed: $e', isError: true);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingReceipt = false;
        });
      }
    }
  }

  Future<bool> _printTicket(Vehicle vehicle) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final receiptData = {
      'vehicleNumber': vehicle.vehicleNumber,
      'vehicleType': vehicle.vehicleType.name,
      'entryTime': Helpers.formatDateTime(vehicle.entryTime),
      'exitTime': '',
      'duration': '',
      'amount': '0.00',
    };

    // Use proper receipt printing method
    final success = await bluetoothProvider.printReceipt(receiptData);
    return success;
  }

  Future<void> _printTicketOld(Vehicle vehicle) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final ticket = '''
${settingsProvider.settings.businessName}
${settingsProvider.settings.businessAddress}
Ph: ${settingsProvider.settings.businessPhone}

==============================
PARKING TICKET
==============================
Ticket ID: ${vehicle.ticketId}
Vehicle: ${vehicle.vehicleNumber}
Type: ${vehicle.vehicleType.name}
Entry Time: ${Helpers.formatDateTime(vehicle.entryTime)}
Rate: ${Helpers.formatCurrency(vehicle.vehicleType.hourlyRate)}/hr
==============================
Please keep this ticket safe
==============================
''';

    await bluetoothProvider.printText(ticket);
  }
}