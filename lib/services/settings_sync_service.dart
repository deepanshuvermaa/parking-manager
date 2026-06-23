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
    // Rates and zones
    'vehicle_rates_v2', 'parking_zones',
    // Ticket counter
    'ticket_id_prefix', 'ticket_id_serial', 'ticket_device_suffix',
    // Optional entry fields
    'show_driver_name', 'show_driver_mobile', 'show_fare',
    // Receipt customization toggles
    'bill_show_business_name', 'bill_show_business_address', 'bill_show_business_phone',
    'bill_show_gst_number', 'bill_show_rate_info', 'bill_show_notes',
    'bill_show_receipt_header', 'bill_show_receipt_footer',
    // Receipt formatting (bold/size)
    'receipt_business_name_bold', 'receipt_business_name_size',
    'receipt_business_address_bold', 'receipt_business_address_size',
    'receipt_business_phone_bold', 'receipt_business_phone_size',
    'receipt_ticket_id_bold', 'receipt_ticket_id_size',
    'receipt_vehicle_number_bold', 'receipt_vehicle_number_size',
    'receipt_vehicle_type_bold', 'receipt_vehicle_type_size',
    'receipt_amount_bold', 'receipt_amount_size',
    'receipt_header', 'receipt_footer',
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
