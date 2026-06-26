import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/simple_vehicle.dart';

/// Local SQLite database service for offline data persistence
class LocalDatabaseService {
  static Database? _database;
  static const int _dbVersion = 1; // Single clean version — no migrations needed

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, 'parkease.db');

    // Delete old broken DB so onCreate runs fresh with correct schema
    final oldFile = File(path);
    if (await oldFile.exists()) {
      // Check if old DB has the driver_name column — if not, it's broken
      try {
        final testDb = await openDatabase(path, readOnly: true);
        final info = await testDb.rawQuery("PRAGMA table_info(vehicles)");
        final cols = info.map((r) => r['name'] as String).toSet();
        await testDb.close();
        if (!cols.contains('driver_name')) {
          await oldFile.delete();
        }
      } catch (_) {
        await oldFile.delete();
      }
    }

    // Also clean up parkease_v2.db if it exists from previous bad fix
    try {
      final v2File = File(join(dbDir, 'parkease_v2.db'));
      if (await v2File.exists()) await v2File.delete();
    } catch (_) {}

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles (
            id TEXT PRIMARY KEY,
            vehicle_number TEXT NOT NULL,
            vehicle_type TEXT NOT NULL,
            entry_time TEXT NOT NULL,
            exit_time TEXT,
            amount REAL,
            status TEXT NOT NULL DEFAULT 'parked',
            ticket_id TEXT,
            hourly_rate REAL,
            minimum_rate REAL,
            notes TEXT,
            duration_minutes INTEGER,
            from_location TEXT,
            to_location TEXT,
            driver_name TEXT,
            driver_mobile TEXT,
            fare REAL,
            synced INTEGER DEFAULT 0,
            user_id TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute('CREATE INDEX idx_v_status ON vehicles(status)');
        await db.execute('CREATE INDEX idx_v_synced ON vehicles(synced)');
        await db.execute('CREATE INDEX idx_v_entry ON vehicles(entry_time)');
        await db.execute('CREATE INDEX idx_v_number ON vehicles(vehicle_number)');

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
      },
    );
  }

  // ============================================
  // VEHICLE OPERATIONS
  // ============================================

  static Map<String, dynamic> _vehicleToMap(SimpleVehicle v, {required bool synced}) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': v.id,
      'vehicle_number': v.vehicleNumber,
      'vehicle_type': v.vehicleType,
      'entry_time': v.entryTime.toIso8601String(),
      'exit_time': v.exitTime?.toIso8601String(),
      'amount': v.amount,
      'status': v.status,
      'ticket_id': v.ticketId,
      'hourly_rate': v.hourlyRate,
      'minimum_rate': v.minimumRate,
      'notes': v.notes,
      'duration_minutes': v.durationMinutes,
      'from_location': v.fromLocation,
      'to_location': v.toLocation,
      'driver_name': v.driverName,
      'driver_mobile': v.driverMobile,
      'fare': v.fare,
      'synced': synced ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    };
  }

  static SimpleVehicle _mapToVehicle(Map<String, dynamic> m) {
    return SimpleVehicle(
      id: m['id'] ?? '',
      vehicleNumber: m['vehicle_number'] ?? '',
      vehicleType: m['vehicle_type'] ?? 'Car',
      entryTime: m['entry_time'] != null ? DateTime.parse(m['entry_time']) : DateTime.now(),
      exitTime: m['exit_time'] != null ? DateTime.parse(m['exit_time']) : null,
      amount: (m['amount'] as num?)?.toDouble(),
      status: m['status'] ?? 'parked',
      ticketId: m['ticket_id'],
      hourlyRate: (m['hourly_rate'] as num?)?.toDouble(),
      minimumRate: (m['minimum_rate'] as num?)?.toDouble(),
      notes: m['notes'],
      durationMinutes: m['duration_minutes'] as int?,
      fromLocation: m['from_location'],
      toLocation: m['to_location'],
      driverName: m['driver_name'],
      driverMobile: m['driver_mobile'],
      fare: (m['fare'] as num?)?.toDouble(),
    );
  }

  static Future<void> saveVehicle(SimpleVehicle vehicle, {bool synced = true}) async {
    final db = await database;
    await db.insert('vehicles', _vehicleToMap(vehicle, synced: synced), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<SimpleVehicle>> getVehicles({String? status}) async {
    final db = await database;
    final maps = await db.query('vehicles',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'entry_time DESC',
    );
    return maps.map(_mapToVehicle).toList();
  }

  static Future<void> updateVehicle(SimpleVehicle vehicle, {bool synced = true}) async {
    final db = await database;
    await db.update('vehicles', {
      'exit_time': vehicle.exitTime?.toIso8601String(),
      'amount': vehicle.amount,
      'status': vehicle.status,
      'notes': vehicle.notes,
      'duration_minutes': vehicle.durationMinutes,
      'driver_name': vehicle.driverName,
      'driver_mobile': vehicle.driverMobile,
      'fare': vehicle.fare,
      'synced': synced ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [vehicle.id]);
  }

  static Future<List<SimpleVehicle>> getUnsyncedVehicles() async {
    final db = await database;
    final maps = await db.query('vehicles', where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
    return maps.map(_mapToVehicle).toList();
  }

  static Future<void> markAsSynced(String vehicleId) async {
    final db = await database;
    await db.update('vehicles', {'synced': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [vehicleId]);
  }

  static Future<void> deleteVehicle(String vehicleId) async {
    final db = await database;
    await db.delete('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
  }

  static Future<void> batchSaveVehicles(List<SimpleVehicle> vehicles, {bool synced = true}) async {
    final db = await database;
    final batch = db.batch();
    for (var v in vehicles) {
      batch.insert('vehicles', _vehicleToMap(v, synced: synced), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<SimpleVehicle>> getRecentVehicles({int days = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final maps = await db.rawQuery("SELECT * FROM vehicles WHERE status = 'parked' OR entry_time >= ? ORDER BY entry_time DESC", [cutoff]);
    return maps.map(_mapToVehicle).toList();
  }

  static Future<List<SimpleVehicle>> getVehiclesByDateRange({required DateTime startDate, required DateTime endDate, String? status}) async {
    final db = await database;
    String q = 'SELECT * FROM vehicles WHERE entry_time >= ? AND entry_time <= ?';
    List<dynamic> args = [startDate.toIso8601String(), endDate.toIso8601String()];
    if (status != null) { q += ' AND status = ?'; args.add(status); }
    q += ' ORDER BY entry_time DESC';
    final maps = await db.rawQuery(q, args);
    return maps.map(_mapToVehicle).toList();
  }

  static Future<double> getTodayRevenue() async {
    final db = await database;
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
    final result = await db.rawQuery("SELECT COALESCE(SUM(amount), 0) as total FROM vehicles WHERE status = 'exited' AND exit_time >= ? AND amount IS NOT NULL", [todayStart]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<bool> isPlateParked(String plateNumber) async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM vehicles WHERE vehicle_number = ? AND status = 'parked'", [plateNumber.toUpperCase().trim()]);
    return (result.first['cnt'] as int) > 0;
  }

  // ============================================
  // SYNC QUEUE
  // ============================================

  static Future<void> addToSyncQueue({required String action, required String entityType, required String entityId, required Map<String, dynamic> data}) async {
    final db = await database;
    await db.insert('sync_queue', {'action': action, 'entity_type': entityType, 'entity_id': entityId, 'data': jsonEncode(data), 'created_at': DateTime.now().toIso8601String(), 'retry_count': 0});
  }

  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', where: 'retry_count < ?', whereArgs: [5], orderBy: 'created_at ASC');
  }

  static Future<void> removeFromSyncQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> incrementSyncRetry(int id) async {
    final db = await database;
    await db.rawUpdate('UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  // ============================================
  // SETTINGS
  // ============================================

  static Future<void> saveSettings({required String userId, String? businessName, String? vehicleTypes, bool? autoPrint, String? printerAddress}) async {
    final db = await database;
    await db.insert('user_settings', {
      'user_id': userId, 'business_name': businessName, 'vehicle_types': vehicleTypes,
      'last_sync': DateTime.now().toIso8601String(), 'auto_print': autoPrint == true ? 1 : 0, 'printer_address': printerAddress,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getSettings(String userId) async {
    final db = await database;
    final maps = await db.query('user_settings', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return maps.isEmpty ? null : maps.first;
  }

  // ============================================
  // DATABASE MANAGEMENT
  // ============================================

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('vehicles');
    await db.delete('sync_queue');
    await db.delete('user_settings');
  }

  static Future<Map<String, int>> getStats() async {
    final db = await database;
    final vc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM vehicles')) ?? 0;
    final uc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM vehicles WHERE synced = 0')) ?? 0;
    final qc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue')) ?? 0;
    return {'vehicles': vc, 'unsynced': uc, 'queue': qc};
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
