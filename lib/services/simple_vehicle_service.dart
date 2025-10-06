import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/simple_vehicle.dart';
import '../utils/debug_logger.dart';
import '../config/api_config.dart';
import 'local_database_service.dart';
import 'vehicle_rate_service.dart';

class SimpleVehicleService {
  static String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');
  static List<SimpleVehicle> _cachedVehicles = [];
  static bool _isInitialized = false;

  // ============================================
  // INITIALIZATION AND SYNC
  // ============================================

  /// Initialize service and sync with backend
  static Future<void> initialize(String token) async {
    if (_isInitialized) {
      print('⚠️ Service already initialized');
      return;
    }

    try {
      await syncWithBackend(token);
      _isInitialized = true;
      print('✅ SimpleVehicleService initialized');
    } catch (e) {
      print('⚠️ Initialization failed, loading from local DB: $e');
      await loadFromLocalDatabase();
      _isInitialized = true;
    }
  }

  /// Sync all data from backend to local database
  static Future<void> syncWithBackend(String token) async {
    try {
      print('🔄 Starting full sync with backend...');

      final response = await http.get(
        Uri.parse('$baseUrl/api/vehicles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final vehiclesList = data['data']['vehicles'] as List;
          final backendVehicles = vehiclesList
              .map((v) => SimpleVehicle.fromJson(v))
              .toList();

          print('✅ Downloaded ${backendVehicles.length} vehicles from backend');

          // Save all vehicles to local database
          for (var vehicle in backendVehicles) {
            await LocalDatabaseService.saveVehicle(vehicle, synced: true);
          }

          // Update memory cache
          _cachedVehicles = backendVehicles;

          print('✅ Sync complete - ${_cachedVehicles.length} vehicles loaded');
          return;
        }
      }

      print('⚠️ Backend sync failed, loading from local DB');
      await loadFromLocalDatabase();
    } catch (e) {
      print('❌ Sync error: $e');
      print('📂 Loading from local database...');
      await loadFromLocalDatabase();
    }
  }

  /// Load vehicles from local database
  static Future<void> loadFromLocalDatabase() async {
    try {
      _cachedVehicles = await LocalDatabaseService.getVehicles();
      print('📂 Loaded ${_cachedVehicles.length} vehicles from local DB');
    } catch (e) {
      print('❌ Error loading from local DB: $e');
      _cachedVehicles = [];
    }
  }

  /// Get all vehicles (from memory cache)
  static Future<List<SimpleVehicle>> getVehicles(String token) async {
    // If not initialized, initialize first
    if (!_isInitialized) {
      await initialize(token);
    }

    // Try to refresh from backend in background
    syncWithBackend(token).catchError((e) {
      print('Background sync failed: $e');
    });

    return _cachedVehicles;
  }

  // ============================================
  // VEHICLE OPERATIONS (OFFLINE-FIRST)
  // ============================================

  /// Add new vehicle - SAVE LOCALLY FIRST, then sync to backend
  static Future<SimpleVehicle?> addVehicle({
    required String token,
    required String vehicleNumber,
    required String vehicleType,
    double? hourlyRate,
    double? minimumRate,
    String? notes,
  }) async {
    // Create vehicle object
    final vehicle = SimpleVehicle(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      vehicleNumber: vehicleNumber.toUpperCase(),
      vehicleType: vehicleType,
      entryTime: DateTime.now(),
      status: 'parked',
      ticketId: 'PE${DateTime.now().millisecondsSinceEpoch}',
      hourlyRate: hourlyRate ?? getDefaultRate(vehicleType)['hourly'],
      minimumRate: minimumRate ?? getDefaultRate(vehicleType)['minimum'],
      notes: notes,
    );

    // 1. SAVE LOCALLY FIRST (guaranteed to succeed)
    try {
      await LocalDatabaseService.saveVehicle(vehicle, synced: false);
      _cachedVehicles.insert(0, vehicle);
      print('✅ Vehicle saved locally: ${vehicle.vehicleNumber}');
    } catch (e) {
      print('❌ Failed to save locally: $e');
      return null;
    }

    // 2. TRY TO SYNC TO BACKEND (optional - will retry later if fails)
    try {
      final requestBody = {
        'vehicleNumber': vehicle.vehicleNumber,
        'vehicleType': vehicle.vehicleType,
        'entryTime': vehicle.entryTime.toIso8601String(),
        'hourlyRate': vehicle.hourlyRate,
        'minimumRate': vehicle.minimumRate,
        'notes': vehicle.notes,
        'ticketId': vehicle.ticketId,
      };

      DebugLogger.log('=== VEHICLE ADD REQUEST ===');
      DebugLogger.log('URL: $baseUrl/api/vehicles');
      DebugLogger.log('Request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/vehicles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      DebugLogger.log('Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          final backendVehicle = SimpleVehicle.fromJson(data['data']['vehicle']);

          // Update local record with backend ID and mark as synced
          await LocalDatabaseService.saveVehicle(backendVehicle, synced: true);

          // Update in cache
          final index = _cachedVehicles.indexWhere((v) => v.ticketId == vehicle.ticketId);
          if (index != -1) {
            _cachedVehicles[index] = backendVehicle;
          }

          print('✅ Vehicle synced to backend: ${backendVehicle.id}');
          return backendVehicle;
        }
      }
    } catch (e) {
      print('⚠️ Backend sync failed (will retry later): $e');
      // Vehicle is already saved locally, so operation succeeded
    }

