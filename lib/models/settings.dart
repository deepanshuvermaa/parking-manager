class Settings {
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String currency;
  final String timezone;
  final bool autoPrint;
  final String? primaryPrinterId;
  final int gracePeriodMinutes;
  final String statePrefix;
  final bool enableGST;
  final String gstNumber;
  final double gstPercentage;
  final String ticketIdPrefix;
  final int nextTicketNumber;

  Settings({
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.autoPrint = true,
    this.primaryPrinterId,
    this.gracePeriodMinutes = 15,
    this.statePrefix = 'UP',
    this.enableGST = false,
    this.gstNumber = '',
    this.gstPercentage = 18.0,
    this.ticketIdPrefix = 'PKE',
    this.nextTicketNumber = 1,
  });

  Settings copyWith({
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? currency,
    String? timezone,
    bool? autoPrint,
    String? primaryPrinterId,
    int? gracePeriodMinutes,
    String? statePrefix,
    bool? enableGST,
    String? gstNumber,
    double? gstPercentage,
    String? ticketIdPrefix,
    int? nextTicketNumber,
  }) {
    return Settings(
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      autoPrint: autoPrint ?? this.autoPrint,
      primaryPrinterId: primaryPrinterId ?? this.primaryPrinterId,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      statePrefix: statePrefix ?? this.statePrefix,
      enableGST: enableGST ?? this.enableGST,
      gstNumber: gstNumber ?? this.gstNumber,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      ticketIdPrefix: ticketIdPrefix ?? this.ticketIdPrefix,
      nextTicketNumber: nextTicketNumber ?? this.nextTicketNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'currency': currency,
      'timezone': timezone,
      'autoPrint': autoPrint,
      'primaryPrinterId': primaryPrinterId,
      'gracePeriodMinutes': gracePeriodMinutes,
      'statePrefix': statePrefix,
      'enableGST': enableGST,
      'gstNumber': gstNumber,
      'gstPercentage': gstPercentage,
      'ticketIdPrefix': ticketIdPrefix,
      'nextTicketNumber': nextTicketNumber,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      businessName: json['businessName'] ?? 'ParkEase Parking',
      businessAddress: json['businessAddress'] ?? '',
      businessPhone: json['businessPhone'] ?? '',
      currency: json['currency'] ?? 'INR',
      timezone: json['timezone'] ?? 'Asia/Kolkata',
      autoPrint: json['autoPrint'] ?? true,
      primaryPrinterId: json['primaryPrinterId'],
      gracePeriodMinutes: json['gracePeriodMinutes'] ?? 15,
      statePrefix: json['statePrefix'] ?? 'UP',
      enableGST: json['enableGST'] ?? false,
      gstNumber: json['gstNumber'] ?? '',
      gstPercentage: (json['gstPercentage'] ?? 18.0).toDouble(),
      ticketIdPrefix: json['ticketIdPrefix'] ?? 'PKE',
      nextTicketNumber: json['nextTicketNumber'] ?? 1,
    );
  }

  @override
  String toString() {
    return 'Settings(businessName: $businessName, autoPrint: $autoPrint)';
  }
}