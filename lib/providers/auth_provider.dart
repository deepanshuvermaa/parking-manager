import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/device_service.dart';
import '../services/simple_vehicle_service.dart';
import '../services/settings_sync_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.uninitialized;
  String? _token;
  String? _refreshToken;
  String? _userId;
  String _userName = '';
  String _userEmail = '';
  String _userRole = 'guest';
  String _parkingName = '';
  DateTime? _trialExpires;
  bool _isOffline = false;
  bool _multiStaffEnabled = false;

  // Getters
  AuthStatus get status => _status;
  String? get token => _token;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userRole => _userRole;
  String get parkingName => _parkingName;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isOffline => _isOffline;
  bool get isGuest => _userRole == 'guest';
  bool get multiStaffEnabled => _multiStaffEnabled;
  int get trialDaysLeft {
    if (_trialExpires == null) return 0;
    return _trialExpires!.difference(DateTime.now()).inDays;
  }
  bool get trialExpired => isGuest && trialDaysLeft <= 0 && _trialExpires != null;

  /// Initialize - check stored credentials
  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userName = prefs.getString('user_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _userRole = prefs.getString('user_role') ?? 'guest';
    _parkingName = prefs.getString('parking_name') ?? '';
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _multiStaffEnabled = prefs.getBool('multi_staff_enabled') ?? false;
    final trialStr = prefs.getString('trial_expires');
    if (trialStr != null && trialStr.isNotEmpty) {
      _trialExpires = DateTime.tryParse(trialStr);
    }

    if (_token == null || _userName.isEmpty) {
      // No saved credentials — check if we have local data to allow offline
      if (_token == 'offline_local_token') {
        _isOffline = true;
        await SimpleVehicleService.loadFromLocalDatabase();
        _status = AuthStatus.authenticated;
        notifyListeners();
        return;
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Skip backend validation for offline mode
    if (_token == 'offline_local_token') {
      _isOffline = true;
      await SimpleVehicleService.loadFromLocalDatabase();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // Trust saved token - mark as online, validate in background
    _isOffline = false;
    _status = AuthStatus.authenticated;
    notifyListeners();

    // Initialize vehicle service (loads from local DB first, syncs in background)
    await SimpleVehicleService.initialize(_token!);

    // Sync settings from backend
    SettingsSyncService.loadFromBackend(_token!);

    // Refresh role from backend (in case admin changed it)
    _refreshRole();

    // Background validate - don't block the UI
    _validateInBackground();

    notifyListeners();
  }

  Future<void> _validateInBackground() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/validate'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        // Token expired on server - force re-login next time
        _isOffline = true;
        notifyListeners();
      }
    } catch (_) {
      // Network issue - mark offline silently
      _isOffline = true;
      notifyListeners();
    }
  }

  Future<void> _refreshRole() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['user'] != null) {
          final user = data['data']['user'];
          final newRole = (user['role'] as String?) ?? _userRole;
          final newMultiStaff = user['multi_device_enabled'] == true || user['multiDeviceEnabled'] == true;
          bool changed = false;
          if (newRole != _userRole) { _userRole = newRole; changed = true; }
          if (newMultiStaff != _multiStaffEnabled) { _multiStaffEnabled = newMultiStaff; changed = true; }
          if (changed) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_role', _userRole);
            await prefs.setBool('multi_staff_enabled', _multiStaffEnabled);
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  /// Login with credentials
  Future<String?> login(String username, String password) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final deviceId = await DeviceService.getDeviceId();
      final deviceInfo = await DeviceService.getDeviceInfo();

      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
          'platform': deviceInfo['platform'] ?? 'Android',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['data']['user'];
        _token = data['data']['token'];
        _refreshToken = data['data']['refreshToken'];
        _userId = userData['id'] ?? '';
        _userName = userData['fullName'] ?? userData['username'] ?? '';
        _userEmail = userData['email'] ?? userData['username'] ?? '';
        _userRole = userData['role'] ?? userData['userType'] ?? 'owner';
        _parkingName = userData['parkingName'] ?? '';
        _multiStaffEnabled = userData['multiDeviceEnabled'] == true;
        final trialStr = userData['trialExpiresAt'] ?? '';
        if (trialStr.isNotEmpty) _trialExpires = DateTime.tryParse(trialStr);

        await _saveCredentials();

        // Populate business settings from login data if empty locally
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getString('business_name') ?? '').isEmpty && _parkingName.isNotEmpty) {
          await prefs.setString('business_name', _parkingName);
        }

        await SimpleVehicleService.initialize(_token!);
        _status = AuthStatus.authenticated;
        _isOffline = false;
        notifyListeners();
        return null; // success
      } else if (response.statusCode == 403 && data['code'] == 'DEVICE_LIMIT_REACHED') {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'DEVICE_LIMIT';
      } else {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return data['error'] ?? 'Login failed';
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        return 'Cannot connect to server. Check your internet connection.';
      } else if (e.toString().contains('TimeoutException')) {
        return 'Connection timeout. Server might be down.';
      }
      return 'Connection error: ${e.toString()}';
    }
  }

  /// Guest signup
  Future<String?> guestSignup({
    required String name,
    required String parkingName,
    required String password,
    String? email,
    String? phone,
  }) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final deviceInfo = await DeviceService.getDeviceInfo();
      final deviceId = await DeviceService.getDeviceId();

      final emailToUse = (email == null || email.isEmpty)
          ? 'guest_${DateTime.now().millisecondsSinceEpoch}@go2parking.temp'
          : email;

      final response = await http.post(
        Uri.parse(ApiConfig.guestSignupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': name,
          'email': emailToUse,
          'phone': phone ?? '',
          'parkingName': parkingName,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
          'platform': deviceInfo['platform'] ?? 'Android',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        final userData = data['data']['user'];
        _token = data['data']['token'];
        _refreshToken = data['data']['refreshToken'];
        _userId = userData['id'] ?? '';
        _userName = userData['fullName'] ?? name;
        _userEmail = userData['email'] ?? emailToUse;
        _userRole = userData['userType'] ?? 'guest';
        _parkingName = userData['parkingName'] ?? parkingName;
        _multiStaffEnabled = userData['multiDeviceEnabled'] == true;
        final trialStr = userData['trialExpiresAt'] ?? '';
        if (trialStr.isNotEmpty) _trialExpires = DateTime.tryParse(trialStr);

        await _saveCredentials();

        // Populate business settings from signup data on first registration
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getString('business_name') ?? '').isEmpty && _parkingName.isNotEmpty) {
          await prefs.setString('business_name', _parkingName);
        }
        if ((prefs.getString('business_phone') ?? '').isEmpty && (phone ?? '').isNotEmpty) {
          await prefs.setString('business_phone', phone!);
        }

        await SimpleVehicleService.initialize(_token!);
        _status = AuthStatus.authenticated;
        _isOffline = false;
        notifyListeners();
        return null;
      } else {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return data['error'] ?? data['message'] ?? 'Registration failed';
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'Connection error: ${e.toString()}';
    }
  }

  /// Logout
  Future<void> logout() async {
    SimpleVehicleService.stopPeriodicSync();
    await _clearCredentials();
    _token = null;
    _refreshToken = null;
    _userId = null;
    _userName = '';
    _userEmail = '';
    _userRole = 'guest';
    _parkingName = '';
    _trialExpires = null;
    _isOffline = false;
    _multiStaffEnabled = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Continue offline (when network fails during init)
  void continueOffline() {
    _isOffline = true;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Login offline without backend - for fully local operation
  Future<void> loginOffline({String name = 'Local User', String parkingName = 'My Parking'}) async {
    _token = 'offline_local_token';
    _userName = name;
    _userEmail = '';
    _userRole = 'owner';
    _parkingName = parkingName;
    _isOffline = true;
    _status = AuthStatus.authenticated;
    await _saveCredentials();
    await SimpleVehicleService.loadFromLocalDatabase();
    notifyListeners();
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token ?? '');
    await prefs.setString('refresh_token', _refreshToken ?? '');
    await prefs.setString('user_id', _userId ?? '');
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_role', _userRole);
    await prefs.setString('parking_name', _parkingName);
    await prefs.setString('trial_expires', _trialExpires?.toIso8601String() ?? '');
    await prefs.setBool('multi_staff_enabled', _multiStaffEnabled);
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    // Only remove auth keys - preserve business settings, rates, printer config
    for (final key in ['auth_token', 'refresh_token', 'user_id', 'user_name', 'user_email', 'user_role', 'parking_name', 'trial_expires']) {
      await prefs.remove(key);
    }
  }
}
