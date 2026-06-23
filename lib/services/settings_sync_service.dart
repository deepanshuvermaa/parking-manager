import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SettingsSyncService {
  static const _keys = [
    'business_name', 'business_address', 'business_phone',
    'gst_number', 'upi_vpa', 'auto_print', 'auto_print_exit',
    'paper_width', 'bill_show_qr_code',
  ];

  /// Also sync vehicle_rates_v2 and parking_zones
  static const _extraKeys = [
    'vehicle_rates_v2', 'parking_zones',
    'ticket_id_prefix', 'ticket_id_serial', 'ticket_device_suffix',
    'show_driver_name', 'show_driver_mobile', 'show_fare',
  ];

  static Future<void> syncToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> settings = {};
      for (final key in [..._keys, ..._extraKeys]) {
        final val = prefs.get(key);
        if (val != null) settings[key] = val;
      }
      // Use PUT to update settings
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/settings'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(settings),
      ).timeout(ApiConfig.timeout);
    } catch (e) {
      print('⚠️ Settings sync to backend failed: $e');
    }
  }

  static Future<void> loadFromBackend(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/settings'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.timeout);
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      if (body['success'] != true) return;

      // Backend returns { success: true, data: { business_name: ..., ... } }
      // The data object itself IS the settings row
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();
      // Only restore keys we care about
      for (final key in [..._keys, ..._extraKeys]) {
        final v = data[key];
        if (v == null) continue;
        if (v is String) await prefs.setString(key, v);
        else if (v is int) await prefs.setInt(key, v);
        else if (v is bool) await prefs.setBool(key, v);
        else if (v is double) await prefs.setDouble(key, v);
        else if (v is List) await prefs.setStringList(key, v.cast<String>());
      }
    } catch (e) {
      print('⚠️ Settings load from backend failed: $e');
    }
  }
}
