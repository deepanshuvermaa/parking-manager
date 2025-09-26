class User {
  final String id;
  final String? username;
  final String? email;
  final String? name;
  final String? fullName;
  final String? password;
  final String role;
  final String? businessId;
  final String? deviceId;
  final String? currentDeviceId;
  final bool isGuest;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final Map<String, dynamic>? metadata;
  final DateTime? trialEndDate;
  final String? subscriptionType;
  final List<String>? features;

  User({
    required this.id,
    this.username,
    this.email,
    this.name,
    this.fullName,
    this.password,
    this.role = 'user',
    this.businessId,
    this.deviceId,
    this.currentDeviceId,
    this.isGuest = false,
    required this.createdAt,
    this.lastLogin,
    this.metadata,
    this.trialEndDate,
    this.subscriptionType,
    this.features,
  });

  bool get canAccess {
    // Premium users always have access
    if (subscriptionType == 'premium') return true;

    // Admin users always have access
    if (role == 'admin') return true;

    // For trial or guest users, check trial expiration
    if (isGuest || subscriptionType == 'trial') {
      // If no trial end date set, give 7 days from creation
      if (trialEndDate == null) {
        final defaultTrialEnd = createdAt.add(Duration(days: 7));
        return DateTime.now().isBefore(defaultTrialEnd);
      }
      return DateTime.now().isBefore(trialEndDate!);
    }

    // Default to true for regular users (backwards compatibility)
    return true;
  }

  int get remainingTrialDays {
    if (trialEndDate != null) {
      return trialEndDate!.difference(DateTime.now()).inDays;
    }
    return 0;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'],
      email: json['email'],
      name: json['name'],
      fullName: json['fullName'] ?? json['name'],
      password: json['password'],
      role: json['role'] ?? 'user',
      businessId: json['businessId'],
      deviceId: json['deviceId'],
      currentDeviceId: json['currentDeviceId'],
      isGuest: json['isGuest'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      metadata: json['metadata'],
      trialEndDate: json['trialEndDate'] != null
          ? DateTime.parse(json['trialEndDate'])
          : null,
      subscriptionType: json['subscriptionType'],
      features: json['features'] != null
          ? List<String>.from(json['features'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'fullName': fullName,
      'password': password,
      'role': role,
      'businessId': businessId,
      'deviceId': deviceId,
      'currentDeviceId': currentDeviceId,
      'isGuest': isGuest,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'metadata': metadata,
      'trialEndDate': trialEndDate?.toIso8601String(),
      'subscriptionType': subscriptionType,
      'features': features,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? fullName,
    String? password,
    String? role,
    String? businessId,
    String? deviceId,
    String? currentDeviceId,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? lastLogin,
    Map<String, dynamic>? metadata,
    DateTime? trialEndDate,
    String? subscriptionType,
    List<String>? features,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      password: password ?? this.password,
      role: role ?? this.role,
      businessId: businessId ?? this.businessId,
      deviceId: deviceId ?? this.deviceId,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      metadata: metadata ?? this.metadata,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      features: features ?? this.features,
    );
  }
}