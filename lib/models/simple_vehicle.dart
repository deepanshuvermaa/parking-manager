// Simple vehicle model for working without providers
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
  String? notes;
  int? durationMinutes;

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
  });

  Duration get parkingDuration {
    final endTime = exitTime ?? DateTime.now();
    return endTime.difference(entryTime);
  }

  bool get isActive => status == 'parked';

  factory SimpleVehicle.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (from DB) and camelCase fields
    return SimpleVehicle(
      id: json['id'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'] ?? '',
      vehicleType: json['vehicle_type'] ?? json['vehicleType'] ?? 'Car',
      entryTime: (json['entry_time'] ?? json['entryTime']) != null
        ? DateTime.parse(json['entry_time'] ?? json['entryTime'])
        : DateTime.now(),
      exitTime: (json['exit_time'] ?? json['exitTime']) != null
        ? DateTime.parse(json['exit_time'] ?? json['exitTime'])
        : null,
      status: json['status'] ?? 'parked',
      ticketId: json['ticket_id'] ?? json['ticketId'],
      hourlyRate: (json['hourly_rate'] ?? json['hourlyRate'])?.toDouble(),
      minimumRate: (json['minimum_rate'] ?? json['minimumRate'])?.toDouble(),
      amount: json['amount']?.toDouble(),
      notes: json['notes'],
      durationMinutes: json['duration_minutes'] ?? json['durationMinutes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'entry_time': entryTime.toIso8601String(),
      'exit_time': exitTime?.toIso8601String(),
      'status': status,
      'ticket_id': ticketId,
      'hourly_rate': hourlyRate,
      'minimum_rate': minimumRate,
      'amount': amount,
      'notes': notes,
      'duration_minutes': durationMinutes,
    };
  }
}