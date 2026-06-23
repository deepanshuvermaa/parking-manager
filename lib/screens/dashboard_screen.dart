import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../services/simple_vehicle_service.dart';
import '../services/platform_printer_service.dart';
import '../services/receipt_service.dart';
import '../models/simple_vehicle.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;
  const DashboardScreen({super.key, this.onTabSwitch});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final parking = context.read<ParkingProvider>();
    if (auth.token != null) await parking.initialize(auth.token!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final parking = context.watch<ParkingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Go2-Parking'),
            if (auth.parkingName.isNotEmpty)
              Text(auth.parkingName, style: const TextStyle(fontSize: 11, color: Go2Colors.textSecondary)),
          ],
        ),
        actions: [
          if (auth.isOffline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Go2Colors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Go2Radius.full),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded, size: 12, color: Go2Colors.warning),
                SizedBox(width: 4),
                Text('Offline', style: TextStyle(fontSize: 10, color: Go2Colors.warning, fontWeight: FontWeight.w500)),
              ]),
            ),
          // Sync health indicator
          if (SimpleVehicleService.unsyncedCount > 0)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${SimpleVehicleService.unsyncedCount} records pending sync${SimpleVehicleService.lastSyncError != null ? "\nLast error: ${SimpleVehicleService.lastSyncError}" : ""}'),
                  backgroundColor: Go2Colors.warning,
                  duration: const Duration(seconds: 4),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Go2Colors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Go2Radius.full),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.sync_problem_rounded, size: 12, color: Go2Colors.error),
                  const SizedBox(width: 4),
                  Text('${SimpleVehicleService.unsyncedCount} unsynced', style: const TextStyle(fontSize: 10, color: Go2Colors.error, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          FutureBuilder<bool>(
            future: PlatformPrinterService.isConnected(),
            builder: (_, snap) => snap.data == true
                ? const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.print_rounded, size: 18, color: Go2Colors.success))
                : const SizedBox.shrink(),
          ),
          if (auth.userRole != 'staff')
            IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () => Navigator.pushNamed(context, '/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(Go2Spacing.lg),
          children: [
            // Stats row
            _buildStats(parking),
            const SizedBox(height: Go2Spacing.xl),

            // Action buttons
            Row(children: [
              Expanded(child: _ActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Entry',
                color: Go2Colors.primary,
                onTap: () => widget.onTabSwitch?.call(1),
              )),
              const SizedBox(width: Go2Spacing.md),
              Expanded(child: _ActionButton(
                icon: Icons.exit_to_app_rounded,
                label: 'Vehicle Exit',
                color: Go2Colors.warning,
                onTap: () => widget.onTabSwitch?.call(2),
              )),
            ]),
            const SizedBox(height: Go2Spacing.xxl),

            // Parked vehicles
            Row(children: [
              Text('Currently Parked', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (parking.activeVehicles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Go2Colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Go2Radius.full)),
                  child: Text('${parking.activeVehicles.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Go2Colors.primary)),
                ),
            ]),
            const SizedBox(height: Go2Spacing.md),

            if (parking.activeVehicles.isEmpty)
              _buildEmpty()
            else
              ...parking.activeVehicles.take(15).map((v) => _buildVehicleTile(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(ParkingProvider parking) {
    return Container(
      padding: const EdgeInsets.all(Go2Spacing.lg),
      decoration: BoxDecoration(
        color: Go2Colors.surface,
        borderRadius: BorderRadius.circular(Go2Radius.md),
        border: Border.all(color: Go2Colors.divider, width: 0.5),
      ),
      child: Row(children: [
        _StatItem(icon: Icons.local_parking_rounded, value: '${parking.activeVehicles.length}', label: 'Parked', color: Go2Colors.primary),
        _divider(),
        _StatItem(icon: Icons.currency_rupee_rounded, value: '₹${parking.todayRevenue.toStringAsFixed(0)}', label: 'Revenue', color: Go2Colors.success),
        _divider(),
        _StatItem(icon: Icons.logout_rounded, value: '${parking.todayExits}', label: 'Exits', color: Go2Colors.textSecondary),
      ]),
    );
  }

  Widget _divider() => Container(width: 0.5, height: 36, color: Go2Colors.divider, margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _buildVehicleTile(SimpleVehicle v) {
    final duration = DateTime.now().difference(v.entryTime);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return GestureDetector(
      onTap: () => _showVehicleDetail(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Go2Colors.surface,
          borderRadius: BorderRadius.circular(Go2Radius.md),
          border: Border.all(color: Go2Colors.divider, width: 0.5),
        ),
        child: Row(children: [
          Icon(_vehicleIcon(v.vehicleType), size: 20, color: Go2Colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.vehicleNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
            Text('${v.vehicleType} • $timeStr', style: TextStyle(fontSize: 12, color: Go2Colors.textHint)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: Go2Colors.textHint),
        ]),
      ),
    );
  }

  void _showVehicleDetail(SimpleVehicle v) {
    final duration = DateTime.now().difference(v.entryTime);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final fee = (v.hourlyRate ?? 20) * (h + (m > 0 ? 1 : 0));
    final amount = fee < (v.minimumRate ?? 20) ? (v.minimumRate ?? 20) : fee;

    showModalBottomSheet(
      context: context,
      backgroundColor: Go2Colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(_vehicleIcon(v.vehicleType), size: 28, color: Go2Colors.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.vehicleNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(v.vehicleType, style: TextStyle(fontSize: 13, color: Go2Colors.textHint)),
            ])),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Go2Colors.skyWash, borderRadius: BorderRadius.circular(Go2Radius.md)),
            child: Row(children: [
              Expanded(child: Column(children: [
                Text('${h}h ${m}m', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary)),
                Text('Duration', style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
              ])),
              Container(width: 0.5, height: 32, color: Go2Colors.divider),
              Expanded(child: Column(children: [
                Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Go2Colors.primary)),
                Text('Amount', style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Entry: ${_formatTime(v.entryTime)}', style: TextStyle(fontSize: 12, color: Go2Colors.textSecondary))),
            if (v.ticketId != null) Text('Ticket: ${v.ticketId}', style: TextStyle(fontSize: 12, color: Go2Colors.textHint)),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Show confirmation before exit
              _confirmAndExit(v, amount);
            },
            child: const Text('Process Exit'),
          )),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _confirmAndExit(SimpleVehicle v, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exit ${v.vehicleNumber}?'),
        content: Text('Duration: ${DateTime.now().difference(v.entryTime).inHours}h ${DateTime.now().difference(v.entryTime).inMinutes.remainder(60)}m\nAmount: ₹${amount.toStringAsFixed(0)}\n\nReceipt will be printed automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm & Print')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().token ?? '';
    await SimpleVehicleService.exitVehicle(token: token, vehicleId: v.id, amount: amount);
    if (!mounted) return;

    context.read<ParkingProvider>().recordExit(amount);
    HapticFeedback.mediumImpact();

    // Print exit receipt
    final connected = await PlatformPrinterService.isConnected();
    if (connected) {
      v.exitTime = DateTime.now();
      v.amount = amount;
      final duration = v.exitTime!.difference(v.entryTime);
      final receipt = await ReceiptService.generateExitReceipt(v, amount, duration);
      await PlatformPrinterService.printText(receipt);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ ${v.vehicleNumber} exited • ₹${amount.toStringAsFixed(0)}${connected ? ' • Printed' : ''}'),
        backgroundColor: Go2Colors.success,
      ));
      _loadData();
    }
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildEmpty() => Container(
    padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(Icons.local_parking_rounded, size: 48, color: Go2Colors.textHint.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      Text('No vehicles parked', style: TextStyle(color: Go2Colors.textHint, fontSize: 14)),
      const SizedBox(height: 4),
      Text('Tap "New Entry" to add a vehicle', style: TextStyle(color: Go2Colors.textHint.withValues(alpha: 0.6), fontSize: 12)),
    ]),
  );

  IconData _vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike': case 'scooter': return Icons.two_wheeler;
      case 'bus': return Icons.directions_bus;
      case 'truck': case 'mini truck': case 'tempo': return Icons.local_shipping;
      case 'auto rickshaw': case 'e-rickshaw': return Icons.electric_rickshaw;
      case 'cycle': case 'e-cycle': return Icons.pedal_bike;
      case 'suv': return Icons.directions_car_filled;
      default: return Icons.directions_car;
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color;
  const _StatItem({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 6),
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary)),
    Text(label, style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
  ]));
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Go2Radius.lg),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}
