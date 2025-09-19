import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class VehicleExitScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const VehicleExitScreen({super.key, this.vehicle});

  @override
  State<VehicleExitScreen> createState() => _VehicleExitScreenState();
}

class _VehicleExitScreenState extends State<VehicleExitScreen> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController();
  final _reasonController = TextEditingController();

  Vehicle? _selectedVehicle;
  double _discountAmount = 0.0;
  bool _isLoading = false;
  bool _showManualSearch = false;
  bool _isPrintingReceipt = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _selectedVehicle = widget.vehicle;
    } else {
      _showManualSearch = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Exit'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedVehicle != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _selectedVehicle = null;
                  _showManualSearch = true;
                  _searchController.clear();
                });
              },
            ),
        ],
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
                  bottom: MediaQuery.of(context).padding.bottom + 120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showManualSearch && _selectedVehicle == null) ...[
                      _buildVehicleSearch(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildActiveVehiclesList(),
                    ] else if (_selectedVehicle != null) ...[
                      _buildVehicleDetails(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildAmountCalculation(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildDiscountSection(),
                    ],
                  ],
                ),
              ),
            ),
            if (_selectedVehicle != null) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Vehicle',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter vehicle number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanVehicleNumber,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _searchVehicle,
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _searchVehicle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehiclesList() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final activeVehicles = vehicleProvider.activeVehicles;

        if (activeVehicles.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.local_parking,
                    size: 48,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No vehicles currently parked',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Active Vehicles',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeVehicles.take(10).length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = activeVehicles[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        vehicle.vehicleType.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      vehicle.vehicleNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${vehicle.vehicleType.name} • ${Helpers.formatDuration(vehicle.parkingDuration)}',
                    ),
                    trailing: Text(
                      Helpers.formatCurrency(vehicle.calculateAmount()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVehicle = vehicle;
                        _showManualSearch = false;
                      });
                    },
                  );
                },
              ),
              if (activeVehicles.length > 10)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    '... and ${activeVehicles.length - 10} more vehicles',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _selectedVehicle!.vehicleType.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedVehicle!.vehicleNumber,
                        style: const TextStyle(
                          fontSize: AppFontSize.xl,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedVehicle!.vehicleType.name,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildDetailRow('Ticket ID', _selectedVehicle!.ticketId),
            _buildDetailRow('Entry Time', Helpers.formatDateTime(_selectedVehicle!.entryTime)),
            _buildDetailRow('Parking Duration', Helpers.formatDuration(_selectedVehicle!.parkingDuration)),
            if (_selectedVehicle!.ownerName != null)
              _buildDetailRow('Owner', _selectedVehicle!.ownerName!),
            if (_selectedVehicle!.ownerPhone != null)
              _buildDetailRow('Phone', _selectedVehicle!.ownerPhone!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSize.sm,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCalculation() {
    final totalAmount = _selectedVehicle!.calculateAmount();
    final finalAmount = totalAmount - _discountAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount Calculation',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hourly Rate:'),
                Text(Helpers.formatCurrency(_selectedVehicle!.vehicleType.hourlyRate)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Duration:'),
                Text(Helpers.formatDuration(_selectedVehicle!.parkingDuration)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  Helpers.formatCurrency(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (_discountAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Discount:',
                    style: TextStyle(color: AppColors.error),
                  ),
                  Text(
                    '- ${Helpers.formatCurrency(_discountAmount)}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Helpers.formatCurrency(finalAmount),
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apply Discount (Optional)',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    decoration: const InputDecoration(
                      labelText: 'Discount Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _discountAmount = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    final totalAmount = _selectedVehicle!.calculateAmount();
                    _discountController.text = totalAmount.toString();
                    setState(() {
                      _discountAmount = totalAmount;
                    });
                  },
                  child: const Text('Free'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Discount Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final finalAmount = _selectedVehicle!.calculateAmount() - _discountAmount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount to Collect:',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                Helpers.formatCurrency(finalAmount),
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedVehicle = null;
                      _showManualSearch = true;
                      _searchController.clear();
                      _discountController.clear();
                      _reasonController.clear();
                      _discountAmount = 0.0;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkoutVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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
                          : const Text('Checkout & Print'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scanVehicleNumber() {
    // TODO: Implement QR/Barcode scanner
    Helpers.showSnackBar(context, 'QR Scanner not implemented yet');
  }

  void _searchVehicle() {
    final vehicleNumber = _searchController.text.trim().toUpperCase();
    if (vehicleNumber.isEmpty) return;

    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.getVehicleByNumber(vehicleNumber);

    if (vehicle != null) {
      setState(() {
        _selectedVehicle = vehicle;
        _showManualSearch = false;
      });
    } else {
      Helpers.showSnackBar(
        context,
        'Vehicle $vehicleNumber not found or not currently parked',
        isError: true,
      );
    }
  }

  Future<void> _checkoutVehicle() async {
    if (_selectedVehicle == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      final bluetoothProvider = context.read<BluetoothProvider>();

      final finalAmount = _selectedVehicle!.calculateAmount() - _discountAmount;

      // Update vehicle with exit details
      await vehicleProvider.exitVehicle(_selectedVehicle!.id, finalAmount);

      // Auto-print receipt - MANDATORY for exit
      bool printSuccess = false;
      setState(() {
        _isPrintingReceipt = true;
      });

      try {
        // Always attempt to print receipt for exit
        final printerReady = await bluetoothProvider.ensurePrinterReady();

        if (printerReady) {
          printSuccess = await _printReceipt(_selectedVehicle!, finalAmount);
          if (printSuccess && mounted) {
            Helpers.showSnackBar(context, '✓ Exit receipt printed successfully');
          }
        } else {
          if (mounted) {
            // Show manual print option if auto-print fails
            final shouldPrintManually = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Print Exit Receipt'),
                content: Text(
                  'Amount to collect: ${Helpers.formatCurrency(finalAmount)}\n\n' +
                  'Printer not connected. Would you like to:\n' +
                  '1. Try connecting again\n' +
                  '2. Continue without receipt',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Continue Without Receipt'),
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
                printSuccess = await _printReceipt(_selectedVehicle!, finalAmount);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Print error: $e');
        if (mounted) {
          Helpers.showSnackBar(context, 'Failed to print receipt: $e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isPrintingReceipt = false;
          });
        }
      }

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Vehicle ${_selectedVehicle!.vehicleNumber} checked out' +
              (printSuccess ? ' with receipt' : ' (no receipt printed)'),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to checkout vehicle: $e', isError: true);
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

  Future<bool> _printReceipt(Vehicle vehicle, double finalAmount) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final receiptData = {
      'vehicleNumber': vehicle.vehicleNumber,
      'vehicleType': vehicle.vehicleType.name,
      'entryTime': Helpers.formatDateTime(vehicle.entryTime),
      'exitTime': Helpers.formatDateTime(DateTime.now()),
      'duration': Helpers.formatDuration(vehicle.parkingDuration),
      'amount': finalAmount.toStringAsFixed(2),
    };

    // Use proper receipt printing method
    final success = await bluetoothProvider.printReceipt(receiptData);
    return success;
  }

}