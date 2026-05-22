import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../theme/app_theme.dart';
import '../services/simple_bluetooth_service.dart';

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
    if (auth.token != null) {
      await parking.initialize(auth.token!);
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
    final auth = context.watch<AuthProvider>();
    final parking = context.watch<ParkingProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Go2-Parking'),
            Text(
              auth.parkingName.isNotEmpty ? auth.parkingName : 'Dashboard',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          if (auth.isOffline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Go2Colors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: Go2Colors.accentLight),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(fontSize: 11, color: Go2Colors.accentLight)),
                ],
              ),
            ),
          Icon(
            Icons.print,
            size: 20,
            color: SimpleBluetoothService.isConnected ? Go2Colors.success : Go2Colors.textHint,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(Go2Spacing.lg),
          children: [
            _buildStatsCard(parking),
            const SizedBox(height: Go2Spacing.lg),
            _buildActionButtons(),
            const SizedBox(height: Go2Spacing.xl),
            _buildParkedSection(parking, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ParkingProvider parking) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Go2Spacing.xl, horizontal: Go2Spacing.md),
        child: Row(
          children: [
            _statColumn(Icons.directions_car, parking.activeVehicles.length.toString(), 'Parked', Go2Colors.primary),
            _statColumn(Icons.currency_rupee, '₹${parking.todayRevenue.toStringAsFixed(0)}', 'Revenue', Go2Colors.success),
            _statColumn(Icons.exit_to_app, parking.todayExits.toString(), 'Exits', Go2Colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: Go2Spacing.xs),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.add_circle_outline,
            label: 'New Entry',
            color: Go2Colors.success,
            onTap: () {
              if (widget.onTabSwitch != null) {
                widget.onTabSwitch!(1);
              } else {
                Navigator.pushNamed(context, '/entry');
              }
            },
          ),
        ),
        const SizedBox(width: Go2Spacing.md),
        Expanded(
          child: _actionButton(
            icon: Icons.exit_to_app_rounded,
            label: 'Vehicle Exit',
            color: Go2Colors.accent,
            onTap: () {
              if (widget.onTabSwitch != null) {
                widget.onTabSwitch!(2);
              } else {
                Navigator.pushNamed(context, '/exit');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(Go2Radius.lg),
      elevation: 1,
      shadowColor: color.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Go2Radius.lg),
        child: Container(
          height: 80,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: Go2Spacing.sm),
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParkedSection(ParkingProvider parking, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Currently Parked', style: theme.textTheme.titleLarge),
            const SizedBox(width: Go2Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Go2Colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Go2Radius.full),
              ),
              child: Text(
                '${parking.activeVehicles.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Go2Colors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: Go2Spacing.md),
        if (parking.activeVehicles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Go2Spacing.xxl),
              child: Column(
                children: [
                  const Icon(Icons.directions_car_outlined, size: 48, color: Go2Colors.textHint),
                  const SizedBox(height: Go2Spacing.md),
                  Text('No vehicles parked yet', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          )
        else
          ...parking.activeVehicles.take(10).map((v) {
            final duration = DateTime.now().difference(v.entryTime);
            final h = duration.inHours;
            final m = duration.inMinutes.remainder(60);
            final durationText = h > 0 ? '${h}h ${m}m' : '${m}m';
            return Card(
              margin: const EdgeInsets.only(bottom: Go2Spacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Go2Colors.primary.withValues(alpha: 0.1),
                  child: Icon(_vehicleIcon(v.vehicleType), color: Go2Colors.primary, size: 20),
                ),
                title: Text(v.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('${v.vehicleType} • $durationText', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Go2Colors.textHint, size: 20),
                dense: true,
              ),
            );
          }),
      ],
    );
  }
}
