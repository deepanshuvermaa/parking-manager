class AppConfig {
  // Backend Configuration
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://parkease-production-6679.up.railway.app'
  );
  
  // Local development URL (when testing locally)
  static const String localBackendUrl = 'http://localhost:3000';
  
  // Admin Panel Configuration
  static const String adminPanelUrl = 'https://deepanshuvermaa.github.io/quickbill-admin';
  
  // App Configuration
  static const String appName = 'ParkEase Manager';
  static const String appVersion = '1.2.1';
  static const String companyName = 'Go2 Billing Softwares';
  
  // Feature Flags
  static const bool enableBackendSync = true;
  static const bool enableOfflineMode = true;
  static const bool enableGuestMode = true;
  
  // Default Settings
  static const int defaultTrialDays = 3;
  static const int sessionCheckIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;
  
  // API Timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
  
  // Local Database
  static const String databaseName = 'parkease.db';
  static const int databaseVersion = 1;
  
  // Environment Detection
  static bool get isProduction => 
      const bool.fromEnvironment('dart.vm.product', defaultValue: false);
  
  static bool get isDebug => !isProduction;
  
  // Get appropriate backend URL based on environment
  static String get apiBaseUrl {
    if (isDebug && const bool.fromEnvironment('USE_LOCAL_BACKEND', defaultValue: false)) {
      return localBackendUrl;
    }
    return backendUrl;
  }
}