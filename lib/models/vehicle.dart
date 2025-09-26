import 'vehicle_type.dart';
import 'settings.dart';

class Vehicle {
  final String id;
  final String vehicleNumber;
  final VehicleType vehicleType;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String? ownerName;
  final String? ownerPhone;
  final double? totalAmount;
  final String? notes;
  final String ticketId;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.entryTime,
    this.exitTime,
    this.ownerName,
    this.ownerPhone,
    this.totalAmount,
    this.notes,
    required this.ticketId,
  });

  Duration get parkingDuration {
    final endTime = exitTime ?? DateTime.now();
    return endTime.difference(entryTime);
  }

  bool get isActive => exitTime == null;

  double calculateAmount({Settings? settings}) {
    final duration = parkingDuration;

    // Apply grace period if settings provided (should always pass settings!)
    int gracePeriodMinutes = settings?.gracePeriodMinutes ?? 0;
    final adjustedDuration = Duration(
      minutes: duration.inMinutes > gracePeriodMinutes
        ? duration.inMinutes - gracePeriodMinutes
        : 0
    );

    final hours = adjustedDuration.inMinutes / 60.0;

    if (vehicleType.flatRate != null) {
      double baseAmount = vehicleType.flatRate!;

      // Apply GST if enabled
      if (settings?.enableGST == true) {
        final gstAmount = baseAmount * (settings!.gstPercentage / 100);
        return baseAmount + gstAmount;
      }

      return baseAmount;
    }

    // Minimum 1 hour charge after grace period
    final chargeableHours = hours < 1 ? 1.0 : hours.ceilToDouble();

    // Use tiered pricing if available, otherwise use hourly rate
    double baseAmount;
    if (vehicleType.usesTieredPricing) {
      baseAmount = vehicleType.calculateTieredAmount(chargeableHours);
    } else {
      baseAmount = chargeableHours * vehicleType.hourlyRate;
    }

    // Apply GST if enabled
    if (settings?.enableGST == true) {
      final gstAmount = baseAmount * (settings!.gstPercentage / 100);
      return baseAmount + gstAmount;
    }

    return baseAmount;
  }

  Vehicle copyWith({
    String? id,
    String? vehicleNumber,
    VehicleType? vehicleType,
    DateTime? entryTime,
    DateTime? exitTime,
    String? ownerName,
    String? ownerPhone,
    double? totalAmount,
    String? notes,
    String? ticketId,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      ticketId: ticketId ?? this.ticketId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType.toJson(),
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime?.toIso8601String(),
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'totalAmount': totalAmount,
      'notes': notes,
      'ticketId': ticketId,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      vehicleNumber: json['vehicleNumber'],
      vehicleType: VehicleType.fromJson(json['vehicleType']),
      entryTime: DateTime.parse(json['entryTime']),
      exitTime: json['exitTime'] != null ? DateTime.parse(json['exitTime']) : null,
      ownerName: json['ownerName'],
      ownerPhone: json['ownerPhone'],
      totalAmount: json['totalAmount']?.toDouble(),
      notes: json['notes'],
      ticketId: json['ticketId'],
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, vehicleNumber: $vehicleNumber, vehicleType: ${vehicleType.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}