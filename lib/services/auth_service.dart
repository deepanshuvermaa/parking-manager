import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_session.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/device_info_helper.dart';

/// Authentication service
/// Handles login, logout, and session management
class AuthService {
  final StorageService _storage = StorageService();
  final DatabaseService _database = DatabaseService();

  /// Initialize service
  Future<void> initialize() async {
    await _storage.initialize();
  }

  /// Login with credentials
  Future<AuthSession?> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      print('🔐 Attempting login for: $email');

      // Get device info
      final deviceId = await DeviceInfoHelper.getDeviceId();
      final deviceName = await DeviceInfoHelper.getDeviceName();

      // Make login request
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,  // Changed from 'username' to 'email'
          'password': password,
          'device_id': deviceId,  // Changed to snake_case
          'device_name': deviceName,  // Changed to snake_case
        }),
      ).timeout(const Duration(seconds: 15));

      print('📨 Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final userData = data['data']['user'];
          final token = data['data']['token'];
          final refreshToken = data['data']['refreshToken'];

          // Create auth session
          final session = AuthSession(
            userId: userData['id'].toString(),
            email: userData['email'] ?? userData['username'] ?? email,
            fullName: userData['fullName'] ?? userData['full_name'] ?? '',
            role: userData['role'] ?? 'user',
            isGuest: false,
            token: token,
            refreshToken: refreshToken,
            deviceId: deviceId,
            loginTime: DateTime.now(),
            expiryTime: DateTime.now().add(const Duration(hours: 1)),
            metadata: userData,
          );

          // Save session if remember me is checked
          if (rememberMe) {
            await _storage.saveAuthSession(session.toJson());
            await _storage.saveRememberMe(true);
          } else {
            // Clear any stored session
            await _storage.clearAuthSession();
            await _storage.saveRememberMe(false);
          }

          // Save device ID
          await _storage.saveDeviceId(deviceId);

          // Register device in database
          await _database.registerDevice(
            session.userId,
            deviceId,
            deviceName,
          );

          // Save user to database
          await _database.saveUser({
            'id': session.userId,
            'email': session.email,
            'full_name': session.fullName,
            'role': session.role,
            'is_guest': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          print('✅ Login successful for: ${session.displayName}');
          return session;
        }
      }

      // Handle error response
      if (response.body.isNotEmpty) {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? error['error'] ?? 'Login failed';
        print('❌ Login failed: $message');
        throw Exception(message);
      }

      throw Exception('Invalid response from server');
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  /// Signup new user
  Future<Map<String, dynamic>?> signup({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final deviceId = await DeviceInfoHelper.getDeviceId();
      final deviceInfo = await DeviceInfoHelper.getDeviceInfo();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone': phoneNumber ?? '',
          'device_id': deviceId,
          'device_info': deviceInfo,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Signup successful');
        return data;
      }

      throw Exception('Signup failed: ${response.body}');
    } catch (e) {
      print('❌ Signup error: $e');
      return null;
    }
  }

  /// Guest login
  Future<AuthSession?> guestLogin({
    required String guestName,
  }) async {
    try {
      print('👤 Guest login for: $guestName');

      // Get device info
      final deviceId = await DeviceInfoHelper.getDeviceId();

      // Make guest signup request
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/guest-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'guest_${DateTime.now().millisecondsSinceEpoch}',
          'full_name': guestName,  // Changed to snake_case
          'device_id': deviceId,  // Changed to snake_case
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final userData = data['data']['user'];
          final token = data['data']['token'];

          // Create guest session
          final session = AuthSession(
            userId: userData['id'].toString(),
            email: userData['email'] ?? '',
            fullName: guestName, // Use the provided guest name
            role: 'guest',
            isGuest: true,
            token: token,
            refreshToken: data['data']['refreshToken'],
            deviceId: deviceId,
            loginTime: DateTime.now(),
            expiryTime: DateTime.now().add(const Duration(hours: 24)),
            metadata: userData,
          );

          // Don't save guest sessions
          await _storage.clearAuthSession();
          await _storage.saveRememberMe(false);

          // Save device ID
          await _storage.saveDeviceId(deviceId);

          print('✅ Guest login successful: $guestName');
          return session;
        }
      }

      throw Exception('Guest signup failed');
    } catch (e) {
      print('❌ Guest login error: $e');
      // If backend fails, create local guest session
      final deviceId = await DeviceInfoHelper.getDeviceId();
      return AuthSession.guest(
        guestName: guestName,
        deviceId: deviceId,
      );
    }
  }

  /// Logout
  Future<bool> logout(String? token) async {
    try {
      print('🚪 Logging out...');

      // Try to notify backend
      if (token != null) {
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Backend logout error (continuing): $e');
        }
      }

      // Clear local data
      await _storage.clearAuthData();
      await _database.clearUserData();

      print('✅ Logout complete');
      return true;
    } catch (e) {
      print('❌ Logout error: $e');
      // Force clear even on error
      await _storage.clearAuthData();
      await _database.clearUserData();
      return true;
    }
  }

  /// Check stored session
  Future<AuthSession?> checkStoredSession() async {
    try {
      // Check if remember me was enabled
      if (!_storage.getRememberMe()) {
        print('📝 Remember me not enabled, no auto-login');
        return null;
      }

      // Get stored session
      final sessionData = _storage.getAuthSession();
      if (sessionData == null) {
        print('📝 No stored session found');
        return null;
      }

      // Parse session
      final session = AuthSession.fromJson(sessionData);

      // Check if expired
      if (session.isExpired) {
        print('⏰ Session expired, clearing');
        await _storage.clearAuthSession();
        return null;
      }

      // Check if device is still active
      final deviceId = await DeviceInfoHelper.getDeviceId();
      if (session.deviceId != deviceId) {
        print('📱 Device mismatch, clearing session');
        await _storage.clearAuthSession();
        return null;
      }

      // Verify with backend if possible
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/auth/validate'),
          headers: {
            'Authorization': 'Bearer ${session.token}',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          print('❌ Token invalid, clearing session');
          await _storage.clearAuthSession();
          return null;
        }
      } catch (e) {
        print('⚠️ Could not validate with backend, using cached session');
      }

      print('✅ Valid session found for: ${session.displayName}');
      return session;
    } catch (e) {
      print('❌ Error checking stored session: $e');
      await _storage.clearAuthSession();
      return null;
    }
  }

  /// Refresh token
  Future<AuthSession?> refreshToken(AuthSession currentSession) async {
    try {
      if (currentSession.refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': currentSession.refreshToken,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // Update session with new tokens
          final newSession = currentSession.copyWith(
            token: data['data']['token'],
            refreshToken: data['data']['refreshToken'],
            expiryTime: DateTime.now().add(const Duration(hours: 1)),
          );

          // Update stored session if remember me was enabled
          if (_storage.getRememberMe()) {
            await _storage.saveAuthSession(newSession.toJson());
          }

          return newSession;
        }
      }

      throw Exception('Token refresh failed');
    } catch (e) {
      print('❌ Token refresh error: $e');
      return null;
    }
  }

  /// Check if device is active
  Future<bool> isDeviceActive(String deviceId) async {
    try {
      // Check local database first
      final isActive = await _database.isDeviceActive(deviceId);
      if (!isActive) {
        return false;
      }

      // Verify with backend
      // This would be implemented based on your backend API
      return true;
    } catch (e) {
      print('Error checking device status: $e');
      return true; // Default to active if can't check
    }
  }
}