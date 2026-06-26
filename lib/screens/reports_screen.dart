import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/simple_vehicle_service.dart';
import '../services/platform_printer_service.dart';
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
      final all = await SimpleVehicleService.getVehicles(token);
      _vehicles = all.where((v) => v.status == 'exited').toList();
    } catch (e) {
      print('Reports load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _printReport() async {
    final period = ['Today', 'This Week', 'This Month'][_tabController.index];
    final vehicles = [_getExitedToday(), _getExitedThisWeek(), _getExitedThisMonth()][_tabController.index];
    final revenue = vehicles.fold<double>(0, (sum, v) => sum + (v.amount ?? 0));
    final count = vehicles.length;

    final report = StringBuffer();
    report.writeln('================================');
    report.writeln('       PARKING REPORT');
    report.writeln('================================');
    report.writeln('Period: $period');
    report.writeln('Date: ${DateTime.now().toString().substring(0, 16)}');
    report.writeln('--------------------------------');
    report.writeln('Total Vehicles: $count');
    report.writeln('Total Revenue: Rs. ${revenue.toStringAsFixed(0)}');
    report.writeln('--------------------------------');
    if (vehicles.isNotEmpty) {
      report.writeln('Breakdown:');
      final types = <String, int>{};
      for (final v in vehicles) { types[v.vehicleType] = (types[v.vehicleType] ?? 0) + 1; }
      types.forEach((type, c) => report.writeln('  $type: $c'));
    }
    report.writeln('================================');
    report.writeln('');

    final connected = await PlatformPrinterService.isConnected();
    if (connected) {
      await PlatformPrinterService.printText(report.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Report printed'), backgroundColor: Go2Colors.success));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer not connected'), backgroundColor: Go2Colors.error));
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, size: 20),
            tooltip: 'Print Report',
            onPressed: _printReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Go2Colors.primary,
          labelColor: Go2Colors.primary,
          unselectedLabelColor: Go2Colors.textHint,
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

          // Detailed breakdown
          const SizedBox(height: Go2Spacing.xl),
          Text('Detailed Breakdown', style: theme.textTheme.titleMedium),
          const SizedBox(height: Go2Spacing.md),

          // Type-wise revenue table
          if (typeCounts.isNotEmpty) ...[
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('By Vehicle Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
                const SizedBox(height: 8),
                ...typeCounts.entries.map((e) {
                  final typeVehicles = vehicles.where((v) => v.vehicleType == e.key).toList();
                  final typeRevenue = typeVehicles.fold<double>(0, (s, v) => s + (v.amount ?? 0));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(e.key, style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 1, child: Text('${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('₹${typeRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Go2Colors.success), textAlign: TextAlign.right)),
                    ]),
                  );
                }),
                const Divider(height: 16),
                Row(children: [
                  const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                  Expanded(flex: 1, child: Text('${vehicles.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('₹${revenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Go2Colors.success), textAlign: TextAlign.right)),
                ]),
              ]),
            )),
            const SizedBox(height: 12),
          ],

          // Duration breakdown
          if (vehicles.isNotEmpty) ...[
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('By Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
                const SizedBox(height: 8),
                ..._durationBreakdown(vehicles).entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                    Text('${e.value} vehicles', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Go2Colors.textSecondary)),
                  ]),
                )),
              ]),
            )),
            const SizedBox(height: 12),
          ],

          // Vehicle list
          if (vehicles.isNotEmpty) ...[
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('All Vehicles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary)),
                  const Spacer(),
                  Text('${vehicles.length} total', style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
                ]),
                const SizedBox(height: 8),
                ...vehicles.take(20).map((v) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(v.vehicleNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text(v.vehicleType, style: const TextStyle(fontSize: 11, color: Go2Colors.textHint))),
                    Expanded(flex: 2, child: Text(v.exitTime != null ? '${v.exitTime!.hour}:${v.exitTime!.minute.toString().padLeft(2, '0')}' : '-', style: const TextStyle(fontSize: 11, color: Go2Colors.textSecondary), textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text('₹${(v.amount ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Go2Colors.success), textAlign: TextAlign.right)),
                  ]),
                )),
                if (vehicles.length > 20) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('+ ${vehicles.length - 20} more...', style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
                ),
              ]),
            )),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Map<String, int> _durationBreakdown(List<SimpleVehicle> vehicles) {
    int under1h = 0, h1to3 = 0, h3to6 = 0, over6h = 0;
    for (final v in vehicles) {
      final mins = v.durationMinutes ?? (v.exitTime != null ? v.exitTime!.difference(v.entryTime).inMinutes : 0);
      if (mins < 60) under1h++;
      else if (mins < 180) h1to3++;
      else if (mins < 360) h3to6++;
      else over6h++;
    }
    return {'Under 1 hour': under1h, '1-3 hours': h1to3, '3-6 hours': h3to6, 'Over 6 hours': over6h};
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
    if (byHour.isEmpty) return const Center(child: Text('No peak hour data', style: TextStyle(color: Go2Colors.textHint)));

    final maxVal = byHour.values.isEmpty ? 1.0 : byHour.values.reduce((a, b) => a > b ? a : b);

    // Show hours 6 AM to 10 PM (6-22)
    final groups = <BarChartGroupData>[];
    for (int h = 6; h <= 22; h++) {
      final val = byHour[h] ?? 0;
      groups.add(BarChartGroupData(
        x: h,
        barRods: [
          BarChartRodData(
            toY: val > 0 ? val : 0.5, // minimum height for visibility
            color: val == maxVal && val > 0 ? Go2Colors.primary : Go2Colors.primary.withValues(alpha: val > 0 ? 0.6 : 0.1),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      ));
    }

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
              interval: 2,
              getTitlesWidget: (value, _) {
                final h = value.toInt();
                if (h % 2 == 0) return Text('${h > 12 ? h - 12 : h}${h >= 12 ? 'p' : 'a'}', style: const TextStyle(fontSize: 8, color: Go2Colors.textHint));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxVal * 1.2,
        barGroups: groups,
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
