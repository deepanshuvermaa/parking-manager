import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../models/vehicle.dart';

class MigrationService {
  static const String _migrationKey = 'migration_completed_v1';
  static const String _backendIntegrationKey = 'backend_integration_enabled';
  
  // Check if migration to hybrid system is completed
  static Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationKey) ?? false;
  }
  
  // Mark migration as completed
  static Future<void> markMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationKey, true);
  }
  
  // Check if backend integration is enabled
  static Future<bool> isBackendIntegrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backendIntegrationKey) ?? true; // Default to enabled
  }
  
  // Enable/disable backend integration
  static Future<void> setBackendIntegration(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backendIntegrationKey, enabled);
  }
  
  // Migrate local data to support hybrid system
  static Future<void> migrateToHybridSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final dbHelper = DatabaseHelper();
    
    try {
      // Check if this is a fresh install or needs migration
      final hasExistingData = await _hasExistingLocalData();
      
      if (hasExistingData && await ApiService.isBackendHealthy()) {
        // Backend is available, attempt to sync existing data
        await _syncExistingDataToBackend();
      }
      
      // Create new configuration entries
      await prefs.setBool(_backendIntegrationKey, true);
      await prefs.setString('app_mode', 'hybrid');
      
      await markMigrationCompleted();
      
      print('✅ Migration to hybrid system completed');
    } catch (e) {
      print('❌ Migration error: $e');
      // If migration fails, disable backend integration for safety
      await prefs.setBool(_backendIntegrationKey, false);
      await prefs.setString('app_mode', 'offline_only');
    }
  }
  
  static Future<bool> _hasExistingLocalData() async {
    final dbHelper = DatabaseHelper();
    try {
      final vehicles = await dbHelper.getActiveVehicles();
      return vehicles.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> _syncExistingDataToBackend() async {
    final dbHelper = DatabaseHelper();
    
    try {
      // Get all local vehicles
      final localVehicles = await dbHelper.getActiveVehicles();
      
      if (localVehicles.isNotEmpty) {
        print('📤 Syncing ${localVehicles.length} local vehicles to backend...');
        
        // Convert to Vehicle objects and send to backend
        final vehicles = localVehicles;
        final success = await ApiService.syncVehicles(vehicles);
        
        if (success) {
          print('✅ Local data synced successfully');
        } else {
          print('⚠️ Failed to sync local data to backend');
        }
      }
    } catch (e) {
      print('❌ Error syncing existing data: $e');
      rethrow;
    }
  }
  
  // Reset migration status (for development/testing)
  static Future<void> resetMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationKey);
    await prefs.remove(_backendIntegrationKey);
    await prefs.remove('app_mode');
  }
  
  // Get current app mode
  static Future<String> getAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_mode') ?? 'hybrid';
  }
  
  // Set app mode
  static Future<void> setAppMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode);
  }
}