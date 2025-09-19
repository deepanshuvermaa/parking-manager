import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printCurrentReport(context),
            tooltip: 'Print Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Daily'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Monthly'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: TabBarView(
          controller: _tabController,
          children: const [
            DailyReportTab(),
            MonthlyReportTab(),
            VehicleHistoryTab(),
          ],
        ),
      ),
    );
  }

  void _printCurrentReport(BuildContext context) {
    // Print based on the current tab - now handled directly in each tab
    Helpers.showSnackBar(context, 'Use the print button in each report tab');
  }
}

class DailyReportTab extends StatefulWidget {
  const DailyReportTab({super.key});

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: AppSpacing.lg),
          _buildDailySummary(),
          const SizedBox(height: AppSpacing.lg),
          _buildDailyTransactions(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Report for ${Helpers.formatDate(_selectedDate)}',
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _selectDate,
              child: const Text('Change Date'),
            ),
            IconButton(
              icon: const Icon(Icons.print, color: AppColors.primary),
              onPressed: () => _printDailyReport(context),
              tooltip: 'Print Daily Report',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayVehicles = vehicleProvider.vehicles.where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(dayStart) &&
            v.exitTime!.isBefore(dayEnd)).toList();

        final totalRevenue = dayVehicles.fold(0.0, (sum, v) => sum + (v.totalAmount ?? 0.0));
        final totalVehicles = dayVehicles.length;

        final typeStats = <String, int>{};
        for (var vehicle in dayVehicles) {
          typeStats[vehicle.vehicleType.name] = (typeStats[vehicle.vehicleType.name] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Summary',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              children: [
                _buildSummaryCard(
                  'Total Revenue',
                  Helpers.formatCurrency(totalRevenue),
                  Icons.attach_money,
                  AppColors.success,
                ),
                _buildSummaryCard(
                  'Total Vehicles',
                  totalVehicles.toString(),
                  Icons.directions_car,
                  AppColors.primary,
                ),
                _buildSummaryCard(
                  'Avg. Per Vehicle',
                  totalVehicles > 0
                      ? Helpers.formatCurrency(totalRevenue / totalVehicles)
                      : '₹0.00',
                  Icons.trending_up,
                  AppColors.accent,
                ),
                _buildSummaryCard(
                  'Peak Hour',
                  _getPeakHour(dayVehicles),
                  Icons.schedule,
                  AppColors.info,
                ),
              ],
            ),
            if (typeStats.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Vehicle Type Breakdown',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: typeStats.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text(
                              '${entry.value} vehicles',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTransactions() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayVehicles = vehicleProvider.vehicles.where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(dayStart) &&
            v.exitTime!.isBefore(dayEnd)).toList();

        dayVehicles.sort((a, b) => b.exitTime!.compareTo(a.exitTime!));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${dayVehicles.length} transactions',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (dayVehicles.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'No transactions for this date',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = dayVehicles[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.success.withOpacity(0.1),
                        child: Text(
                          vehicle.vehicleType.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(
                        vehicle.vehicleNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${vehicle.vehicleType.name} • ${Helpers.formatTime(vehicle.exitTime!)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Helpers.formatCurrency(vehicle.totalAmount ?? 0.0),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            Helpers.formatDuration(vehicle.parkingDuration),
                            style: const TextStyle(
                              fontSize: AppFontSize.xs,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  String _getPeakHour(List<Vehicle> vehicles) {
    if (vehicles.isEmpty) return 'N/A';

    final hourCounts = <int, int>{};
    for (var vehicle in vehicles) {
      final hour = vehicle.exitTime!.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final peakHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return '${peakHour.toString().padLeft(2, '0')}:00';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _printDailyReport(BuildContext context) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    if (!bluetoothProvider.isConnected) {
      // Try to connect to default printer
      await bluetoothProvider.initialize();
      if (bluetoothProvider.devices.isEmpty) {
        await bluetoothProvider.startScan();
      }
      if (bluetoothProvider.devices.isNotEmpty) {
        await bluetoothProvider.connectToDevice(bluetoothProvider.devices.first);
      }

      if (!bluetoothProvider.isConnected) {
        Helpers.showSnackBar(context, 'Please connect a printer first', isError: true);
        return;
      }
    }

    // Generate daily report
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayVehicles = vehicleProvider.vehicles.where((v) =>
        v.exitTime != null &&
        v.exitTime!.isAfter(dayStart) &&
        v.exitTime!.isBefore(dayEnd)).toList();

    final totalRevenue = dayVehicles.fold(0.0, (sum, v) => sum + (v.totalAmount ?? 0.0));

    // Group vehicles by type
    final typeStats = <String, int>{};
    for (var vehicle in dayVehicles) {
      typeStats[vehicle.vehicleType.name] = (typeStats[vehicle.vehicleType.name] ?? 0) + 1;
    }

    String report = '''
================================
      DAILY REPORT
================================
Date: ${Helpers.formatDate(_selectedDate)}
Generated: ${Helpers.formatDateTime(DateTime.now())}
--------------------------------
Total Vehicles: ${dayVehicles.length}
Total Revenue: ${Helpers.formatCurrency(totalRevenue)}
--------------------------------
VEHICLE TYPE BREAKDOWN:
''';

    typeStats.forEach((type, count) {
      report += '$type: $count vehicles\n';
    });

    report += '''
--------------------------------
TOP TRANSACTIONS:
''';

    // Add top 5 transactions
    final topVehicles = dayVehicles
      ..sort((a, b) => (b.totalAmount ?? 0).compareTo(a.totalAmount ?? 0));

    for (var i = 0; i < topVehicles.length && i < 5; i++) {
      final vehicle = topVehicles[i];
      report += '''
${i + 1}. ${vehicle.vehicleNumber}
   Amount: ${Helpers.formatCurrency(vehicle.totalAmount ?? 0)}
''';
    }

    report += '''
================================
    END OF REPORT
================================
    ''';

    await bluetoothProvider.printText(report);
    Helpers.showSnackBar(context, 'Daily report printed successfully');
  }
}

class MonthlyReportTab extends StatefulWidget {
  const MonthlyReportTab({super.key});

  @override
  State<MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<MonthlyReportTab> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthSelector(),
          const SizedBox(height: AppSpacing.lg),
          _buildMonthlySummary(),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Report for ${_getMonthYearString(_selectedMonth)}',
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _selectMonth,
              child: const Text('Change Month'),
            ),
            IconButton(
              icon: const Icon(Icons.print, color: AppColors.primary),
              onPressed: () => _printMonthlyReport(context),
              tooltip: 'Print Monthly Report',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

        final monthVehicles = vehicleProvider.vehicles.where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(monthStart) &&
            v.exitTime!.isBefore(monthEnd)).toList();

        final totalRevenue = monthVehicles.fold(0.0, (sum, v) => sum + (v.totalAmount ?? 0.0));
        final totalVehicles = monthVehicles.length;

        // Daily breakdown
        final dailyStats = <int, double>{};
        for (var vehicle in monthVehicles) {
          final day = vehicle.exitTime!.day;
          dailyStats[day] = (dailyStats[day] ?? 0.0) + (vehicle.totalAmount ?? 0.0);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Summary',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              children: [
                _buildSummaryCard(
                  'Total Revenue',
                  Helpers.formatCurrency(totalRevenue),
                  Icons.attach_money,
                  AppColors.success,
                ),
                _buildSummaryCard(
                  'Total Vehicles',
                  totalVehicles.toString(),
                  Icons.directions_car,
                  AppColors.primary,
                ),
                _buildSummaryCard(
                  'Daily Average',
                  dailyStats.isNotEmpty
                      ? Helpers.formatCurrency(totalRevenue / dailyStats.length)
                      : '₹0.00',
                  Icons.trending_up,
                  AppColors.accent,
                ),
                _buildSummaryCard(
                  'Best Day',
                  _getBestDay(dailyStats),
                  Icons.star,
                  AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Daily Breakdown',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: dailyStats.isEmpty
                    ? const Center(
                        child: Text('No data for selected month'),
                      )
                    : Column(
                        children: dailyStats.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Day ${entry.key}'),
                                Text(
                                  Helpers.formatCurrency(entry.value),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getBestDay(Map<int, double> dailyStats) {
    if (dailyStats.isEmpty) return 'N/A';

    final bestDay = dailyStats.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return 'Day $bestDay';
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _printMonthlyReport(BuildContext context) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    if (!bluetoothProvider.isConnected) {
      // Try to connect to default printer
      await bluetoothProvider.initialize();
      if (bluetoothProvider.devices.isEmpty) {
        await bluetoothProvider.startScan();
      }
      if (bluetoothProvider.devices.isNotEmpty) {
        await bluetoothProvider.connectToDevice(bluetoothProvider.devices.first);
      }

      if (!bluetoothProvider.isConnected) {
        Helpers.showSnackBar(context, 'Please connect a printer first', isError: true);
        return;
      }
    }

    // Generate monthly report
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    final monthVehicles = vehicleProvider.vehicles.where((v) =>
        v.exitTime != null &&
        v.exitTime!.isAfter(monthStart) &&
        v.exitTime!.isBefore(monthEnd)).toList();

    final totalRevenue = monthVehicles.fold(0.0, (sum, v) => sum + (v.totalAmount ?? 0.0));

    // Daily breakdown
    final dailyStats = <int, double>{};
    final dailyCounts = <int, int>{};
    for (var vehicle in monthVehicles) {
      final day = vehicle.exitTime!.day;
      dailyStats[day] = (dailyStats[day] ?? 0.0) + (vehicle.totalAmount ?? 0.0);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
    }

    // Vehicle type breakdown
    final typeStats = <String, int>{};
    for (var vehicle in monthVehicles) {
      typeStats[vehicle.vehicleType.name] = (typeStats[vehicle.vehicleType.name] ?? 0) + 1;
    }

    String report = '''
================================
      MONTHLY REPORT
================================
Month: ${_getMonthYearString(_selectedMonth)}
Generated: ${Helpers.formatDateTime(DateTime.now())}
--------------------------------
Total Vehicles: ${monthVehicles.length}
Total Revenue: ${Helpers.formatCurrency(totalRevenue)}
Daily Average: ${dailyStats.isNotEmpty ? Helpers.formatCurrency(totalRevenue / dailyStats.length) : '₹0.00'}
--------------------------------
VEHICLE TYPE BREAKDOWN:
''';

    typeStats.forEach((type, count) {
      report += '$type: $count vehicles\n';
    });

    report += '''
--------------------------------
TOP 5 DAYS BY REVENUE:
''';

    // Sort days by revenue and show top 5
    final sortedDays = dailyStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sortedDays.length && i < 5; i++) {
      final day = sortedDays[i];
      report += '''
Day ${day.key}: ${Helpers.formatCurrency(day.value)}
    (${dailyCounts[day.key] ?? 0} vehicles)
''';
    }

    report += '''
================================
    END OF REPORT
================================
    ''';

    await bluetoothProvider.printText(report);
    Helpers.showSnackBar(context, 'Monthly report printed successfully');
  }
}

class VehicleHistoryTab extends StatefulWidget {
  const VehicleHistoryTab({super.key});

  @override
  State<VehicleHistoryTab> createState() => _VehicleHistoryTabState();
}

class _VehicleHistoryTabState extends State<VehicleHistoryTab> {
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _buildVehicleHistory(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by vehicle number...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.print, color: AppColors.primary),
                onPressed: () => _printHistoryReport(context),
                tooltip: 'Print History Report',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              final types = ['All', 'Active', 'Completed', ...vehicleProvider.vehicleTypes.map((type) => type.name)];

              return Row(
                children: [
                  const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: types.map((type) {
                          final isSelected = _filterType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: FilterChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _filterType = type;
                                });
                              },
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              checkmarkColor: AppColors.primary,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleHistory() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final filteredVehicles = _getFilteredVehicles(vehicleProvider);

        if (filteredVehicles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'No vehicle history found',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: filteredVehicles.length,
          itemBuilder: (context, index) {
            final vehicle = filteredVehicles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: vehicle.isActive
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  child: Text(
                    vehicle.vehicleType.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${vehicle.vehicleType.name} • Ticket: ${vehicle.ticketId}'),
                    Text(
                      'Entry: ${Helpers.formatDateTime(vehicle.entryTime)}',
                      style: const TextStyle(fontSize: AppFontSize.xs),
                    ),
                    if (vehicle.exitTime != null)
                      Text(
                        'Exit: ${Helpers.formatDateTime(vehicle.exitTime!)}',
                        style: const TextStyle(fontSize: AppFontSize.xs),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: vehicle.isActive
                            ? AppColors.warning.withOpacity(0.2)
                            : AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        vehicle.isActive ? 'Active' : 'Completed',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: vehicle.isActive ? AppColors.warning : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.totalAmount != null
                          ? Helpers.formatCurrency(vehicle.totalAmount!)
                          : Helpers.formatCurrency(vehicle.calculateAmount()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Vehicle> _getFilteredVehicles(VehicleProvider vehicleProvider) {
    var vehicles = vehicleProvider.vehicles;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      vehicles = vehicles.where((vehicle) {
        return vehicle.vehicleNumber.toLowerCase().contains(_searchQuery) ||
            vehicle.ticketId.toLowerCase().contains(_searchQuery) ||
            (vehicle.ownerName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply type filter
    if (_filterType == 'Active') {
      vehicles = vehicles.where((vehicle) => vehicle.isActive).toList();
    } else if (_filterType == 'Completed') {
      vehicles = vehicles.where((vehicle) => !vehicle.isActive).toList();
    } else if (_filterType != 'All') {
      vehicles = vehicles.where((vehicle) {
        return vehicle.vehicleType.name == _filterType;
      }).toList();
    }

    // Sort by entry time (newest first)
    vehicles.sort((a, b) => b.entryTime.compareTo(a.entryTime));

    return vehicles;
  }

  Future<void> _printHistoryReport(BuildContext context) async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    if (!bluetoothProvider.isConnected) {
      // Try to connect to default printer
      await bluetoothProvider.initialize();
      if (bluetoothProvider.devices.isEmpty) {
        await bluetoothProvider.startScan();
      }
      if (bluetoothProvider.devices.isNotEmpty) {
        await bluetoothProvider.connectToDevice(bluetoothProvider.devices.first);
      }

      if (!bluetoothProvider.isConnected) {
        Helpers.showSnackBar(context, 'Please connect a printer first', isError: true);
        return;
      }
    }

    // Get filtered vehicles
    final filteredVehicles = _getFilteredVehicles(vehicleProvider);
    final reportVehicles = filteredVehicles.take(20).toList();

    // Calculate stats
    final activeCount = filteredVehicles.where((v) => v.isActive).length;
    final completedCount = filteredVehicles.where((v) => !v.isActive).length;
    final totalRevenue = filteredVehicles
        .where((v) => v.totalAmount != null)
        .fold(0.0, (sum, v) => sum + v.totalAmount!);

    String report = '''
================================
    VEHICLE HISTORY REPORT
================================
Generated: ${Helpers.formatDateTime(DateTime.now())}
Filter: $_filterType${_searchQuery.isNotEmpty ? ' | Search: $_searchQuery' : ''}
--------------------------------
Total Records: ${filteredVehicles.length}
Active: $activeCount | Completed: $completedCount
Total Revenue: ${Helpers.formatCurrency(totalRevenue)}
--------------------------------
RECENT VEHICLES:
''';

    for (var i = 0; i < reportVehicles.length; i++) {
      final vehicle = reportVehicles[i];
      report += '''
--------------------------------
${i + 1}. ${vehicle.vehicleNumber} [${vehicle.ticketId}]
Type: ${vehicle.vehicleType.name}
Entry: ${Helpers.formatDateTime(vehicle.entryTime)}''';

      if (vehicle.exitTime != null) {
        report += '''
Exit: ${Helpers.formatDateTime(vehicle.exitTime!)}
Duration: ${Helpers.formatDuration(vehicle.parkingDuration)}
Amount: ${Helpers.formatCurrency(vehicle.totalAmount!)}''';
      } else {
        report += '''
Status: ACTIVE
Duration: ${Helpers.formatDuration(vehicle.parkingDuration)}
Current: ${Helpers.formatCurrency(vehicle.calculateAmount())}''';
      }

      if (vehicle.ownerName != null) {
        report += '\nOwner: ${vehicle.ownerName}';
      }
    }

    report += '''
--------------------------------
Showing ${reportVehicles.length} of ${filteredVehicles.length} vehicles
================================
    END OF REPORT
================================
    ''';

    await bluetoothProvider.printText(report);
    Helpers.showSnackBar(context, 'History report printed successfully');
  }
}