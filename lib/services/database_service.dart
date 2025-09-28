import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_metadata.dart';
import '../models/auth_session.dart';

/// Database service with full sync support
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'parkease_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        is_guest INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // Devices table
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_id TEXT UNIQUE NOT NULL,
        device_name TEXT,
        is_active INTEGER DEFAULT 0,
        last_active TEXT,
        registered_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Settings table with versioning
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        version INTEGER DEFAULT 1,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        UNIQUE(key)
      )
    ''');

    // Vehicles table with sync support
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        vehicle_number TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        owner_name TEXT,
        owner_phone TEXT,
        check_in_time TEXT NOT NULL,
        check_out_time TEXT,
        duration INTEGER,
        charges REAL,
        status TEXT NOT NULL,
        payment_method TEXT,
        gst_amount REAL,
        total_amount REAL,
        user_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Vehicle types table
    await db.execute('''
      CREATE TABLE vehicle_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        rate_per_hour REAL NOT NULL,
        icon TEXT,
        color INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // Sync queue table for offline changes
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_updated_at TEXT NOT NULL,
        server_updated_at TEXT,
        sync_status TEXT NOT NULL,
        device_id TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        PRIMARY KEY (entity_type, entity_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_vehicles_status ON vehicles(status)');
    await db.execute('CREATE INDEX idx_vehicles_sync ON vehicles(sync_status)');
    await db.execute('CREATE INDEX idx_sync_queue_retry ON sync_queue(retry_count)');
    await db.execute('CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status)');
  }

  /// Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
    if (oldVersion < newVersion) {
      // Add migration logic
    }
  }

  // ============= User Operations =============

  /// Save user
  Future<void> saveUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      'users',
      {
        ...user,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUser(String userId) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ============= Vehicle Operations =============

  /// Save vehicle
  Future<String> saveVehicle(Map<String, dynamic> vehicle) async {
    final db = await database;
    final id = vehicle['id'] ?? 'vehicle_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert(
      'vehicles',
      {
        ...vehicle,
        'id': id,
        'created_at': vehicle['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to sync queue
    await addToSyncQueue('vehicles', id, SyncOperation.create, vehicle);

    return id;
  }

  /// Get active vehicles
  Future<List<Map<String, dynamic>>> getActiveVehicles() async {
    final db = await database;
    return await db.query(
      'vehicles',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'check_in_time DESC',
    );
  }

  /// Update vehicle
  Future<void> updateVehicle(String id, Map<String, dynamic> updates) async {
    final db = await database;

    await db.update(
      'vehicles',
      {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Add to sync queue
    await addToSyncQueue('vehicles', id, SyncOperation.update, updates);
  }

  // ============= Settings Operations =============

  /// Save setting
  Future<void> saveSetting(String key, String value, int version) async {
    final db = await database;

    await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'version': version,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to sync queue
    await addToSyncQueue('settings', key, SyncOperation.update, {
      'key': key,
      'value': value,
      'version': version,
    });
  }

  /// Get setting
  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isNotEmpty) {
      return results.first['value'] as String?;
    }
    return null;
  }

  /// Get all settings
  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('settings');

    final settings = <String, String>{};
    for (final row in results) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  // ============= Sync Operations =============

  /// Add to sync queue
  Future<void> addToSyncQueue(
    String entityType,
    String entityId,
    SyncOperation operation,
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    await db.insert(
      'sync_queue',
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation.name,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      },
    );
  }

  /// Get pending sync items
  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await database;
    final results = await db.query(
      'sync_queue',
      where: 'retry_count < ?',
      whereArgs: [3], // Max 3 retries
      orderBy: 'created_at ASC',
      limit: 100, // Process in batches
    );

    return results.map((row) => SyncQueueItem.fromJson(row)).toList();
  }

  /// Mark sync item as completed
  Future<void> markSyncCompleted(int queueId) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Increment sync retry count
  Future<void> incrementSyncRetry(int queueId, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, queueId],
    );
  }

  /// Update sync metadata
  Future<void> updateSyncMetadata(SyncMetadata metadata) async {
    final db = await database;

    await db.insert(
      'sync_metadata',
      metadata.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get sync metadata
  Future<SyncMetadata?> getSyncMetadata(String entityType, String entityId) async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );

    if (results.isNotEmpty) {
      return SyncMetadata.fromJson(results.first);
    }
    return null;
  }

  // ============= Device Operations =============

  /// Register device
  Future<void> registerDevice(String userId, String deviceId, String deviceName) async {
    final db = await database;

    // Mark all other devices as inactive
    await db.update(
      'devices',
      {'is_active': 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Register new device as active
    await db.insert(
      'devices',
      {
        'id': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceName,
        'is_active': 1,
        'last_active': DateTime.now().toIso8601String(),
        'registered_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check if device is active
  Future<bool> isDeviceActive(String deviceId) async {
    final db = await database;
    final results = await db.query(
      'devices',
      where: 'device_id = ? AND is_active = 1',
      whereArgs: [deviceId],
    );
    return results.isNotEmpty;
  }

  // ============= Cleanup Operations =============

  /// Clear all user data (logout)
  Future<void> clearUserData() async {
    final db = await database;

    // Clear sync queue
    await db.delete('sync_queue');

    // Clear sync metadata
    await db.delete('sync_metadata');

    // Clear vehicles
    await db.delete('vehicles');

    // Clear devices
    await db.delete('devices');

    // Keep settings and vehicle types
  }

  /// Clear everything (factory reset)
  Future<void> clearAllData() async {
    final db = await database;

    await db.delete('sync_queue');
    await db.delete('sync_metadata');
    await db.delete('vehicles');
    await db.delete('vehicle_types');
    await db.delete('settings');
    await db.delete('devices');
    await db.delete('users');
  }
}