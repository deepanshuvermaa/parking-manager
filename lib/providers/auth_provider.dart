import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/device_info_helper.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _deviceId;
  Timer? _sessionCheckTimer;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isGuest => _currentUser?.isGuest ?? false;
  bool get canAccess => _currentUser?.canAccess ?? false;
  int get remainingTrialDays => _currentUser?.remainingTrialDays ?? 0;

  AuthProvider() {
    _initializeProvider();
  }
  
  Future<void> _initializeProvider() async {
    _deviceId = await DeviceInfoHelper.getDeviceId();
    await checkAuthStatus();
    _startSessionCheck();
  }
  
  void _startSessionCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSessionValidity();
    });
  }
  
  Future<void> _checkSessionValidity() async {
    if (_currentUser == null) return;
    
    // Check if guest trial expired
    if (_currentUser!.isGuest && !_currentUser!.canAccess) {
      await logout();
      notifyListeners();
      return;
    }
    
    // Check if device changed (another device logged in)
    if (_deviceId != null && _currentUser!.currentDeviceId != _deviceId) {
      // Another device has logged in, force logout
      await logout(showMessage: 'You have been logged out because your account was accessed from another device.');
      notifyListeners();
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
        _currentUser = User(
          id: userId,
          username: username,
          password: '', // We don't store password in preferences
          fullName: fullName,
          role: role,
          createdAt: DateTime.now(),
        );
        _isAuthenticated = true;
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, bool rememberMe) async {
    _isLoading = true;
    notifyListeners();

    try {
      
      // Normal database authentication
      final user = await _dbHelper.authenticateUser(username, password);
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;

        // Save to preferences if remember me is checked
        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', user.id);
          await prefs.setString('username', user.username ?? '');
          await prefs.setString('fullName', user.fullName ?? '');
          await prefs.setString('role', user.role);
          await prefs.setBool('rememberMe', true);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>> signupAsGuest({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      if (_deviceId == null) {
        _deviceId = await DeviceInfoHelper.getDeviceId();
      }
      
      // Check if device is already in use by another user
      final deviceInUse = await _dbHelper.isDeviceInUse(_deviceId!);
      if (deviceInUse) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'This device is already registered with another account. Please logout from that account first.',
        };
      }
      
      // Create guest user - store extra info separately
      final user = await _dbHelper.createGuestUser(_deviceId!);
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.id);
        await prefs.setString('username', user.username ?? '');
        await prefs.setString('fullName', user.fullName ?? '');
        await prefs.setString('role', user.role);
        await prefs.setBool('rememberMe', true);
        
        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'Account created successfully! You have a 3-day free trial.',
          'trialDays': 3,
        };
      } else {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'An account with this email already exists.',
        };
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Failed to create account. Please try again.',
      };
    }
  }
  
  Future<bool> upgradeToSubscription(String paymentId, int months) async {
    if (_currentUser == null || !_currentUser!.isGuest) return false;
    
    try {
      final endDate = DateTime.now().add(Duration(days: months * 30));
      // Update user subscription
      await _dbHelper.updateUserSubscription(
        _currentUser!.id,
        paymentId,
      );
      const success = true;
      
      if (success) {
        // Refresh user data
        final users = await _dbHelper.getAllUsers();
        final updatedUser = users.firstWhere((u) => u.id == _currentUser!.id);
        _currentUser = updatedUser;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      debugPrint('Subscription upgrade error: $e');
      return false;
    }
  }
  
  Future<void> logout({String? showMessage}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear only auth-related preferences, preserve other app settings
      await prefs.remove('userId');
      await prefs.remove('username');
      await prefs.remove('fullName');
      await prefs.remove('role');
      await prefs.remove('rememberMe');
      await prefs.remove('deviceId');
      
      _currentUser = null;
      _isAuthenticated = false;
      _deviceId = null;
      
      // Show logout message if provided
      if (showMessage != null) {
        debugPrint('Logout message: $showMessage');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;

    try {
      final success = await _dbHelper.changePassword(
        _currentUser!.id,
        oldPassword,
        newPassword,
      );
      return success;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    }
  }

  Future<bool> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    if (!isAdmin) return false;

    try {
      final newUser = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: username,
        password: _dbHelper.hashPassword(password),
        fullName: fullName,
        role: role,
        createdAt: DateTime.now(),
      );

      await _dbHelper.createUser(newUser);
      return true;
    } catch (e) {
      debugPrint('Create user error: $e');
      return false;
    }
  }

  Future<List<User>> getAllUsers() async {
    if (!isAdmin) return [];
    
    try {
      return await _dbHelper.getAllUsers();
    } catch (e) {
      debugPrint('Get users error: $e');
      return [];
    }
  }

  Future<bool> updateUserStatus(String userId, bool isActive) async {
    if (!isAdmin) return false;

    try {
      final users = await _dbHelper.getAllUsers();
      final user = users.firstWhere((u) => u.id == userId);

      // Store status in metadata since User doesn't have isActive field
      final updatedMetadata = Map<String, dynamic>.from(user.metadata ?? {});
      updatedMetadata['isActive'] = isActive;

      final updatedUser = user.copyWith(metadata: updatedMetadata);
      await _dbHelper.updateUser(updatedUser);
      return true;
    } catch (e) {
      debugPrint('Update user status error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    if (!isAdmin || userId == _currentUser?.id) return false;

    try {
      await _dbHelper.deleteUser(userId);
      return true;
    } catch (e) {
      debugPrint('Delete user error: $e');
      return false;
    }
  }
}