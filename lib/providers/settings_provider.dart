import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  Settings _settings = Settings(
    businessName: 'ParkEase Parking',
    businessAddress: '123 Main Street, City',
    businessPhone: '+91 9876543210',
    currency: 'INR',
    timezone: 'Asia/Kolkata',
    autoPrint: true,
    primaryPrinterId: null,
    gracePeriodMinutes: 15,
    statePrefix: 'UP',
    enableGST: false,
    gstNumber: '',
    gstPercentage: 18.0,
    ticketIdPrefix: 'PKE',
    nextTicketNumber: 1,
  );

  // Additional settings not in the Settings model yet
  String _printerFormat = '2"'; // 2" or 3"
  bool _enableAdvancedReports = false;
  bool _enableMultiLanguage = false;
  bool _enableSmsNotifications = false;
  bool _showQRCode = true;
  String _receiptFooterText = 'Thank you!';

  Settings get settings => _settings;
  String get printerFormat => _printerFormat;
  bool get enableAdvancedReports => _enableAdvancedReports;
  bool get enableMultiLanguage => _enableMultiLanguage;
  bool get enableSmsNotifications => _enableSmsNotifications;
  bool get showQRCode => _showQRCode;
  String get receiptFooterText => _receiptFooterText;

  SettingsProvider() {
    // Load settings immediately when provider is created
    loadSettings();
  }

  /// Persist settings to SharedPreferences every time they change
  Future<void> _persistSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save main settings
      await prefs.setString('settings', jsonEncode(_settings.toJson()));

      // Save additional settings
      await prefs.setString('printerFormat', _printerFormat);
      await prefs.setBool('enableAdvancedReports', _enableAdvancedReports);
      await prefs.setBool('enableMultiLanguage', _enableMultiLanguage);
      await prefs.setBool('enableSmsNotifications', _enableSmsNotifications);
      await prefs.setBool('showQRCode', _showQRCode);
      await prefs.setString('receiptFooterText', _receiptFooterText);

      debugPrint('✅ Settings persisted to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error persisting settings: $e');
    }
  }

  /// Load all settings from SharedPreferences or backend
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // First, load from local storage
    final settingsJson = prefs.getString('settings');
    if (settingsJson != null) {
      try {
        _settings = Settings.fromJson(jsonDecode(settingsJson));
        debugPrint('✅ Settings loaded from SharedPreferences');
      } catch (e) {
        debugPrint('❌ Error parsing local settings: $e');
      }
    }

    // Load additional settings
    _printerFormat = prefs.getString('printerFormat') ?? '2"';
    _enableAdvancedReports = prefs.getBool('enableAdvancedReports') ?? false;
    _enableMultiLanguage = prefs.getBool('enableMultiLanguage') ?? false;
    _enableSmsNotifications = prefs.getBool('enableSmsNotifications') ?? false;
    _showQRCode = prefs.getBool('showQRCode') ?? true;
    _receiptFooterText = prefs.getString('receiptFooterText') ?? 'Thank you!';

    // Try to sync with backend if available
    try {
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        final backendSettings = await ApiService.getSettings();
        if (backendSettings != null) {
          _settings = Settings.fromJson(backendSettings);
          await _persistSettings(); // Save backend settings locally
          debugPrint('✅ Settings synced from backend');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not sync with backend, using local settings: $e');
    }

    notifyListeners();
  }

  /// Update entire settings object
  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    await _persistSettings();

    // Try to sync with backend
    try {
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        await ApiService.updateSettings(_settings.toJson());
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing settings to backend: $e');
    }

    notifyListeners();
  }

  /// Update business information
  Future<void> updateBusinessInfo({
    String? name,
    String? address,
    String? phone,
  }) async {
    _settings = _settings.copyWith(
      businessName: name ?? _settings.businessName,
      businessAddress: address ?? _settings.businessAddress,
      businessPhone: phone ?? _settings.businessPhone,
    );
    await _persistSettings();
    notifyListeners();
  }

  /// Update business name
  Future<void> updateBusinessName(String name) async {
    _settings = _settings.copyWith(businessName: name);
    await _persistSettings();
    notifyListeners();
  }

  /// Update business address
  Future<void> updateBusinessAddress(String address) async {
    _settings = _settings.copyWith(businessAddress: address);
    await _persistSettings();
    notifyListeners();
  }

  /// Update business phone
  Future<void> updateBusinessPhone(String phone) async {
    _settings = _settings.copyWith(businessPhone: phone);
    await _persistSettings();
    notifyListeners();
  }

  /// Update auto-print setting
  Future<void> updateAutoPrint(bool autoPrint) async {
    _settings = _settings.copyWith(autoPrint: autoPrint);
    await _persistSettings();
    notifyListeners();
  }

  /// Update primary printer
  Future<void> updatePrimaryPrinter(String? printerId) async {
    _settings = _settings.copyWith(primaryPrinterId: printerId);
    await _persistSettings();
    notifyListeners();
  }

  /// Update grace period
  Future<void> updateGracePeriod(int minutes) async {
    _settings = _settings.copyWith(gracePeriodMinutes: minutes);
    await _persistSettings();
    notifyListeners();
  }

  /// Update state prefix
  Future<void> updateStatePrefix(String prefix) async {
    _settings = _settings.copyWith(statePrefix: prefix.toUpperCase());
    await _persistSettings();
    notifyListeners();
  }

  /// Update GST settings
  Future<void> updateGSTSettings({
    bool? enableGST,
    String? gstNumber,
    double? gstPercentage,
  }) async {
    _settings = _settings.copyWith(
      enableGST: enableGST ?? _settings.enableGST,
      gstNumber: gstNumber ?? _settings.gstNumber,
      gstPercentage: gstPercentage ?? _settings.gstPercentage,
    );
    await _persistSettings();
    notifyListeners();
  }

  /// Update ticket ID prefix
  Future<void> updateTicketIdPrefix(String prefix) async {
    _settings = _settings.copyWith(ticketIdPrefix: prefix.toUpperCase());
    await _persistSettings();
    notifyListeners();
  }

  /// Get next ticket number and increment it
  Future<String> generateNextTicketId() async {
    final ticketId = '${_settings.ticketIdPrefix}${_settings.nextTicketNumber.toString().padLeft(6, '0')}';
    _settings = _settings.copyWith(nextTicketNumber: _settings.nextTicketNumber + 1);
    await _persistSettings();
    notifyListeners();
    return ticketId;
  }

  /// Update printer format (2" or 3")
  Future<void> updatePrinterFormat(String format) async {
    _printerFormat = format;
    await _persistSettings();
    notifyListeners();
  }

  /// Update advanced reports setting
  Future<void> updateAdvancedReports(bool enabled) async {
    _enableAdvancedReports = enabled;
    await _persistSettings();
    notifyListeners();
  }

  /// Update multi-language setting
  Future<void> updateMultiLanguage(bool enabled) async {
    _enableMultiLanguage = enabled;
    await _persistSettings();
    notifyListeners();
  }

  /// Update SMS notifications setting
  Future<void> updateSmsNotifications(bool enabled) async {
    _enableSmsNotifications = enabled;
    await _persistSettings();
    notifyListeners();
  }

  /// Update QR code setting
  Future<void> updateShowQRCode(bool show) async {
    _showQRCode = show;
    await _persistSettings();
    notifyListeners();
  }

  /// Update receipt footer text
  Future<void> updateReceiptFooterText(String text) async {
    _receiptFooterText = text;
    await _persistSettings();
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _settings = Settings(
      businessName: 'ParkEase Parking',
      businessAddress: '123 Main Street, City',
      businessPhone: '+91 9876543210',
      currency: 'INR',
      timezone: 'Asia/Kolkata',
      autoPrint: true,
      primaryPrinterId: null,
      gracePeriodMinutes: 15,
      statePrefix: 'UP',
      enableGST: false,
      gstNumber: '',
      gstPercentage: 18.0,
      ticketIdPrefix: 'PKE',
      nextTicketNumber: 1,
    );

    _printerFormat = '2"';
    _enableAdvancedReports = false;
    _enableMultiLanguage = false;
    _enableSmsNotifications = false;
    _showQRCode = true;
    _receiptFooterText = 'Thank you!';

    await _persistSettings();
    notifyListeners();
  }

  /// Get formatted business info for receipts
  String getReceiptHeader() {
    return '''
${_settings.businessName}
${_settings.businessAddress}
Tel: ${_settings.businessPhone}
${_settings.enableGST ? 'GST: ${_settings.gstNumber}' : ''}'''.trim();
  }

  /// Calculate amount with GST if enabled
  double calculateAmountWithGST(double baseAmount) {
    if (_settings.enableGST) {
      return baseAmount + (baseAmount * _settings.gstPercentage / 100);
    }
    return baseAmount;
  }

  /// Apply grace period to duration
  Duration applyGracePeriod(Duration originalDuration) {
    final graceDuration = Duration(minutes: _settings.gracePeriodMinutes);
    if (originalDuration <= graceDuration) {
      return Duration.zero;
    }
    return originalDuration - graceDuration;
  }

  /// Format currency amount
  String formatCurrency(double amount) {
    return 'Rs ${amount.toStringAsFixed(2)}';
  }
}