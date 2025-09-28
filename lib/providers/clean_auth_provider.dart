import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;

/// Clean, simple auth provider that actually works
/// No auto-login, no complex flags, just simple auth
class CleanAuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  String? _authToken;
  bool _isLoading = false;
  String? _lastError;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _userData;
  String? get authToken => _authToken;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  CleanAuthProvider() {
    // DO NOT AUTO-LOGIN
    // Just check if we have a token for API calls, but don't authenticate
    _initializeTokenOnly();
  }

  /// Only load token for API calls, don't auto-authenticate
  Future<void> _initializeTokenOnly() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user explicitly wants to stay logged in
    final stayLoggedIn = prefs.getBool('stay_logged_in') ?? false;

    if (stayLoggedIn) {
      // User chose to stay logged in, restore session
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('user_data');

      if (token != null && userJson != null) {
        try {
          _authToken = token;
          _userData = jsonDecode(userJson);
          _isAuthenticated = true;

          // Set tokens in ApiService
          final refreshToken = prefs.getString('refresh_token');
          ApiService.setTokensFromAuthProvider(token, refreshToken,
            userId: _userData?['id']?.toString());

        } catch (e) {
          print('Session restore failed: $e');
          await _clearAll();
        }
      }
    } else {
      // No stay logged in, ensure everything is cleared
      await _clearAll();
    }

    notifyListeners();
  }

  /// Login with credentials
  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // Save auth data
          final prefs = await SharedPreferences.getInstance();

          _authToken = data['data']['token'];
          _userData = data['data']['user'];
          _isAuthenticated = true;

          // Only save to storage if remember me is checked
          if (rememberMe) {
            await prefs.setBool('stay_logged_in', true);
            await prefs.setString('auth_token', _authToken!);
            await prefs.setString('refresh_token', data['data']['refreshToken'] ?? '');
            await prefs.setString('user_data', jsonEncode(_userData));
          } else {
            // Clear stay logged in flag
            await prefs.setBool('stay_logged_in', false);
          }

          // Set tokens in ApiService
          ApiService.setTokensFromAuthProvider(
            _authToken,
            data['data']['refreshToken'],
            userId: _userData?['id']?.toString(),
          );

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _lastError = 'Invalid credentials';
    } catch (e) {
      _lastError = 'Connection error: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Simple logout - clear everything
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    // Try to notify backend (don't care if it fails)
    if (_authToken != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        // Ignore backend errors
      }
    }

    // Clear everything
    await _clearAll();

    _isLoading = false;
    notifyListeners();
  }

  /// Clear all auth data
  Future<void> _clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear auth data from storage
    await prefs.remove('stay_logged_in');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('user_id');

    // Clear tokens from ApiService
    ApiService.setTokensFromAuthProvider(null, null, userId: null);
    await ApiService.clearTokens();

    // Clear memory
    _authToken = null;
    _userData = null;
    _isAuthenticated = false;
    _lastError = null;
  }

  /// Force refresh authentication status
  Future<void> checkAuthStatus() async {
    // This is called to check if user should be authenticated
    // We only authenticate if stay_logged_in is true and we have valid data
    await _initializeTokenOnly();
  }

  /// Get user display name
  String get displayName {
    if (_userData == null) return 'User';
    return _userData!['fullName'] ??
           _userData!['username'] ??
           _userData!['email'] ??
           'User';
  }

  /// Check if user is admin/owner
  bool get isAdmin {
    if (_userData == null) return false;
    final role = _userData!['role'] ?? '';
    return role == 'admin' || role == 'owner';
  }

  /// Check if user is super admin (Deepanshu)
  bool get isSuperAdmin {
    if (_userData == null) return false;
    final email = _userData!['username'] ?? _userData!['email'] ?? '';
    return email == 'deepanshuverma966@gmail.com';
  }

  /// Get user email
  String? get userEmail {
    if (_userData == null) return null;
    return _userData!['email'] ?? _userData!['username'];
  }

  /// Get user ID
  String? get userId {
    if (_userData == null) return null;
    return _userData!['id']?.toString();
  }

  /// Regular signup (same as guest for now)
  Future<bool> signup(String email, String password, String fullName, {String? phoneNumber}) async {
    // For now, just use guest signup
    return guestSignup(email, fullName);
  }

  /// Guest signup
  Future<bool> guestSignup(String username, String fullName) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/guest-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'fullName': fullName,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // Auto-login after signup
          _authToken = data['data']['token'];
          _userData = data['data']['user'];
          _isAuthenticated = true;

          // Don't save for guest users
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('stay_logged_in', false);

          // Set tokens in ApiService
          ApiService.setTokensFromAuthProvider(
            _authToken,
            data['data']['refreshToken'],
            userId: _userData?['id']?.toString(),
          );

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _lastError = 'Signup failed';
    } catch (e) {
      _lastError = 'Connection error: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}