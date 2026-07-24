import '../services/gst_service.dart';

class Booking {
  final String id;
  final String? userId;
  final String? bookingNumber;
  final String customerName;
  final String? customerMobile;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? driverName;
  final String? driverMobile;
  final String? fromLocation;
  final String? toLocation;
  double totalFare;
  double amountPaid;
  String status;
  final String? remarks;
  final DateTime bookingDate;

  Booking({
    required this.id,
    this.userId,
    this.bookingNumber,
    required this.customerName,
    this.customerMobile,
    this.vehicleNumber,
    this.vehicleType,
    this.driverName,
    this.driverMobile,
    this.fromLocation,
    this.toLocation,
    this.totalFare = 0,
    this.amountPaid = 0,
    this.status = 'partial',
    this.remarks,
    required this.bookingDate,
  });

  // GST-inclusive grand total — what the customer actually pays.
  // Uses the cached booking-GST config (GstService.refreshBookingGst()).
  double get grandTotal {
    if (GstService.bookingGstApplies && totalFare > 0) {
      return totalFare + totalFare * GstService.bookingGstRate / 100;
    }
    return totalFare;
  }

  // Balance remaining on the booking (GST-inclusive)
  double get balance => grandTotal - amountPaid;

  // Fully paid when nothing (or less) is left to collect
  bool get isPaid => balance <= 0.01;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: (json['id'] ?? '').toString(),
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      bookingNumber: json['booking_number'] ?? json['bookingNumber'],
      customerName: json['customer_name'] ?? json['customerName'] ?? '',
      customerMobile: json['customer_mobile'] ?? json['customerMobile'],
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
      vehicleType: json['vehicle_type'] ?? json['vehicleType'],
      driverName: json['driver_name'] ?? json['driverName'],
      driverMobile: json['driver_mobile'] ?? json['driverMobile'],
      fromLocation: json['from_location'] ?? json['fromLocation'],
      toLocation: json['to_location'] ?? json['toLocation'],
      totalFare: _toDouble(json['total_fare'] ?? json['totalFare']) ?? 0,
      amountPaid: _toDouble(json['amount_paid'] ?? json['amountPaid']) ?? 0,
      status: json['status'] ?? 'partial',
      remarks: json['remarks'],
      bookingDate: _parseTime(json['booking_date'] ?? json['bookingDate']),
    );
  }

  // Parse time — always returns local time regardless of whether input is UTC or local
  static DateTime _parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    final dt = DateTime.parse(v.toString());
    return dt.isUtc ? dt.toLocal() : dt;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'booking_number': bookingNumber,
        'customer_name': customerName,
        'customer_mobile': customerMobile,
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'driver_name': driverName,
        'driver_mobile': driverMobile,
        'from_location': fromLocation,
        'to_location': toLocation,
        'total_fare': totalFare,
        'amount_paid': amountPaid,
        'status': status,
        'remarks': remarks,
        'booking_date': bookingDate.toUtc().toIso8601String(),
      };
}
