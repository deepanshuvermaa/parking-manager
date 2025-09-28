import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/simplified_bluetooth_provider.dart';
import '../providers/simplified_auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/stats_card.dart';
import '../widgets/action_card.dart';
import '../widgets/connectivity_indicator.dart';
import 'vehicle_entry_screen.dart';
import 'parking_queue_screen.dart';
import 'vehicle_exit_screen.dart';
import 'reports_screen.dart';
import 'printer_settings_screen.dart';
import 'business_settings_screen.dart';
import 'vehicle_types_management_screen.dart';
import 'advanced_settings_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'admin_management_screen.dart';
import 'subscription_screen.dart';
import 'receipt_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
    _checkTrialStatus();
  }

  Future<void> _initializeApp() async {
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.loadSettings();
    // Simplified - no auto-connect on startup
  }
  
  void _checkTrialStatus() {
    // Simplified - no trial checking for now
    // This will be added in Phase 2
  }
  
  void _showTrialExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Trial Expired'),
          ],
        ),
        content: const Text(
          'Your 3-day free trial has ended. Please subscribe to continue using ParkEase.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Small delay to ensure dialog is closed
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (!mounted) return;
              
              try {
                await context.read<SimplifiedAuthProvider>().logout();
                // AuthWrapper will automatically navigate to LoginScreen when isAuthenticated becomes false
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(isTrialExpired: true),
                ),
              );
            },
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }
  
  void _showTrialEndingSoonBanner() {
    final authProvider = context.read<SimplifiedAuthProvider>();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.orange.shade50,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trial Ending Soon!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Welcome to ParkEase!',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        leading: const Icon(Icons.timer, color: Colors.orange),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('DISMISS'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text('SUBSCRIBE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.appName,
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<VehicleProvider>().loadVehicles();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ConnectivityBanner(),
                _buildGreeting(),
                const SizedBox(height: AppSpacing.lg),
                _buildStatsGrid(),
                const SizedBox(height: AppSpacing.lg),
                _buildQuickActions(),
                const SizedBox(height: AppSpacing.lg),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Helpers.getGreeting(),
              style: const TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              settingsProvider.settings.businessName,
              style: const TextStyle(
                fontSize: AppFontSize.lg,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        // Make grid responsive based on screen width
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth < 360 ? 2 : 2;
        final childAspectRatio = screenWidth < 360 ? 1.1 : 1.35;
        final spacing = screenWidth < 360 ? 8.0 : 12.0;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: [
            StatsCard(
              title: AppStrings.activeVehicles,
              value: vehicleProvider.totalActiveVehicles.toString(),
              icon: Icons.directions_car,
              color: AppColors.primary,
              onTap: () => _navigateToScreen(context, const ParkingQueueScreen()),
            ),
            StatsCard(
              title: AppStrings.todayCollection,
              value: Helpers.formatCurrency(vehicleProvider.todayCollection),
              icon: Icons.attach_money,
              color: AppColors.success,
              onTap: () => _navigateToScreen(context, const ReportsScreen()),
            ),
            StatsCard(
              title: AppStrings.completedToday,
              value: vehicleProvider.todayCompletedVehicles.toString(),
              icon: Icons.check_circle,
              color: AppColors.accent,
              onTap: () => _navigateToScreen(context, const ReportsScreen()),
            ),
            StatsCard(
              title: 'Vehicle Types',
              value: '${vehicleProvider.vehicleTypeStats.values.reduce((a, b) => a + b)}',
              icon: Icons.category,
              color: AppColors.info,
              subtitle: 'Total Parked',
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This is the change',
          style: TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w500,
            color: AppColors.info,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: AppFontSize.xl,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ActionCard(
                title: AppStrings.vehicleEntry,
                icon: Icons.add_circle,
                color: AppColors.primary,
                onTap: () => _navigateToScreen(context, const VehicleEntryScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ActionCard(
                title: AppStrings.parkingQueue,
                icon: Icons.queue,
                color: AppColors.warning,
                onTap: () => _navigateToScreen(context, const ParkingQueueScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ActionCard(
                title: AppStrings.vehicleExit,
                icon: Icons.exit_to_app,
                color: AppColors.error,
                onTap: () => _navigateToScreen(context, const VehicleExitScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ActionCard(
                title: AppStrings.reports,
                icon: Icons.bar_chart,
                color: AppColors.success,
                onTap: () => _navigateToScreen(context, const ReportsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final recentVehicles = vehicleProvider.activeVehicles.take(5).toList();
        
        if (recentVehicles.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Entries',
                  style: TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToScreen(context, const ParkingQueueScreen()),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentVehicles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = recentVehicles[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        vehicle.vehicleType.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      vehicle.vehicleNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Entry: ${Helpers.formatTime(vehicle.entryTime)}',
                    ),
                    trailing: Text(
                      Helpers.formatDuration(vehicle.parkingDuration),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSize.sm,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListView(
            controller: scrollController,
            shrinkWrap: true,
            children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text(AppStrings.printerSettings),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(context, const PrinterSettingsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Receipt Settings'),
              subtitle: const Text('Customize ticket ID and receipt format'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(context, const ReceiptSettingsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text(AppStrings.businessSettings),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(context, const BusinessSettingsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Vehicle Types & Pricing'),
              subtitle: const Text('Manage vehicle categories and rates'),
              onTap: () {
                Navigator.pop(context);
                _navigateToVehicleTypes(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Advanced Settings'),
              subtitle: const Text('State prefix, grace period, etc.'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAdvancedSettings(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup & Restore'),
              onTap: () {
                Navigator.pop(context);
                _showBackupDialog(context);
              },
            ),
            if (context.read<SimplifiedAuthProvider>().isAdmin)
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('User Management'),
                subtitle: const Text('Manage users and permissions'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(context, const UserManagementScreen());
                },
              ),
            if (context.read<SimplifiedAuthProvider>().isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Management'),
                subtitle: const Text('Deletion codes, audit log, device limits'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(context, const AdminManagementScreen());
                },
              ),
            // Subscription tile removed - will be added in Phase 2
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              subtitle: Text(
                'Logged in as: ${context.read<SimplifiedAuthProvider>().userEmail ?? "User"}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () async {
                // Close the drawer first
                Navigator.pop(context);
                
                // Small delay to ensure drawer is closed
                await Future.delayed(const Duration(milliseconds: 100));
                
                if (!context.mounted) return;
                
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true && context.mounted) {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  
                  try {
                    await context.read<SimplifiedAuthProvider>().logout();

                    if (context.mounted) {
                      // Close loading indicator
                      Navigator.pop(context);
                      // Force navigate to login screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')),
                      );
                    }
                  }
                }
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Create Backup'),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup created successfully')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore Backup'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _navigateToVehicleTypes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VehicleTypesManagementScreen()),
    );
  }

  void _navigateToAdvancedSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdvancedSettingsScreen()),
    );
  }
}