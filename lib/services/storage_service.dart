import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Storage service for managing local storage
/// Single source of truth for all SharedPreferences operations
class StorageService {
  static const String _keyPrefix = 'parkease_';

  // Storage keys
  static const String _authSessionKey = '${_keyPrefix}auth_session';
  static const String _rememberMeKey = '${_keyPrefix}remember_me';
  static const String _deviceIdKey = '${_keyPrefix}device_id';
  static const String _lastSyncKey = '${_keyPrefix}last_sync';
  static const String _settingsKey = '${_keyPrefix}settings';
  static const String _settingsVersionKey = '${_keyPrefix}settings_version';

  SharedPreferences? _prefs;

  /// Initialize storage
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get preferences instance
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // ============= Auth Storage =============

  /// Save auth session
  Future<bool> saveAuthSession(Map<String, dynamic> session) async {
    return await prefs.setString(_authSessionKey, jsonEncode(session));
  }

  /// Get auth session
  Map<String, dynamic>? getAuthSession() {
    final sessionStr = prefs.getString(_authSessionKey);
    if (sessionStr == null) return null;

    try {
      return jsonDecode(sessionStr);
    } catch (e) {
      print('Error decoding auth session: $e');
      return null;
    }
  }

  /// Clear auth session
  Future<bool> clearAuthSession() async {
    return await prefs.remove(_authSessionKey);
  }

  /// Save remember me preference
  Future<bool> saveRememberMe(bool value) async {
    return await prefs.setBool(_rememberMeKey, value);
  }

  /// Get remember me preference
  bool getRememberMe() {
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // ============= Device Storage =============

  /// Save device ID
  Future<bool> saveDeviceId(String deviceId) async {
    return await prefs.setString(_deviceIdKey, deviceId);
  }

  /// Get device ID
  String? getDeviceId() {
    return prefs.getString(_deviceIdKey);
  }

  // ============= Sync Storage =============

  /// Save last sync timestamp
  Future<bool> saveLastSync(DateTime timestamp) async {
    return await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
  }

  /// Get last sync timestamp
  DateTime? getLastSync() {
    final timestampStr = prefs.getString(_lastSyncKey);
    if (timestampStr == null) return null;

    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      print('Error parsing last sync timestamp: $e');
      return null;
    }
  }

  // ============= Settings Storage =============

  /// Save settings with version
  Future<bool> saveSettings(Map<String, dynamic> settings, int version) async {
    final saved = await prefs.setString(_settingsKey, jsonEncode(settings));
    if (saved) {
      await prefs.setInt(_settingsVersionKey, version);
    }
    return saved;
  }

  /// Get settings
  Map<String, dynamic>? getSettings() {
    final settingsStr = prefs.getString(_settingsKey);
    if (settingsStr == null) return null;

    try {
      return jsonDecode(settingsStr);
    } catch (e) {
      print('Error decoding settings: $e');
      return null;
    }
  }

  /// Get settings version
  int getSettingsVersion() {
    return prefs.getInt(_settingsVersionKey) ?? 0;
  }

  /// Clear settings
  Future<void> clearSettings() async {
    await prefs.remove(_settingsKey);
    await prefs.remove(_settingsVersionKey);
  }

  // ============= Utility Methods =============

  /// Clear all storage except settings
  Future<void> clearAuthData() async {
    await clearAuthSession();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_lastSyncKey);
    // Keep device ID for tracking
    // Keep settings for user preferences
  }

  /// Clear everything (factory reset)
  Future<void> clearAll() async {
    // Get all keys
    final keys = prefs.getKeys();

    // Only clear our app keys (with prefix)
    for (final key in keys) {
      if (key.startsWith(_keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Check if this is first launch
  bool isFirstLaunch() {
    return getDeviceId() == null;
  }

  /// Debug: Print all stored data
  void debugPrintStorage() {
    print('===== Storage Debug =====');
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_keyPrefix)) {
        final value = prefs.get(key);
        print('$key: $value');
      }
    }
    print('========================');
  }
}