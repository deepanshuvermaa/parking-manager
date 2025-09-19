class VehicleType {
  final String id;
  final String name;
  final String icon;
  final double hourlyRate;
  final double? flatRate;
  final bool isActive;

  VehicleType({
    required this.id,
    required this.name,
    required this.icon,
    required this.hourlyRate,
    this.flatRate,
    this.isActive = true,
  });

  VehicleType copyWith({
    String? id,
    String? name,
    String? icon,
    double? hourlyRate,
    double? flatRate,
    bool? isActive,
  }) {
    return VehicleType(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      flatRate: flatRate ?? this.flatRate,
      isActive: isActive ?? this.isActive,
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
    };
  }

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      hourlyRate: json['hourlyRate'].toDouble(),
      flatRate: json['flatRate']?.toDouble(),
      isActive: json['isActive'] ?? true,
    );
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