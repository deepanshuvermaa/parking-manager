import 'dart:convert';

class VehicleRate {
  final String vehicleType;
  final double hourlyRate;
  final double minimumCharge;
  final int freeMinutes;
  final List<TimedRate> timedRates; // Optional time-based rates

  VehicleRate({
    required this.vehicleType,
    required this.hourlyRate,
    required this.minimumCharge,
    this.freeMinutes = 0,
    this.timedRates = const [],
  });

  /// Calculate fee based on duration
  double calculateFee(Duration duration) {
    // Check if we're still in free period
    if (duration.inMinutes <= freeMinutes) {
      return 0;
    }

    // Check if any time-based rates apply
    if (timedRates.isNotEmpty) {
      for (final timedRate in timedRates) {
        if (duration.inHours >= timedRate.afterHours) {
          return timedRate.flatRate ?? _calculateHourlyFee(duration, timedRate.hourlyRate ?? hourlyRate);
        }
      }
    }

    // Default hourly calculation
    return _calculateHourlyFee(duration, hourlyRate);
  }

  double _calculateHourlyFee(Duration duration, double rate) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    double totalFee = hours * rate;
    if (minutes > 0) {
      totalFee += rate; // Charge full hour for any partial hour
    }

    return totalFee < minimumCharge ? minimumCharge : totalFee;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'vehicleType': vehicleType,
      'hourlyRate': hourlyRate,
      'minimumCharge': minimumCharge,
      'freeMinutes': freeMinutes,
      'timedRates': timedRates.map((e) => e.toJson()).toList(),
    };
  }

  // Create from JSON
  factory VehicleRate.fromJson(Map<String, dynamic> json) {
    return VehicleRate(
      vehicleType: json['vehicleType'] as String,
      hourlyRate: (json['hourlyRate'] as num).toDouble(),
      minimumCharge: (json['minimumCharge'] as num).toDouble(),
      freeMinutes: json['freeMinutes'] as int? ?? 0,
      timedRates: (json['timedRates'] as List<dynamic>?)
              ?.map((e) => TimedRate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Encode to string for SharedPreferences
  String encode() => jsonEncode(toJson());

  // Decode from string
  static VehicleRate decode(String str) => VehicleRate.fromJson(jsonDecode(str));

  VehicleRate copyWith({
    String? vehicleType,
    double? hourlyRate,
    double? minimumCharge,
    int? freeMinutes,
    List<TimedRate>? timedRates,
  }) {
    return VehicleRate(
      vehicleType: vehicleType ?? this.vehicleType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      minimumCharge: minimumCharge ?? this.minimumCharge,
      freeMinutes: freeMinutes ?? this.freeMinutes,
      timedRates: timedRates ?? this.timedRates,
    );
  }
}

/// Time-based rate configuration
class TimedRate {
  final int afterHours; // Apply this rate after X hours
  final double? hourlyRate; // Use this hourly rate (null = use default)
  final double? flatRate; // Or use a flat rate instead

  TimedRate({
    required this.afterHours,
    this.hourlyRate,
    this.flatRate,
  });

  Map<String, dynamic> toJson() {
    return {
      'afterHours': afterHours,
      'hourlyRate': hourlyRate,
      'flatRate': flatRate,
    };
  }

  factory TimedRate.fromJson(Map<String, dynamic> json) {
    return TimedRate(
      afterHours: json['afterHours'] as int,
      hourlyRate: json['hourlyRate'] != null ? (json['hourlyRate'] as num).toDouble() : null,
      flatRate: json['flatRate'] != null ? (json['flatRate'] as num).toDouble() : null,
    );
  }

  TimedRate copyWith({
    int? afterHours,
    double? hourlyRate,
    double? flatRate,
  }) {
    return TimedRate(
      afterHours: afterHours ?? this.afterHours,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      flatRate: flatRate ?? this.flatRate,
    );
  }
}
