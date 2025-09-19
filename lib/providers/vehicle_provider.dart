import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/vehicle.dart';
import '../models/vehicle_type.dart';
import '../services/api_service.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  List<VehicleType> _vehicleTypes = [
    // Two Wheeler Category
    VehicleType(
      id: '1',
      name: 'Motorcycle/Scooter',
      icon: '🏍️',
      hourlyRate: 10.0,
      flatRate: 20.0,
    ),
    VehicleType(
      id: '2',
      name: 'Bicycle',
      icon: '🚲',
      hourlyRate: 5.0,
      flatRate: 10.0,
    ),

    // Three Wheeler Category
    VehicleType(
      id: '3',
      name: 'Auto Rickshaw',
      icon: '🛺',
      hourlyRate: 15.0,
      flatRate: 30.0,
    ),
    VehicleType(
      id: '4',
      name: 'E-Rickshaw',
      icon: '🛺',
      hourlyRate: 12.0,
      flatRate: 25.0,
    ),

    // Four Wheeler Category
    VehicleType(
      id: '5',
      name: 'Car/Sedan',
      icon: '🚗',
      hourlyRate: 20.0,
      flatRate: 50.0,
    ),
    VehicleType(
      id: '6',
      name: 'SUV/MUV',
      icon: '🚙',
      hourlyRate: 30.0,
      flatRate: 60.0,
    ),
    VehicleType(
      id: '7',
      name: 'Taxi/Cab',
      icon: '🚕',
      hourlyRate: 20.0,
      flatRate: 40.0,
    ),

    // Commercial Vehicles
    VehicleType(
      id: '8',
      name: 'Tempo/Mini Truck',
      icon: '🚐',
      hourlyRate: 40.0,
      flatRate: 80.0,
    ),
    VehicleType(
      id: '9',
      name: 'Truck/Lorry',
      icon: '🚛',
      hourlyRate: 50.0,
      flatRate: 100.0,
    ),
    VehicleType(
      id: '10',
      name: 'Bus',
      icon: '🚌',
      hourlyRate: 60.0,
      flatRate: 120.0,
    ),
    VehicleType(
      id: '11',
      name: 'Tractor',
      icon: '🚜',
      hourlyRate: 40.0,
      flatRate: 80.0,
    ),

    // Electric Vehicles
    VehicleType(
      id: '12',
      name: 'Electric Car',
      icon: '🚗',
      hourlyRate: 15.0,
      flatRate: 40.0,
    ),
    VehicleType(
      id: '13',
      name: 'Electric Scooter',
      icon: '🛵',
      hourlyRate: 8.0,
      flatRate: 15.0,
    ),
  ];

  VehicleProvider() {
    _loadVehicleTypes();
  }

  List<Vehicle> get vehicles => _vehicles;
  List<Vehicle> get activeVehicles => _vehicles.where((v) => v.exitTime == null).toList();
  List<VehicleType> get vehicleTypes => _vehicleTypes;

  int get totalActiveVehicles => activeVehicles.length;

  double get todayCollection {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return _vehicles
        .where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(todayStart) &&
            v.exitTime!.isBefore(todayEnd))
        .fold(0.0, (sum, v) => sum + (v.totalAmount ?? 0.0));
  }

  int get todayCompletedVehicles {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return _vehicles
        .where((v) =>
            v.exitTime != null &&
            v.exitTime!.isAfter(todayStart) &&
            v.exitTime!.isBefore(todayEnd))
        .length;
  }

  Map<String, int> get vehicleTypeStats {
    final stats = <String, int>{};
    for (var type in _vehicleTypes) {
      stats[type.name] = activeVehicles
          .where((v) => v.vehicleType.id == type.id)
          .length;
    }
    return stats;
  }

  Future<void> loadVehicles() async {
    try {
      // Try to load from backend first
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        final backendVehicles = await ApiService.getVehicles();
        if (backendVehicles != null) {
          _vehicles = backendVehicles.map((v) => v is Vehicle ? v : Vehicle.fromJson(v as Map<String, dynamic>)).toList();
        }
      } else {
        // Load from local database if offline
        // Keep existing local vehicles
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
    notifyListeners();
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);

    // Try to sync with backend
    try {
      final isOnline = await ApiService.isBackendHealthy();
      if (isOnline) {
        await ApiService.addVehicle(vehicle);
      }
    } catch (e) {
      debugPrint('Error syncing vehicle to backend: $e');
    }

    notifyListeners();
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      _vehicles[index] = vehicle;
      notifyListeners();
    }
  }

  Future<void> exitVehicle(String vehicleId, double amount) async {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index] = _vehicles[index].copyWith(
        exitTime: DateTime.now(),
        totalAmount: amount,
      );

      // Try to sync with backend
      try {
        final isOnline = await ApiService.isBackendHealthy();
        if (isOnline) {
          await ApiService.updateVehicle(_vehicles[index]);
        }
      } catch (e) {
        debugPrint('Error syncing vehicle exit to backend: $e');
      }

      notifyListeners();
    }
  }

  Vehicle? getVehicleByNumber(String vehicleNumber) {
    try {
      return activeVehicles.firstWhere(
        (v) => v.vehicleNumber.toLowerCase() == vehicleNumber.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  VehicleType? getVehicleTypeById(String id) {
    try {
      return _vehicleTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }

  // Vehicle Type Management Methods
  void addVehicleType(VehicleType vehicleType) {
    _vehicleTypes.add(vehicleType);
    notifyListeners();
    _saveVehicleTypes();
  }

  void updateVehicleType(VehicleType vehicleType) {
    final index = _vehicleTypes.indexWhere((type) => type.id == vehicleType.id);
    if (index != -1) {
      _vehicleTypes[index] = vehicleType;
      notifyListeners();
      _saveVehicleTypes();
    }
  }

  void deleteVehicleType(String id) {
    _vehicleTypes.removeWhere((type) => type.id == id);
    notifyListeners();
    _saveVehicleTypes();
  }

  Future<void> _saveVehicleTypes() async {
    // Save vehicle types to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final typesJson = _vehicleTypes.map((type) => {
        'id': type.id,
        'name': type.name,
        'icon': type.icon,
        'hourlyRate': type.hourlyRate,
        'flatRate': type.flatRate,
      }).toList();
      await prefs.setString('vehicleTypes', jsonEncode(typesJson));
    } catch (e) {
      debugPrint('Error saving vehicle types: $e');
    }
  }

  Future<void> _loadVehicleTypes() async {
    // Load vehicle types from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final typesString = prefs.getString('vehicleTypes');
      if (typesString != null) {
        final typesList = jsonDecode(typesString) as List;
        _vehicleTypes = typesList.map((json) => VehicleType(
          id: json['id'],
          name: json['name'],
          icon: json['icon'],
          hourlyRate: json['hourlyRate'].toDouble(),
          flatRate: json['flatRate']?.toDouble(),
        )).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading vehicle types: $e');
    }
  }
}