import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../models/settings.dart';
import '../services/device_info_helper.dart';
import '../config/app_config.dart';
import '../config/api_config.dart';

class ApiService {
  // Use centralized API configuration
  static String get apiUrl => ApiConfig.baseUrl;

  static String? _authToken;
  static String? _refreshToken;
  static Timer? _tokenRefreshTimer;
  static String? _userId;

  // Initialize with stored tokens
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');

    if (_authToken != null) {
      _scheduleTokenRefresh();
    }
  }

  // Schedule token refresh
  static void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    // Refresh token 5 minutes before expiry (55 minutes)
    _tokenRefreshTimer = Timer(const Duration(minutes: 55), () async {
      await _refreshAuthToken();
    });
  }

  // Get headers with auth token
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Store tokens
  static Future<void> _storeTokens(String authToken, String refreshToken, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', authToken);
    await prefs.setString('refresh_token', refreshToken);
    if (userId != null) {
      await prefs.setString('user_id', userId);
      _userId = userId;
    }
    _authToken = authToken;
    _refreshToken = refreshToken;
    _scheduleTokenRefresh();
  }

  // Clear tokens
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    _authToken = null;
    _refreshToken = null;
    _userId = null;
    _tokenRefreshTimer?.cancel();
  }

  // Refresh token if needed
  static Future<bool> _refreshAuthToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          await _storeTokens(data['data']['token'], data['data']['refreshToken']);
          return true;
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    return false;
  }

  // Make authenticated request with automatic token refresh
  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$apiUrl$endpoint');
    
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: _headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: _headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // If token expired, try to refresh and retry
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAuthToken();
      if (refreshed) {
        // Retry the request with new token
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(url, headers: _headers);
            break;
          case 'POST':
            response = await http.post(
              url,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              url,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(url, headers: _headers);
            break;
        }
      }
    }

    return response;
  }

  // Auth endpoints
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();

      print('🔐 Attempting login for: $username');
      final response = await http.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📨 Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          await _storeTokens(data['data']['token'], data['data']['refreshToken'], userId: data['data']['user']['id'].toString());
          print('✅ Login successful, tokens stored');
          return data['data'];
        }
        throw Exception(data['message'] ?? 'Login failed - invalid response');
      } else {
        final error = jsonDecode(response.body);
        final errorMessage = error['error'] ?? error['message'] ?? 'Login failed';
        print('❌ Login failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Login exception: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: Please check your connection');
    }
  }

  static Future<Map<String, dynamic>?> guestSignup(String username, String fullName) async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();
      print('=== GUEST SIGNUP DEBUG ===');
      print('Username: $username');
      print('FullName: $fullName');
      print('DeviceId: $deviceId');
      print('API URL: $apiUrl/auth/guest-signup');

      final response = await http.post(
        Uri.parse('$apiUrl/auth/guest-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'fullName': fullName,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          await _storeTokens(data['data']['token'], data['data']['refreshToken'], userId: data['data']['user']['id'].toString());
          print('Guest signup successful, tokens stored');
          return data['data'];
        }
        print('Response success false or data null');
        return null;
      } else {
        print('Guest signup failed with status ${response.statusCode}');
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? error['message'] ?? 'Signup failed');
      }
    } catch (e) {
      print('Guest signup exception: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> signup(String email, String password, String fullName) async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();

      print('🔐 Attempting signup for: $email');

      final requestBody = {
        'email': email,
        'password': password,
        'fullName': fullName,
        'deviceId': deviceId,
        'isTrialUser': true,
      };

      final response = await http.post(
        Uri.parse('$apiUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📨 Signup response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          await _storeTokens(data['data']['token'], data['data']['refreshToken'], userId: data['data']['user']['id'].toString());
          print('✅ Signup successful, tokens stored');
          return data['data'];
        }
        throw Exception(data['message'] ?? 'Signup failed - invalid response');
      } else {
        final error = jsonDecode(response.body);
        final errorMessage = error['error'] ?? error['message'] ?? 'Signup failed';
        print('❌ Signup failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Signup exception: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: Please check your connection');
    }
  }

  static Future<bool> logout() async {
    try {
      // Try to call logout endpoint if we have a token
      if (_authToken != null) {
        await _makeRequest('POST', '/auth/logout');
      }
    } catch (e) {
      print('Logout API error: $e');
      // Continue with logout even if API fails
    }

    // Always clear tokens
    await clearTokens();
    return true;
  }

  // Vehicle endpoints
  static Future<List<Vehicle>?> getVehicles() async {
    try {
      final response = await _makeRequest('GET', '/vehicles');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> vehiclesJson = data['data']['vehicles'];
          return vehiclesJson.map((json) => Vehicle.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Get vehicles error: $e');
    }
    return null;
  }

  static Future<Vehicle?> addVehicle(Vehicle vehicle) async {
    try {
      final response = await _makeRequest('POST', '/vehicles', body: vehicle.toJson());
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
      }
    } catch (e) {
      print('Add vehicle error: $e');
    }
    return null;
  }

  static Future<Vehicle?> updateVehicle(Vehicle vehicle) async {
    try {
      final response = await _makeRequest('PUT', '/vehicles/${vehicle.id}', body: vehicle.toJson());
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
      }
    } catch (e) {
      print('Update vehicle error: $e');
    }
    return null;
  }

  static Future<bool> deleteVehicle(String vehicleId) async {
    try {
      final response = await _makeRequest('DELETE', '/vehicles/$vehicleId');
      return response.statusCode == 200;
    } catch (e) {
      print('Delete vehicle error: $e');
      return false;
    }
  }

  // Sync local data to backend
  static Future<bool> syncVehicles(List<Vehicle> localVehicles) async {
    try {
      final response = await _makeRequest('POST', '/vehicles/sync', 
        body: {'vehicles': localVehicles.map((v) => v.toJson()).toList()});
      
      return response.statusCode == 200;
    } catch (e) {
      print('Sync vehicles error: $e');
      return false;
    }
  }

  // Settings endpoints
  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final response = await _makeRequest('GET', '/settings');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
    } catch (e) {
      print('Get settings error: $e');
    }
    return null;
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final response = await _makeRequest('PUT', '/settings', body: settings);
      return response.statusCode == 200;
    } catch (e) {
      print('Update settings error: $e');
      return false;
    }
  }

  // Health check
  static Future<bool> isBackendHealthy() async {
    try {
      print('=== HEALTH CHECK DEBUG ===');
      print('Checking URL: ${ApiConfig.healthUrl}');

      final response = await http.get(
        Uri.parse(ApiConfig.healthUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Health check response: ${response.statusCode}');
      print('Health check body: ${response.body}');

      // Accept any 2xx status as healthy
      final isHealthy = response.statusCode >= 200 && response.statusCode < 300;
      print('Backend is healthy: $isHealthy');

      return isHealthy;
    } catch (e) {
      print('Backend health check exception: $e');
      print('Stack trace: ${StackTrace.current}');

      // For release builds, assume online if we can't check
      // This allows the app to try API calls even if health check fails
      if (!kDebugMode) {
        print('Release mode: Assuming backend is online');
        return true;
      }
      return false;
    }
  }

  // Subscription Management APIs
  static Future<Map<String, dynamic>?> getUserSubscriptionStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userSubscriptionUrl(userId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['subscription'];
      }
      return null;
    } catch (e) {
      print('Get subscription status error: $e');
      return null;
    }
  }

  // Sync user trial/subscription status
  static Future<Map<String, dynamic>?> syncUserStatus() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.syncStatusUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('Sync user status error: $e');
      return null;
    }
  }

  // Check for pending notifications
  static Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.notificationsUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications']);
      }
      return [];
    } catch (e) {
      print('Get notifications error: $e');
      return [];
    }
  }

  // Mark notifications as read
  static Future<bool> markNotificationsRead(List<String> notificationIds) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.markNotificationsReadUrl),
        headers: _headers,
        body: json.encode({
          'notificationIds': notificationIds,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Mark notifications read error: $e');
      return false;
    }
  }

  // Device Management Methods
  static Future<Map<String, dynamic>?> registerDevice(Map<String, dynamic> deviceInfo) async {
    try {
      final response = await _makeRequest('POST', '/devices/register', body: deviceInfo);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Register device error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkDevicePermission(String userId, String deviceId) async {
    try {
      final response = await _makeRequest('GET', '/devices/check-permission?userId=$userId&deviceId=$deviceId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Check device permission error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> syncDeviceData(Map<String, dynamic> data) async {
    try {
      final response = await _makeRequest('POST', '/devices/sync', body: data);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Sync device data error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> logoutOtherDevices(String currentDeviceId) async {
    try {
      final response = await _makeRequest('POST', '/devices/logout-others', body: {'deviceId': currentDeviceId});
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Logout other devices error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDeviceStatus() async {
    try {
      final response = await _makeRequest('GET', '/devices/status');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get device status error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkAdminStatus(String userId) async {
    try {
      final response = await _makeRequest('GET', '/admin/check-status?userId=$userId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Check admin status error: $e');
      return null;
    }
  }

  // Admin deletion protection methods
  static Future<Map<String, dynamic>?> validateDeletionCode(String code, String itemType, String itemId) async {
    try {
      final response = await _makeRequest('POST', '/admin/validate-deletion', body: {
        'code': code,
        'itemType': itemType,
        'itemId': itemId,
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Validate deletion code error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> validateAdminPassword(String password) async {
    try {
      final response = await _makeRequest('POST', '/admin/validate-password', body: {
        'password': password,
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Validate admin password error: $e');
      return null;
    }
  }
}