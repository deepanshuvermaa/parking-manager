/// Taxi Booking Model
/// Represents a taxi/cab booking - completely separate from parking vehicles
class TaxiBooking {
  final String id;
  final String userId;

  // Booking Information
  final String ticketNumber;
  final DateTime bookingDate;

  // Customer Details
  final String customerName;
  final String customerMobile;

  // Vehicle Details
  final String vehicleName;
  final String vehicleNumber;

  // Trip Details
  final String fromLocation;
  final String toLocation;
  final double fareAmount;
  final DateTime? startTime;
  final DateTime? endTime;

  // Remarks (3 fields)
  final String? remarks1;
  final String? remarks2;
  final String? remarks3;

  // Driver Details
  final String driverName;
  final String driverMobile;

  // Status: booked, ongoing, completed, cancelled
  final String status;

  // Audit fields
  final DateTime createdAt;
  final DateTime updatedAt;

  TaxiBooking({
    required this.id,
    required this.userId,
    required this.ticketNumber,
    required this.bookingDate,
    required this.customerName,
    required this.customerMobile,
    required this.vehicleName,
    required this.vehicleNumber,
    required this.fromLocation,
    required this.toLocation,
    required this.fareAmount,
    this.startTime,
    this.endTime,
    this.remarks1,
    this.remarks2,
    this.remarks3,
    required this.driverName,
    required this.driverMobile,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON (from API)
  factory TaxiBooking.fromJson(Map<String, dynamic> json) {
    return TaxiBooking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ticketNumber: json['ticket_number'] as String,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      customerName: json['customer_name'] as String,
      customerMobile: json['customer_mobile'] as String,
      vehicleName: json['vehicle_name'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      fromLocation: json['from_location'] as String,
      toLocation: json['to_location'] as String,
      fareAmount: (json['fare_amount'] is String)
          ? double.parse(json['fare_amount'])
          : (json['fare_amount'] as num).toDouble(),
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      remarks1: json['remarks_1'] as String?,
      remarks2: json['remarks_2'] as String?,
      remarks3: json['remarks_3'] as String?,
      driverName: json['driver_name'] as String,
      driverMobile: json['driver_mobile'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON (for API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'ticket_number': ticketNumber,
      'booking_date': bookingDate.toIso8601String(),
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'vehicle_name': vehicleName,
      'vehicle_number': vehicleNumber,
      'from_location': fromLocation,
      'to_location': toLocation,
      'fare_amount': fareAmount,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'remarks_1': remarks1,
      'remarks_2': remarks2,
      'remarks_3': remarks3,
      'driver_name': driverName,
      'driver_mobile': driverMobile,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for API request (without id and timestamps)
  Map<String, dynamic> toApiJson() {
    return {
      'customerName': customerName,
      'customerMobile': customerMobile,
      'vehicleName': vehicleName,
      'vehicleNumber': vehicleNumber,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'fareAmount': fareAmount,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'remarks1': remarks1,
      'remarks2': remarks2,
      'remarks3': remarks3,
      'driverName': driverName,
      'driverMobile': driverMobile,
    };
  }

  /// Create a copy with updated fields
  TaxiBooking copyWith({
    String? id,
    String? userId,
    String? ticketNumber,
    DateTime? bookingDate,
    String? customerName,
    String? customerMobile,
    String? vehicleName,
    String? vehicleNumber,
    String? fromLocation,
    String? toLocation,
    double? fareAmount,
    DateTime? startTime,
    DateTime? endTime,
    String? remarks1,
    String? remarks2,
    String? remarks3,
    String? driverName,
    String? driverMobile,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxiBooking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      bookingDate: bookingDate ?? this.bookingDate,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      fareAmount: fareAmount ?? this.fareAmount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      remarks1: remarks1 ?? this.remarks1,
      remarks2: remarks2 ?? this.remarks2,
      remarks3: remarks3 ?? this.remarks3,
      driverName: driverName ?? this.driverName,
      driverMobile: driverMobile ?? this.driverMobile,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if booking is active (booked or ongoing)
  bool get isActive => status == 'booked' || status == 'ongoing';

  /// Check if trip is ongoing
  bool get isOngoing => status == 'ongoing';

  /// Check if trip is completed
  bool get isCompleted => status == 'completed';

  /// Check if booking is cancelled
  bool get isCancelled => status == 'cancelled';

  /// Get duration in minutes (if started)
  int? get durationMinutes {
    if (startTime == null) return null;
    final endTimeToUse = endTime ?? DateTime.now();
    return endTimeToUse.difference(startTime!).inMinutes;
  }

  /// Get formatted duration
  String get formattedDuration {
    final duration = durationMinutes;
    if (duration == null) return 'Not started';
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'booked':
        return 'Booked';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  String toString() {
    return 'TaxiBooking{ticket: $ticketNumber, customer: $customerName, from: $fromLocation, to: $toLocation, status: $status}';
  }
}
