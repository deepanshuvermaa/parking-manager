import 'package:flutter/material.dart';
import '../services/simple_vehicle_service.dart';
import '../models/simple_vehicle.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SimpleParkingListScreen extends StatefulWidget {
  final String token;

  const SimpleParkingListScreen({super.key, required this.token});

  @override
  State<SimpleParkingListScreen> createState() => _SimpleParkingListScreenState();
}

class _SimpleParkingListScreenState extends State<SimpleParkingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SimpleVehicle> _allVehicles = [];
  List<SimpleVehicle> _parkedVehicles = [];
  List<SimpleVehicle> _exitedVehicles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVehicles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehicles = await SimpleVehicleService.getVehicles(widget.token);
      setState(() {
        _allVehicles = vehicles;
        _filterVehicles();
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

  void _filterVehicles() {
    final query = _searchQuery.toLowerCase();
    final filtered = query.isEmpty
        ? _allVehicles
        : _allVehicles.where((v) =>
            v.vehicleNumber.toLowerCase().contains(query) ||
            v.vehicleType.toLowerCase().contains(query) ||
            (v.ticketId?.toLowerCase().contains(query) ?? false)).toList();

    _parkedVehicles = filtered.where((v) => v.status == 'parked').toList();
    _exitedVehicles = filtered.where((v) => v.status == 'exited').toList();
  }

  Widget _buildVehicleList(List<SimpleVehicle> vehicles) {
    if (vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No vehicles found' : 'No matching vehicles',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final isParked = vehicle.status == 'parked';
        final duration = isParked
            ? DateTime.now().difference(vehicle.entryTime)
            : vehicle.exitTime != null
                ? vehicle.exitTime!.difference(vehicle.entryTime)
                : Duration.zero;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isParked ? Colors.green : Colors.grey,
              child: Text(
                vehicle.vehicleType[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isParked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PARKED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vehicle.vehicleType} • Duration: ${_formatDuration(duration)}'),
                if (vehicle.amount != null && !isParked)
                  Text(
                    'Amount: ₹${vehicle.amount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Ticket ID', vehicle.ticketId ?? 'N/A'),
                    _buildDetailRow('Vehicle Type', vehicle.vehicleType),
                    _buildDetailRow('Entry Time', Helpers.formatDateTime(vehicle.entryTime)),
                    if (vehicle.exitTime != null)
                      _buildDetailRow('Exit Time', Helpers.formatDateTime(vehicle.exitTime!)),
                    _buildDetailRow('Duration', _formatDuration(duration)),
                    if (vehicle.hourlyRate != null)
                      _buildDetailRow('Hourly Rate', '₹${vehicle.hourlyRate!.toStringAsFixed(2)}'),
                    if (vehicle.amount != null)
                      _buildDetailRow('Amount', '₹${vehicle.amount!.toStringAsFixed(2)}'),
                    if (vehicle.notes != null && vehicle.notes!.isNotEmpty)
                      _buildDetailRow('Notes', vehicle.notes!),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes} min';
    } else {
      return '$minutes minutes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Parking List'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'All (${_allVehicles.length})',
            ),
            Tab(
              text: 'Parked (${_parkedVehicles.length})',
            ),
            Tab(
              text: 'Exited (${_exitedVehicles.length})',
            ),
          ],
        ),
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
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterVehicles();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by vehicle number, type, or ticket ID',
                prefixIcon: const Icon(Icons.search),
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
                _buildStatItem(
                  'Total',
                  _allVehicles.length.toString(),
                  Icons.directions_car,
                ),
                _buildStatItem(
                  'Parked',
                  _parkedVehicles.length.toString(),
                  Icons.local_parking,
                ),
                _buildStatItem(
                  'Exited',
                  _exitedVehicles.length.toString(),
                  Icons.exit_to_app,
                ),
                _buildStatItem(
                  'Collection',
                  '₹${SimpleVehicleService.getTodayCollection().toStringAsFixed(0)}',
                  Icons.attach_money,
                ),
              ],
            ),
          ),

          // Vehicle lists
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVehicleList(_allVehicles),
                      _buildVehicleList(_parkedVehicles),
                      _buildVehicleList(_exitedVehicles),
                    ],
                  ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}