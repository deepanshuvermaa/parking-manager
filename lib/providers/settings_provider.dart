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
  );

  Settings get settings => _settings;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load from backend first
    try {
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        final backendSettings = await ApiService.getSettings();
        if (backendSettings != null) {
          _settings = Settings.fromJson(backendSettings);
          // Save to local storage
          await prefs.setString('settings', jsonEncode(backendSettings));
        }
      } else {
        // Load from local storage if offline
        final settingsJson = prefs.getString('settings');
        if (settingsJson != null) {
          _settings = Settings.fromJson(jsonDecode(settingsJson));
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Fallback to local settings
      final settingsJson = prefs.getString('settings');
      if (settingsJson != null) {
        try {
          _settings = Settings.fromJson(jsonDecode(settingsJson));
        } catch (e) {
          debugPrint('Error parsing local settings: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(_settings.toJson()));

    // Try to sync with backend
    try {
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        await ApiService.updateSettings(_settings.toJson());
      }
    } catch (e) {
      debugPrint('Error syncing settings to backend: $e');
    }

    notifyListeners();
  }

  Future<void> updateBusinessName(String name) async {
    _settings = _settings.copyWith(businessName: name);
    notifyListeners();
  }

  Future<void> updateBusinessAddress(String address) async {
    _settings = _settings.copyWith(businessAddress: address);
    notifyListeners();
  }

  Future<void> updateBusinessPhone(String phone) async {
    _settings = _settings.copyWith(businessPhone: phone);
    notifyListeners();
  }

  Future<void> updateAutoPrint(bool autoPrint) async {
    _settings = _settings.copyWith(autoPrint: autoPrint);
    notifyListeners();
  }

  Future<void> updatePrimaryPrinter(String? printerId) async {
    _settings = _settings.copyWith(primaryPrinterId: printerId);
    notifyListeners();
  }

  Future<void> updateGracePeriod(int minutes) async {
    _settings = _settings.copyWith(gracePeriodMinutes: minutes);
    notifyListeners();
  }

  Future<void> updateStatePrefix(String prefix) async {
    _settings = _settings.copyWith(statePrefix: prefix);
    notifyListeners();
  }

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
    notifyListeners();
  }
}