import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../services/simple_vehicle_service.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/platform_printer_service.dart';
import '../services/receipt_service.dart';
import '../theme/app_theme.dart';

class VehicleEntryScreen extends StatefulWidget {
  const VehicleEntryScreen({super.key});

  @override
  State<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends State<VehicleEntryScreen> {
  final _plateController = TextEditingController();
  final _plateFocus = FocusNode();
  String _selectedType = 'Car';
  bool _isSubmitting = false;

  static const _vehicleTypes = [
    {'type': 'Bike', 'icon': Icons.two_wheeler},
    {'type': 'Scooter', 'icon': Icons.two_wheeler},
    {'type': 'Car', 'icon': Icons.directions_car},
    {'type': 'SUV', 'icon': Icons.directions_car_filled},
    {'type': 'Van', 'icon': Icons.airport_shuttle},
    {'type': 'Bus', 'icon': Icons.directions_bus},
    {'type': 'Truck', 'icon': Icons.local_shipping},
    {'type': 'Auto Rickshaw', 'icon': Icons.electric_rickshaw},
  ];

  @override
  void initState() {
    super.initState();
    // Auto-focus plate input for speed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _plateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _plateFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      _plateFocus.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = context.read<AuthProvider>().token ?? '';
      final vehicle = await SimpleVehicleService.addVehicle(
        token: token,
        vehicleNumber: plate,
        vehicleType: _selectedType,
      );

      if (vehicle != null && mounted) {
        // Record in parking provider
        context.read<ParkingProvider>().recordEntry();

        // Auto-print if enabled
        final prefs = await SharedPreferences.getInstance();
        final autoPrint = prefs.getBool('auto_print') ?? true;
        if (autoPrint && SimpleBluetoothService.isConnected) {
          try {
            final receipt = await ReceiptService.generateEntryReceipt(vehicle);
            await PlatformPrinterService.printText(receipt);
          } catch (_) {}
        }

        // Haptic feedback for success
        HapticFeedback.mediumImpact();

        // Show success and offer next action
        if (mounted) _showSuccess(vehicle.vehicleNumber, vehicle.ticketId ?? '');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Go2Colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String plate, String ticketId) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Go2Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Go2Colors.success, size: 56),
            const SizedBox(height: Go2Spacing.lg),
            Text('Vehicle Parked',
                style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: Go2Spacing.sm),
            Text(plate,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            if (ticketId.isNotEmpty)
              Text('Ticket: $ticketId',
                  style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: Go2Spacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Back to dashboard
                    },
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: Go2Spacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetForNext();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Go2Spacing.lg),
          ],
        ),
      ),
    );
  }

  void _resetForNext() {
    _plateController.clear();
    _plateFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parking = context.watch<ParkingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Entry'),
        actions: [
          if (parking.totalCapacity > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: parking.isFull
                        ? Go2Colors.error.withOpacity(0.2)
                        : Go2Colors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(Go2Radius.full),
                  ),
                  child: Text(
                    '${parking.totalAvailable} slots free',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: parking.isFull ? Go2Colors.error : Go2Colors.success,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle type selector — tap 1
            Text('Vehicle Type', style: theme.textTheme.titleMedium),
            const SizedBox(height: Go2Spacing.md),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _vehicleTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: Go2Spacing.sm),
                itemBuilder: (ctx, i) {
                  final vt = _vehicleTypes[i];
                  final isSelected = _selectedType == vt['type'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = vt['type'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Go2Colors.primary
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(Go2Radius.md),
                        border: Border.all(
                          color: isSelected
                              ? Go2Colors.primary
                              : Go2Colors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            vt['icon'] as IconData,
                            color: isSelected ? Colors.white : Go2Colors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (vt['type'] as String).length > 6
                                ? (vt['type'] as String).substring(0, 6)
                                : vt['type'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Go2Colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Go2Spacing.xl),

            // Plate number — tap 2
            Text('Number Plate', style: theme.textTheme.titleMedium),
            const SizedBox(height: Go2Spacing.md),
            TextFormField(
              controller: _plateController,
              focusNode: _plateFocus,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'MH 12 AB 1234',
                hintStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: Go2Colors.textHint,
                  letterSpacing: 1.5,
                ),
                prefixIcon: const Icon(Icons.pin_outlined),
                suffixIcon: _plateController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _plateController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              inputFormatters: [
                UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(14),
              ],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
            ),
            const Spacer(),

            // Submit — tap 3
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _plateController.text.trim().isEmpty
                    ? null
                    : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 24),
                label: Text(
                  _isSubmitting ? 'Saving...' : 'Park Vehicle',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Go2Colors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Go2Radius.md)),
                ),
              ),
            ),
            const SizedBox(height: Go2Spacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Formats text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
