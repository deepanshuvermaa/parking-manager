import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../services/simple_vehicle_service.dart';
import '../services/platform_printer_service.dart';
import '../services/receipt_service.dart';
import '../models/simple_vehicle.dart';
import '../theme/app_theme.dart';

class VehicleEntryScreen extends StatefulWidget {
  const VehicleEntryScreen({super.key});

  @override
  State<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends State<VehicleEntryScreen> {
  final _plateController = TextEditingController();
  final _hasText = ValueNotifier<bool>(false);
  String _selectedType = 'Car';
  bool _isSubmitting = false;
  SimpleVehicle? _lastVehicle;
  String? _lastReceipt;
  SharedPreferences? _prefs;

  // Only 6 primary types - user can add more via Settings > Rates
  static const _types = [
    ('Car', Icons.directions_car_rounded),
    ('Bike', Icons.two_wheeler_rounded),
    ('Truck', Icons.local_shipping_rounded),
    ('Auto', Icons.electric_rickshaw_rounded),
    ('Cycle', Icons.pedal_bike_rounded),
    ('Scooter', Icons.two_wheeler_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _plateController.addListener(() {
      _hasText.value = _plateController.text.trim().isNotEmpty;
    });
    SharedPreferences.getInstance().then((p) => _prefs = p);
  }

  @override
  void dispose() { _plateController.dispose(); _hasText.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final token = context.read<AuthProvider>().token ?? '';
      final vehicle = await SimpleVehicleService.addVehicle(
        token: token, vehicleNumber: plate, vehicleType: _selectedType,
      );

      if (vehicle != null && mounted) {
        context.read<ParkingProvider>().recordEntry();
        HapticFeedback.mediumImpact();

        final receipt = await ReceiptService.generateEntryReceipt(vehicle);
        _lastVehicle = vehicle;
        _lastReceipt = receipt;

        final prefs = _prefs ?? await SharedPreferences.getInstance();
        final autoPrint = prefs.getBool('auto_print') ?? true;
        final connected = await PlatformPrinterService.isConnected();
        String msg;
        if (connected && autoPrint) {
          await PlatformPrinterService.printText(receipt);
          msg = '✓ $plate parked • Receipt printed';
        } else {
          msg = '✓ $plate parked';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 15)), backgroundColor: Go2Colors.success));
          _plateController.clear();
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Go2Colors.error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reprint() async {
    if (_lastReceipt == null) return;
    final connected = await PlatformPrinterService.isConnected();
    if (connected) {
      await PlatformPrinterService.printText(_lastReceipt!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt reprinted'), backgroundColor: Go2Colors.success));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer not connected'), backgroundColor: Go2Colors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rates = SimpleVehicleService.getDefaultRate(_selectedType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Entry'),
        actions: [
          if (_lastReceipt != null)
            IconButton(icon: const Icon(Icons.print_rounded), tooltip: 'Reprint', onPressed: _reprint),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 6 vehicle types - large tiles for dark parking lot
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: _types.map((t) {
              final (type, icon) = t;
              final sel = _selectedType == type;
              return GestureDetector(
                onTap: () { setState(() => _selectedType = type); HapticFeedback.lightImpact(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: sel ? Go2Colors.primary : Go2Colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? Go2Colors.primary : Go2Colors.divider, width: sel ? 2 : 0.5),
                    boxShadow: sel ? [BoxShadow(color: Go2Colors.primary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: sel ? Colors.white : Go2Colors.textPrimary, size: 28),
                    const SizedBox(height: 6),
                    Text(type, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : Go2Colors.textPrimary,
                    )),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Rate chip
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Go2Colors.skyWash, borderRadius: BorderRadius.circular(20)),
            child: Text('₹${(rates['hourly'] as num).toStringAsFixed(0)}/hr  •  Min ₹${(rates['minimum'] as num).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Go2Colors.primary)),
          )),
          const SizedBox(height: 20),

          // Plate input - LARGE for dark parking lot visibility
          TextFormField(
            controller: _plateController,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'MH 12 AB 1234',
              hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Go2Colors.textHint.withValues(alpha: 0.5), letterSpacing: 1),
              prefixIcon: const Icon(Icons.pin_outlined, size: 24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(14)],
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),

          // Park button - large, prominent
          SizedBox(
            height: 54,
            child: ValueListenableBuilder<bool>(
              valueListenable: _hasText,
              builder: (_, hasText, __) => ElevatedButton(
                onPressed: _isSubmitting || !hasText ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Go2Colors.success,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Park Vehicle'),
              ),
            ),
          ),

          // Last entry
          if (_lastVehicle != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Go2Colors.skyWash, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Go2Colors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Last: ${_lastVehicle!.vehicleNumber}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${_lastVehicle!.vehicleType} • ${_lastVehicle!.ticketId ?? ''}', style: const TextStyle(fontSize: 12, color: Go2Colors.textHint)),
                ])),
                TextButton(onPressed: _reprint, child: const Text('Reprint', style: TextStyle(fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
