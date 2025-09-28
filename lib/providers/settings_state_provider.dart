import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

/// Settings state provider
/// Manages app and business settings with proper persistence
class SettingsStateProvider extends ChangeNotifier {
  final DatabaseService _database = DatabaseService();
  final StorageService _storage = StorageService();
  final SyncService _syncService = SyncService();

  Settings? _settings;
  int _settingsVersion = 1;
  bool _isLoading = false;
  bool _isDirty = false;

  /// Current settings
  Settings get settings => _settings ?? _defaultSettings;

  /// Loading state
  bool get isLoading => _isLoading;

  /// Check if settings have unsaved changes
  bool get hasUnsavedChanges => _isDirty;

  /// Default settings
  Settings get _defaultSettings => Settings(
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

  /// Constructor - NO auto-loading
  SettingsStateProvider() {
    print('🔨 SettingsStateProvider initialized');
  }

  /// Initialize settings (called after auth)
  Future<void> initialize() async {
    print('🚀 Initializing SettingsStateProvider...');

    _isLoading = true;
    notifyListeners();

    try {
      await _storage.initialize();

      // Load settings from local storage
      await _loadSettings();
    } catch (e) {
      print('❌ Settings initialization error: $e');
      _settings = _defaultSettings;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      print('📥 Loading settings...');

      // Try to load from storage first
      final storedSettings = _storage.getSettings();
      final storedVersion = _storage.getSettingsVersion();

      if (storedSettings != null) {
        _settings = Settings.fromJson(storedSettings);
        _settingsVersion = storedVersion;

        print('✅ Settings loaded from storage');
        print('   Business Name: ${_settings!.businessName}');
        print('   Version: $_settingsVersion');
        return;
      }

      // If no stored settings, try to load from database
      final dbSettings = await _database.getAllSettings();

      if (dbSettings.isNotEmpty) {
        // Reconstruct settings from database
        _settings = _reconstructSettingsFromDb(dbSettings);
        print('✅ Settings loaded from database');

        // Save to storage for faster access
        await _saveToStorage();
        return;
      }

      // Use defaults if no settings found
      print('⚠️ No settings found, using defaults');
      _settings = _defaultSettings;

      // Save defaults
      await saveSettings();
    } catch (e) {
      print('❌ Error loading settings: $e');
      _settings = _defaultSettings;
    }
  }

  /// Reconstruct settings from database entries
  Settings _reconstructSettingsFromDb(Map<String, String> dbSettings) {
    return Settings(
      businessName: dbSettings['businessName'] ?? _defaultSettings.businessName,
      businessAddress: dbSettings['businessAddress'] ?? _defaultSettings.businessAddress,
      businessPhone: dbSettings['businessPhone'] ?? _defaultSettings.businessPhone,
      currency: dbSettings['currency'] ?? _defaultSettings.currency,
      timezone: dbSettings['timezone'] ?? _defaultSettings.timezone,
      autoPrint: dbSettings['autoPrint'] == 'true',
      primaryPrinterId: dbSettings['primaryPrinterId'],
      gracePeriodMinutes: int.tryParse(dbSettings['gracePeriodMinutes'] ?? '') ?? _defaultSettings.gracePeriodMinutes,
      statePrefix: dbSettings['statePrefix'] ?? _defaultSettings.statePrefix,
      enableGST: dbSettings['enableGST'] == 'true',
      gstNumber: dbSettings['gstNumber'] ?? '',
      gstPercentage: double.tryParse(dbSettings['gstPercentage'] ?? '') ?? _defaultSettings.gstPercentage,
      ticketIdPrefix: dbSettings['ticketIdPrefix'] ?? _defaultSettings.ticketIdPrefix,
      nextTicketNumber: int.tryParse(dbSettings['nextTicketNumber'] ?? '') ?? _defaultSettings.nextTicketNumber,
    );
  }

  /// Update settings
  Future<bool> updateSettings(Settings newSettings) async {
    print('💾 Updating settings...');

    _isLoading = true;
    notifyListeners();

    try {
      _settings = newSettings;
      _settingsVersion++;
      _isDirty = false;

      // Save to storage and database
      await _saveToStorage();
      await _saveToDatabase();

      // Sync with server
      await _syncService.syncEntity('settings', 'all');

      print('✅ Settings updated successfully');
      print('   Business Name: ${_settings!.businessName}');
      print('   Version: $_settingsVersion');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error updating settings: $e');

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update specific setting
  Future<bool> updateSetting(String key, dynamic value) async {
    try {
      final currentJson = _settings?.toJson() ?? _defaultSettings.toJson();
      currentJson[key] = value;

      final newSettings = Settings.fromJson(currentJson);
      return await updateSettings(newSettings);
    } catch (e) {
      print('❌ Error updating setting $key: $e');
      return false;
    }
  }

  /// Save settings without updating version (for auto-save)
  Future<void> saveSettings() async {
    try {
      await _saveToStorage();
      await _saveToDatabase();
      _isDirty = false;
      print('💾 Settings auto-saved');
    } catch (e) {
      print('❌ Error saving settings: $e');
    }
  }

  /// Save to storage
  Future<void> _saveToStorage() async {
    if (_settings == null) return;

    await _storage.saveSettings(
      _settings!.toJson(),
      _settingsVersion,
    );
  }

  /// Save to database
  Future<void> _saveToDatabase() async {
    if (_settings == null) return;

    final settingsMap = _settings!.toJson();

    for (final entry in settingsMap.entries) {
      await _database.saveSetting(
        entry.key,
        entry.value.toString(),
        _settingsVersion,
      );
    }
  }

  /// Mark settings as dirty (has unsaved changes)
  void markDirty() {
    _isDirty = true;
    notifyListeners();
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    print('🔄 Resetting to default settings...');

    _isLoading = true;
    notifyListeners();

    try {
      _settings = _defaultSettings;
      _settingsVersion = 1;
      _isDirty = false;

      await _saveToStorage();
      await _saveToDatabase();

      print('✅ Settings reset to defaults');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error resetting settings: $e');

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear settings (for logout)
  void clearSettings() {
    // Don't clear settings on logout - they should persist
    // Only clear user-specific settings if needed
    print('📝 Settings preserved during logout');
  }

  /// Generate next ticket ID
  String generateNextTicketId() {
    final ticketId = '${settings.ticketIdPrefix}${settings.nextTicketNumber.toString().padLeft(6, '0')}';

    // Increment counter
    if (_settings != null) {
      _settings = _settings!.copyWith(
        nextTicketNumber: _settings!.nextTicketNumber + 1,
      );
      markDirty();

      // Auto-save
      saveSettings();
    }

    return ticketId;
  }

  /// Get formatted business header for receipts
  String getReceiptHeader() {
    return '''
${settings.businessName}
${settings.businessAddress}
Tel: ${settings.businessPhone}
${settings.enableGST ? 'GST: ${settings.gstNumber}' : ''}'''.trim();
  }

  /// Calculate amount with GST
  double calculateAmountWithGST(double baseAmount) {
    if (settings.enableGST) {
      return baseAmount + (baseAmount * settings.gstPercentage / 100);
    }
    return baseAmount;
  }

  /// Format currency
  String formatCurrency(double amount) {
    return '${settings.currency} ${amount.toStringAsFixed(2)}';
  }
}