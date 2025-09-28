import 'package:flutter/material.dart';
import 'auth_state_provider.dart';
import 'settings_state_provider.dart';
import 'vehicle_provider.dart';
import '../services/sync_service.dart';
import '../models/sync_metadata.dart';

/// Root application state provider
/// Coordinates all other providers and manages app-wide state
class AppStateProvider extends ChangeNotifier {
  final AuthStateProvider authProvider = AuthStateProvider();
  final SettingsStateProvider settingsProvider = SettingsStateProvider();
  final VehicleProvider vehicleProvider = VehicleProvider();
  final SyncService _syncService = SyncService();

  bool _isInitialized = false;
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.synced;

  /// Check if app is initialized
  bool get isInitialized => _isInitialized;

  /// Check if app is online
  bool get isOnline => _isOnline;

  /// Current sync status
  SyncStatus get syncStatus => _syncStatus;

  /// Constructor
  AppStateProvider() {
    print('🔨 AppStateProvider initialized');
    _setupListeners();
  }

  /// Setup listeners for child providers
  void _setupListeners() {
    // Listen to auth changes
    authProvider.addListener(_onAuthChanged);

    // Listen to sync status
    _syncService.syncStatusStream.listen((status) {
      _syncStatus = status;
      notifyListeners();
    });
  }

  /// Initialize app
  Future<void> initialize() async {
    print('🚀 Initializing app...');

    try {
      // Initialize auth first with timeout
      await authProvider.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Auth initialization timeout - marking as initialized');
        },
      );

      // If authenticated, initialize other providers
      if (authProvider.isAuthenticated) {
        // Don't block on authenticated state init
        Future.microtask(() async {
          await _initializeAuthenticatedState();
        });
      }

      _isInitialized = true;
      notifyListeners();

      print('✅ App initialization complete');
    } catch (e) {
      print('❌ App initialization error: $e');
      // Mark as initialized even on error so app doesn't hang
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Initialize state for authenticated user
  Future<void> _initializeAuthenticatedState() async {
    print('👤 Initializing authenticated state...');

    // Initialize settings
    await settingsProvider.initialize();

    // Initialize vehicle provider
    await vehicleProvider.loadVehicles();

    // Start sync service
    await _syncService.initialize();

    // Check device status
    await authProvider.checkDeviceStatus();
  }

  /// Handle auth state changes
  void _onAuthChanged() {
    print('🔄 Auth state changed: ${authProvider.isAuthenticated}');

    if (authProvider.isAuthenticated && !authProvider.isGuest) {
      // User logged in - initialize services
      _initializeAuthenticatedState();
    } else if (!authProvider.isAuthenticated) {
      // User logged out - cleanup
      _cleanup();
    }

    notifyListeners();
  }

  /// Cleanup on logout
  void _cleanup() {
    print('🧹 Cleaning up app state...');

    // Stop sync
    _syncService.stopPeriodicSync();

    // Clear vehicle data
    vehicleProvider.clearVehicles();

    // Settings persist across logout
    // settingsProvider.clearSettings(); // Don't clear settings

    _syncStatus = SyncStatus.synced;
  }

  /// Force sync all data
  Future<void> syncAllData() async {
    if (!authProvider.isAuthenticated || authProvider.isGuest) {
      print('⚠️ Sync skipped - not authenticated or guest user');
      return;
    }

    print('🔄 Force syncing all data...');

    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      final result = await _syncService.syncAll(
        authToken: authProvider.session?.token,
      );

      if (result.success) {
        _syncStatus = SyncStatus.synced;
        print('✅ Sync successful: ${result.itemsSynced} items');
      } else {
        _syncStatus = SyncStatus.failed;
        print('⚠️ Sync partially failed: ${result.itemsFailed} items');
      }
    } catch (e) {
      _syncStatus = SyncStatus.failed;
      print('❌ Sync error: $e');
    }

    notifyListeners();
  }

  /// Check online status
  Future<void> checkOnlineStatus() async {
    // This would check actual connectivity
    // For now, assume online
    _isOnline = true;
    notifyListeners();
  }

  /// Handle app resume
  Future<void> onAppResume() async {
    print('📱 App resumed');

    // Check if still authenticated
    if (authProvider.isAuthenticated) {
      // Check device status
      await authProvider.checkDeviceStatus();

      // Check token expiry
      await authProvider.refreshTokenIfNeeded();

      // Sync data
      if (_isOnline) {
        await syncAllData();
      }
    }
  }

  /// Handle app pause
  Future<void> onAppPause() async {
    print('📱 App paused');

    // Save any pending changes
    if (settingsProvider.hasUnsavedChanges) {
      await settingsProvider.saveSettings();
    }

    // Quick sync if online
    if (_isOnline && authProvider.isAuthenticated) {
      _syncService.syncAll(authToken: authProvider.session?.token);
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    authProvider.dispose();
    _syncService.dispose();
    super.dispose();
  }
}