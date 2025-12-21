import 'package:flutter/material.dart';
import '../models/taxi_booking.dart';
import '../services/taxi_booking_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'taxi_booking_form_screen.dart';

/// Taxi Service Screen
/// Shows booking queue: booked, ongoing, and completed trips
/// Completely separate from parking operations
class TaxiServiceScreen extends StatefulWidget {
  final String token;

  const TaxiServiceScreen({super.key, required this.token});

  @override
  State<TaxiServiceScreen> createState() => _TaxiServiceScreenState();
}

class _TaxiServiceScreenState extends State<TaxiServiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TaxiBooking> _allBookings = [];
  Map<String, dynamic> _counts = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await TaxiBookingService.getBookings(widget.token);
      setState(() {
        _allBookings = result['bookings'] as List<TaxiBooking>;
        _counts = result['counts'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bookings: $e';
        _isLoading = false;
      });
    }
  }

  List<TaxiBooking> _getBookingsByStatus(String status) {
    if (status == 'all') return _allBookings;
    return _allBookings.where((b) => b.status == status).toList();
  }

  Future<void> _startTrip(TaxiBooking booking) async {
    try {
      await TaxiBookingService.startTrip(widget.token, booking.id);
      _showSnackBar('Trip started successfully', Colors.green);
      _loadBookings();
    } catch (e) {
      _showSnackBar('Failed to start trip: $e', Colors.red);
    }
  }

  Future<void> _completeTrip(TaxiBooking booking) async {
    // Show dialog to confirm completion and optionally update fare
    final fareController = TextEditingController(
      text: booking.fareAmount.toString(),
    );

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Complete trip for ${booking.customerName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: fareController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Final Fare Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (shouldComplete == true && mounted) {
      try {
        final fareAmount = double.tryParse(fareController.text);
        await TaxiBookingService.completeTrip(
          widget.token,
          booking.id,
          fareAmount: fareAmount,
        );
        _showSnackBar('Trip completed successfully', Colors.green);
        _loadBookings();
      } catch (e) {
        _showSnackBar('Failed to complete trip: $e', Colors.red);
      }
    }
  }

  Future<void> _cancelBooking(TaxiBooking booking) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Cancel booking for ${booking.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      try {
        await TaxiBookingService.cancelBooking(widget.token, booking.id);
        _showSnackBar('Booking cancelled', Colors.orange);
        _loadBookings();
      } catch (e) {
        _showSnackBar('Failed to cancel booking: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteBooking(TaxiBooking booking) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text('Permanently delete booking for ${booking.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await TaxiBookingService.deleteBooking(widget.token, booking.id);
        _showSnackBar('Booking deleted', Colors.grey);
        _loadBookings();
      } catch (e) {
        _showSnackBar('Failed to delete booking: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToForm({TaxiBooking? booking}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaxiBookingFormScreen(
          token: widget.token,
          booking: booking,
        ),
      ),
    );

    if (result == true) {
      _loadBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookedCount = int.tryParse(_counts['booked_count']?.toString() ?? '0') ?? 0;
    final ongoingCount = int.tryParse(_counts['ongoing_count']?.toString() ?? '0') ?? 0;
    final completedCount = int.tryParse(_counts['completed_count']?.toString() ?? '0') ?? 0;
    final totalCount = int.tryParse(_counts['total_count']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Taxi Service'),
        backgroundColor: const Color(0xFFFFA726), // Orange/Amber for taxi
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'All ($totalCount)'),
            Tab(text: 'Booked ($bookedCount)'),
            Tab(text: 'Ongoing ($ongoingCount)'),
            Tab(text: 'Completed ($completedCount)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadBookings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingList(_getBookingsByStatus('all')),
                    _buildBookingList(_getBookingsByStatus('booked')),
                    _buildBookingList(_getBookingsByStatus('ongoing')),
                    _buildBookingList(_getBookingsByStatus('completed')),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFFFFA726),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Booking', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBookingList(List<TaxiBooking> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No bookings yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a new booking',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(TaxiBooking booking) {
    Color statusColor;
    IconData statusIcon;

    switch (booking.status) {
      case 'booked':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      case 'ongoing':
        statusColor = Colors.orange;
        statusIcon = Icons.directions_car;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToForm(booking: booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Ticket number and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.ticketNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          booking.statusDisplay,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Customer info
              Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          booking.customerMobile,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.trip_origin, size: 16, color: Colors.green),
                      Container(
                        width: 2,
                        height: 24,
                        color: Colors.grey[300],
                      ),
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.fromLocation,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          booking.toLocation,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vehicle and driver info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${booking.vehicleName} - ${booking.vehicleNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${booking.driverName} - ${booking.driverMobile}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fare and time info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fare',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          formatCurrency(booking.fareAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (booking.startTime != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          booking.formattedDuration,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Action buttons
              if (booking.status != 'cancelled' && booking.status != 'completed')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (booking.status == 'booked') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _startTrip(booking),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Start Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelBooking(booking),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      if (booking.status == 'ongoing') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _completeTrip(booking),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
