import 'rate_tier.dart';

class VehicleType {
  final String id;
  final String name;
  final String icon;
  final double hourlyRate;
  final double? flatRate;
  final bool isActive;
  final List<RateTier>? rateTiers; // Optional tiered pricing

  VehicleType({
    required this.id,
    required this.name,
    required this.icon,
    required this.hourlyRate,
    this.flatRate,
    this.isActive = true,
    this.rateTiers,
  });

  VehicleType copyWith({
    String? id,
    String? name,
    String? icon,
    double? hourlyRate,
    double? flatRate,
    bool? isActive,
    List<RateTier>? rateTiers,
  }) {
    return VehicleType(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      flatRate: flatRate ?? this.flatRate,
      isActive: isActive ?? this.isActive,
      rateTiers: rateTiers ?? this.rateTiers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'hourlyRate': hourlyRate,
      'flatRate': flatRate,
      'isActive': isActive,
      'rateTiers': rateTiers?.map((tier) => tier.toJson()).toList(),
    };
  }

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    List<RateTier>? tiers;
    if (json['rateTiers'] != null) {
      tiers = (json['rateTiers'] as List)
          .map((tierJson) => RateTier.fromJson(tierJson))
          .toList();
    }

    return VehicleType(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      hourlyRate: json['hourlyRate'].toDouble(),
      flatRate: json['flatRate']?.toDouble(),
      isActive: json['isActive'] ?? true,
      rateTiers: tiers,
    );
  }

  /// Check if this vehicle type uses tiered pricing
  bool get usesTieredPricing => rateTiers != null && rateTiers!.isNotEmpty;

  /// Calculate amount using tiered pricing if available
  double calculateTieredAmount(double hours) {
    if (!usesTieredPricing) {
      // Fall back to regular hourly rate
      return hours * hourlyRate;
    }

    double totalAmount = 0.0;
    double remainingHours = hours;

    // Sort tiers by minHours to ensure proper calculation
    final sortedTiers = List<RateTier>.from(rateTiers!)
      ..sort((a, b) => a.minHours.compareTo(b.minHours));

    for (int i = 0; i < sortedTiers.length; i++) {
      final tier = sortedTiers[i];

      if (remainingHours <= 0) break;

      double tierHours;
      if (tier.maxHours != null) {
        // Calculate hours for this tier
        tierHours = (tier.maxHours! - tier.minHours + 1).toDouble();
        tierHours = tierHours > remainingHours ? remainingHours : tierHours;
      } else {
        // Last tier - all remaining hours
        tierHours = remainingHours;
      }

      totalAmount += tierHours * tier.rate;
      remainingHours -= tierHours;
    }

    return totalAmount;
  }

  /// Get pricing summary for display
  String get pricingSummary {
    if (usesTieredPricing) {
      return 'Tiered pricing (${rateTiers!.length} tiers)';
    } else {
      return 'Rs $hourlyRate/hr';
    }
  }

  @override
  String toString() {
    return 'VehicleType(id: $id, name: $name, icon: $icon, hourlyRate: $hourlyRate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}