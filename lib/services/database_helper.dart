import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../models/vehicle_type.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'parkease.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        businessId TEXT,
        deviceId TEXT,
        createdAt TEXT NOT NULL,
        lastLogin TEXT,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicles(
        id TEXT PRIMARY KEY,
        vehicleNumber TEXT NOT NULL,
        vehicleType TEXT NOT NULL,
        ownerName TEXT,
        ownerPhone TEXT,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        duration INTEGER,
        charges REAL,
        status TEXT NOT NULL,
        paymentMethod TEXT,
        gstAmount REAL,
        totalAmount REAL,
        userId TEXT,
        businessId TEXT,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicle_types(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ratePerHour REAL NOT NULL,
        icon TEXT,
        color INTEGER,
        isActive INTEGER DEFAULT 1,
        businessId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings(
        id TEXT PRIMARY KEY,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        type TEXT DEFAULT 'string',
        businessId TEXT
      )
    ''');

    await _insertDefaultVehicleTypes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN metadata TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN metadata TEXT');
    }
  }

  Future<void> _insertDefaultVehicleTypes(Database db) async {
    final defaultTypes = [
      {'id': '1', 'name': 'Car', 'ratePerHour': 50.0, 'icon': 'car', 'color': 0xFF2196F3},
      {'id': '2', 'name': 'Bike', 'ratePerHour': 20.0, 'icon': 'motorcycle', 'color': 0xFF4CAF50},
      {'id': '3', 'name': 'Truck', 'ratePerHour': 100.0, 'icon': 'truck', 'color': 0xFFFF9800},
      {'id': '4', 'name': 'Bus', 'ratePerHour': 150.0, 'icon': 'bus', 'color': 0xFF9C27B0},
      {'id': '5', 'name': 'Auto', 'ratePerHour': 30.0, 'icon': 'auto', 'color': 0xFFFFC107},
    ];

    for (final type in defaultTypes) {
      await db.insert('vehicle_types', type);
    }
  }

  Future<User?> getUser(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toJson());
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Vehicle>> getVehicles({String? status}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = status != null
        ? await db.query('vehicles', where: 'status = ?', whereArgs: [status])
        : await db.query('vehicles');

    return List.generate(maps.length, (i) {
      return Vehicle.fromJson(maps[i]);
    });
  }

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    return await db.insert('vehicles', vehicle.toJson());
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    return await db.update(
      'vehicles',
      vehicle.toJson(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<List<VehicleType>> getVehicleTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('vehicle_types');

    return List.generate(maps.length, (i) {
      return VehicleType.fromJson(maps[i]);
    });
  }

  Future<int> insertVehicleType(VehicleType type) async {
    final db = await database;
    return await db.insert('vehicle_types', type.toJson());
  }

  Future<int> updateVehicleType(VehicleType type) async {
    final db = await database;
    return await db.update(
      'vehicle_types',
      type.toJson(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<int> deleteVehicleType(String id) async {
    final db = await database;
    return await db.delete(
      'vehicle_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');

    final settings = <String, dynamic>{};
    for (final map in maps) {
      settings[map['key']] = map['value'];
    }

    return settings;
  }

  Future<void> saveSetting(String key, dynamic value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('vehicles');
    await db.delete('users');
    await db.delete('settings');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<User?> authenticateUser(String username, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<bool> isDeviceInUse(String deviceId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'deviceId = ? AND isGuest = ?',
      whereArgs: [deviceId, 1],
    );
    return maps.isNotEmpty;
  }

  Future<User> createGuestUser(String deviceId) async {
    final user = User(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      username: 'Guest',
      name: 'Guest User',
      isGuest: true,
      deviceId: deviceId,
      createdAt: DateTime.now(),
      trialEndDate: DateTime.now().add(const Duration(days: 7)),
      subscriptionType: 'trial',
    );

    await insertUser(user);
    return user;
  }

  Future<void> updateUserSubscription(String userId, String subscriptionType) async {
    final db = await database;
    await db.update(
      'users',
      {'subscriptionType': subscriptionType},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromJson(maps[i]));
  }

  Future<bool> changePassword(String userId, String oldPassword, String newPassword) async {
    final db = await database;
    final result = await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ? AND password = ?',
      whereArgs: [userId, oldPassword],
    );
    return result > 0;
  }

  String hashPassword(String password) {
    // Simple hash for demo - in production use proper crypto library
    return password;
  }

  Future<void> createUser(dynamic userOrData) async {
    final db = await database;
    Map<String, dynamic> userData;

    if (userOrData is User) {
      userData = userOrData.toJson();
    } else if (userOrData is Map<String, dynamic>) {
      userData = userOrData;
    } else {
      throw ArgumentError('Expected User or Map<String, dynamic>');
    }

    await db.insert('users', userData);
  }

  Future<List<Vehicle>> getActiveVehicles() async {
    return getVehicles(status: 'active');
  }
}