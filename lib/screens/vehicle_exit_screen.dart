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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Go2Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vehicle info
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Go2Colors.primary.withOpacity(0.1),
                  child: Icon(_vehicleIcon(vehicle.vehicleType),
                      color: Go2Colors.primary, size: 28),
                ),
                const SizedBox(width: Go2Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.vehicleNumber,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(vehicle.vehicleType,
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Go2Spacing.xl),

            // Duration & Amount
            Container(
              padding: const EdgeInsets.all(Go2Spacing.lg),
              decoration: BoxDecoration(
                color: Go2Colors.background,
                borderRadius: BorderRadius.circular(Go2Radius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Go2Colors.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text('Duration',
                            style: Theme.of(ctx).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Go2Colors.divider),
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.currency_rupee,
                            color: Go2Colors.success),
                        const SizedBox(height: 4),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Go2Colors.success,
                          ),
                        ),
                        Text('Amount',
                            style: Theme.of(ctx).textTheme.labelSmall),
                      ],
                    ),
                  ),
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
                  return Column(
                    children: [
                      UpiQrService.buildPaymentQR(
                        vpa: snapshot.data!['vpa']!,
                        merchantName: snapshot.data!['name'] ?? 'Go2-Parking',
                        amount: amount,
                        vehicleNumber: vehicle.vehicleNumber,
                        size: 140,
                      ),
                      const SizedBox(height: Go2Spacing.xl),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Exit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _processExit(ctx, vehicle, amount),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Confirm Exit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Go2Colors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Go2Radius.md)),
                ),
              ),
            ),
            const SizedBox(height: Go2Spacing.md),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: Go2Spacing.lg),
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
                            Icon(Icons.search_off,
                                size: 48, color: Go2Colors.textHint),
                            const SizedBox(height: Go2Spacing.md),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No matching vehicles'
                                  : 'No vehicles parked',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Go2Colors.textSecondary),
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
                                    Go2Colors.primary.withOpacity(0.1),
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

  void _scanQR() {
    // QR scanning placeholder — requires camera permission and qr_code_scanner package
    // For now, show a dialog explaining the feature
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Scanner'),
        content: const Text(
          'Point camera at the QR code on the parking ticket to instantly find the vehicle.\n\n'
          'This feature requires camera access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
