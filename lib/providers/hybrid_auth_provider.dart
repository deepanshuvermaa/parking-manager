import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../services/device_info_helper.dart';

class HybridAuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isOnline = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _deviceId;
  Timer? _sessionCheckTimer;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isGuest => _currentUser?.isGuest ?? false;
  bool get canAccess => _currentUser?.canAccess ?? false;
  int get remainingTrialDays => _currentUser?.remainingTrialDays ?? 0;

  HybridAuthProvider() {
    _initializeProvider();
  }
  
  Future<void> _initializeProvider() async {
    _deviceId = await DeviceInfoHelper.getDeviceId();
    await ApiService.initialize();
    await _checkBackendConnectivity();
    await checkAuthStatus();
    _startSessionCheck();
  }

  Future<void> _checkBackendConnectivity() async {
    _isOnline = await ApiService.isBackendHealthy();
    notifyListeners();
  }
  
  void _startSessionCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSessionValidity();
    });
  }
  
  Future<void> _checkSessionValidity() async {
    if (_currentUser == null) return;
    
    // Check backend connectivity periodically
    await _checkBackendConnectivity();
    
    // Check if guest trial expired
    if (_currentUser!.isGuest && !_currentUser!.canAccess) {
      await logout();
      notifyListeners();
      return;
    }
    
    // If online, sync with backend
    if (_isOnline) {
      await _syncWithBackend();
    }
  }
  
  Future<void> _syncWithBackend() async {
    try {
      // Sync user status with backend
      final status = await ApiService.syncUserStatus();
      if (status != null && status['forceLogout'] == true) {
        // Another device logged in, force logout
        await logout(showMessage: 'You have been logged out because your account was accessed from another device.');
        return;
      }

      // Sync vehicles with backend
      final localVehicles = await _dbHelper.getAllVehicles();
      if (localVehicles.isNotEmpty) {
        final vehicleMaps = localVehicles.map((v) => v.toJson()).toList();
        await ApiService.syncVehicles(localVehicles);
      }

      // Sync settings from backend
      final settings = await ApiService.getSettings();
      if (settings != null) {
        // Update local settings from backend
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('settings_json', jsonEncode(settings));
      }

      debugPrint('Backend sync completed successfully');
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }
  
  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final username = prefs.getString('username');
      final fullName = prefs.getString('fullName');
      final role = prefs.getString('role');
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (rememberMe && userId != null && username != null && fullName != null && role != null) {
        // Try to restore user session
        if (_isOnline) {
          // If online, validate with backend
          final isValidSession = await _validateBackendSession();
          if (isValidSession) {
            _currentUser = User(
              id: userId,
              username: username,
              password: '',
              fullName: fullName,
              role: role,
              createdAt: DateTime.now(),
            );
            _isAuthenticated = true;
          } else {
            // Backend session invalid, clear local session
            await _clearLocalSession();
          }
        } else {
          // Offline mode - use local session
          _currentUser = User(
            id: userId,
            username: username,
            password: '',
            fullName: fullName,
            role: role,
            createdAt: DateTime.now(),
          );
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _validateBackendSession() async {
    try {
      // Try to make an authenticated request
      final settings = await ApiService.getSettings();
      return settings != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('fullName');
    await prefs.remove('role');
    await prefs.setBool('rememberMe', false);
  }

  Future<bool> login(String username, String password, bool rememberMe) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user;

      // Check for demo/admin login
      if (username.toLowerCase() == 'admin' && password == 'admin123') {
        user = User(
          id: 'admin_001',
          username: 'admin',
          password: '',
          fullName: 'Admin User',
          role: 'admin',
          createdAt: DateTime.now(),
          isGuest: false,
          subscriptionType: 'premium',
        );
        _currentUser = user;
        _isAuthenticated = true;

        // Save to local session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.id);
        await prefs.setString('username', user.username ?? '');
        await prefs.setString('fullName', user.fullName ?? '');
        await prefs.setString('role', user.role);
        await prefs.setBool('rememberMe', rememberMe);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      if (_isOnline) {
        // Try backend login first
        final backendResponse = await ApiService.login(username, password);
        if (backendResponse != null) {
          user = User(
            id: backendResponse['user']['id'],
            username: backendResponse['user']['username'],
            password: '',
            fullName: backendResponse['user']['fullName'],
            role: backendResponse['user']['role'],
            createdAt: DateTime.parse(backendResponse['user']['createdAt']),
            isGuest: backendResponse['user']['isGuest'] ?? false,
            trialEndDate: backendResponse['user']['trialEndDate'] != null
                ? DateTime.parse(backendResponse['user']['trialEndDate'])
                : DateTime.now().add(const Duration(days: 7)),
          );
          
          // Store in local database for offline access
          await _dbHelper.createUser(user);
        }
      } else {
        // Offline mode - use local database
        user = await _dbHelper.authenticateUser(username, password);
      }
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        // Save auth state
        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', user.id);
          await prefs.setString('username', user.username ?? '');
          await prefs.setString('fullName', user.fullName ?? '');
          await prefs.setString('role', user.role);
          await prefs.setBool('rememberMe', true);
        }
        
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return false;
  }

  Future<bool> guestSignup(String email, String fullName, {String? password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user;

      if (_isOnline) {
        // Try backend signup with proper API call
        Map<String, dynamic>? backendResponse;

        // If password is provided, use the full signup endpoint
        if (password != null && password.isNotEmpty) {
          backendResponse = await ApiService.signup(email, password, fullName);
        } else {
          // Otherwise use guest signup
          backendResponse = await ApiService.guestSignup(email, fullName);
        }

        if (backendResponse != null) {
          final userData = backendResponse['user'] ?? backendResponse;
          user = User(
            id: userData['id'] ?? userData['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            username: userData['username'] ?? userData['email'] ?? email,
            email: userData['email'] ?? email,
            password: '',
            fullName: userData['fullName'] ?? fullName,
            role: userData['role'] ?? 'guest',
            createdAt: userData['createdAt'] != null
                ? DateTime.parse(userData['createdAt'])
                : DateTime.now(),
            isGuest: userData['isGuest'] ?? true,
            trialEndDate: userData['trialEndDate'] != null
                ? DateTime.parse(userData['trialEndDate'])
                : DateTime.now().add(const Duration(days: 3)),
          );

          // Store in local database
          await _dbHelper.createUser(user);
        }
      } else {
        // Offline guest signup
        final trialStart = DateTime.now();
        final trialEnd = trialStart.add(const Duration(days: 3));

        user = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: email,
          email: email,
          password: password ?? 'guest',
          fullName: fullName,
          role: 'guest',
          createdAt: DateTime.now(),
          isGuest: true,
          trialEndDate: trialEnd,
        );

        await _dbHelper.createUser(user);
      }
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        // Save auth state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.id);
        await prefs.setString('username', user.username ?? '');
        await prefs.setString('fullName', user.fullName ?? '');
        await prefs.setString('role', user.role);
        await prefs.setBool('rememberMe', true);
        
        return true;
      }
    } catch (e) {
      debugPrint('Guest signup error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return false;
  }

  Future<void> logout({String? showMessage}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Cancel any ongoing timers
      _sessionCheckTimer?.cancel();
      _sessionCheckTimer = null;

      // Try to logout from backend if online
      if (_isOnline) {
        try {
          await ApiService.logout();
        } catch (e) {
          debugPrint('Backend logout error (continuing anyway): $e');
        }
      }

      // Clear local state
      _currentUser = null;
      _isAuthenticated = false;

      // Clear all stored preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('username');
      await prefs.remove('fullName');
      await prefs.remove('role');
      await prefs.setBool('rememberMe', false);

      // Clear API tokens
      await ApiService.initialize(); // This will clear tokens

    } catch (e) {
      debugPrint('Logout error: $e');
      // Even if there's an error, still clear the local state
      _currentUser = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Force refresh connectivity status
  Future<void> refreshConnectivity() async {
    await _checkBackendConnectivity();
    if (_isOnline && _currentUser != null) {
      await _syncWithBackend();
      await _syncUserStatus();
      await _checkPendingNotifications();
    }
  }

  // Sync user status with backend
  Future<void> _syncUserStatus() async {
    if (!_isOnline || _currentUser == null) return;
    
    try {
      final syncResult = await ApiService.syncUserStatus();
      if (syncResult != null) {
        final user = syncResult['user'];
        final statusChanged = syncResult['statusChanged'] ?? false;
        final newStatus = syncResult['newStatus'];
        
        if (statusChanged) {
          // Update current user with fresh data
          _currentUser = User.fromJson(user);
          
          // Handle status changes
          if (newStatus == 'expired' && _isAuthenticated) {
            // User trial/subscription expired
            await logout();
            _showExpirationNotification();
          } else if (newStatus == 'extended') {
            // User subscription was extended
            _showExtensionNotification();
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Sync user status error: $e');
    }
  }

  // Check for pending notifications
  Future<void> _checkPendingNotifications() async {
    if (!_isOnline || _currentUser == null) return;
    
    try {
      final notifications = await ApiService.getPendingNotifications();
      if (notifications.isNotEmpty) {
        // Show notifications to user
        for (final notification in notifications) {
          _showInAppNotification(notification);
        }
        
        // Mark notifications as read
        final notificationIds = notifications
            .map((n) => n['id'].toString())
            .toList();
        await ApiService.markNotificationsRead(notificationIds);
      }
    } catch (e) {
      debugPrint('Check notifications error: $e');
    }
  }

  // Show expiration notification
  void _showExpirationNotification() {
    // This would typically show a dialog or snackbar
    // For now, we'll just print to debug
    debugPrint('🚫 Trial/Subscription has expired');
  }

  // Show extension notification
  void _showExtensionNotification() {
    debugPrint('✅ Subscription has been extended');
  }

  // Show in-app notification
  void _showInAppNotification(Map<String, dynamic> notification) {
    final type = notification['notification_type'];
    final title = notification['title'];
    final message = notification['message'];
    
    debugPrint('📱 Notification: $title - $message');
    
    // Handle specific notification types
    switch (type) {
      case 'TRIAL_EXPIRING_SOON':
      case 'TRIAL_EXPIRING_FINAL':
        // Show trial expiring dialog
        break;
      case 'SUBSCRIPTION_EXTENDED':
        // Show success message
        break;
      case 'TRIAL_EXPIRED':
        // Force logout
        logout();
        break;
    }
  }
}