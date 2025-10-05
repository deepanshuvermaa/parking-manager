/// Central API configuration for ParkEase app
/// Single source of truth for all API endpoints
class ApiConfig {
  // Environment detection
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;

  // API Base URLs
  static String get baseUrl {
    // IMPORTANT: Choose ONE option based on your deployment:

    // Option 1: Cloudflare Workers Proxy (RECOMMENDED - Works globally)
    // Deploy cloudflare-worker.js to Cloudflare and update this URL
    // This bypasses all DNS/ISP blocking issues
    // return 'https://parkease-proxy.YOUR-SUBDOMAIN.workers.dev/api';

    // Option 2: Use hosts file workaround (QUICK FIX)
    // Add "66.33.22.37 parkease-production-6679.up.railway.app" to C:\Windows\System32\drivers\etc\hosts
    // Then Railway URL will work
    return 'https://parkease-production-6679.up.railway.app/api';

    // Option 3: Direct Railway URL (May have DNS issues with some ISPs)
    // Use this if you're sure all your users can access Railway domains
    // return 'https://parkease-production-6679.up.railway.app/api';

    // Option 4: Custom Domain with Cloudflare (Best for production)
    // Buy a domain and point it to your backend
    // return 'https://api.parkease.com/api';

    // Option 5: Local testing only
    // return 'http://192.168.1.7:5000/api';
  }

  // Auth endpoints
  static String get loginUrl => '$baseUrl/auth/login';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get guestSignupUrl => '$baseUrl/auth/guest-signup';
  static String get refreshTokenUrl => '$baseUrl/auth/refresh';

  // Vehicle endpoints
  static String get vehiclesUrl => '$baseUrl/vehicles';
  static String vehicleByIdUrl(String id) => '$baseUrl/vehicles/$id';
  static String get syncVehiclesUrl => '$baseUrl/vehicles/sync';

  // Settings endpoints
  static String get settingsUrl => '$baseUrl/settings';

  // User endpoints
  static String userSubscriptionUrl(String userId) => '$baseUrl/users/$userId/subscription-status';
  static String get syncStatusUrl => '$baseUrl/users/sync-status';
  static String get notificationsUrl => '$baseUrl/users/notifications';
  static String get markNotificationsReadUrl => '$baseUrl/users/notifications/mark-read';

  // Business endpoints (User Management)
  static String get businessUsersUrl => '$baseUrl/business/users';
  static String get businessInviteUrl => '$baseUrl/business/users/invite';
  static String businessUserUrl(String userId) => '$baseUrl/business/users/$userId';
  static String get businessInfoUrl => '$baseUrl/business/info';
  static String get businessVehiclesUrl => '$baseUrl/business/vehicles';

  // Device endpoints
  static String get deviceRegisterUrl => '$baseUrl/devices/register';
  static String get deviceCheckPermissionUrl => '$baseUrl/devices/check-permission';
  static String get deviceSyncUrl => '$baseUrl/devices/sync';
  static String get deviceLogoutOthersUrl => '$baseUrl/devices/logout-others';
  static String get deviceStatusUrl => '$baseUrl/devices/status';

  // Admin endpoints
  static String get adminCheckStatusUrl => '$baseUrl/admin/check-status';
  static String get adminValidateDeletionUrl => '$baseUrl/admin/validate-deletion';
  static String get adminValidatePasswordUrl => '$baseUrl/admin/validate-password';

  // Health check
  static String get healthUrl => '${baseUrl.replaceAll('/api', '')}/health';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}