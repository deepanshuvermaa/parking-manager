class SimpleVehicle {
  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final DateTime entryTime;
  DateTime? exitTime;
  String status;
  String? ticketId;
  double? hourlyRate;
  double? minimumRate;
  double? amount;
  String? notes; // Remarks
  int? durationMinutes;
  String? fromLocation;
  String? toLocation;
  String? bookedBy; // Booked by Name
  String? bookedByMobile; // Mob. no.
  String? driverName;
  String? driverMobile;
  double? fare;

  SimpleVehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.entryTime,
    this.exitTime,
    this.status = 'parked',
    this.ticketId,
    this.hourlyRate,
    this.minimumRate,
    this.amount,
    this.notes,
    this.durationMinutes,
    this.fromLocation,
    this.toLocation,
    this.bookedBy,
    this.bookedByMobile,
    this.driverName,
    this.driverMobile,
    this.fare,
  });

  Duration get parkingDuration => (exitTime ?? DateTime.now()).difference(entryTime);
  bool get isActive => status == 'parked';

  factory SimpleVehicle.fromJson(Map<String, dynamic> json) {
    return SimpleVehicle(
      id: json['id'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'] ?? '',
      vehicleType: _str(json['vehicle_type'] ?? json['vehicleType'] ?? 'Car'),
      entryTime: _parseTime(json['entry_time'] ?? json['entryTime']),
      exitTime: (json['exit_time'] ?? json['exitTime']) != null
        ? _parseTime(json['exit_time'] ?? json['exitTime']) : null,
      status: json['status'] ?? 'parked',
      ticketId: json['ticket_id'] ?? json['ticketId'],
      hourlyRate: _toDouble(json['hourly_rate'] ?? json['hourlyRate']),
      minimumRate: _toDouble(json['minimum_rate'] ?? json['minimumRate']),
      amount: _toDouble(json['amount']),
      notes: json['notes'],
      durationMinutes: json['duration_minutes'] ?? json['durationMinutes'],
      fromLocation: json['from_location'] ?? json['fromLocation'],
      toLocation: json['to_location'] ?? json['toLocation'],
      bookedBy: json['booked_by'] ?? json['bookedBy'],
      bookedByMobile: json['booked_by_mobile'] ?? json['bookedByMobile'],
      driverName: json['driver_name'] ?? json['driverName'],
      driverMobile: json['driver_mobile'] ?? json['driverMobile'],
      fare: _toDouble(json['fare']),
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

  static String _str(dynamic v) {
    if (v is String) return v;
    if (v is Map) return v['name'] ?? v['type'] ?? 'Car';
    return 'Car';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'vehicle_number': vehicleNumber, 'vehicle_type': vehicleType,
    'entry_time': entryTime.toUtc().toIso8601String(), 'exit_time': exitTime?.toUtc().toIso8601String(),
    'status': status, 'ticket_id': ticketId, 'hourly_rate': hourlyRate,
    'minimum_rate': minimumRate, 'amount': amount, 'notes': notes,
    'duration_minutes': durationMinutes, 'from_location': fromLocation,
    'to_location': toLocation, 'booked_by': bookedBy,
    'booked_by_mobile': bookedByMobile, 'driver_name': driverName,
    'driver_mobile': driverMobile, 'fare': fare,
  };
}
