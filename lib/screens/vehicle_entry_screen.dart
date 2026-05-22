import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../services/simple_vehicle_service.dart';
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
    {'type': 'E-Rickshaw', 'icon': Icons.electric_rickshaw},
    {'type': 'Cycle', 'icon': Icons.pedal_bike},
    {'type': 'E-Cycle', 'icon': Icons.pedal_bike},
    {'type': 'Tempo', 'icon': Icons.fire_truck},
    {'type': 'Mini Truck', 'icon': Icons.fire_truck},
  ];

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final token = context.read<AuthProvider>().token ?? '';
      final vehicle = await SimpleVehicleService.addVehicle(
        token: token,
        vehicleNumber: plate,
        vehicleType: _selectedType,
      );

      if (vehicle != null && mounted) {
        context.read<ParkingProvider>().recordEntry();
        HapticFeedback.mediumImpact();

        final prefs = await SharedPreferences.getInstance();
        final autoPrint = prefs.getBool('auto_print') ?? true;
        final printerConnected = await PlatformPrinterService.isConnected();

        String message;
        if (printerConnected && autoPrint) {
          try {
            final receipt = await ReceiptService.generateEntryReceipt(vehicle);
            await PlatformPrinterService.printText(receipt);
          } catch (_) {}
          message = '✓ $plate parked • Receipt printed';
        } else {
          message = '✓ $plate parked • Printer not connected';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Go2Colors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          _plateController.clear();
          setState(() {});
        }
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

  @override
  Widget build(BuildContext context) {
    final rates = SimpleVehicleService.getDefaultRate(_selectedType);

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Entry')),
      body: Padding(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle type grid — 2 rows, 4 columns
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: Go2Spacing.sm,
                crossAxisSpacing: Go2Spacing.sm,
                childAspectRatio: 1.1,
              ),
              itemCount: _vehicleTypes.length,
              itemBuilder: (ctx, i) {
                final vt = _vehicleTypes[i];
                final isSelected = _selectedType == vt['type'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = vt['type'] as String),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Go2Colors.success : Go2Colors.surface,
                      borderRadius: BorderRadius.circular(Go2Radius.md),
                      border: Border.all(
                        color: isSelected ? Go2Colors.success : Go2Colors.divider,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          vt['icon'] as IconData,
                          color: isSelected ? Colors.white : Go2Colors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vt['type'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Go2Colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: Go2Spacing.md),

            // Rate chip
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Go2Colors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Go2Radius.full),
                ),
                child: Text(
                  '₹${rates['hourly']?.toStringAsFixed(0)}/hr • Min ₹${rates['minimum']?.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Go2Colors.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: Go2Spacing.xl),

            // Plate number input
            TextFormField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: 'MH 12 AB 1234',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Go2Colors.textHint,
                  letterSpacing: 1.5,
                ),
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              inputFormatters: [
                UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(14),
              ],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: Go2Spacing.xl),

            // Park Vehicle button
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting || _plateController.text.trim().isEmpty
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Go2Colors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Go2Radius.md),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Park Vehicle',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
