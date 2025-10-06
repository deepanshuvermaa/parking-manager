import 'package:flutter/material.dart';
import '../models/vehicle_rate.dart';
import '../services/vehicle_rate_service.dart';
import '../utils/constants.dart';

class VehicleRatesManagementScreen extends StatefulWidget {
  const VehicleRatesManagementScreen({super.key});

  @override
  State<VehicleRatesManagementScreen> createState() => _VehicleRatesManagementScreenState();
}

class _VehicleRatesManagementScreenState extends State<VehicleRatesManagementScreen> {
  List<VehicleRate> _rates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    final rates = await VehicleRateService.loadRates();
    setState(() {
      _rates = rates;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({VehicleRate? existingRate, int? index}) {
    final isEdit = existingRate != null;
    final typeController = TextEditingController(text: existingRate?.vehicleType ?? '');
    final hourlyController = TextEditingController(text: existingRate?.hourlyRate.toString() ?? '');
    final minimumController = TextEditingController(text: existingRate?.minimumCharge.toString() ?? '');
    final freeMinutesController = TextEditingController(text: existingRate?.freeMinutes.toString() ?? '0');

    final List<TimedRate> timedRates = List.from(existingRate?.timedRates ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit ${existingRate.vehicleType}' : 'Add Vehicle Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  enabled: !isEdit, // Can't change type when editing
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hourlyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hourly Rate (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minimumController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Charge (₹)',
                    prefixIcon: Icon(Icons.money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: freeMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Free Minutes',
                    prefixIcon: Icon(Icons.timer),
                    border: OutlineInputBorder(),
                    helperText: 'Grace period with no charge',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Time-Based Pricing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        setState(() {
                          timedRates.add(TimedRate(afterHours: 1));
                        });
                      },
                    ),
                  ],
                ),
                const Text(
                  'Apply different rates after certain hours',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ...timedRates.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final timedRate = entry.value;
                  return _buildTimedRateCard(timedRate, idx, setState, timedRates);
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final type = typeController.text.trim();
                final hourly = double.tryParse(hourlyController.text) ?? 0;
                final minimum = double.tryParse(minimumController.text) ?? 0;
                final freeMin = int.tryParse(freeMinutesController.text) ?? 0;

                if (type.isEmpty || hourly <= 0 || minimum <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields correctly'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newRate = VehicleRate(
                  vehicleType: type,
                  hourlyRate: hourly,
                  minimumCharge: minimum,
                  freeMinutes: freeMin,
                  timedRates: timedRates,
                );

                bool success;
                if (isEdit) {
                  success = await VehicleRateService.updateVehicleType(
                    existingRate.vehicleType,
                    newRate,
                  );
                } else {
                  success = await VehicleRateService.addVehicleType(newRate);
                }

                if (success) {
                  Navigator.pop(context);
                  _loadRates();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Rate updated!' : 'Vehicle type added!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Update failed' : 'Type already exists'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimedRateCard(TimedRate timedRate, int index, StateSetter setState, List<TimedRate> timedRates) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('After ${timedRate.afterHours} hours:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (timedRate.flatRate != null)
                    Text('Flat: ₹${timedRate.flatRate}', style: const TextStyle(fontSize: 11))
                  else if (timedRate.hourlyRate != null)
                    Text('Hourly: ₹${timedRate.hourlyRate}/hr', style: const TextStyle(fontSize: 11))
                  else
                    const Text('No rate set', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editTimedRate(index, timedRate, setState, timedRates),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () {
                setState(() {
                  timedRates.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editTimedRate(int index, TimedRate timedRate, StateSetter parentSetState, List<TimedRate> timedRates) {
    final hoursController = TextEditingController(text: timedRate.afterHours.toString());
    final hourlyController = TextEditingController(text: timedRate.hourlyRate?.toString() ?? '');
    final flatController = TextEditingController(text: timedRate.flatRate?.toString() ?? '');
    String rateType = timedRate.flatRate != null ? 'flat' : 'hourly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Time-Based Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'After Hours',
                  helperText: 'Apply this rate after X hours',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: rateType,
                decoration: const InputDecoration(labelText: 'Rate Type'),
                items: const [
                  DropdownMenuItem(value: 'hourly', child: Text('Hourly Rate')),
                  DropdownMenuItem(value: 'flat', child: Text('Flat Rate')),
                ],
                onChanged: (value) {
                  setState(() {
                    rateType = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (rateType == 'hourly')
                TextField(
                  controller: hourlyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hourly Rate (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                )
              else
                TextField(
                  controller: flatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Flat Rate (₹)',
                    prefixIcon: Icon(Icons.money),
                    helperText: 'Fixed amount regardless of hours',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final hours = int.tryParse(hoursController.text) ?? 1;
                final hourly = double.tryParse(hourlyController.text);
                final flat = double.tryParse(flatController.text);

                parentSetState(() {
                  timedRates[index] = TimedRate(
                    afterHours: hours,
                    hourlyRate: rateType == 'hourly' ? hourly : null,
                    flatRate: rateType == 'flat' ? flat : null,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRate(VehicleRate rate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle Type'),
        content: Text('Are you sure you want to delete "${rate.vehicleType}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await VehicleRateService.deleteVehicleType(rate.vehicleType);
      if (success) {
        _loadRates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle type deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('This will reset all vehicle rates to default values. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await VehicleRateService.resetToDefaults();
      _loadRates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rates reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Rates Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to Defaults',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: const Text(
                    'Manage pricing for different vehicle types. Add time-based pricing for special rates after certain hours.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rates.length,
                    itemBuilder: (context, index) {
                      final rate = _rates[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.directions_car, color: Colors.white),
                          ),
                          title: Text(
                            rate.vehicleType,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${rate.hourlyRate}/hr • Min: ₹${rate.minimumCharge}'),
                              if (rate.freeMinutes > 0)
                                Text('Free: ${rate.freeMinutes} min', style: const TextStyle(fontSize: 11)),
                              if (rate.timedRates.isNotEmpty)
                                Text(
                                  '${rate.timedRates.length} time-based rate(s)',
                                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showAddEditDialog(existingRate: rate, index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteRate(rate),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Vehicle Type', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
