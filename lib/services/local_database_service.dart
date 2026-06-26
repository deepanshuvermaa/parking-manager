import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/simple_vehicle.dart';

/// Local SQLite database service for offline data persistence
/// Stores vehicles, settings, and sync queue for offline functionality
class LocalDatabaseService {
  static Database? _database;

  /// Get database instance (singleton pattern)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Initialize database with tables
  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'parkease.db');

    // Pre-migration backup: save a copy before any upgrade
    await _preMigrationBackup(path);

    return await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        // Enable WAL mode — prevents corruption on crash during writes
        await db.execute('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, version) async {
        print('🗄️ Creating local database...');

        // Vehicles table — includes ALL columns from all migrations
        await db.execute('''
          CREATE TABLE vehicles (
            id TEXT PRIMARY KEY,
            vehicle_number TEXT NOT NULL,
            vehicle_type TEXT NOT NULL,
            entry_time TEXT NOT NULL,
            exit_time TEXT,
            amount REAL,
            status TEXT NOT NULL,
            ticket_id TEXT,
            hourly_rate REAL,
            minimum_rate REAL,
            notes TEXT,
            duration_minutes INTEGER,
            from_location TEXT,
            to_location TEXT,
            version INTEGER DEFAULT 1,
            driver_name TEXT,
            driver_mobile TEXT,
            fare REAL,
            synced INTEGER DEFAULT 0,
            user_id TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // Sync queue table (for changes made offline)
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0
          )
        ''');

        // User settings table
        await db.execute('''
          CREATE TABLE user_settings (
            user_id TEXT PRIMARY KEY,
            business_name TEXT,
            vehicle_types TEXT,
            last_sync TEXT,
            auto_print INTEGER DEFAULT 1,
            printer_address TEXT
          )
        ''');

        // Create indexes for better query performance
        await db.execute('CREATE INDEX idx_vehicles_status ON vehicles(status)');
        await db.execute('CREATE INDEX idx_vehicles_synced ON vehicles(synced)');
        await db.execute('CREATE INDEX idx_vehicles_entry_time ON vehicles(entry_time)');

        print('✅ Local database created successfully');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('📦 Upgrading database from v$oldVersion to v$newVersion');

        if (oldVersion < 2) {
          // Add duration_minutes column if upgrading from v1
          await db.execute('ALTER TABLE vehicles ADD COLUMN duration_minutes INTEGER');
        }

        if (oldVersion < 3) {
          // Add destination fields (v2 → v3)
          await db.execute('ALTER TABLE vehicles ADD COLUMN from_location TEXT');
          await db.execute('ALTER TABLE vehicles ADD COLUMN to_location TEXT');
          print('✅ Added destination fields to vehicles table');
        }

        if (oldVersion < 5) {
          // Add all columns safely — each in its own try-catch so one failure doesn't block others
          final cols = [
            'ALTER TABLE vehicles ADD COLUMN version INTEGER DEFAULT 1',
            'ALTER TABLE vehicles ADD COLUMN driver_name TEXT',
            'ALTER TABLE vehicles ADD COLUMN driver_mobile TEXT',
            'ALTER TABLE vehicles ADD COLUMN fare REAL',
          ];
          for (final sql in cols) {
            try { await db.execute(sql); } catch (_) { /* column already exists */ }
          }
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_vehicles_number ON vehicles(vehicle_number)'); } catch (_) {}
        }
      },
    );
  }

  /// Create a backup copy of the database before any migration
  static Future<void> _preMigrationBackup(String dbPath) async {
    try {
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return; // No DB yet, skip

      final backupDir = Directory('${dirname(dbPath)}/pre_migration_backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${backupDir.path}/parkease_pre_migration_$timestamp.db';
      await dbFile.copy(backupPath);
      print('✅ Pre-migration backup created: $backupPath');

      // Keep only last 3 backups
      final files = await backupDir.list().where((f) => f is File).toList();
      if (files.length > 3) {
        files.sort((a, b) => a.path.compareTo(b.path));
        for (var i = 0; i < files.length - 3; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      print('⚠️ Pre-migration backup failed: $e');
    }
  }

  // ============================================
  // VEHICLE OPERATIONS
  // ============================================

  /// Save vehicle to local database
  static Future<void> saveVehicle(SimpleVehicle vehicle, {bool synced = true}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Core fields that always exist
    final data = <String, dynamic>{
      'id': vehicle.id,
      'vehicle_number': vehicle.vehicleNumber,
      'vehicle_type': vehicle.vehicleType,
      'entry_time': vehicle.entryTime.toIso8601String(),
      'exit_time': vehicle.exitTime?.toIso8601String(),
      'amount': vehicle.amount,
      'status': vehicle.status,
      'ticket_id': vehicle.ticketId,
      'hourly_rate': vehicle.hourlyRate,
      'minimum_rate': vehicle.minimumRate,
      'notes': vehicle.notes,
      'duration_minutes': vehicle.durationMinutes,
      'from_location': vehicle.fromLocation,
      'to_location': vehicle.toLocation,
      'synced': synced ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    };

    // Try with optional columns — fall back to core if DB schema is old
    try {
      data['driver_name'] = vehicle.driverName;
      data['driver_mobile'] = vehicle.driverMobile;
      data['fare'] = vehicle.fare;
      await db.insert('vehicles', data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      // Remove optional columns and retry with core only
      print('⚠️ saveVehicle retry without optional cols: $e');
      data.remove('driver_name');
      data.remove('driver_mobile');
      data.remove('fare');
      await db.insert('vehicles', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Get all vehicles from local database
  static Future<List<SimpleVehicle>> getVehicles({String? userId, String? status}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause = 'WHERE status = ?';
      whereArgs.add(status);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'entry_time DESC',
    );

    final vehicles = List.generate(maps.length, (i) {
      return SimpleVehicle(
        id: maps[i]['id'],
        vehicleNumber: maps[i]['vehicle_number'],
        vehicleType: maps[i]['vehicle_type'],
        entryTime: DateTime.parse(maps[i]['entry_time']),
        exitTime: maps[i]['exit_time'] != null
            ? DateTime.parse(maps[i]['exit_time'])
            : null,
        amount: maps[i]['amount'],
        status: maps[i]['status'],
        ticketId: maps[i]['ticket_id'],
        hourlyRate: maps[i]['hourly_rate'],
        minimumRate: maps[i]['minimum_rate'],
        notes: maps[i]['notes'],
        durationMinutes: maps[i]['duration_minutes'],
        fromLocation: maps[i]['from_location'],
        toLocation: maps[i]['to_location'],
        driverName: maps[i]['driver_name'],
        driverMobile: maps[i]['driver_mobile'],
        fare: (maps[i]['fare'] as num?)?.toDouble(),
      );
    });

    print('📂 Loaded ${vehicles.length} vehicles from local database');
    return vehicles;
  }

  /// Update vehicle in local database
  static Future<void> updateVehicle(SimpleVehicle vehicle, {bool synced = true}) async {
    final db = await database;

    final data = <String, dynamic>{
      'vehicle_number': vehicle.vehicleNumber,
      'vehicle_type': vehicle.vehicleType,
      'exit_time': vehicle.exitTime?.toIso8601String(),
      'amount': vehicle.amount,
      'status': vehicle.status,
      'notes': vehicle.notes,
      'duration_minutes': vehicle.durationMinutes,
      'from_location': vehicle.fromLocation,
      'to_location': vehicle.toLocation,
      'synced': synced ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      data['driver_name'] = vehicle.driverName;
      data['driver_mobile'] = vehicle.driverMobile;
      data['fare'] = vehicle.fare;
      await db.update('vehicles', data, where: 'id = ?', whereArgs: [vehicle.id]);
    } catch (e) {
      data.remove('driver_name');
      data.remove('driver_mobile');
      data.remove('fare');
      await db.update('vehicles', data, where: 'id = ?', whereArgs: [vehicle.id]);
    }
  }

  /// Get unsynced vehicles (for background sync)
  static Future<List<SimpleVehicle>> getUnsyncedVehicles() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    final vehicles = List.generate(maps.length, (i) {
      return SimpleVehicle(
        id: maps[i]['id'],
        vehicleNumber: maps[i]['vehicle_number'],
        vehicleType: maps[i]['vehicle_type'],
        entryTime: DateTime.parse(maps[i]['entry_time']),
        exitTime: maps[i]['exit_time'] != null
            ? DateTime.parse(maps[i]['exit_time'])
            : null,
        amount: maps[i]['amount'],
        status: maps[i]['status'],
        ticketId: maps[i]['ticket_id'],
        hourlyRate: maps[i]['hourly_rate'],
        minimumRate: maps[i]['minimum_rate'],
        notes: maps[i]['notes'],
        durationMinutes: maps[i]['duration_minutes'],
        fromLocation: maps[i]['from_location'],
        toLocation: maps[i]['to_location'],
        driverName: maps[i]['driver_name'],
        driverMobile: maps[i]['driver_mobile'],
        fare: (maps[i]['fare'] as num?)?.toDouble(),
      );
    });

    print('📤 Found ${vehicles.length} unsynced vehicles');
    return vehicles;
  }

  /// Mark vehicle as synced
  static Future<void> markAsSynced(String vehicleId) async {
    final db = await database;
    await db.update(
      'vehicles',
      {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
    print('✅ Vehicle marked as synced: $vehicleId');
  }

  /// Delete vehicle from local database
  static Future<void> deleteVehicle(String vehicleId) async {
    final db = await database;
    await db.delete(
      'vehicles',
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Batch save vehicles in a single transaction (for backend pull)
  static Future<void> batchSaveVehicles(List<SimpleVehicle> vehicles, {bool synced = true}) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (var vehicle in vehicles) {
      batch.insert(
        'vehicles',
        {
          'id': vehicle.id,
          'vehicle_number': vehicle.vehicleNumber,
          'vehicle_type': vehicle.vehicleType,
          'entry_time': vehicle.entryTime.toIso8601String(),
          'exit_time': vehicle.exitTime?.toIso8601String(),
          'amount': vehicle.amount,
          'status': vehicle.status,
          'ticket_id': vehicle.ticketId,
          'hourly_rate': vehicle.hourlyRate,
          'minimum_rate': vehicle.minimumRate,
          'notes': vehicle.notes,
          'duration_minutes': vehicle.durationMinutes,
          'from_location': vehicle.fromLocation,
          'to_location': vehicle.toLocation,
          'driver_name': vehicle.driverName,
          'driver_mobile': vehicle.driverMobile,
          'fare': vehicle.fare,
          'synced': synced ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get recent vehicles: all parked + exited within last N days
  static Future<List<SimpleVehicle>> getRecentVehicles({int days = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM vehicles
      WHERE status = 'parked' OR entry_time >= ?
      ORDER BY entry_time DESC
    ''', [cutoff]);

    return _mapsToVehicles(maps);
  }

  /// Get vehicles by date range (for reports — queries DB directly)
  static Future<List<SimpleVehicle>> getVehiclesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM vehicles WHERE entry_time >= ? AND entry_time <= ?';
    List<dynamic> args = [startDate.toIso8601String(), endDate.toIso8601String()];

    if (status != null) {
      query += ' AND status = ?';
      args.add(status);
    }

    query += ' ORDER BY entry_time DESC';
    final maps = await db.rawQuery(query, args);
    return _mapsToVehicles(maps);
  }

  /// Get today's revenue directly from DB
  static Future<double> getTodayRevenue() async {
    final db = await database;
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM vehicles
      WHERE status = 'exited' AND exit_time >= ? AND amount IS NOT NULL
    ''', [todayStart]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Check if a plate is currently parked (for duplicate detection)
  static Future<bool> isPlateParked(String plateNumber) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM vehicles WHERE vehicle_number = ? AND status = 'parked'",
      [plateNumber.toUpperCase().trim()],
    );
    return (result.first['cnt'] as int) > 0;
  }

  /// Helper: convert DB maps to SimpleVehicle list
  static List<SimpleVehicle> _mapsToVehicles(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return SimpleVehicle(
        id: maps[i]['id'],
        vehicleNumber: maps[i]['vehicle_number'],
        vehicleType: maps[i]['vehicle_type'],
        entryTime: DateTime.parse(maps[i]['entry_time']),
        exitTime: maps[i]['exit_time'] != null ? DateTime.parse(maps[i]['exit_time']) : null,
        amount: maps[i]['amount'],
        status: maps[i]['status'],
        ticketId: maps[i]['ticket_id'],
        hourlyRate: maps[i]['hourly_rate'],
        minimumRate: maps[i]['minimum_rate'],
        notes: maps[i]['notes'],
        durationMinutes: maps[i]['duration_minutes'],
        fromLocation: maps[i]['from_location'],
        toLocation: maps[i]['to_location'],
        driverName: maps[i]['driver_name'],
        driverMobile: maps[i]['driver_mobile'],
        fare: (maps[i]['fare'] as num?)?.toDouble(),
      );
    });
  }

  // ============================================
  // SYNC QUEUE OPERATIONS
  // ============================================

  /// Add action to sync queue (for offline changes)
  static Future<void> addToSyncQueue({
    required String action,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;

    await db.insert('sync_queue', {
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });

    print('📋 Added to sync queue: $action $entityType $entityId');
  }

  /// Get pending sync queue items
  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;

    final maps = await db.query(
      'sync_queue',
      where: 'retry_count < ?',
      whereArgs: [5], // Max 5 retries
      orderBy: 'created_at ASC',
    );

    return maps;
  }

  /// Remove item from sync queue
  static Future<void> removeFromSyncQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Increment retry count for sync queue item
  static Future<void> incrementSyncRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id]
    );
  }

  // ============================================
  // SETTINGS OPERATIONS
  // ============================================

  /// Save user settings
  static Future<void> saveSettings({
    required String userId,
    String? businessName,
    String? vehicleTypes,
    bool? autoPrint,
    String? printerAddress,
  }) async {
    final db = await database;

    await db.insert(
      'user_settings',
      {
        'user_id': userId,
        'business_name': businessName,
        'vehicle_types': vehicleTypes,
        'last_sync': DateTime.now().toIso8601String(),
        'auto_print': autoPrint == true ? 1 : 0,
        'printer_address': printerAddress,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get user settings
  static Future<Map<String, dynamic>?> getSettings(String userId) async {
    final db = await database;

    final maps = await db.query(
      'user_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    return maps.isEmpty ? null : maps.first;
  }

  /// Update last sync time
  static Future<void> updateLastSync(String userId) async {
    final db = await database;
    await db.update(
      'user_settings',
      {'last_sync': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ============================================
  // DATABASE MANAGEMENT
  // ============================================

  /// Clear all data (on logout if needed)
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('vehicles');
    await db.delete('sync_queue');
    await db.delete('user_settings');
    print('🗑️ All local data cleared');
  }

  /// Get database statistics
  static Future<Map<String, int>> getStats() async {
    final db = await database;

    final vehicleCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM vehicles')
    ) ?? 0;

    final unsyncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM vehicles WHERE synced = 0')
    ) ?? 0;

    final queueCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue')
    ) ?? 0;

    return {
      'vehicles': vehicleCount,
      'unsynced': unsyncedCount,
      'queue': queueCount,
    };
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 Database closed');
    }
  }
}
