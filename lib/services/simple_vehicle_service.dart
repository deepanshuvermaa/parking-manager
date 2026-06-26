import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/simple_vehicle.dart';
import '../utils/debug_logger.dart';
import '../config/api_config.dart';
import 'local_database_service.dart';
import 'vehicle_rate_service.dart';
import 'ticket_id_service.dart';

class SimpleVehicleService {
  static String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');
  static List<SimpleVehicle> _cachedVehicles = [];
  static bool _isInitialized = false;
  static DateTime? _lastSyncTime;
  static Timer? _syncTimer;
  static bool _isSyncing = false;

  // Sync health — exposed so UI can show warnings
  static int syncErrorCount = 0;
  static String? lastSyncError;
  static int unsyncedCount = 0;

  /// Generate a collision-safe local ID using random hex (UUID v4)
  static String _generateLocalId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'local_${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ============================================
  // INITIALIZATION AND SYNC
  // ============================================

  /// Initialize service, load local data, start background sync
  static Future<void> initialize(String token) async {
    if (_isInitialized) return;

    // Always load from local DB first (instant)
    await loadFromLocalDatabase();
    _isInitialized = true;

    // Skip backend for offline mode
    if (token.isEmpty || token == 'offline_local_token') return;

    // Background: push unsynced, then pull from backend
    _fullSync(token);

    // Start periodic sync every 2 minutes
    _startPeriodicSync(token);
  }

