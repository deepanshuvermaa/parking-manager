import 'package:flutter/material.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/device_info_helper.dart';

/// Authentication state provider
/// Single source of truth for authentication state
class AuthStateProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();

  AuthSession? _session;
  bool _isLoading = false;
  String? _lastError;

  /// Current auth session
  AuthSession? get session => _session;

  /// Check if authenticated
  bool get isAuthenticated => _session != null && !_session!.isExpired;

  /// Check if guest
  bool get isGuest => _session?.isGuest ?? false;

  /// Get display name
  String get displayName => _session?.displayName ?? '';

  /// Get user email
  String? get userEmail => _session?.email;

  /// Get user ID
  String? get userId => _session?.userId;

  /// Get user role
  String get userRole => _session?.role ?? 'user';

  /// Check if admin
  bool get isAdmin => _session?.isAdmin ?? false;

  /// Check if can manage staff
  bool get canManageStaff => _session?.canManageStaff ?? false;

  /// Check if super admin
  bool get isSuperAdmin {
    if (_session == null) return false;
    return _session!.email == 'deepanshuverma966@gmail.com';
  }

  /// Get current user map (for compatibility)
  Map<String, dynamic>? get currentUser {
    if (_session == null) return null;
    return _session!.toJson();
  }

  /// Loading state
  bool get isLoading => _isLoading;

  /// Last error
  String? get lastError => _lastError;

  /// Constructor - NO auto-loading
  AuthStateProvider() {
    print('===== AuthStateProvider Constructor =====');
    print('[AuthStateProvider] Constructor called - NO auto-loading');
    print('[AuthStateProvider] Creating AuthService and SyncService instances...');
  }

  /// Initialize provider (called once from main)
  Future<void> initialize() async {
    print('===== AuthStateProvider.initialize() =====');
    print('[AuthStateProvider] Starting initialization...');

    _isLoading = true;
    print('[AuthStateProvider] Set isLoading = true');
    notifyListeners();
    print('[AuthStateProvider] Notified listeners');

    try {
      // Initialize services with timeout
      print('[AuthStateProvider] Starting Future.wait for services...');
      await Future.wait([
        _authService.initialize(),
        _syncService.initialize(),
      ]).timeout(const Duration(seconds: 5), onTimeout: () {
        print('[AuthStateProvider] Services initialization TIMEOUT after 5s');
        return <void>[];
      });
      print('[AuthStateProvider] Services initialized');

      // Check for stored session ONLY if user chose to remember
      try {
        final storedSession = await _authService.checkStoredSession()
            .timeout(const Duration(seconds: 3));

        if (storedSession != null) {
          print('✅ Restored session for: ${storedSession.displayName}');
          _session = storedSession;

          // Start background sync (don't await)
          _syncService.startPeriodicSync();

          // Do initial sync in background (don't await)
          Future.microtask(() {
            _syncService.syncAll(authToken: storedSession.token);
          });
        } else {
          print('📝 No stored session, starting fresh');
          _session = null;
        }
      } catch (e) {
        print('⚠️ Could not check stored session: $e');
        _session = null;
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      _lastError = e.toString();
      _session = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with credentials
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    print('🔐 Login attempt for: $email');

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Perform login
      final session = await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      if (session != null) {
        _session = session;

        // Start sync service
        _syncService.startPeriodicSync();

        // Initial data sync
        await _syncService.syncAll(authToken: session.token);

        print('✅ Login successful: ${session.displayName}');

        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception('Login failed - please check your credentials');
    } catch (e) {
      print('❌ Login error: $e');

      // Parse error message for better user feedback
      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException')) {
        _lastError = 'No internet connection. Please check your network.';
      } else if (errorMessage.contains('TimeoutException')) {
        _lastError = 'Connection timeout. Please try again.';
      } else if (errorMessage.contains('Invalid credentials')) {
        _lastError = 'Invalid email or password.';
      } else {
        _lastError = errorMessage.replaceAll('Exception: ', '');
      }
      _session = null;

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Guest login
  Future<bool> guestLogin(String guestName) async {
    print('👤 Guest login for: $guestName');

    if (guestName.trim().isEmpty) {
      _lastError = 'Please enter your name';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Perform guest login
      final session = await _authService.guestLogin(
        guestName: guestName.trim(),
      );

      if (session != null) {
        _session = session;

        print('✅ Guest login successful: ${session.displayName}');

        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception('Guest login failed - please try again');
    } catch (e) {
      print('❌ Guest login error: $e');

      // Parse error message for better user feedback
      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException')) {
        _lastError = 'No internet connection. Please check your network.';
      } else if (errorMessage.contains('TimeoutException')) {
        _lastError = 'Connection timeout. Please try again.';
      } else {
        _lastError = errorMessage.replaceAll('Exception: ', '');
      }
      _session = null;

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    print('🚪 Logging out: ${_session?.displayName}');

    _isLoading = true;
    notifyListeners();

    try {
      // Stop sync service
      _syncService.stopPeriodicSync();

      // Final sync before logout
      if (_session != null && !_session!.isGuest) {
        await _syncService.syncAll(authToken: _session!.token);
      }

      // Perform logout
      await _authService.logout(_session?.token);

      // Clear session
      _session = null;
      _lastError = null;

      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Force clear session even on error
      _session = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh token if needed
  Future<void> refreshTokenIfNeeded() async {
    if (_session == null || _session!.isGuest) return;

    // Check if token is about to expire (within 5 minutes)
    if (_session!.expiryTime != null) {
      final timeUntilExpiry = _session!.expiryTime!.difference(DateTime.now());

      if (timeUntilExpiry.inMinutes <= 5) {
        print('🔄 Token expiring soon, refreshing...');

        final newSession = await _authService.refreshToken(_session!);

        if (newSession != null) {
          _session = newSession;
          notifyListeners();
          print('✅ Token refreshed');
        } else {
          print('❌ Token refresh failed, user will need to login again');
        }
      }
    }
  }

  /// Check if device is still active
  Future<bool> checkDeviceStatus() async {
    if (_session == null) return true;

    final deviceId = await DeviceInfoHelper.getDeviceId();
    final isActive = await _authService.isDeviceActive(deviceId);

    if (!isActive) {
      print('⚠️ Device no longer active, logging out');
      await logout();
      _lastError = 'You have been logged in on another device';
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Signup with credentials
  Future<bool> signup(
    String email,
    String password,
    String fullName, {
    String? phoneNumber,
  }) async {
    print('📝 Signup attempt for: $email');

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Call signup API
      final response = await _authService.signup(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );

      if (response != null) {
        // Auto-login after successful signup
        final session = await _authService.login(
          email: email,
          password: password,
          rememberMe: true,
        );

        if (session != null) {
          _session = session;
          _syncService.startPeriodicSync();
          await _syncService.syncAll(authToken: session.token);

          print('✅ Signup and login successful: ${session.displayName}');

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      throw Exception('Signup failed');
    } catch (e) {
      print('❌ Signup error: $e');
      _lastError = e.toString();
      _session = null;

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}