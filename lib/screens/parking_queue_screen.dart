import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'vehicle_exit_screen.dart';

class ParkingQueueScreen extends StatefulWidget {
  const ParkingQueueScreen({super.key});

  @override
  State<ParkingQueueScreen> createState() => _ParkingQueueScreenState();
}

class _ParkingQueueScreenState extends State<ParkingQueueScreen> {
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Parking Queue'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<VehicleProvider>().loadVehicles();
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchAndFilter(),
            _buildStatsBar(),
            Expanded(
              child: _buildVehicleList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by vehicle number...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              final types = ['All', ...vehicleProvider.vehicleTypes.map((type) => type.name)];

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

  Widget _buildStatsBar() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final filteredVehicles = _getFilteredVehicles(vehicleProvider);
        final totalAmount = filteredVehicles.fold(0.0, (sum, vehicle) {
          return sum + vehicle.calculateAmount();
        });

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: AppColors.primary.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Vehicles',
                filteredVehicles.length.toString(),
                Icons.directions_car,
              ),
              _buildStatItem(
                'Expected Amount',
                Helpers.formatCurrency(totalAmount),
                Icons.attach_money,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFontSize.xs,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleList() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final filteredVehicles = _getFilteredVehicles(vehicleProvider);

        if (filteredVehicles.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => vehicleProvider.loadVehicles(),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: filteredVehicles.length,
            itemBuilder: (context, index) {
              final vehicle = filteredVehicles[index];
              return _buildVehicleCard(vehicle);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_parking,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'All'
                ? 'No vehicles found'
                : 'No vehicles currently parked',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'All'
                ? 'Try adjusting your search or filter'
                : 'Add a vehicle to get started',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    final parkingDuration = vehicle.parkingDuration;
    final currentAmount = vehicle.calculateAmount();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _showVehicleDetails(vehicle),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      vehicle.vehicleType.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicleNumber,
                          style: const TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vehicle.vehicleType.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      Helpers.formatCurrency(currentAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _buildInfoItem(
                    Icons.access_time,
                    'Entry: ${Helpers.formatTime(vehicle.entryTime)}',
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  _buildInfoItem(
                    Icons.timer,
                    'Duration: ${Helpers.formatDuration(parkingDuration)}',
                  ),
                ],
              ),
              if (vehicle.ownerName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildInfoItem(
                  Icons.person,
                  'Owner: ${vehicle.ownerName}',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showVehicleDetails(vehicle),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Details'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _checkoutVehicle(vehicle),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: const TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Vehicle> _getFilteredVehicles(VehicleProvider vehicleProvider) {
    var vehicles = vehicleProvider.activeVehicles;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      vehicles = vehicles.where((vehicle) {
        return vehicle.vehicleNumber.toLowerCase().contains(_searchQuery) ||
            (vehicle.ownerName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply type filter
    if (_filterType != 'All') {
      vehicles = vehicles.where((vehicle) {
        return vehicle.vehicleType.name == _filterType;
      }).toList();
    }

    // Sort by entry time (newest first)
    vehicles.sort((a, b) => b.entryTime.compareTo(a.entryTime));

    return vehicles;
  }

  void _showVehicleDetails(Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Vehicle Details',
                style: const TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildDetailRow('Ticket ID', vehicle.ticketId),
              _buildDetailRow('Vehicle Number', vehicle.vehicleNumber),
              _buildDetailRow('Vehicle Type', vehicle.vehicleType.name),
              _buildDetailRow('Entry Time', Helpers.formatDateTime(vehicle.entryTime)),
              _buildDetailRow('Parking Duration', Helpers.formatDuration(vehicle.parkingDuration)),
              _buildDetailRow('Current Amount', Helpers.formatCurrency(vehicle.calculateAmount())),
              if (vehicle.ownerName != null)
                _buildDetailRow('Owner Name', vehicle.ownerName!),
              if (vehicle.ownerPhone != null)
                _buildDetailRow('Phone Number', vehicle.ownerPhone!),
              if (vehicle.notes != null)
                _buildDetailRow('Notes', vehicle.notes!),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _checkoutVehicle(vehicle);
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Checkout Vehicle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkoutVehicle(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleExitScreen(vehicle: vehicle),
      ),
    );
  }
}