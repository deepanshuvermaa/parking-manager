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
import '../services/simple_bluetooth_service.dart';
import '../services/platform_printer_service.dart';
import '../services/receipt_service.dart';
import '../services/upi_qr_service.dart';
import '../models/simple_vehicle.dart';
import '../theme/app_theme.dart';

class VehicleExitScreen extends StatefulWidget {
  const VehicleExitScreen({super.key});

  @override
  State<VehicleExitScreen> createState() => _VehicleExitScreenState();
}

class _VehicleExitScreenState extends State<VehicleExitScreen> {
  final _searchController = TextEditingController();
  List<SimpleVehicle> _allVehicles = [];
  List<SimpleVehicle> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token ?? '';
      final vehicles = await SimpleVehicleService.getVehicles(token);
      _allVehicles = vehicles.where((v) => v.status == 'parked').toList()
        ..sort((a, b) => b.entryTime.compareTo(a.entryTime));
      _filtered = _allVehicles;
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _allVehicles;
      } else {
        final q = query.toLowerCase();
        _filtered = _allVehicles.where((v) =>
            v.vehicleNumber.toLowerCase().contains(q) ||
            (v.ticketId?.toLowerCase().contains(q) ?? false) ||
            v.vehicleType.toLowerCase().contains(q)).toList();
      }
    });
  }

  void _showExitConfirmation(SimpleVehicle vehicle) {
    final duration = DateTime.now().difference(vehicle.entryTime);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    final amount = SimpleVehicleService.calculateFee(
      entryTime: vehicle.entryTime,
      vehicleType: vehicle.vehicleType,
      exitTime: DateTime.now(),
      hourlyRate: vehicle.hourlyRate,
      minimumRate: vehicle.minimumRate,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Go2Colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Go2Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vehicle info
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Go2Colors.skyWash,
                    borderRadius: BorderRadius.circular(Go2Radius.md),
                  ),
                  child: Icon(_vehicleIcon(vehicle.vehicleType), color: Go2Colors.primary, size: 24),
                ),
                const SizedBox(width: Go2Spacing.lg),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.vehicleNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
                    Text(vehicle.vehicleType, style: const TextStyle(fontSize: 13, color: Go2Colors.textHint)),
                  ],
                )),
              ],
            ),
            const SizedBox(height: Go2Spacing.xl),

            // Duration & Amount
            Container(
              padding: const EdgeInsets.all(Go2Spacing.lg),
              decoration: BoxDecoration(
                color: Go2Colors.skyWash,
                borderRadius: BorderRadius.circular(Go2Radius.md),
              ),
              child: Row(
                children: [
                  Expanded(child: Column(children: [
                    const Icon(Icons.timer_outlined, color: Go2Colors.textSecondary, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary),
                    ),
                    const Text('Duration', style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
                  ])),
                  Container(width: 0.5, height: 40, color: Go2Colors.divider),
                  Expanded(child: Column(children: [
                    const Icon(Icons.currency_rupee_rounded, color: Go2Colors.primary, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Go2Colors.primary),
                    ),
                    const Text('Amount', style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
                  ])),
                ],
              ),
            ),
            const SizedBox(height: Go2Spacing.xl),

            // UPI QR Code (if configured)
            FutureBuilder<Map<String, String?>>(
              future: UpiQrService.getConfig(),
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data!['vpa'] != null &&
                    snapshot.data!['vpa']!.isNotEmpty) {
                  return Column(children: [
                    UpiQrService.buildPaymentQR(
                      vpa: snapshot.data!['vpa']!,
                      merchantName: snapshot.data!['name'] ?? 'Go2-Parking',
                      amount: amount,
                      vehicleNumber: vehicle.vehicleNumber,
                      size: 120,
                    ),
                    const SizedBox(height: Go2Spacing.lg),
                  ]);
                }
                return const SizedBox.shrink();
              },
            ),

            // Exit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _processExit(ctx, vehicle, amount),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Confirm Exit'),
              ),
            ),
            const SizedBox(height: Go2Spacing.sm),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            const SizedBox(height: Go2Spacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _processExit(
      BuildContext ctx, SimpleVehicle vehicle, double amount) async {
    Navigator.pop(ctx); // Close bottom sheet

    try {
      final token = context.read<AuthProvider>().token ?? '';
      await SimpleVehicleService.exitVehicle(
        token: token,
        vehicleId: vehicle.id,
        amount: amount,
      );

      if (mounted) {
        context.read<ParkingProvider>().recordExit(amount);
        HapticFeedback.mediumImpact();

        // Auto-print exit receipt
        final prefs = await SharedPreferences.getInstance();
        final autoPrint = prefs.getBool('auto_print_exit') ?? true;
        if (autoPrint && SimpleBluetoothService.isConnected) {
          try {
            vehicle.exitTime = DateTime.now();
            vehicle.amount = amount;
            final duration = vehicle.exitTime!.difference(vehicle.entryTime);
            final receipt = await ReceiptService.generateExitReceipt(vehicle, amount, duration);
            await PlatformPrinterService.printText(receipt);
          } catch (_) {}
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${vehicle.vehicleNumber} exited • ₹${amount.toStringAsFixed(0)}'),
            backgroundColor: Go2Colors.success,
          ),
        );
        _loadVehicles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Go2Colors.error),
        );
      }
    }
  }

  IconData _vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
      case 'scooter':
        return Icons.two_wheeler;
      case 'bus':
        return Icons.directions_bus;
      case 'truck':
        return Icons.local_shipping;
      case 'auto rickshaw':
        return Icons.electric_rickshaw;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Exit'),
        actions: [
          // QR scan button
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan QR',
            onPressed: _scanQR,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(Go2Spacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search plate number or ticket ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Go2Spacing.lg),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} vehicle${_filtered.length != 1 ? 's' : ''} parked',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Go2Spacing.sm),

          // Vehicle list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_parking_rounded, size: 56, color: Go2Colors.textHint.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No matching vehicles'
                                  : 'No vehicles parked',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Go2Colors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Vehicles will appear here after entry',
                              style: const TextStyle(fontSize: 12, color: Go2Colors.textHint),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Go2Spacing.lg),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Go2Spacing.sm),
                        itemBuilder: (ctx, i) {
                          final v = _filtered[i];
                          final duration =
                              DateTime.now().difference(v.entryTime);
                          final hours = duration.inHours;
                          final mins = duration.inMinutes.remainder(60);

                          return Card(
                            child: ListTile(
                              onTap: () => _showExitConfirmation(v),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Go2Colors.skyWash,
                                child: Icon(_vehicleIcon(v.vehicleType),
                                    color: Go2Colors.primary, size: 20),
                              ),
                              title: Text(v.vehicleNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(v.vehicleType),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    hours > 0
                                        ? '${hours}h ${mins}m'
                                        : '${mins}m',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: hours >= 4
                                          ? Go2Colors.warning
                                          : Go2Colors.textSecondary,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Go2Colors.textHint),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQR() async {
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
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    // Use ML Kit to read ticket ID from QR/text
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    try {
      final result = await textRecognizer.processImage(inputImage);
      // Look for ticket ID pattern (PT + digits) or plate number
      final ticketRegex = RegExp(r'PT\d{7,}');
      final plateRegex = RegExp(r'[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,3}\s*\d{1,4}');
      String? searchTerm;
      for (final block in result.blocks) {
        final text = block.text.toUpperCase();
        final ticketMatch = ticketRegex.firstMatch(text);
        if (ticketMatch != null) { searchTerm = ticketMatch.group(0); break; }
        final plateMatch = plateRegex.firstMatch(text);
        if (plateMatch != null) { searchTerm = plateMatch.group(0); break; }
      }
      if (searchTerm != null && mounted) {
        _searchController.text = searchTerm;
        _filter(searchTerm);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Found: $searchTerm'), backgroundColor: Go2Colors.success));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read ticket. Try again.'), backgroundColor: Go2Colors.warning));
      }
    } finally {
      textRecognizer.close();
    }
  }
}
