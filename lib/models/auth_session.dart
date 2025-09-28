/// Authentication session model
/// Represents a user session with device information
class AuthSession {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final bool isGuest;
  final String token;
  final String? refreshToken;
  final String deviceId;
  final DateTime loginTime;
  final DateTime? expiryTime;
  final Map<String, dynamic>? metadata;

  AuthSession({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isGuest,
    required this.token,
    this.refreshToken,
    required this.deviceId,
    required this.loginTime,
    this.expiryTime,
    this.metadata,
  });

  /// Get display name for UI
  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email.split('@')[0];
    return isGuest ? 'Guest User' : 'User';
  }

  /// Check if session is expired
  bool get isExpired {
    if (expiryTime == null) return false;
    return DateTime.now().isAfter(expiryTime!);
  }

  /// Check if user is admin/owner
  bool get isAdmin => role == 'admin' || role == 'owner';

  /// Check if user is manager or above
  bool get canManageStaff => role == 'owner' || role == 'manager';

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
      'role': role,
      'isGuest': isGuest,
      'token': token,
      'refreshToken': refreshToken,
      'deviceId': deviceId,
      'loginTime': loginTime.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'user',
      isGuest: json['isGuest'] ?? false,
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'],
      deviceId: json['deviceId'] ?? '',
      loginTime: DateTime.parse(json['loginTime']),
      expiryTime: json['expiryTime'] != null
          ? DateTime.parse(json['expiryTime'])
          : null,
      metadata: json['metadata'],
    );
  }

  /// Create a guest session
  factory AuthSession.guest({
    required String guestName,
    required String deviceId,
  }) {
    final now = DateTime.now();
    return AuthSession(
      userId: 'guest_${now.millisecondsSinceEpoch}',
      email: '',
      fullName: guestName,
      role: 'guest',
      isGuest: true,
      token: 'guest_token_${now.millisecondsSinceEpoch}',
      deviceId: deviceId,
      loginTime: now,
      expiryTime: now.add(const Duration(hours: 24)), // Guest sessions expire in 24 hours
    );
  }

  /// Copy with modifications
  AuthSession copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? role,
    bool? isGuest,
    String? token,
    String? refreshToken,
    String? deviceId,
    DateTime? loginTime,
    DateTime? expiryTime,
    Map<String, dynamic>? metadata,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isGuest: isGuest ?? this.isGuest,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      deviceId: deviceId ?? this.deviceId,
      loginTime: loginTime ?? this.loginTime,
      expiryTime: expiryTime ?? this.expiryTime,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'AuthSession(userId: $userId, email: $email, role: $role, isGuest: $isGuest)';
  }
}