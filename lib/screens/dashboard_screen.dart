import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../theme/app_theme.dart';
import '../services/simple_bluetooth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
                color: Colors.white.withOpacity(0.8),
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
                color: Go2Colors.warning.withOpacity(0.2),
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
          if (SimpleBluetoothService.isConnected)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.print, size: 20, color: Go2Colors.success),
            ),
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
            // Trial banner
            if (auth.isGuest) _buildTrialBanner(auth),

            // Capacity overview
            _buildCapacityCard(parking, theme),
            const SizedBox(height: Go2Spacing.lg),

            // Stats row
            _buildStatsRow(parking, theme),
            const SizedBox(height: Go2Spacing.xl),

            // Quick actions
            Text('Quick Actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: Go2Spacing.md),
            _buildQuickActions(parking),
            const SizedBox(height: Go2Spacing.xl),

            // Recent activity
            _buildRecentActivity(parking, theme),
          ],
        ),
      ),
      // Big FAB for vehicle entry — the #1 action
      floatingActionButton: FloatingActionButton.extended(
        onPressed: parking.isFull
            ? null
            : () async {
                await Navigator.pushNamed(context, '/entry');
                _loadData();
              },
        icon: const Icon(Icons.add_rounded, size: 28),
        label: const Text('Entry'),
        backgroundColor: parking.isFull ? Go2Colors.disabled : null,
      ),
    );
  }

  Widget _buildTrialBanner(AuthProvider auth) {
    final days = auth.trialDaysLeft;
    final isUrgent = days <= 1;
    return Container(
      margin: const EdgeInsets.only(bottom: Go2Spacing.lg),
      padding: const EdgeInsets.all(Go2Spacing.md),
      decoration: BoxDecoration(
        color: isUrgent ? Go2Colors.warningLight : Go2Colors.infoLight,
        borderRadius: BorderRadius.circular(Go2Radius.md),
        border: Border.all(
          color: isUrgent ? Go2Colors.warning : Go2Colors.info,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.timer_outlined,
            color: isUrgent ? Go2Colors.warning : Go2Colors.info,
            size: 20,
          ),
          const SizedBox(width: Go2Spacing.sm),
          Expanded(
            child: Text(
              days > 0
                  ? 'Trial: $days day${days > 1 ? 's' : ''} remaining'
                  : 'Trial expired',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isUrgent ? Go2Colors.accentDark : Go2Colors.info,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/subscribe'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard(ParkingProvider parking, ThemeData theme) {
    final percent = parking.occupancyPercent;
    final color = percent > 90
        ? Go2Colors.error
        : percent > 70
            ? Go2Colors.warning
            : Go2Colors.success;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Go2Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lot Occupancy', style: theme.textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(Go2Radius.full),
                  ),
                  child: Text(
                    parking.isFull ? 'FULL' : '${parking.totalAvailable} free',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Go2Spacing.lg),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(Go2Radius.full),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 12,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: Go2Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${parking.totalOccupied} / ${parking.totalCapacity} slots',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${percent.toStringAsFixed(0)}% occupied',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ParkingProvider parking, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.directions_car,
            label: 'Parked',
            value: parking.activeVehicles.length.toString(),
            color: Go2Colors.primary,
          ),
        ),
        const SizedBox(width: Go2Spacing.md),
        Expanded(
          child: _StatTile(
            icon: Icons.currency_rupee,
            label: 'Revenue',
            value: '₹${parking.todayRevenue.toStringAsFixed(0)}',
            color: Go2Colors.success,
          ),
        ),
        const SizedBox(width: Go2Spacing.md),
        Expanded(
          child: _StatTile(
            icon: Icons.exit_to_app,
            label: 'Exits',
            value: parking.todayExits.toString(),
            color: Go2Colors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ParkingProvider parking) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: Go2Spacing.md,
      crossAxisSpacing: Go2Spacing.md,
      childAspectRatio: 1.1,
      children: [
        _ActionTile(
          icon: Icons.exit_to_app_rounded,
          label: 'Exit',
          color: Go2Colors.accent,
          badge: parking.activeVehicles.isNotEmpty
              ? parking.activeVehicles.length.toString()
              : null,
          onTap: () async {
            await Navigator.pushNamed(context, '/exit');
            _loadData();
          },
        ),
        _ActionTile(
          icon: Icons.grid_view_rounded,
          label: 'Slots',
          color: Go2Colors.primaryLight,
          onTap: () => Navigator.pushNamed(context, '/slots'),
        ),
        _ActionTile(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          color: Color(0xFF7C4DFF),
          onTap: () => Navigator.pushNamed(context, '/reports'),
        ),
        _ActionTile(
          icon: Icons.print_rounded,
          label: 'Printer',
          color: Go2Colors.info,
          onTap: () => Navigator.pushNamed(context, '/printer'),
        ),
        _ActionTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          color: Go2Colors.textSecondary,
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        _ActionTile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          color: Go2Colors.error,
          onTap: () => _confirmLogout(),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(ParkingProvider parking, ThemeData theme) {
    if (parking.activeVehicles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Go2Spacing.xxl),
          child: Column(
            children: [
              Icon(Icons.local_parking_rounded,
                  size: 48, color: Go2Colors.textHint),
              const SizedBox(height: Go2Spacing.md),
              Text('No vehicles parked',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Go2Colors.textSecondary)),
              const SizedBox(height: Go2Spacing.sm),
              Text('Tap + Entry to add a vehicle',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Currently Parked', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/exit'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: Go2Spacing.sm),
        ...parking.activeVehicles.take(5).map((v) {
          final duration = DateTime.now().difference(v.entryTime);
          final hours = duration.inHours;
          final mins = duration.inMinutes.remainder(60);
          return Card(
            margin: const EdgeInsets.only(bottom: Go2Spacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Go2Colors.primary.withOpacity(0.1),
                child: Icon(_vehicleIcon(v.vehicleType),
                    color: Go2Colors.primary, size: 20),
              ),
              title: Text(v.vehicleNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(v.vehicleType),
              trailing: Text(
                hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hours >= 4 ? Go2Colors.warning : Go2Colors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ],
    );
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Go2Colors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Stat tile widget
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Go2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: Go2Spacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Action tile widget
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Go2Radius.lg),
      child: Card(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: Go2Spacing.sm),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Go2Colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Go2Colors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
