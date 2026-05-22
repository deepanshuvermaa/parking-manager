import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/simple_vehicle_service.dart';
import '../models/simple_vehicle.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SimpleVehicle> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token ?? '';
      _vehicles = await SimpleVehicleService.getVehicles(token);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  // Helpers
  List<SimpleVehicle> _getExitedToday() {
    final now = DateTime.now();
    return _vehicles.where((v) =>
        v.status == 'exited' &&
        v.exitTime != null &&
        v.exitTime!.year == now.year &&
        v.exitTime!.month == now.month &&
        v.exitTime!.day == now.day).toList();
  }

  List<SimpleVehicle> _getExitedThisWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _vehicles.where((v) =>
        v.status == 'exited' &&
        v.exitTime != null &&
        v.exitTime!.isAfter(weekStart)).toList();
  }

  List<SimpleVehicle> _getExitedThisMonth() {
    final now = DateTime.now();
    return _vehicles.where((v) =>
        v.status == 'exited' &&
        v.exitTime != null &&
        v.exitTime!.year == now.year &&
        v.exitTime!.month == now.month).toList();
  }

  double _totalRevenue(List<SimpleVehicle> vehicles) =>
      vehicles.fold(0, (sum, v) => sum + (v.amount ?? 0));

  Map<String, int> _vehicleTypeCounts(List<SimpleVehicle> vehicles) {
    final map = <String, int>{};
    for (var v in vehicles) {
      map[v.vehicleType] = (map[v.vehicleType] ?? 0) + 1;
    }
    return map;
  }

  Map<int, double> _revenueByHour(List<SimpleVehicle> vehicles) {
    final map = <int, double>{};
    for (var v in vehicles) {
      if (v.exitTime != null) {
        final hour = v.exitTime!.hour;
        map[hour] = (map[hour] ?? 0) + (v.amount ?? 0);
      }
    }
    return map;
  }

  Map<int, double> _revenueByDay(List<SimpleVehicle> vehicles) {
    final map = <int, double>{};
    for (var v in vehicles) {
      if (v.exitTime != null) {
        final day = v.exitTime!.weekday;
        map[day] = (map[day] ?? 0) + (v.amount ?? 0);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReportTab(_getExitedToday(), 'today'),
                _buildReportTab(_getExitedThisWeek(), 'week'),
                _buildReportTab(_getExitedThisMonth(), 'month'),
              ],
            ),
    );
  }

  Widget _buildReportTab(List<SimpleVehicle> vehicles, String period) {
    final revenue = _totalRevenue(vehicles);
    final typeCounts = _vehicleTypeCounts(vehicles);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Revenue',
                  value: '₹${revenue.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee,
                  color: Go2Colors.success,
                ),
              ),
              const SizedBox(width: Go2Spacing.md),
              Expanded(
                child: _SummaryCard(
                  label: 'Vehicles',
                  value: vehicles.length.toString(),
                  icon: Icons.directions_car,
                  color: Go2Colors.primary,
                ),
              ),
              const SizedBox(width: Go2Spacing.md),
              Expanded(
                child: _SummaryCard(
                  label: 'Avg Fee',
                  value: vehicles.isNotEmpty
                      ? '₹${(revenue / vehicles.length).toStringAsFixed(0)}'
                      : '₹0',
                  icon: Icons.trending_up,
                  color: Go2Colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Revenue chart
          Text('Revenue Trend', style: theme.textTheme.titleMedium),
          const SizedBox(height: Go2Spacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Go2Spacing.lg),
              child: SizedBox(
                height: 200,
                child: _buildRevenueChart(vehicles, period),
              ),
            ),
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Vehicle type breakdown
          Text('Vehicle Types', style: theme.textTheme.titleMedium),
          const SizedBox(height: Go2Spacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Go2Spacing.lg),
              child: typeCounts.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(Go2Spacing.xl),
                        child: Text('No data yet'),
                      ),
                    )
                  : SizedBox(
                      height: 180,
                      child: _buildPieChart(typeCounts),
                    ),
            ),
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Peak hours
          if (period == 'today' || period == 'week') ...[
            Text('Peak Hours', style: theme.textTheme.titleMedium),
            const SizedBox(height: Go2Spacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Go2Spacing.lg),
                child: SizedBox(
                  height: 160,
                  child: _buildHourlyChart(vehicles),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueChart(List<SimpleVehicle> vehicles, String period) {
    if (vehicles.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_rounded, size: 48, color: Go2Colors.textHint.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        const Text('No data yet', style: TextStyle(fontSize: 14, color: Go2Colors.textSecondary)),
        const SizedBox(height: 4),
        const Text('Park vehicles to see reports', style: TextStyle(fontSize: 12, color: Go2Colors.textHint)),
      ]));
    }

    if (period == 'week') {
      final byDay = _revenueByDay(vehicles);
      final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final spots = <FlSpot>[];
      for (int i = 1; i <= 7; i++) {
        spots.add(FlSpot(i.toDouble(), byDay[i] ?? 0));
      }
      return LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 1 && idx <= 7) {
                    return Text(days[idx], style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Go2Colors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Go2Colors.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      );
    }

    // Default: hourly revenue for today/month
    final byHour = _revenueByHour(vehicles);
    final spots = <FlSpot>[];
    for (int i = 6; i <= 22; i++) {
      spots.add(FlSpot(i.toDouble(), byHour[i] ?? 0));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 4,
              getTitlesWidget: (value, _) {
                final h = value.toInt();
                return Text('${h}h', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Go2Colors.success,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Go2Colors.success.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> typeCounts) {
    final colors = [
      Go2Colors.primary,
      Go2Colors.accent,
      Go2Colors.success,
      Go2Colors.info,
      Go2Colors.error,
      const Color(0xFF7C4DFF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6E40),
    ];
    final total = typeCounts.values.fold(0, (a, b) => a + b);
    final entries = typeCounts.entries.toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: colors[idx % colors.length],
                  radius: 40,
                  showTitle: false,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: Go2Spacing.lg),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final pct = (entry.value / total * 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[idx % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${entry.key} ($pct%)',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(List<SimpleVehicle> vehicles) {
    final byHour = _revenueByHour(vehicles);
    if (byHour.isEmpty) return const Center(child: Text('No data'));

    final maxVal = byHour.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                return Text('${value.toInt()}', style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: byHour.entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: e.value == maxVal ? Go2Colors.accent : Go2Colors.primary,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList()
          ..sort((a, b) => a.x.compareTo(b.x)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Go2Spacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
