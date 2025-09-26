class RateTier {
  final String id;
  final String name;
  final int minHours; // Minimum hours for this tier
  final int? maxHours; // Maximum hours for this tier (null for last tier)
  final double rate; // Rate per hour for this tier
  final bool isActive;

  RateTier({
    required this.id,
    required this.name,
    required this.minHours,
    this.maxHours,
    required this.rate,
    this.isActive = true,
  });

  RateTier copyWith({
    String? id,
    String? name,
    int? minHours,
    int? maxHours,
    double? rate,
    bool? isActive,
  }) {
    return RateTier(
      id: id ?? this.id,
      name: name ?? this.name,
      minHours: minHours ?? this.minHours,
      maxHours: maxHours ?? this.maxHours,
      rate: rate ?? this.rate,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minHours': minHours,
      'maxHours': maxHours,
      'rate': rate,
      'isActive': isActive,
    };
  }

  factory RateTier.fromJson(Map<String, dynamic> json) {
    return RateTier(
      id: json['id'],
      name: json['name'],
      minHours: json['minHours'],
      maxHours: json['maxHours'],
      rate: json['rate'].toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  /// Check if a duration in hours falls within this tier
  bool appliesToDuration(double hours) {
    if (hours < minHours) return false;
    if (maxHours != null && hours > maxHours!) return false;
    return true;
  }

  /// Get a human readable description of this tier
  String get description {
    if (maxHours != null) {
      return '$minHours-${maxHours}h @ Rs $rate/hr';
    } else {
      return '${minHours}h+ @ Rs $rate/hr';
    }
  }

  @override
  String toString() {
    return 'RateTier(id: $id, name: $name, range: $minHours-${maxHours ?? "∞"}h, rate: $rate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RateTier && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}