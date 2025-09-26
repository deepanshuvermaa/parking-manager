import 'package:shared_preferences/shared_preferences.dart';

/// App configuration and feature flags
/// This allows enabling/disabling features without code changes
class AppConfig {
  // Feature flags
  static bool _enableUserManagement = false;
  static bool _enableAdvancedReports = false;
  static bool _debugMode = false;

  // Beta users who get early access to features
  static const List<String> _betaUsers = [
    'deepanshuverma966@gmail.com',
    // Add more beta testers here
  ];

  // Getters
  static bool get enableUserManagement => _enableUserManagement;
  static bool get enableAdvancedReports => _enableAdvancedReports;
  static bool get debugMode => _debugMode;

  /// Initialize app configuration
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user is a beta tester
    final userEmail = prefs.getString('user_email') ?? '';
    final isBetaUser = _betaUsers.contains(userEmail.toLowerCase());

    // Load feature flags from preferences or defaults
    _enableUserManagement = prefs.getBool('enable_user_management') ?? isBetaUser;
    _enableAdvancedReports = prefs.getBool('enable_advanced_reports') ?? false;
    _debugMode = prefs.getBool('debug_mode') ?? false;

    // For production safety, can override all features
    final safeMode = prefs.getBool('safe_mode') ?? false;
    if (safeMode) {
      _enableUserManagement = false;
      _enableAdvancedReports = false;
      print('⚠️ Safe mode enabled - new features disabled');
    }

    print('📱 App Config initialized:');
    print('   User Management: $_enableUserManagement');
    print('   Advanced Reports: $_enableAdvancedReports');
    print('   Debug Mode: $_debugMode');
    print('   Beta User: $isBetaUser');
  }

  /// Enable/disable user management feature
  static Future<void> setUserManagement(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_user_management', enabled);
    _enableUserManagement = enabled;
  }

  /// Enable safe mode (disables all experimental features)
  static Future<void> enableSafeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safe_mode', true);
    _enableUserManagement = false;
    _enableAdvancedReports = false;
    print('🛡️ Safe mode activated - all experimental features disabled');
  }

  /// Check if current user is owner (for permission checks)
  static Future<bool> isOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      // Check role in user data
      return userData.contains('"role":"owner"');
    }
    // Default to true for backward compatibility
    return true;
  }

  /// Check if feature is available for current user
  static bool isFeatureAvailable(String feature) {
    switch (feature) {
      case 'user_management':
        return _enableUserManagement;
      case 'advanced_reports':
        return _enableAdvancedReports;
      default:
        return false;
    }
  }
}