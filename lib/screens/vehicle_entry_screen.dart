import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  String _selectedType = 'Car';
  bool _isSubmitting = false;
  SimpleVehicle? _lastVehicle;
  String? _lastReceipt;

  static const _types = [
    ('Bike', Icons.two_wheeler),
    ('Scooter', Icons.two_wheeler),
    ('Car', Icons.directions_car),
    ('SUV', Icons.directions_car_filled),
    ('Van', Icons.airport_shuttle),
    ('Bus', Icons.directions_bus),
    ('Truck', Icons.local_shipping),
    ('Auto Rickshaw', Icons.electric_rickshaw),
    ('E-Rickshaw', Icons.electric_rickshaw),
    ('Cycle', Icons.pedal_bike),
    ('E-Cycle', Icons.pedal_bike),
    ('Tempo', Icons.fire_truck),
    ('Mini Truck', Icons.fire_truck),
  ];

  @override
  void dispose() { _plateController.dispose(); super.dispose(); }

  Future<void> _scanPlate() async {
    // Request camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission required'), backgroundColor: Go2Colors.error));
          if (status.isPermanentlyDenied) openAppSettings();
        }
        return;
      }
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1920);
    if (image == null) return;

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading plate number...'), duration: Duration(seconds: 1)));

    // OCR with Google ML Kit
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    try {
      final recognized = await textRecognizer.processImage(inputImage);
      final plateRegex = RegExp(r'[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,3}\s*\d{1,4}');
      String? plate;
      for (final block in recognized.blocks) {
        final match = plateRegex.firstMatch(block.text.toUpperCase().replaceAll('\n', ' '));
        if (match != null) {
          plate = match.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
          break;
        }
      }
      if (plate != null && mounted) {
        _plateController.text = plate;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detected: $plate'), backgroundColor: Go2Colors.success));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not detect plate. Please type manually.'), backgroundColor: Go2Colors.warning));
      }
    } finally {
      textRecognizer.close();
    }
  }

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

        // Generate receipt
        final receipt = await ReceiptService.generateEntryReceipt(vehicle);
        _lastVehicle = vehicle;
        _lastReceipt = receipt;

        // Auto-print
        final prefs = await SharedPreferences.getInstance();
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Go2Colors.success));
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
            IconButton(
              icon: const Icon(Icons.print_rounded, size: 20),
              tooltip: 'Reprint last receipt',
              onPressed: _reprint,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Vehicle type grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1.05,
            ),
            itemCount: _types.length,
            itemBuilder: (_, i) {
              final (type, icon) = _types[i];
              final sel = _selectedType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: Container(
                  decoration: BoxDecoration(
                    color: sel ? Go2Colors.primary : Go2Colors.surface,
                    borderRadius: BorderRadius.circular(Go2Radius.md),
                    border: Border.all(color: sel ? Go2Colors.primary : Go2Colors.divider, width: sel ? 1.5 : 0.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: sel ? Colors.white : Go2Colors.textSecondary, size: 20),
                    const SizedBox(height: 2),
                    Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: sel ? Colors.white : Go2Colors.textHint), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Rate display
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Go2Colors.skyWash, borderRadius: BorderRadius.circular(Go2Radius.full)),
            child: Text('₹${(rates['hourly'] as num).toStringAsFixed(0)}/hr  •  Min ₹${(rates['minimum'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Go2Colors.primary)),
          )),
          const SizedBox(height: 20),

          // Plate input
          TextFormField(
            controller: _plateController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: 'MH 12 AB 1234',
              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.camera_alt_rounded, size: 22, color: Go2Colors.primary),
                tooltip: 'Scan plate with camera',
                onPressed: _scanPlate,
              ),
            ),
            inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(14)],
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),

          // Park button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting || _plateController.text.trim().isEmpty ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Park Vehicle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),

          // Last entry info
          if (_lastVehicle != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Go2Colors.skyWash, borderRadius: BorderRadius.circular(Go2Radius.md)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Go2Colors.success, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Last: ${_lastVehicle!.vehicleNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
                  Text('${_lastVehicle!.vehicleType} • ${_lastVehicle!.ticketId ?? ''}', style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
                ])),
                TextButton.icon(
                  onPressed: _reprint,
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('Reprint', style: TextStyle(fontSize: 12)),
                ),
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
