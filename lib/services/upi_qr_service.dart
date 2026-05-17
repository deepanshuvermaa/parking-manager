import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates UPI payment QR codes for parking exit receipts.
/// Follows the UPI deep link specification:
/// upi://pay?pa=<VPA>&pn=<Name>&am=<Amount>&cu=INR&tn=<Note>
class UpiQrService {
  static const String _upiIdKey = 'upi_vpa';
  static const String _upiNameKey = 'upi_merchant_name';

  /// Generate UPI payment URI
  static String generateUpiUri({
    required String vpa,
    required String merchantName,
    required double amount,
    String? transactionNote,
  }) {
    final params = {
      'pa': vpa,
      'pn': merchantName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (transactionNote != null) 'tn': transactionNote,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  /// Get saved UPI configuration
  static Future<Map<String, String?>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'vpa': prefs.getString(_upiIdKey),
      'name': prefs.getString(_upiNameKey),
    };
  }

  /// Save UPI configuration
  static Future<void> saveConfig(String vpa, String merchantName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_upiIdKey, vpa);
    await prefs.setString(_upiNameKey, merchantName);
  }

  /// Check if UPI is configured
  static Future<bool> isConfigured() async {
    final config = await getConfig();
    return config['vpa'] != null && config['vpa']!.isNotEmpty;
  }

  /// Widget to display UPI QR code
  static Widget buildPaymentQR({
    required String vpa,
    required String merchantName,
    required double amount,
    String? vehicleNumber,
    double size = 180,
  }) {
    final note = vehicleNumber != null
        ? 'Parking fee - $vehicleNumber'
        : 'Parking fee';
    final uri = generateUpiUri(
      vpa: vpa,
      merchantName: merchantName,
      amount: amount,
      transactionNote: note,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: QrImageView(
            data: uri,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan to pay ₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
          ),
        ),
        Text(
          vpa,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
