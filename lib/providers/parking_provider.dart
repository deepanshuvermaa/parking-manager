import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/simple_vehicle_service.dart';
import '../models/simple_vehicle.dart';

/// Parking zone definition
class ParkingZone {
  final String id;
  final String name;
  final int totalSlots;
  int occupiedSlots;

  ParkingZone({
    required this.id,
    required this.name,
    required this.totalSlots,
    this.occupiedSlots = 0,
  });

  int get availableSlots => totalSlots - occupiedSlots;
  double get occupancyPercent =>
      totalSlots > 0 ? (occupiedSlots / totalSlots) * 100 : 0;
  bool get isFull => occupiedSlots >= totalSlots;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalSlots': totalSlots,
        'occupiedSlots': occupiedSlots,
      };

  factory ParkingZone.fromJson(Map<String, dynamic> json) => ParkingZone(
        id: json['id'],
        name: json['name'],
        totalSlots: json['totalSlots'],
        occupiedSlots: json['occupiedSlots'] ?? 0,
      );
}

class ParkingProvider extends ChangeNotifier {
  List<ParkingZone> _zones = [];
  List<SimpleVehicle> _activeVehicles = [];
  double _todayRevenue = 0;
  int _todayExits = 0;
  bool _isLoading = false;

  // Getters
  List<ParkingZone> get zones => _zones;
  List<SimpleVehicle> get activeVehicles => _activeVehicles;
  double get todayRevenue => _todayRevenue;
  int get todayExits => _todayExits;
  bool get isLoading => _isLoading;

  int get totalCapacity => _zones.fold(0, (sum, z) => sum + z.totalSlots);
  int get totalOccupied => _zones.fold(0, (sum, z) => sum + z.occupiedSlots);
  int get totalAvailable => totalCapacity - totalOccupied;
  double get occupancyPercent =>
      totalCapacity > 0 ? (totalOccupied / totalCapacity) * 100 : 0;
  bool get isFull => totalAvailable <= 0 && totalCapacity > 0;

  /// Initialize parking data
  Future<void> initialize(String token) async {
    _isLoading = true;
    notifyListeners();

    await _loadZones();
    await refreshVehicles(token);

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh vehicle data
  Future<void> refreshVehicles(String token) async {
    try {
      final vehicles = await SimpleVehicleService.getVehicles(token);
      _activeVehicles = vehicles.where((v) => v.status == 'parked').toList();
      _todayRevenue = SimpleVehicleService.getTodayCollection();
      _todayExits = vehicles
          .where((v) =>
              v.status == 'exited' &&
              v.exitTime != null &&
              _isToday(v.exitTime!))
          .length;

      // Update zone occupancy from active vehicles
      _updateZoneOccupancy();
      notifyListeners();
    } catch (e) {
      // Silent fail, keep cached data
    }
  }

  /// Add a parking zone
  Future<void> addZone(String name, int totalSlots) async {
    final zone = ParkingZone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      totalSlots: totalSlots,
    );
    _zones.add(zone);
    await _saveZones();
    notifyListeners();
  }

  /// Update a zone
  Future<void> updateZone(String id, {String? name, int? totalSlots}) async {
    final idx = _zones.indexWhere((z) => z.id == id);
    if (idx == -1) return;
    _zones[idx] = ParkingZone(
      id: id,
      name: name ?? _zones[idx].name,
      totalSlots: totalSlots ?? _zones[idx].totalSlots,
      occupiedSlots: _zones[idx].occupiedSlots,
    );
    await _saveZones();
    notifyListeners();
  }

  /// Remove a zone
  Future<void> removeZone(String id) async {
    _zones.removeWhere((z) => z.id == id);
    await _saveZones();
    notifyListeners();
  }

  /// Record a vehicle entry (increment occupancy)
  void recordEntry() {
    if (_zones.isNotEmpty) {
      // Fill first non-full zone
      for (var zone in _zones) {
        if (!zone.isFull) {
          zone.occupiedSlots++;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Record a vehicle exit (decrement occupancy)
  void recordExit(double amount) {
    if (_zones.isNotEmpty) {
      for (var zone in _zones.reversed) {
        if (zone.occupiedSlots > 0) {
          zone.occupiedSlots--;
          break;
        }
      }
    }
    _todayRevenue += amount;
    _todayExits++;
    notifyListeners();
  }

  void _updateZoneOccupancy() {
    if (_zones.isEmpty) return;
    // Distribute active vehicles across zones proportionally
    int remaining = _activeVehicles.length;
    for (var zone in _zones) {
      zone.occupiedSlots = remaining.clamp(0, zone.totalSlots);
      remaining -= zone.occupiedSlots;
      if (remaining <= 0) break;
    }
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _loadZones() async {
    final prefs = await SharedPreferences.getInstance();
    final zonesJson = prefs.getString('parking_zones');
    if (zonesJson != null) {
      final list = jsonDecode(zonesJson) as List;
      _zones = list.map((z) => ParkingZone.fromJson(z)).toList();
    } else {
      // Default zone if none configured
      _zones = [
        ParkingZone(id: 'default', name: 'Main Lot', totalSlots: 50),
      ];
      await _saveZones();
    }
  }

  Future<void> _saveZones() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'parking_zones', jsonEncode(_zones.map((z) => z.toJson()).toList()));
  }
}
