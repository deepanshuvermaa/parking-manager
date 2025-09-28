import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/device_sync_service.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/device_info_helper.dart';
import '../models/user.dart';
import '../config/api_config.dart';

class SimplifiedAuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  User? _currentUserModel; // Full User model for trial/subscription tracking
  String? _authToken;
  bool _isLoading = false;
  String? _lastError;
  bool _isOnline = true;
  Timer? _sessionCheckTimer;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _deviceId;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _userData;
  User? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String? get authToken => _authToken;
  bool get isOnline => _isOnline;

  // Compatibility getters from HybridAuthProvider
  bool get canAccess => _currentUserModel?.canAccess ?? true;
  int get remainingTrialDays => _currentUserModel?.remainingTrialDays ?? 0;
  bool get isGuest => _currentUserModel?.isGuest ?? (_userData?['isGuest'] ?? false);

  SimplifiedAuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _deviceId = await DeviceInfoHelper.getDeviceId();
    await ApiService.initialize();
    await _checkBackendConnectivity();
    await _checkStoredAuth();
    _startSessionCheck();
  }

  Future<void> _checkStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final userJson = prefs.getString('user_data');

      // Only restore session if ALL required data is present
      if (isLoggedIn == true && token != null && token.isNotEmpty && userJson != null && userJson.isNotEmpty) {
        try {
          final userData = jsonDecode(userJson);
          // Validate that user data is properly formatted
          if (userData != null && userData is Map) {
            _authToken = token;
            _userData = Map<String, dynamic>.from(userData);
            _isAuthenticated = true;

            // Restore User model
            _currentUserModel = User(
              id: userData['id']?.toString() ?? '',
              username: userData['username'],
              email: userData['email'],
              fullName: userData['fullName'],
              role: userData['userType'] == 'premium' ? 'admin' :
                    userData['role'] ?? 'guest',
              isGuest: userData['isGuest'] ?? false,
              subscriptionType: userData['userType'] ?? 'trial',
              trialEndDate: userData['trialExpiresAt'] != null
                  ? DateTime.parse(userData['trialExpiresAt'])
                  : DateTime.now().add(const Duration(days: 7)),
              createdAt: DateTime.now(),
            );

            print('✅ Auth restored from storage');
          } else {
            // Invalid user data format, clear everything
            print('⚠️ Invalid user data format, clearing auth');
            await logout();
          }
        } catch (jsonError) {
          // JSON decode error, clear everything
          print('⚠️ Error parsing user data, clearing auth: $jsonError');
          await logout();
        }
      } else {
        // Not all required data present, ensure clean state
        _authToken = null;
        _userData = null;
        _isAuthenticated = false;
        print('📝 No valid stored auth found');
      }
    } catch (e) {
      print('Error checking stored auth: $e');
      _authToken = null;
      _userData = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Direct API call using centralized config
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'username': email,
          'password': password,
          'deviceId': 'device-${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Save to SharedPreferences - exactly like SimpleAuthTest
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['data']['token']);
          await prefs.setString('user_id', data['data']['user']['id'].toString());
          await prefs.setString('user_email', data['data']['user']['username'] ?? email);
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_data', jsonEncode(data['data']['user']));

          // Update state
          _authToken = data['data']['token'];
          _userData = data['data']['user'];
          _isAuthenticated = true;

          // Create User model for subscription tracking
          _currentUserModel = User(
            id: _userData!['id']?.toString() ?? '',
            username: _userData!['username'] ?? email,
            email: _userData!['email'] ?? email,
            fullName: _userData!['fullName'],
            role: _userData!['userType'] == 'premium' ? 'admin' :
                  _userData!['role'] ?? 'guest',
            isGuest: _userData!['isGuest'] ?? false,
            subscriptionType: _userData!['userType'] ?? 'trial',
            trialEndDate: _userData!['trialExpiresAt'] != null
                ? DateTime.parse(_userData!['trialExpiresAt'])
                : DateTime.now().add(const Duration(days: 7)),
            createdAt: DateTime.now(),
          );

          // Store in local database for offline access
          await _dbHelper.createUser(_currentUserModel!);

          // Register device and sync data
          await _postLoginSetup();

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _lastError = data['message'] ?? 'Login failed';
        }
      } else {
        final error = jsonDecode(response.body);
        _lastError = error['message'] ?? error['error'] ?? 'Login failed';
      }
    } catch (e) {
      _lastError = e.toString();
      print('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signup(String email, String password, String fullName, {String? phoneNumber}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'deviceId': 'device-${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Auto-login after signup
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['data']['token']);
          await prefs.setString('user_id', data['data']['user']['id'].toString());
          await prefs.setString('user_email', email);
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_data', jsonEncode(data['data']['user']));

          _authToken = data['data']['token'];
          _userData = data['data']['user'];
          _isAuthenticated = true;

          // Create User model for subscription tracking
          _currentUserModel = User(
            id: _userData!['id']?.toString() ?? '',
            username: _userData!['username'] ?? email,
            email: _userData!['email'] ?? email,
            fullName: _userData!['fullName'] ?? fullName,
            role: _userData!['userType'] == 'premium' ? 'admin' :
                  _userData!['role'] ?? 'guest',
            isGuest: _userData!['isGuest'] ?? false,
            subscriptionType: _userData!['userType'] ?? 'trial',
            trialEndDate: _userData!['trialExpiresAt'] != null
                ? DateTime.parse(_userData!['trialExpiresAt'])
                : DateTime.now().add(const Duration(days: 7)),
            createdAt: DateTime.now(),
          );

          // Store in local database for offline access
          await _dbHelper.createUser(_currentUserModel!);

          // Register device and sync data
          await _postLoginSetup();

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _lastError = data['message'] ?? 'Signup failed';
        }
      } else {
        final error = jsonDecode(response.body);
        _lastError = error['message'] ?? error['error'] ?? 'Signup failed';
      }
    } catch (e) {
      _lastError = e.toString();
      print('Signup error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to call backend logout endpoint (optional, don't fail if it doesn't work)
      if (_authToken != null) {
        try {
          await http.post(
            Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Backend logout error (continuing anyway): $e');
        }
      }

      // Clear ALL auth-related data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Remove all auth keys
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
      await prefs.remove('userId'); // Alternative key that might be used
      await prefs.remove('user_email');
      await prefs.remove('user_data');
      await prefs.remove('username');
      await prefs.remove('fullName');
      await prefs.remove('role');
      await prefs.remove('email');
      await prefs.setBool('is_logged_in', false);
      await prefs.setBool('isAuthenticated', false);
      await prefs.setBool('rememberMe', false);

      // Clear any device sync data
      await prefs.remove('device_id');
      await prefs.remove('device_permissions');

      // Clear any cached data
      await prefs.remove('cached_vehicles');
      await prefs.remove('settings_json');

      // Also clear tokens from ApiService to ensure complete logout
      await ApiService.clearTokens();

      // Clear state variables
      _authToken = null;
      _userData = null;
      _currentUserModel = null;
      _isAuthenticated = false;
      _lastError = null;

      // Cancel session check timer
      _sessionCheckTimer?.cancel();

      print('✅ Logout completed - all data cleared');
    } catch (e) {
      print('❌ Logout error: $e');
      _lastError = 'Logout failed: $e';
      // Even if there's an error, force clear the authentication state
      _authToken = null;
      _userData = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Post-login setup: device registration and data sync
  Future<void> _postLoginSetup() async {
    try {
      // Register current device
      await DeviceSyncService.registerDevice();

      // Check device permissions (temporarily disabled for debugging)
      if (_userData != null) {
        final userId = _userData!['id']?.toString();
        if (userId != null) {
          final isAllowed = await DeviceSyncService.isDeviceAllowed(userId);
          if (!isAllowed) {
            // For now, just log the warning but don't logout
            print('⚠️ Device limit reached but allowing login for debugging');
            _lastError = 'Device limit reached (allowing login for debugging)';
            // TODO: Re-enable device restrictions after login/logout issues are fixed
            // await logout();
            // return;
          }
        }
      }

      // Sync data across devices
      await DeviceSyncService.syncDataAcrossDevices();
    } catch (e) {
      // Don't fail login for sync issues, just log the error
      print('Post-login setup error: $e');
    }
  }

  /// Manual sync trigger for user
  Future<bool> syncData() async {
    try {
      return await DeviceSyncService.syncDataAcrossDevices();
    } catch (e) {
      print('Manual sync error: $e');
      return false;
    }
  }

  /// Check if user is super admin (Deepanshu Verma)
  bool get isSuperAdmin {
    if (_userData == null) return false;
    final email = _userData!['username'] ?? _userData!['email'];
    return email == 'deepanshuverma966@gmail.com';
  }

  /// Get device sync status
  Future<Map<String, dynamic>?> getDeviceSyncStatus() async {
    return await DeviceSyncService.getDeviceSyncStatus();
  }

  // Helper getters for compatibility
  bool get isAdmin => _userData?['userType'] == 'premium' || _userData?['role'] == 'admin' || isSuperAdmin;
  String? get userId => _userData?['id']?.toString();
  String? get userEmail => _userData?['username'] ?? _userData?['email'];

  // Session management methods from HybridAuthProvider
  void _startSessionCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSessionValidity();
    });
  }

  Future<void> _checkSessionValidity() async {
    if (!_isAuthenticated || _userData == null) return;

    // Check backend connectivity periodically
    await _checkBackendConnectivity();

    // Check if guest trial expired
    if (_currentUserModel != null && _currentUserModel!.isGuest && !_currentUserModel!.canAccess) {
      print('⏰ Guest trial expired, logging out');
      await logout();
      return;
    }

    // If online, sync with backend
    if (_isOnline) {
      await _syncWithBackend();
    }
  }

  Future<void> _checkBackendConnectivity() async {
    try {
      _isOnline = await ApiService.isBackendHealthy();
      print(_isOnline ? '🌐 Backend is online' : '📴 Backend is offline');
    } catch (e) {
      print('Error checking backend: $e');
      _isOnline = false;
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      // Sync user status with backend
      final status = await ApiService.syncUserStatus();
      if (status != null) {
        if (status['forceLogout'] == true) {
          // Another device logged in, force logout
          print('⚠️ Force logout - account accessed from another device');
          await logout();
          return;
        }

        // Update user data if changed
        if (status['user'] != null) {
          _updateUserFromBackend(status['user']);
        }
      }

      // Sync vehicles with backend
      final localVehicles = await _dbHelper.getVehicles();
      if (localVehicles.isNotEmpty) {
        await ApiService.syncVehicles(localVehicles);
      }

      // Sync settings from backend
      final settings = await ApiService.getSettings();
      if (settings != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('settings_json', jsonEncode(settings));
      }

      print('✅ Backend sync completed');
    } catch (e) {
      print('Sync error: $e');
    }
  }

  void _updateUserFromBackend(Map<String, dynamic> userData) {
    _userData = userData;

    // Create User model for subscription tracking
    _currentUserModel = User(
      id: userData['id']?.toString() ?? '',
      username: userData['username'],
      email: userData['email'],
      fullName: userData['fullName'],
      role: userData['userType'] == 'premium' ? 'admin' :
            userData['role'] ?? 'guest',
      isGuest: userData['isGuest'] ?? false,
      subscriptionType: userData['userType'] ?? 'trial',
      trialEndDate: userData['trialExpiresAt'] != null
          ? DateTime.parse(userData['trialExpiresAt'])
          : DateTime.now().add(const Duration(days: 7)),
      createdAt: userData['createdAt'] != null
          ? DateTime.parse(userData['createdAt'])
          : DateTime.now(),
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    super.dispose();
  }
}