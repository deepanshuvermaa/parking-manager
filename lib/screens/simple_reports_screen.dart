import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_vehicle_service.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/receipt_service.dart';
import '../models/simple_vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SimpleReportsScreen extends StatefulWidget {
  final String token;

  const SimpleReportsScreen({super.key, required this.token});

  @override
  State<SimpleReportsScreen> createState() => _SimpleReportsScreenState();
}

class _SimpleReportsScreenState extends State<SimpleReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Report data
  int _totalIn = 0;
  int _totalOut = 0;
  int _currentlyParked = 0;
  double _totalCollection = 0;
  Map<String, int> _vehicleTypeCount = {};
  Map<String, double> _vehicleTypeRevenue = {};
  List<SimpleVehicle> _vehicles = [];

  // Date range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadTodayReport();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    switch (_tabController.index) {
      case 0:
        _loadTodayReport();
        break;
      case 1:
        _loadWeekReport();
        break;
      case 2:
        _loadMonthReport();
        break;
      case 3:
        // Custom range - don't auto load
        break;
    }
  }

  Future<void> _loadTodayReport() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    await _loadReportForRange(startOfDay, endOfDay);
  }

  Future<void> _loadWeekReport() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    await _loadReportForRange(start, end);
  }

  Future<void> _loadMonthReport() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    await _loadReportForRange(start, end);
  }

  Future<void> _loadReportForRange(DateTime start, DateTime end) async {
    setState(() {
      _isLoading = true;
      _startDate = start;
      _endDate = end;
    });

    try {
      final allVehicles = await SimpleVehicleService.getVehicles(widget.token);

      // Filter vehicles in date range
      final vehiclesInRange = allVehicles.where((v) {
        return v.entryTime.isAfter(start) && v.entryTime.isBefore(end);
      }).toList();

      // Calculate statistics
      int totalIn = vehiclesInRange.length;
      int totalOut = vehiclesInRange.where((v) => v.status == 'exited').length;
      int currentlyParked = vehiclesInRange.where((v) => v.status == 'parked').length;
      double totalCollection = 0;
      Map<String, int> typeCount = {};
      Map<String, double> typeRevenue = {};

      for (var vehicle in vehiclesInRange) {
        // Count by type
        typeCount[vehicle.vehicleType] = (typeCount[vehicle.vehicleType] ?? 0) + 1;

        // Revenue calculation (only for exited vehicles)
        if (vehicle.status == 'exited' && vehicle.amount != null) {
          totalCollection += vehicle.amount!;
          typeRevenue[vehicle.vehicleType] =
              (typeRevenue[vehicle.vehicleType] ?? 0) + vehicle.amount!;
        }
      }

      setState(() {
        _totalIn = totalIn;
        _totalOut = totalOut;
        _currentlyParked = currentlyParked;
        _totalCollection = totalCollection;
        _vehicleTypeCount = typeCount;
        _vehicleTypeRevenue = typeRevenue;
        _vehicles = vehiclesInRange;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      await _loadReportForRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    }
  }

  Future<void> _printReport() async {
    if (!SimpleBluetoothService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer connected. Please connect a printer first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final receipt = await _generateReportReceipt();
      final success = await SimpleBluetoothService.printReceipt(receipt);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _generateReportReceipt() async {
    final prefs = await SharedPreferences.getInstance();

    // Get business details
    final businessName = prefs.getString('business_name') ?? 'ParkEase Parking';
    final businessAddress = prefs.getString('business_address') ?? '';
    final businessPhone = prefs.getString('business_phone') ?? '';
    final paperWidth = prefs.getInt('paper_width') ?? 32;

    // Get bill format settings
    final showBusinessName = prefs.getBool('bill_show_business_name') ?? true;
    final showBusinessAddress = prefs.getBool('bill_show_business_address') ?? true;
    final showBusinessPhone = prefs.getBool('bill_show_business_phone') ?? true;

    // Build receipt
    final receipt = StringBuffer();
    final divider = '=' * paperWidth;
    final dashLine = '-' * paperWidth;

    // Header
    receipt.writeln(divider);
    if (showBusinessName) {
      receipt.writeln(ReceiptService.centerText(businessName, paperWidth));
    }
    if (showBusinessAddress && businessAddress.isNotEmpty) {
      receipt.writeln(ReceiptService.centerText(businessAddress, paperWidth));
    }
    if (showBusinessPhone && businessPhone.isNotEmpty) {
      receipt.writeln(ReceiptService.centerText(businessPhone, paperWidth));
    }
    receipt.writeln(divider);
    receipt.writeln(ReceiptService.centerText('PARKING REPORT', paperWidth));
    receipt.writeln(divider);

    // Date range
    final periodLabel = _getPeriodLabel();
    receipt.writeln(ReceiptService.centerText(periodLabel, paperWidth));
    receipt.writeln('From: ${Helpers.formatDate(_startDate)}');
    receipt.writeln('To: ${Helpers.formatDate(_endDate)}');
    receipt.writeln(dashLine);

    // Summary statistics
    receipt.writeln('SUMMARY:');
    receipt.writeln('Total Vehicles In: $_totalIn');
    receipt.writeln('Total Vehicles Out: $_totalOut');
    receipt.writeln('Currently Parked: $_currentlyParked');
    receipt.writeln(dashLine);

    // Vehicle type breakdown
    if (_vehicleTypeCount.isNotEmpty) {
      receipt.writeln('VEHICLE TYPE BREAKDOWN:');
      _vehicleTypeCount.forEach((type, count) {
        final revenue = _vehicleTypeRevenue[type] ?? 0;
        receipt.writeln('$type: $count vehicles');
        receipt.writeln('  Revenue: Rs. ${revenue.toStringAsFixed(2)}');
      });
      receipt.writeln(dashLine);
    }

    // Total collection
    receipt.writeln('');
    final amountPadding = paperWidth > 32 ? 28 : 20;
    receipt.writeln(ReceiptService.padRight('TOTAL COLLECTION:', amountPadding) +
                    ReceiptService.padLeft('Rs. ${_totalCollection.toStringAsFixed(2)}', paperWidth - amountPadding));
    receipt.writeln('');
    receipt.writeln(divider);

    // Footer
    receipt.writeln(ReceiptService.centerText('Generated: ${Helpers.formatDateTime(DateTime.now())}', paperWidth));
    receipt.writeln(divider);

    return receipt.toString();
  }

  String _getPeriodLabel() {
    switch (_tabController.index) {
      case 0:
        return 'TODAY\'S REPORT';
      case 1:
        return 'WEEKLY REPORT';
      case 2:
        return 'MONTHLY REPORT';
      case 3:
        return 'CUSTOM REPORT';
      default:
        return 'REPORT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
            Tab(text: 'Custom'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading ? null : _printReport,
            tooltip: 'Print Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              switch (_tabController.index) {
                case 0:
                  _loadTodayReport();
                  break;
                case 1:
                  _loadWeekReport();
                  break;
                case 2:
                  _loadMonthReport();
                  break;
                case 3:
                  if (_startDate != null && _endDate != null) {
                    _loadReportForRange(_startDate, _endDate);
                  }
                  break;
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
        children: [
          _buildReportView(), // Today
          _buildReportView(), // Week
          _buildReportView(), // Month
          _buildCustomRangeView(), // Custom
        ],
        ),
      ),
    );
  }

  Widget _buildReportView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Vehicles In',
                  _totalIn.toString(),
                  Icons.login,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Vehicles Out',
                  _totalOut.toString(),
                  Icons.logout,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Parked',
                  _currentlyParked.toString(),
                  Icons.local_parking,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Collection',
                  '₹${_totalCollection.toStringAsFixed(0)}',
                  Icons.currency_rupee,
                  AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Vehicle Type Breakdown
          if (_vehicleTypeCount.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Vehicle Type Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ..._vehicleTypeCount.entries.map((entry) {
                      final revenue = _vehicleTypeRevenue[entry.key] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${entry.value} vehicles',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '₹${revenue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Print Button
          ElevatedButton.icon(
            onPressed: _printReport,
            icon: const Icon(Icons.print, color: Colors.white),
            label: Text(
              SimpleBluetoothService.isConnected
                  ? 'Print Report'
                  : 'Print Report (No Printer Connected)',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRangeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.date_range, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Select Custom Date Range',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: const Text(
              'Pick Date Range',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          if (!_isLoading && _vehicles.isNotEmpty) ...[
            const SizedBox(height: 32),
            Expanded(child: _buildReportView()),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
