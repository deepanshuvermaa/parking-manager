class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastSeen;
  final bool isActive;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'lastSeen': lastSeen.toIso8601String(),
        'isActive': isActive,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['deviceId'] ?? '',
        deviceName: json['deviceName'] ?? '',
        platform: json['platform'] ?? '',
        lastSeen: DateTime.parse(json['lastSeen'] ?? DateTime.now().toIso8601String()),
        isActive: json['isActive'] ?? false,
      );
}