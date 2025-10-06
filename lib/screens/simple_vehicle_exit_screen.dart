import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_vehicle_service.dart';
import '../services/simple_bluetooth_service.dart';
import '../services/receipt_service.dart';
import '../models/simple_vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SimpleVehicleExitScreen extends StatefulWidget {
  final String token;

  const SimpleVehicleExitScreen({super.key, required this.token});

  @override
  State<SimpleVehicleExitScreen> createState() => _SimpleVehicleExitScreenState();
}

class _SimpleVehicleExitScreenState extends State<SimpleVehicleExitScreen> {
  final _searchController = TextEditingController();
  List<SimpleVehicle> _allVehicles = [];
  List<SimpleVehicle> _filteredVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehicles = await SimpleVehicleService.getVehicles(widget.token);
      setState(() {
        _allVehicles = vehicles.where((v) => v.status == 'parked').toList();
        _filteredVehicles = _allVehicles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterVehicles(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVehicles = _allVehicles;
      } else {
        _filteredVehicles = _allVehicles
            .where((v) =>
                v.vehicleNumber.toLowerCase().contains(query.toLowerCase()) ||
                (v.ticketId?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _showExitDialog(SimpleVehicle vehicle) {
    final entryTime = vehicle.entryTime;
    final exitTime = DateTime.now();
    final duration = exitTime.difference(entryTime);

    // Calculate fee
    final amount = SimpleVehicleService.calculateFee(
      entryTime: entryTime,
      vehicleType: vehicle.vehicleType,
      exitTime: exitTime,
      hourlyRate: vehicle.hourlyRate,
      minimumRate: vehicle.minimumRate,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Vehicle Exit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Vehicle', vehicle.vehicleNumber),
            _buildDetailRow('Type', vehicle.vehicleType),
            _buildDetailRow('Ticket ID', vehicle.ticketId ?? 'N/A'),
            const Divider(height: 24),
            _buildDetailRow('Entry Time', Helpers.formatDateTime(entryTime)),
            _buildDetailRow('Exit Time', Helpers.formatDateTime(exitTime)),
            _buildDetailRow('Duration', _formatDuration(duration)),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
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
              Navigator.pop(context);
              _processExit(vehicle, amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              SimpleBluetoothService.isConnected ? 'Confirm & Print' : 'Confirm Exit',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processExit(SimpleVehicle vehicle, double amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing vehicle exit...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exitedVehicle = await SimpleVehicleService.exitVehicle(
        token: widget.token,
        vehicleId: vehicle.id,
        amount: amount,
      );

      if (exitedVehicle != null) {
        Navigator.pop(context); // Close loading dialog

        // Check auto-print setting
        final prefs = await SharedPreferences.getInstance();
        final autoPrint = prefs.getBool('auto_print_exit') ?? true;

        // Auto-print if enabled and printer connected
        if (autoPrint && SimpleBluetoothService.isConnected) {
          await _printExitReceipt(exitedVehicle, amount);
        }

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Exit Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_car,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount Collected: ₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vehicle has been successfully exited.',
                  textAlign: TextAlign.center,
                ),
                if (autoPrint && SimpleBluetoothService.isConnected)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '✓ Receipt printed automatically',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
              ],
            ),
            actions: [
              if (SimpleBluetoothService.isConnected)
                TextButton.icon(
                  icon: const Icon(Icons.print),
                  label: Text(autoPrint ? 'Print Again' : 'Print Receipt'),
                  onPressed: () async {
                    await _printExitReceipt(exitedVehicle, amount);
                  },
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  _loadVehicles(); // Refresh the list
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process exit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} $minutes min';
    } else {
      return '$minutes minutes';
    }
  }

  Future<void> _printExitReceipt(SimpleVehicle vehicle, double amount) async {
    try {
      final duration = vehicle.exitTime != null
          ? vehicle.exitTime!.difference(vehicle.entryTime)
          : DateTime.now().difference(vehicle.entryTime);

      // Generate receipt
      final receipt = await ReceiptService.generateExitReceipt(
        vehicle,
        amount,
        duration,
      );

      // Print receipt
      final success = await SimpleBluetoothService.printReceipt(receipt);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Exit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicles,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterVehicles,
              decoration: InputDecoration(
                hintText: 'Search by vehicle number or ticket ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterVehicles('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Statistics bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Text(
                    'Parked Vehicles: ${_filteredVehicles.length > 999 ? '999+' : _filteredVehicles.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    'Total: ${_allVehicles.length > 999 ? '999+' : _allVehicles.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Vehicle list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVehicles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No parked vehicles'
                                  : 'No vehicles found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = _filteredVehicles[index];
                          final duration = DateTime.now().difference(vehicle.entryTime);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  vehicle.vehicleType[0],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                vehicle.vehicleNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${vehicle.vehicleType}'),
                                  Text('Duration: ${_formatDuration(duration)}'),
                                  if (vehicle.ticketId != null)
                                    Text('Ticket: ${vehicle.ticketId}'),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _showExitDialog(vehicle),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'EXIT',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
        ),
      ),
    );
  }
}