  /// Start periodic background sync timer
  static void _startPeriodicSync(String token) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!_isSyncing) _fullSync(token);
    });
  }

  /// Stop periodic sync (call on logout)
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Full bidirectional sync: push local unsynced → pull from backend
  static Future<void> _fullSync(String token) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // STEP 1: Push unsynced local vehicles to backend
      await syncPendingChanges(token);

      // STEP 2: Pull from backend and batch-save to local DB
      await _pullFromBackend(token);

      syncErrorCount = 0;
      lastSyncError = null;
      _lastSyncTime = DateTime.now();
    } catch (e) {
      syncErrorCount++;
      lastSyncError = e.toString();
      print('❌ Full sync failed: $e');
    } finally {
      _isSyncing = false;
      // Update unsynced count
      try {
        final unsynced = await LocalDatabaseService.getUnsyncedVehicles();
        unsyncedCount = unsynced.length;
      } catch (_) {}
    }
  }

  /// Pull vehicles from backend and batch-save to local database
  static Future<void> _pullFromBackend(String token) async {
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

        // Batch save in a single transaction
        await LocalDatabaseService.batchSaveVehicles(backendVehicles, synced: true);

        // Reload cache from DB (single source of truth)
        await loadFromLocalDatabase();
        return;
      }
    }

    throw Exception('Pull failed: HTTP ${response.statusCode}');
  }

  /// Load vehicles from local database (recent ones only for performance)
  static Future<void> loadFromLocalDatabase() async {
    try {
      // Load only last 30 days + all parked vehicles for active use
      _cachedVehicles = await LocalDatabaseService.getRecentVehicles(days: 30);
    } catch (e) {
      print('❌ Error loading from local DB: $e');
      _cachedVehicles = [];
    }
  }

  /// Get all vehicles (from memory cache, triggers background sync)
  static Future<List<SimpleVehicle>> getVehicles(String token) async {
    if (!_isInitialized) {
      await initialize(token);
    }

    // Trigger background sync if stale (>60s since last sync)
    if (token.isNotEmpty && token != 'offline_local_token') {
      final now = DateTime.now();
      if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds > 60) {
        _lastSyncTime = now;
        _fullSync(token); // Fire-and-forget, non-blocking
      }
    }

    return _cachedVehicles;
  }

  // ============================================
  // VEHICLE OPERATIONS (OFFLINE-FIRST)
  // ============================================

  /// Check if a vehicle plate is already parked (duplicate detection)
  static bool isVehicleParked(String plateNumber) {
    final plate = plateNumber.toUpperCase().trim();
    return _cachedVehicles.any(
      (v) => v.vehicleNumber == plate && v.status == 'parked',
    );
  }

  /// Add new vehicle - SAVE LOCALLY FIRST, then fire-and-forget sync to backend
  static Future<SimpleVehicle?> addVehicle({
    required String token,
    required String vehicleNumber,
    required String vehicleType,
    double? hourlyRate,
    double? minimumRate,
    String? notes,
    String? fromLocation,
    String? toLocation,
    String? bookedBy,
    String? bookedByMobile,
    String? driverName,
    String? driverMobile,
    double? fare,
  }) async {
    final ticketId = await TicketIdService.generateNextTicketId();

    final vehicle = SimpleVehicle(
      id: _generateLocalId(),
      vehicleNumber: vehicleNumber.toUpperCase(),
      vehicleType: vehicleType,
      entryTime: DateTime.now(),
      status: 'parked',
      ticketId: ticketId,
      hourlyRate: hourlyRate ?? getDefaultRate(vehicleType)['hourly'],
      minimumRate: minimumRate ?? getDefaultRate(vehicleType)['minimum'],
      notes: notes,
      fromLocation: fromLocation,
      toLocation: toLocation,
      bookedBy: bookedBy?.isNotEmpty == true ? bookedBy : null,
      bookedByMobile: bookedByMobile?.isNotEmpty == true ? bookedByMobile : null,
      driverName: driverName?.isNotEmpty == true ? driverName : null,
      driverMobile: driverMobile?.isNotEmpty == true ? driverMobile : null,
      fare: fare,
    );

    // 1. SAVE LOCALLY FIRST (instant, guaranteed)
    try {
      await LocalDatabaseService.saveVehicle(vehicle, synced: false);
      _cachedVehicles.insert(0, vehicle);
    } catch (e) {
      print('❌ Failed to save locally: $e');
      return null;
    }

    // 2. FIRE-AND-FORGET backend sync (non-blocking — UI returns immediately)
    if (token.isNotEmpty && token != 'offline_local_token') {
      _syncSingleVehicleToBackend(token, vehicle);
    }

    return vehicle;
  }

  /// Non-blocking: sync a single newly added vehicle to backend
  static Future<void> _syncSingleVehicleToBackend(String token, SimpleVehicle vehicle) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/vehicles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'vehicleNumber': vehicle.vehicleNumber,
          'vehicleType': vehicle.vehicleType,
          'entryTime': vehicle.entryTime.toUtc().toIso8601String(),
          'hourlyRate': vehicle.hourlyRate,
          'minimumRate': vehicle.minimumRate,
          'notes': vehicle.notes,
          'ticketId': vehicle.ticketId,
          'fromLocation': vehicle.fromLocation,
          'toLocation': vehicle.toLocation,
          'bookedBy': vehicle.bookedBy,
          'bookedByMobile': vehicle.bookedByMobile,
          'driverName': vehicle.driverName,
          'driverMobile': vehicle.driverMobile,
          'fare': vehicle.fare,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['vehicle'] != null) {
          final backendVehicle = SimpleVehicle.fromJson(data['data']['vehicle']);
          await LocalDatabaseService.saveVehicle(backendVehicle, synced: true);
          // Update cache
          final index = _cachedVehicles.indexWhere((v) => v.ticketId == vehicle.ticketId);
          if (index != -1) _cachedVehicles[index] = backendVehicle;
        }
      }
    } catch (e) {
      // Will be retried by periodic syncPendingChanges
      print('⚠️ Background sync will retry: $e');
    }
  }

  /// Exit vehicle - SAVE LOCALLY FIRST, then fire-and-forget sync
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

    // Optimistic lock: prevent double-exit
    if (vehicle.status == 'exited') {
      print('⚠️ Vehicle already exited: $vehicleId');
      return null;
    }

    final exitTime = DateTime.now();
    final durationMinutes = exitTime.difference(vehicle.entryTime).inMinutes;

    vehicle.exitTime = exitTime;
    vehicle.status = 'exited';
    vehicle.amount = amount;
    vehicle.notes = notes;
    vehicle.durationMinutes = durationMinutes;

    // 1. SAVE LOCALLY FIRST (instant)
    try {
      await LocalDatabaseService.updateVehicle(vehicle, synced: false);
      _cachedVehicles[index] = vehicle;
    } catch (e) {
      print('❌ Failed to save exit locally: $e');
      return null;
    }

    // 2. FIRE-AND-FORGET backend sync
    if (token.isNotEmpty && token != 'offline_local_token') {
      _syncExitToBackend(token, vehicle);
    }

    return vehicle;
  }

  /// Non-blocking: sync vehicle exit to backend
  static Future<void> _syncExitToBackend(String token, SimpleVehicle vehicle) async {
    try {
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await LocalDatabaseService.markAsSynced(vehicle.id);
      }
    } catch (e) {
      print('⚠️ Exit sync will retry: $e');
    }
  }

  // ============================================
  // BACKGROUND SYNC — PUSH UNSYNCED TO BACKEND
  // ============================================

  /// Push all unsynced local changes to backend (called by periodic timer)
  static Future<void> syncPendingChanges(String token) async {
    if (token.isEmpty || token == 'offline_local_token') return;

    final unsyncedVehicles = await LocalDatabaseService.getUnsyncedVehicles();
    if (unsyncedVehicles.isEmpty) {
      unsyncedCount = 0;
      return;
    }

    int synced = 0;
    int failed = 0;

    for (var vehicle in unsyncedVehicles) {
      try {
        if (vehicle.status == 'exited' && vehicle.exitTime != null) {
          final response = await http.put(
            Uri.parse('$baseUrl/api/vehicles/${vehicle.id}/exit'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({
              'exitTime': vehicle.exitTime!.toIso8601String(),
              'amount': vehicle.amount,
              'notes': vehicle.notes,
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            await LocalDatabaseService.markAsSynced(vehicle.id);
            synced++;
          } else {
            failed++;
          }
        } else {
          final response = await http.post(
            Uri.parse('$baseUrl/api/vehicles'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({
              'vehicleNumber': vehicle.vehicleNumber,
              'vehicleType': vehicle.vehicleType,
              'entryTime': vehicle.entryTime.toUtc().toIso8601String(),
              'hourlyRate': vehicle.hourlyRate,
              'minimumRate': vehicle.minimumRate,
              'notes': vehicle.notes,
              'ticketId': vehicle.ticketId,
              'fromLocation': vehicle.fromLocation,
              'toLocation': vehicle.toLocation,
              'bookedBy': vehicle.bookedBy,
              'bookedByMobile': vehicle.bookedByMobile,
              'driverName': vehicle.driverName,
              'driverMobile': vehicle.driverMobile,
              'fare': vehicle.fare,
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 201 || response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true && data['data']?['vehicle'] != null) {
              final backendVehicle = SimpleVehicle.fromJson(data['data']['vehicle']);
              await LocalDatabaseService.saveVehicle(backendVehicle, synced: true);
              synced++;
            }
          } else {
            failed++;
          }
        }
      } catch (e) {
        failed++;
      }
    }

    unsyncedCount = failed;
    if (synced > 0) print('✅ Synced $synced pending vehicles ($failed failed)');
  }

  // ============================================
  // FEE CALCULATION
  // ============================================

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

    final rates = getDefaultRate(vehicleType);
    final hourly = hourlyRate ?? rates['hourly'];
    final minimum = minimumRate ?? rates['minimum'];
    final freeMinutes = rates['freeMinutes'] as int;
    final minimumDurationMinutes = rates['minimumDurationMinutes'] as int;

    if (freeMinutes > 0 && minutes <= freeMinutes) return 0;
    if (minutes <= minimumDurationMinutes) return minimum;

    final hours = (minutes / 60).ceil();
    final amount = hours * hourly;
    return amount < minimum ? minimum : amount.toDouble();
  }

  // Cached rates — allocated once, never re-allocated
  static const Map<String, Map<String, dynamic>> _defaultRates = {
    'Car': {'hourly': 20.0, 'minimum': 20.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Bike': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Scooter': {'hourly': 10.0, 'minimum': 10.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'SUV': {'hourly': 30.0, 'minimum': 30.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Van': {'hourly': 25.0, 'minimum': 25.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Bus': {'hourly': 50.0, 'minimum': 50.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Truck': {'hourly': 40.0, 'minimum': 40.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Auto Rickshaw': {'hourly': 15.0, 'minimum': 15.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'E-Rickshaw': {'hourly': 12.0, 'minimum': 12.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Cycle': {'hourly': 5.0, 'minimum': 5.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'E-Cycle': {'hourly': 8.0, 'minimum': 8.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Tempo': {'hourly': 25.0, 'minimum': 25.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
    'Mini Truck': {'hourly': 30.0, 'minimum': 30.0, 'freeMinutes': 0, 'minimumDurationMinutes': 30},
  };

  static Map<String, dynamic> getDefaultRate(String vehicleType) {
    return _defaultRates[vehicleType] ?? _defaultRates['Car']!;
  }

  static List<String> getVehicleTypes() {
    return ['Car', 'Bike', 'Scooter', 'SUV', 'Van', 'Bus', 'Truck', 'Auto Rickshaw', 'E-Rickshaw', 'Cycle', 'E-Cycle', 'Tempo', 'Mini Truck'];
  }

  static int getParkedCount() {
    return _cachedVehicles.where((v) => v.status == 'parked').length;
  }

  /// Get today's collection from LOCAL DATABASE (not memory cache)
  static Future<double> getTodayCollectionFromDb() async {
    return await LocalDatabaseService.getTodayRevenue();
  }

  /// Legacy: get from memory cache (fast but may be stale)
  static double getTodayCollection() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return _cachedVehicles
        .where((v) => v.exitTime != null && v.exitTime!.isAfter(todayStart) && v.amount != null)
        .fold(0.0, (sum, v) => sum + (v.amount ?? 0));
  }

  /// Get vehicles for reports with date range filter (from DB, not cache)
  static Future<List<SimpleVehicle>> getVehiclesForReport({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) async {
    return await LocalDatabaseService.getVehiclesByDateRange(
      startDate: startDate,
      endDate: endDate,
      status: status,
    );
  }
}