    return vehicle; // Return local vehicle even if backend sync failed
  }

  /// Exit vehicle - SAVE LOCALLY FIRST, then sync to backend
  static Future<SimpleVehicle?> exitVehicle({
    required String token,
    required String vehicleId,
    required double amount,
    String? notes,
  }) async {
    // Find vehicle in cache
    final index = _cachedVehicles.indexWhere((v) => v.id == vehicleId);
    if (index == -1) {
      print('❌ Vehicle not found in cache: $vehicleId');
      return null;
    }

    final vehicle = _cachedVehicles[index];

    // Calculate duration
    final exitTime = DateTime.now();
    final durationMinutes = exitTime.difference(vehicle.entryTime).inMinutes;

    // Update vehicle locally
    vehicle.exitTime = exitTime;
    vehicle.status = 'exited';
    vehicle.amount = amount;
    vehicle.notes = notes;
    vehicle.durationMinutes = durationMinutes;

    // 1. SAVE LOCALLY FIRST
    try {
      await LocalDatabaseService.updateVehicle(vehicle, synced: false);
      _cachedVehicles[index] = vehicle;
      print('✅ Vehicle exit saved locally: ${vehicle.vehicleNumber}');
    } catch (e) {
      print('❌ Failed to save exit locally: $e');
      return null;
    }

    // 2. TRY TO SYNC TO BACKEND
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/vehicles/$vehicleId/exit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'exitTime': vehicle.exitTime!.toIso8601String(),
          'amount': amount,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await LocalDatabaseService.markAsSynced(vehicleId);
          print('✅ Vehicle exit synced to backend');
        }
      }
    } catch (e) {
      print('⚠️ Backend sync failed (will retry later): $e');
    }

    return vehicle; // Return updated vehicle even if backend sync failed
  }

  // ============================================
  // BACKGROUND SYNC
  // ============================================

  /// Sync pending changes to backend (call periodically)
  static Future<void> syncPendingChanges(String token) async {
    try {
      final unsyncedVehicles = await LocalDatabaseService.getUnsyncedVehicles();

      if (unsyncedVehicles.isEmpty) {
        print('✅ No pending changes to sync');
        return;
      }

      print('🔄 Syncing ${unsyncedVehicles.length} pending changes...');

      for (var vehicle in unsyncedVehicles) {
        try {
          if (vehicle.status == 'exited' && vehicle.exitTime != null) {
            // Sync vehicle exit
            final response = await http.put(
              Uri.parse('$baseUrl/api/vehicles/${vehicle.id}/exit'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'exitTime': vehicle.exitTime!.toIso8601String(),
                'amount': vehicle.amount,
                'notes': vehicle.notes,
              }),
            ).timeout(const Duration(seconds: 15));

            if (response.statusCode == 200) {
              await LocalDatabaseService.markAsSynced(vehicle.id);
              print('✅ Synced exit: ${vehicle.vehicleNumber}');
            }
          } else {
            // Sync new vehicle
            final response = await http.post(
              Uri.parse('$baseUrl/api/vehicles'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'vehicleNumber': vehicle.vehicleNumber,
                'vehicleType': vehicle.vehicleType,
                'entryTime': vehicle.entryTime.toIso8601String(),
                'hourlyRate': vehicle.hourlyRate,
                'minimumRate': vehicle.minimumRate,
                'notes': vehicle.notes,
                'ticketId': vehicle.ticketId,
              }),
            ).timeout(const Duration(seconds: 15));

            if (response.statusCode == 201 || response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['success'] == true && data['data'] != null) {
                final backendVehicle = SimpleVehicle.fromJson(data['data']['vehicle']);
                await LocalDatabaseService.saveVehicle(backendVehicle, synced: true);
                print('✅ Synced new vehicle: ${vehicle.vehicleNumber}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Failed to sync ${vehicle.vehicleNumber}: $e');
          // Continue with next vehicle
        }
      }

      print('✅ Sync completed');
    } catch (e) {
      print('❌ Sync pending changes error: $e');
    }
  }

  // Calculate parking fee (uses new VehicleRateService with time-based pricing)
  static Future<double> calculateFeeAsync({
    required DateTime entryTime,
    required String vehicleType,
    DateTime? exitTime,
  }) async {
    final exit = exitTime ?? DateTime.now();
    final duration = exit.difference(entryTime);
    return await VehicleRateService.calculateFee(
      vehicleType: vehicleType,
      duration: duration,
    );
  }

  // Legacy sync method for backward compatibility
  static double calculateFee({
    required DateTime entryTime,
    required String vehicleType,
    DateTime? exitTime,
    double? hourlyRate,
    double? minimumRate,
  }) {
    final exit = exitTime ?? DateTime.now();
    final duration = exit.difference(entryTime);
    final minutes = duration.inMinutes;

    // Get rates
    final rates = getDefaultRate(vehicleType);
    final hourly = hourlyRate ?? rates['hourly'];
    final minimum = minimumRate ?? rates['minimum'];
    final freeMinutes = rates['freeMinutes'];

    // Free parking period
    if (minutes <= freeMinutes) {
      return 0;
    }

    // Calculate hours (round up)
    final hours = (minutes / 60).ceil();
    final amount = hours * hourly;

    // Apply minimum charge
    return amount < minimum ? minimum : amount.toDouble();
  }

  // Get default rates for vehicle type
  static Map<String, dynamic> getDefaultRate(String vehicleType) {
    final rates = {
      'Car': {'hourly': 20.0, 'minimum': 20.0, 'freeMinutes': 15},
      'Bike': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 10},
      'Scooter': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 10},
      'SUV': {'hourly': 30.0, 'minimum': 30.0, 'freeMinutes': 15},
      'Van': {'hourly': 25.0, 'minimum': 25.0, 'freeMinutes': 15},
      'Bus': {'hourly': 50.0, 'minimum': 50.0, 'freeMinutes': 10},
      'Truck': {'hourly': 40.0, 'minimum': 40.0, 'freeMinutes': 10},
      'Auto Rickshaw': {'hourly': 15.0, 'minimum': 15.0, 'freeMinutes': 10},
      'E-Rickshaw': {'hourly': 12.0, 'minimum': 12.0, 'freeMinutes': 10},
      'Cycle': {'hourly': 5.0, 'minimum': 5.0, 'freeMinutes': 30},
      'E-Cycle': {'hourly': 8.0, 'minimum': 8.0, 'freeMinutes': 20},
      'Tempo': {'hourly': 25.0, 'minimum': 25.0, 'freeMinutes': 15},
      'Mini Truck': {'hourly': 30.0, 'minimum': 30.0, 'freeMinutes': 15},
    };

    return rates[vehicleType] ?? rates['Car']!;
  }

  // Get vehicle types
  static List<String> getVehicleTypes() {
    return [
      'Car',
      'Bike',
      'Scooter',
      'SUV',
      'Van',
      'Bus',
      'Truck',
      'Auto Rickshaw',
      'E-Rickshaw',
      'Cycle',
      'E-Cycle',
      'Tempo',
      'Mini Truck',
    ];
  }

  // Get parked vehicles count
  static int getParkedCount() {
    return _cachedVehicles.where((v) => v.status == 'parked').length;
  }

  // Get today's collection
  static double getTodayCollection() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return _cachedVehicles
        .where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(todayStart) &&
            v.amount != null)
        .fold(0.0, (sum, v) => sum + (v.amount ?? 0));
  }
}