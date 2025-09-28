import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/auth_state_provider.dart';
import '../models/vehicle_type.dart';
import '../models/rate_tier.dart';
import '../widgets/admin_deletion_dialog.dart';
import '../services/admin_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class VehicleTypesManagementScreen extends StatefulWidget {
  const VehicleTypesManagementScreen({super.key});

  @override
  State<VehicleTypesManagementScreen> createState() => _VehicleTypesManagementScreenState();
}

class _VehicleTypesManagementScreenState extends State<VehicleTypesManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Types & Pricing'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditVehicleTypeDialog(),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Consumer<VehicleProvider>(
          builder: (context, vehicleProvider, _) {
            final vehicleTypes = vehicleProvider.vehicleTypes;

            if (vehicleTypes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No vehicle types defined',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add vehicle types to start managing pricing',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditVehicleTypeDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Vehicle Type'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: vehicleTypes.length,
              itemBuilder: (context, index) {
                final vehicleType = vehicleTypes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          vehicleType.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      vehicleType.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vehicleType.usesTieredPricing)
                          Text(
                            vehicleType.pricingSummary,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            'Hourly: ${Helpers.formatCurrency(vehicleType.hourlyRate)}',
                          ),
                        if (vehicleType.flatRate != null)
                          Text(
                            'Flat: ${Helpers.formatCurrency(vehicleType.flatRate!)}',
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          onPressed: () => _showAddEditVehicleTypeDialog(vehicleType: vehicleType),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _showDeleteConfirmation(vehicleType),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddEditVehicleTypeDialog({VehicleType? vehicleType}) {
    final isEdit = vehicleType != null;
    final nameController = TextEditingController(text: vehicleType?.name);
    final iconController = TextEditingController(text: vehicleType?.icon ?? '🚗');
    final hourlyRateController = TextEditingController(
      text: vehicleType?.hourlyRate.toString() ?? '',
    );
    final flatRateController = TextEditingController(
      text: vehicleType?.flatRate?.toString() ?? '',
    );

    bool useTieredPricing = vehicleType?.usesTieredPricing ?? false;
    List<RateTier> rateTiers = vehicleType?.rateTiers != null
        ? List<RateTier>.from(vehicleType!.rateTiers!)
        : [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Vehicle Type' : 'Add Vehicle Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type Name',
                  hintText: 'e.g., Car, Bike, Truck',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon (Emoji)',
                  hintText: 'e.g., 🚗, 🏍️, 🚛',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hourlyRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hourly Rate (Rs)',
                  hintText: 'e.g., 20',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: flatRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Flat Rate (Optional) (Rs)',
                  hintText: 'e.g., 100',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final icon = iconController.text.trim();
              final hourlyRate = double.tryParse(hourlyRateController.text) ?? 0;
              final flatRate = double.tryParse(flatRateController.text);

              if (name.isEmpty || hourlyRate <= 0) {
                Helpers.showSnackBar(
                  context,
                  'Please enter valid vehicle type name and hourly rate',
                  isError: true,
                );
                return;
              }

              final vehicleProvider = context.read<VehicleProvider>();

              if (isEdit) {
                // Update existing vehicle type
                final updatedType = VehicleType(
                  id: vehicleType.id,
                  name: name,
                  icon: icon.isEmpty ? '🚗' : icon,
                  hourlyRate: hourlyRate,
                  flatRate: flatRate,
                );
                vehicleProvider.updateVehicleType(updatedType);
                Helpers.showSnackBar(context, 'Vehicle type updated successfully');
              } else {
                // Add new vehicle type
                final newType = VehicleType(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  icon: icon.isEmpty ? '🚗' : icon,
                  hourlyRate: hourlyRate,
                  flatRate: flatRate,
                );
                vehicleProvider.addVehicleType(newType);
                Helpers.showSnackBar(context, 'Vehicle type added successfully');
              }

              Navigator.pop(context);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(VehicleType vehicleType) async {
    final authProvider = context.read<AuthStateProvider>();

    // Check if user has permission to delete
    if (!AdminService.canDeleteItems(authProvider)) {
      Helpers.showSnackBar(
        context,
        'You do not have permission to delete items',
        isError: true,
      );
      return;
    }

    // Show admin deletion dialog with protection
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminDeletionDialog(
        itemType: 'Vehicle Type',
        itemId: vehicleType.id,
        itemName: vehicleType.name,
        onConfirmed: () async {
          try {
            final vehicleProvider = context.read<VehicleProvider>();
            vehicleProvider.deleteVehicleType(vehicleType.id);

            // Log the admin action
            await AdminService.logAdminAction(
              'DELETE',
              'Vehicle Type',
              vehicleType.id,
              authProvider.userId ?? 'unknown',
            );

            if (mounted) {
              Helpers.showSnackBar(context, 'Vehicle type deleted successfully');
            }
          } catch (e) {
            if (mounted) {
              Helpers.showSnackBar(
                context,
                'Failed to delete vehicle type: $e',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }
}