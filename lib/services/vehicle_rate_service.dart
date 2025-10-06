import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle_rate.dart';

class VehicleRateService {
  static const String _ratesKey = 'vehicle_rates_v2';

  // Default rates
  static List<VehicleRate> getDefaultRates() {
    return [
      VehicleRate(
        vehicleType: 'Car',
        hourlyRate: 20.0,
        minimumCharge: 20.0,
        freeMinutes: 15,
      ),
      VehicleRate(
        vehicleType: 'Bike',
        hourlyRate: 10.0,
        minimumCharge: 10.0,
        freeMinutes: 10,
      ),
      VehicleRate(
        vehicleType: 'Scooter',
        hourlyRate: 10.0,
        minimumCharge: 10.0,
        freeMinutes: 10,
      ),
      VehicleRate(
        vehicleType: 'SUV',
        hourlyRate: 30.0,
        minimumCharge: 30.0,
        freeMinutes: 15,
      ),
      VehicleRate(
        vehicleType: 'Van',
        hourlyRate: 25.0,
        minimumCharge: 25.0,
        freeMinutes: 15,
      ),
      VehicleRate(
        vehicleType: 'Bus',
        hourlyRate: 50.0,
        minimumCharge: 50.0,
        freeMinutes: 10,
      ),
      VehicleRate(
        vehicleType: 'Truck',
        hourlyRate: 40.0,
        minimumCharge: 40.0,
        freeMinutes: 10,
      ),
      VehicleRate(
        vehicleType: 'Auto Rickshaw',
        hourlyRate: 15.0,
        minimumCharge: 15.0,
        freeMinutes: 10,
      ),
    ];
  }

  // Load rates from SharedPreferences
  static Future<List<VehicleRate>> loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = prefs.getStringList(_ratesKey);

    if (ratesJson == null || ratesJson.isEmpty) {
      // Return default rates if none saved
      return getDefaultRates();
    }

    return ratesJson.map((json) => VehicleRate.decode(json)).toList();
  }

  // Save rates to SharedPreferences
  static Future<bool> saveRates(List<VehicleRate> rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratesJson = rates.map((rate) => rate.encode()).toList();
      await prefs.setStringList(_ratesKey, ratesJson);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Add new vehicle type
  static Future<bool> addVehicleType(VehicleRate rate) async {
    final rates = await loadRates();

    // Check if type already exists
    if (rates.any((r) => r.vehicleType.toLowerCase() == rate.vehicleType.toLowerCase())) {
      return false; // Type already exists
    }

    rates.add(rate);
    return await saveRates(rates);
  }

  // Update existing vehicle type
  static Future<bool> updateVehicleType(String oldType, VehicleRate newRate) async {
    final rates = await loadRates();
    final index = rates.indexWhere((r) => r.vehicleType == oldType);

    if (index == -1) {
      return false; // Type not found
    }

    rates[index] = newRate;
    return await saveRates(rates);
  }

  // Delete vehicle type
  static Future<bool> deleteVehicleType(String vehicleType) async {
    final rates = await loadRates();
    rates.removeWhere((r) => r.vehicleType == vehicleType);
    return await saveRates(rates);
  }

  // Get rate for specific vehicle type
  static Future<VehicleRate?> getRateForType(String vehicleType) async {
    final rates = await loadRates();
    try {
      return rates.firstWhere(
        (r) => r.vehicleType.toLowerCase() == vehicleType.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Calculate fee for a vehicle
  static Future<double> calculateFee({
    required String vehicleType,
    required Duration duration,
  }) async {
    final rate = await getRateForType(vehicleType);

    if (rate == null) {
      // Fallback to default calculation if rate not found
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      double fee = hours * 20.0; // Default ₹20/hour
      if (minutes > 0) fee += 20.0;
      return fee < 20.0 ? 20.0 : fee;
    }

    return rate.calculateFee(duration);
  }

  // Reset to default rates
  static Future<bool> resetToDefaults() async {
    return await saveRates(getDefaultRates());
  }
}
