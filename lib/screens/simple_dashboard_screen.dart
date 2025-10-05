import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_vehicle_service.dart';
import '../models/simple_vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../services/simple_bluetooth_service.dart';
import '../main.dart';
import 'simple_vehicle_entry_screen.dart';
import 'simple_vehicle_exit_screen.dart';
import 'simple_parking_list_screen.dart';
import 'simple_settings_screen.dart';
import 'simple_printer_settings_screen.dart';

class SimpleDashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userRole;
  final String token;

  const SimpleDashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.token,
  });

  @override
  State<SimpleDashboardScreen> createState() => _SimpleDashboardScreenState();
}

class _SimpleDashboardScreenState extends State<SimpleDashboardScreen> {
  int _parkedCount = 0;
  double _todayCollection = 0;
  List<SimpleVehicle> _recentVehicles = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _autoConnectPrinter();
    _checkTrialStatus();

    // Auto refresh dashboard every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadDashboardData();
    });

    // ✅ PERIODIC BACKGROUND SYNC - Sync pending changes every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      SimpleVehicleService.syncPendingChanges(widget.token).then((_) {
        print('✅ Background sync completed');
        _loadDashboardData(); // Refresh UI after sync
      }).catchError((e) {
        print('⚠️ Background sync failed: $e');
      });
    });
  }

  Future<void> _checkTrialStatus() async {
    if (widget.userRole == 'guest') {
      final prefs = await SharedPreferences.getInstance();
      final trialExpires = prefs.getString('trial_expires');
      if (trialExpires != null) {
        final expiryDate = DateTime.parse(trialExpires);
        final daysLeft = expiryDate.difference(DateTime.now()).inDays;

        if (daysLeft <= 0) {
          // Trial expired
          _showTrialExpiredAndExit();
        } else if (daysLeft <= 1) {
          // Show warning
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Trial expires in $daysLeft day${daysLeft > 1 ? 's' : ''}!'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }

  void _showTrialExpiredAndExit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Trial Expired'),
          ],
        ),
        content: const Text(
          'Your 3-day free trial has ended. Please contact the developer to purchase the full version.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoConnectPrinter() async {
    try {
      await SimpleBluetoothService.autoConnect();
    } catch (e) {
      // Silent fail - user can manually connect from settings
    }
  }

  Future<int> _getTrialDaysLeft() async {
    final prefs = await SharedPreferences.getInstance();
    final trialExpires = prefs.getString('trial_expires');
    if (trialExpires != null) {
      final expiryDate = DateTime.parse(trialExpires);
      return expiryDate.difference(DateTime.now()).inDays;
    }
    return 3; // Default trial days
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _syncTimer?.cancel(); // ✅ Cancel sync timer
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final vehicles = await SimpleVehicleService.getVehicles(widget.token);

      if (mounted) {
        setState(() {
          _parkedCount = vehicles.where((v) => v.status == 'parked').length;
          _todayCollection = SimpleVehicleService.getTodayCollection();
          _recentVehicles = vehicles.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    // Refresh data when returning
    _loadDashboardData();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // Clear all saved data
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              // Disconnect Bluetooth if connected
              await SimpleBluetoothService.disconnect();
              // Navigate to login screen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SimpleLoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(icon, size: 40, color: Colors.white),
                  if (badge != null)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ParkEase Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Bluetooth status indicator
          if (SimpleBluetoothService.isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth_connected, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Printer',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.userName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.userEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(SimpleSettingsScreen(token: widget.token));
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Printer Settings'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(const SimplePrinterSettingsScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'ParkEase Manager',
                  applicationVersion: '4.0',
                  applicationLegalese: '© 2024 ParkEase',
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trial Status for Guest Users
                    if (widget.userRole == 'guest')
                      FutureBuilder<int>(
                        future: _getTrialDaysLeft(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final daysLeft = snapshot.data!;
                            return Card(
                              elevation: 0,
                              color: daysLeft <= 1 ? Colors.orange[50] : Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      daysLeft <= 1 ? Icons.warning : Icons.timer,
                                      color: daysLeft <= 1 ? Colors.orange : Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Trial Version',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: daysLeft <= 1 ? Colors.orange : Colors.green,
                                            ),
                                          ),
                                          Text(
                                            daysLeft > 0
                                                ? '$daysLeft day${daysLeft > 1 ? 's' : ''} remaining'
                                                : 'Trial expired',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    if (widget.userRole == 'guest') const SizedBox(height: 10),

                    // Welcome message
                    Card(
                      elevation: 0,
                      color: AppColors.primary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back, ${widget.userName}!',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Today is ${Helpers.formatDate(DateTime.now())}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Parked Vehicles',
                            value: _parkedCount.toString(),
                            icon: Icons.local_parking,
                            color: Colors.blue,
                            subtitle: 'Currently in parking',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: "Today's Collection",
                            value: '₹${_todayCollection.toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                            color: Colors.green,
                            subtitle: 'Total revenue today',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _buildActionButton(
                          title: 'Vehicle Entry',
                          icon: Icons.add_circle,
                          color: Colors.green,
                          onTap: () => _navigateToScreen(
                            SimpleVehicleEntryScreen(token: widget.token),
                          ),
                        ),
                        _buildActionButton(
                          title: 'Vehicle Exit',
                          icon: Icons.exit_to_app,
                          color: Colors.orange,
                          badge: _parkedCount > 0 ? _parkedCount.toString() : null,
                          onTap: () => _navigateToScreen(
                            SimpleVehicleExitScreen(token: widget.token),
                          ),
                        ),
                        _buildActionButton(
                          title: 'Parking List',
                          icon: Icons.list_alt,
                          color: Colors.blue,
                          onTap: () => _navigateToScreen(
                            SimpleParkingListScreen(token: widget.token),
                          ),
                        ),
                        _buildActionButton(
                          title: 'Reports',
                          icon: Icons.bar_chart,
                          color: Colors.purple,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reports feature coming soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent Vehicles
                    if (_recentVehicles.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _navigateToScreen(
                              SimpleParkingListScreen(token: widget.token),
                            ),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(_recentVehicles.take(3).map((vehicle) {
                        final isParked = vehicle.status == 'parked';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isParked ? Colors.green : Colors.grey,
                              child: Icon(
                                isParked ? Icons.local_parking : Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              vehicle.vehicleNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${vehicle.vehicleType} • ${Helpers.formatDateTime(vehicle.entryTime)}',
                            ),
                            trailing: isParked
                                ? Chip(
                                    label: Text(
                                      'PARKED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  )
                                : Text(
                                    '₹${vehicle.amount?.toStringAsFixed(0) ?? '0'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        );
                      }).toList()),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}