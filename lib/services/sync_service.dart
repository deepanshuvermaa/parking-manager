import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/sync_metadata.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';

/// Data synchronization service
/// Handles offline queue and data sync between device and server
class SyncService {
  final DatabaseService _database = DatabaseService();
  final StorageService _storage = StorageService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  /// Get sync status stream
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    await _storage.initialize();
    // Start periodic sync
    startPeriodicSync();
  }

  /// Start periodic sync (every 30 seconds)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncAll();
    });
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  /// Sync all pending data
  Future<SyncResult> syncAll({String? authToken}) async {
    if (_isSyncing) {
      print('⏳ Sync already in progress');
      return SyncResult.empty();
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      print('🔄 Starting full sync...');

      // Get auth token if not provided
      final token = authToken ?? _getAuthToken();
      if (token == null) {
        print('❌ No auth token, skipping sync');
        return SyncResult.failure('No authentication');
      }

      // Push local changes first
      final pushResult = await _pushLocalChanges(token);

      // Pull server changes
      final pullResult = await _pullServerChanges(token);

      // Update last sync time
      await _storage.saveLastSync(DateTime.now());

      final totalSynced = pushResult.itemsSynced + pullResult.itemsSynced;
      final totalFailed = pushResult.itemsFailed + pullResult.itemsFailed;
      final allErrors = [...pushResult.errors, ...pullResult.errors];

      print('✅ Sync complete: $totalSynced synced, $totalFailed failed');

      _syncStatusController.add(
        totalFailed > 0 ? SyncStatus.failed : SyncStatus.synced
      );

      return SyncResult(
        success: totalFailed == 0,
        itemsSynced: totalSynced,
        itemsFailed: totalFailed,
        errors: allErrors,
        syncTime: DateTime.now(),
      );
    } catch (e) {
      print('❌ Sync error: $e');
      _syncStatusController.add(SyncStatus.failed);
      return SyncResult.failure(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Push local changes to server
  Future<SyncResult> _pushLocalChanges(String token) async {
    try {
      print('⬆️ Pushing local changes...');

      // Get pending items from sync queue
      final pendingItems = await _database.getPendingSyncItems();

      if (pendingItems.isEmpty) {
        print('✅ No pending changes to push');
        return SyncResult.empty();
      }

      print('📦 Found ${pendingItems.length} items to sync');

      int synced = 0;
      int failed = 0;
      final errors = <String>[];

      for (final item in pendingItems) {
        try {
          // Send to server based on operation type
          final success = await _syncItem(item, token);

          if (success) {
            // Remove from queue if successful
            if (item.id != null) {
              await _database.markSyncCompleted(item.id!);
            }
            synced++;
          } else {
            failed++;
            if (item.id != null) {
              await _database.incrementSyncRetry(item.id!, 'Sync failed');
            }
          }
        } catch (e) {
          failed++;
          errors.add('${item.entityType}/${item.entityId}: $e');

          if (item.id != null) {
            await _database.incrementSyncRetry(item.id!, e.toString());
          }
        }
      }

      print('⬆️ Push complete: $synced synced, $failed failed');

      return SyncResult(
        success: failed == 0,
        itemsSynced: synced,
        itemsFailed: failed,
        errors: errors,
        syncTime: DateTime.now(),
      );
    } catch (e) {
      print('❌ Push error: $e');
      return SyncResult.failure(e.toString());
    }
  }

  /// Sync individual item
  Future<bool> _syncItem(SyncQueueItem item, String token) async {
    try {
      final endpoint = _getEndpointForEntity(item.entityType);
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      http.Response response;

      switch (item.operation) {
        case SyncOperation.create:
          response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(item.data),
          ).timeout(const Duration(seconds: 10));
          break;

        case SyncOperation.update:
          response = await http.put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint/${item.entityId}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(item.data),
          ).timeout(const Duration(seconds: 10));
          break;

        case SyncOperation.delete:
          response = await http.delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint/${item.entityId}'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));
          break;
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Error syncing item ${item.entityId}: $e');
      return false;
    }
  }

  /// Pull server changes
  Future<SyncResult> _pullServerChanges(String token) async {
    try {
      print('⬇️ Pulling server changes...');

      // Get last sync timestamp
      final lastSync = _storage.getLastSync() ?? DateTime.now().subtract(const Duration(days: 30));

      // Request changes from server
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sync/changes?since=${lastSync.toIso8601String()}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch server changes');
      }

      final data = jsonDecode(response.body);

      if (data['success'] != true || data['data'] == null) {
        print('✅ No server changes to pull');
        return SyncResult.empty();
      }

      final changes = data['data'] as Map<String, dynamic>;
      int synced = 0;

      // Process each entity type
      for (final entityType in changes.keys) {
        final entities = changes[entityType] as List<dynamic>;

        for (final entity in entities) {
          await _applyServerChange(entityType, entity);
          synced++;
        }
      }

      print('⬇️ Pull complete: $synced items synced');

      return SyncResult(
        success: true,
        itemsSynced: synced,
        itemsFailed: 0,
        errors: [],
        syncTime: DateTime.now(),
      );
    } catch (e) {
      print('❌ Pull error: $e');
      return SyncResult.failure(e.toString());
    }
  }

  /// Apply server change to local database
  Future<void> _applyServerChange(String entityType, Map<String, dynamic> data) async {
    try {
      switch (entityType) {
        case 'vehicles':
          await _database.saveVehicle(data);
          break;

        case 'settings':
          for (final key in data.keys) {
            await _database.saveSetting(
              key,
              data[key].toString(),
              1, // Default version
            );
          }
          break;

        case 'vehicle_types':
          // Handle vehicle types
          break;

        default:
          print('Unknown entity type: $entityType');
      }

      // Update sync metadata
      await _database.updateSyncMetadata(
        SyncMetadata(
          entityType: entityType,
          entityId: data['id']?.toString() ?? '',
          localUpdatedAt: DateTime.now(),
          serverUpdatedAt: DateTime.now(),
          syncStatus: SyncStatus.synced,
          deviceId: _storage.getDeviceId() ?? 'unknown',
        ),
      );
    } catch (e) {
      print('Error applying server change: $e');
    }
  }

  /// Get endpoint for entity type
  String _getEndpointForEntity(String entityType) {
    switch (entityType) {
      case 'vehicles':
        return '/vehicles';
      case 'settings':
        return '/settings';
      case 'vehicle_types':
        return '/vehicle-types';
      default:
        return '/$entityType';
    }
  }

  /// Get auth token from storage
  String? _getAuthToken() {
    final session = _storage.getAuthSession();
    return session?['token'];
  }

  /// Force sync specific entity
  Future<bool> syncEntity(String entityType, String entityId) async {
    try {
      final token = _getAuthToken();
      if (token == null) return false;

      // Get entity data based on type
      Map<String, dynamic>? data;

      switch (entityType) {
        case 'vehicles':
          // Get vehicle data
          break;
        case 'settings':
          data = await _database.getAllSettings();
          break;
      }

      if (data == null) return false;

      // Create sync item
      final item = SyncQueueItem(
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.update,
        data: data,
        createdAt: DateTime.now(),
      );

      // Sync immediately
      return await _syncItem(item, token);
    } catch (e) {
      print('Error syncing entity: $e');
      return false;
    }
  }

  /// Check if sync is needed
  Future<bool> isSyncNeeded() async {
    final pendingItems = await _database.getPendingSyncItems();
    return pendingItems.isNotEmpty;
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final pendingItems = await _database.getPendingSyncItems();
    final lastSync = _storage.getLastSync();

    return {
      'pendingItems': pendingItems.length,
      'lastSync': lastSync?.toIso8601String(),
      'isSyncing': _isSyncing,
    };
  }

  /// Dispose service
  void dispose() {
    stopPeriodicSync();
    _syncStatusController.close();
  }
}