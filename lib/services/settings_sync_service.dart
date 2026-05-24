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

  static Future<void> syncToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> settings = {};
      for (final key in _keys) {
        final val = prefs.get(key);
        if (val != null) settings[key] = val;
      }
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/settings'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({'settings': settings}),
      ).timeout(ApiConfig.timeout);
    } catch (_) {}
  }

  static Future<void> loadFromBackend(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/settings'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.timeout);
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final settings = (data['settings'] ?? data['data']?['settings']) as Map<String, dynamic>?;
      if (settings == null) return;
      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.entries) {
        final v = entry.value;
        if (v is String) await prefs.setString(entry.key, v);
        else if (v is int) await prefs.setInt(entry.key, v);
        else if (v is bool) await prefs.setBool(entry.key, v);
        else if (v is double) await prefs.setDouble(entry.key, v);
      }
    } catch (_) {}
  }
}
