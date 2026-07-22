import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/receipt_service.dart';
import '../services/platform_printer_service.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;

  // Vehicle type choices for the booking form (local — independent of parking rates)
  static const List<String> _vehicleTypes = [
    'Car', 'Bike', 'Scooter', 'SUV', 'Van', 'Bus', 'Truck',
    'Auto Rickshaw', 'E-Rickshaw', 'Tempo', 'Mini Truck',
  ];

  String get _token => context.read<AuthProvider>().token ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _bookings = await BookingService.getBookings(_token);
    } catch (e) {
      print('Bookings load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  double get _totalBooked => _bookings.fold(0.0, (s, b) => s + b.totalFare);
  double get _totalCollected => _bookings.fold(0.0, (s, b) => s + b.amountPaid);
  double get _totalOutstanding =>
      _bookings.fold(0.0, (s, b) => s + (b.balance > 0 ? b.balance : 0));

  Future<void> _printSilently(String receipt, String okMsg) async {
    final connected = await PlatformPrinterService.isConnected();
    if (connected) {
      await PlatformPrinterService.printText(receipt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(okMsg), backgroundColor: Go2Colors.success),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer not connected'), backgroundColor: Go2Colors.warning),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: Go2Colors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(),
                Expanded(
                  child: _bookings.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                            itemCount: _bookings.length,
                            itemBuilder: (_, i) => _buildBookingCard(_bookings[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: Go2Colors.skyWash,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _summaryTile('Booked', _totalBooked, Go2Colors.primary),
          _summaryTile('Collected', _totalCollected, Go2Colors.success),
          _summaryTile('Outstanding', _totalOutstanding, Go2Colors.error),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Go2Colors.textSecondary)),
          const SizedBox(height: 2),
          Text('Rs. ${value.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.event_note_rounded, size: 64, color: Go2Colors.textHint),
        SizedBox(height: 12),
        Center(
          child: Text('No bookings yet',
              style: TextStyle(fontSize: 16, color: Go2Colors.textSecondary)),
        ),
        SizedBox(height: 4),
        Center(
          child: Text('Tap "New Booking" to create one',
              style: TextStyle(fontSize: 13, color: Go2Colors.textHint)),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Booking b) {
    final isPaid = b.isPaid;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Go2Radius.md)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Go2Radius.md),
        onTap: () => _openBookingSheet(b),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.customerName.isEmpty ? 'Customer' : b.customerName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusChip(b),
                ],
              ),
              if ((b.vehicleNumber != null && b.vehicleNumber!.isNotEmpty) ||
                  (b.vehicleType != null && b.vehicleType!.isNotEmpty)) ...[
                const SizedBox(height: 2),
                Text(
                  [b.vehicleNumber, b.vehicleType]
                      .where((x) => x != null && x.isNotEmpty)
                      .join(' • '),
                  style: const TextStyle(fontSize: 12, color: Go2Colors.textSecondary),
                ),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _amountBlock('Total', b.totalFare, Go2Colors.textPrimary),
                  _amountBlock('Paid', b.amountPaid, Go2Colors.success),
                  _amountBlock('Balance', b.balance < 0 ? 0 : b.balance,
                      isPaid ? Go2Colors.success : Go2Colors.error),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountBlock(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
        const SizedBox(height: 2),
        Text('Rs. ${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _statusChip(Booking b) {
    final paid = b.isPaid;
    final color = paid ? Go2Colors.success : Go2Colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Go2Radius.full),
      ),
      child: Text(
        paid ? 'PAID' : 'PARTIAL',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ============================================
  // CREATE BOOKING
  // ============================================

  void _openCreateSheet() {
    final customerCtl = TextEditingController();
    final mobileCtl = TextEditingController();
    final vehicleCtl = TextEditingController();
    final driverCtl = TextEditingController();
    final fromCtl = TextEditingController();
    final toCtl = TextEditingController();
    final fareCtl = TextEditingController();
    final advanceCtl = TextEditingController();
    String vehicleType = _vehicleTypes.first;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Go2Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Booking',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _field(customerCtl, 'Customer Name *', TextInputType.name),
                    _field(mobileCtl, 'Customer Mobile', TextInputType.phone, digits: true),
                    _field(vehicleCtl, 'Vehicle Number', TextInputType.text),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: vehicleType,
                      decoration: const InputDecoration(labelText: 'Vehicle Type'),
                      items: _vehicleTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setSheet(() => vehicleType = v ?? vehicleType),
                    ),
                    _field(driverCtl, 'Driver Name', TextInputType.name),
                    _field(fromCtl, 'From', TextInputType.text),
                    _field(toCtl, 'To', TextInputType.text),
                    _field(fareCtl, 'Total Fare *', TextInputType.number, decimal: true),
                    _field(advanceCtl, 'Advance', TextInputType.number, decimal: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = customerCtl.text.trim();
                                final fare = double.tryParse(fareCtl.text.trim()) ?? 0;
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                    content: Text('Customer name is required'),
                                    backgroundColor: Go2Colors.error));
                                  return;
                                }
                                if (fare <= 0) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                    content: Text('Enter a valid total fare'),
                                    backgroundColor: Go2Colors.error));
                                  return;
                                }
                                setSheet(() => saving = true);
                                final advance = double.tryParse(advanceCtl.text.trim()) ?? 0;
                                final booking = await BookingService.createBooking(
                                  token: _token,
                                  customerName: name,
                                  customerMobile: mobileCtl.text,
                                  vehicleNumber: vehicleCtl.text,
                                  vehicleType: vehicleType,
                                  driverName: driverCtl.text,
                                  fromLocation: fromCtl.text,
                                  toLocation: toCtl.text,
                                  totalFare: fare,
                                  advance: advance,
                                );
                                if (booking != null) {
                                  final receipt =
                                      await ReceiptService.generateBookingReceipt(booking);
                                  await _printSilently(receipt, '✓ Booking receipt printed');
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                await _loadData();
                              },
                        child: saving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create & Print'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(TextEditingController ctl, String label, TextInputType type,
      {bool digits = false, bool decimal = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: ctl,
        keyboardType: type,
        textCapitalization:
            type == TextInputType.name ? TextCapitalization.words : TextCapitalization.none,
        inputFormatters: digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : decimal
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  // ============================================
  // BOOKING DETAIL — record payment / close
  // ============================================

  void _openBookingSheet(Booking b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Go2Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.customerName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (b.bookingNumber != null)
                Text(b.bookingNumber!,
                    style: const TextStyle(fontSize: 12, color: Go2Colors.textHint)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _amountBlock('Total', b.totalFare, Go2Colors.textPrimary),
                  _amountBlock('Paid', b.amountPaid, Go2Colors.success),
                  _amountBlock('Balance', b.balance < 0 ? 0 : b.balance,
                      b.isPaid ? Go2Colors.success : Go2Colors.error),
                ],
              ),
              const SizedBox(height: 20),
              if (!b.isPaid)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPaymentDialog(b);
                    },
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Record Payment'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _closeBooking(b);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(b.isPaid ? 'Print Closing Receipt' : 'Close (Pay Balance)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPaymentDialog(Booking b) {
    final amountCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Record Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Balance: Rs. ${(b.balance < 0 ? 0 : b.balance).toStringAsFixed(0)}',
                  style: const TextStyle(color: Go2Colors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
                if (amount <= 0) return;
                Navigator.pop(ctx);
                final updated =
                    await BookingService.addPayment(_token, b.id, amount, 'Payment');
                if (updated != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✓ Payment recorded'), backgroundColor: Go2Colors.success));
                  if (updated.isPaid) {
                    final receipt =
                        await ReceiptService.generateBookingClosingReceipt(updated);
                    await _printSilently(receipt, '✓ Closing receipt printed');
                  }
                }
                await _loadData();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeBooking(Booking b) async {
    // Settle any outstanding balance, then print the closing receipt.
    Booking settled = b;
    if (b.balance > 0) {
      final updated = await BookingService.addPayment(_token, b.id, b.balance, 'Balance settled');
      if (updated != null) settled = updated;
    }
    final receipt = await ReceiptService.generateBookingClosingReceipt(settled);
    await _printSilently(receipt, '✓ Closing receipt printed');
    await _loadData();
  }
}
