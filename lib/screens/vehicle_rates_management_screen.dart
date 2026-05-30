import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/vehicle_rate_service.dart';
import '../services/simple_vehicle_service.dart';
import '../models/vehicle_rate.dart';

class VehicleRatesManagementScreen extends StatefulWidget {
  const VehicleRatesManagementScreen({super.key});

  @override
  State<VehicleRatesManagementScreen> createState() => _VehicleRatesManagementScreenState();
}

class _VehicleRatesManagementScreenState extends State<VehicleRatesManagementScreen> {
  List<Map<String, dynamic>> _rates = [];

  static const _icons = <String, IconData>{
    'Bike': Icons.two_wheeler,
    'Scooter': Icons.two_wheeler,
    'Car': Icons.directions_car,
    'SUV': Icons.directions_car_filled,
    'Van': Icons.airport_shuttle,
    'Bus': Icons.directions_bus,
    'Truck': Icons.local_shipping,
    'Mini Truck': Icons.local_shipping,
    'Tempo': Icons.local_shipping,
    'Auto Rickshaw': Icons.electric_rickshaw,
    'E-Rickshaw': Icons.electric_rickshaw,
    'Cycle': Icons.pedal_bike,
    'E-Cycle': Icons.pedal_bike,
  };

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final saved = await VehicleRateService.loadRates();
    final types = SimpleVehicleService.getVehicleTypes();
    final list = <Map<String, dynamic>>[];
    for (final type in types) {
      final match = saved.where((r) => r.vehicleType == type);
      final defaults = SimpleVehicleService.getDefaultRate(type);
      list.add({
        'type': type,
        'hourly': match.isNotEmpty ? match.first.hourlyRate : defaults['hourly'],
        'minimum': match.isNotEmpty ? match.first.minimumCharge : defaults['minimum'],
        'minimumDurationMinutes': match.isNotEmpty ? match.first.minimumDurationMinutes : (defaults['minimumDurationMinutes'] ?? 30),
      });
    }
    setState(() => _rates = list);
  }

  Future<void> _editRate(int index) async {
    final rate = _rates[index];
    final hourlyCtrl = TextEditingController(text: rate['hourly'].toStringAsFixed(0));
    final minCtrl = TextEditingController(text: rate['minimum'].toStringAsFixed(0));
    final durationCtrl = TextEditingController(text: (rate['minimumDurationMinutes'] ?? 30).toString());
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${rate['type']} Rate'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: hourlyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hourly Rate (₹)'),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum Charge (₹)'),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Duration (minutes)',
                  helperText: 'Parking within this time = minimum charge',
                ),
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid minutes' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final rates = await VehicleRateService.loadRates();
      final idx = rates.indexWhere((r) => r.vehicleType == rate['type']);
      final hourly = double.parse(hourlyCtrl.text);
      final minimum = double.parse(minCtrl.text);
      final minDuration = int.parse(durationCtrl.text);
      if (idx != -1) {
        rates[idx] = rates[idx].copyWith(hourlyRate: hourly, minimumCharge: minimum, minimumDurationMinutes: minDuration);
      } else {
        rates.add(VehicleRate(
          vehicleType: rate['type'],
          hourlyRate: hourly,
          minimumCharge: minimum,
          freeMinutes: 5,
          minimumDurationMinutes: minDuration,
        ));
      }
      await VehicleRateService.saveRates(rates);
      _loadRates();
    }
  }

  Future<void> _addNewType() async {
    final nameCtrl = TextEditingController();
    final hourlyCtrl = TextEditingController(text: '20');
    final minCtrl = TextEditingController(text: '20');
    final durationCtrl = TextEditingController(text: '30');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Vehicle Type'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Type Name (e.g. Tractor)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: hourlyCtrl, decoration: const InputDecoration(labelText: 'Hourly Rate (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextFormField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Minimum Charge (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextFormField(
              controller: durationCtrl,
              decoration: const InputDecoration(labelText: 'Minimum Duration (minutes)', helperText: 'Parking within this time = minimum charge'),
              keyboardType: TextInputType.number,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Add')),
        ],
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final rates = await VehicleRateService.loadRates();
      rates.add(VehicleRate(
        vehicleType: nameCtrl.text.trim(),
        hourlyRate: double.tryParse(hourlyCtrl.text) ?? 20,
        minimumCharge: double.tryParse(minCtrl.text) ?? 20,
        freeMinutes: 5,
        minimumDurationMinutes: int.tryParse(durationCtrl.text) ?? 30,
      ));
      await VehicleRateService.saveRates(rates);
      _loadRates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Go2Colors.canvas,
      appBar: AppBar(title: const Text('Vehicle Rates')),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _addNewType,
        child: const Icon(Icons.add),
      ),
      body: _rates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildCard(i),
            ),
    );
  }

  Widget _buildCard(int index) {
    final rate = _rates[index];
    final minDur = rate['minimumDurationMinutes'] ?? 30;
    return Card(
      child: ListTile(
        leading: Icon(_icons[rate['type']] ?? Icons.directions_car, color: Go2Colors.primary),
        title: Text(rate['type'], style: const TextStyle(color: Go2Colors.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '₹${rate['hourly'].toStringAsFixed(0)}/hr • Min ₹${rate['minimum'].toStringAsFixed(0)} (≤${minDur}min)',
          style: const TextStyle(color: Go2Colors.textSecondary, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Go2Colors.primary, size: 20),
          onPressed: () => _editRate(index),
        ),
      ),
    );
  }
}
