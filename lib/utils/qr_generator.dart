import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class QRGenerator {
  /// Generate QR code widget for display
  static Widget generateQRWidget({
    required String data,
    double size = 200,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black,
  }) {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.all(10),
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }

  /// Generate QR code data for a parking ticket
  static String generateTicketQRData({
    required String ticketId,
    required String vehicleNumber,
    required DateTime entryTime,
    required String vehicleType,
    String? ownerPhone,
  }) {
    final Map<String, dynamic> qrData = {
      'ticketId': ticketId,
      'vehicle': vehicleNumber,
      'entry': entryTime.toIso8601String(),
      'type': vehicleType,
    };

    if (ownerPhone != null && ownerPhone.isNotEmpty) {
      qrData['phone'] = ownerPhone;
    }

    // Convert to URL-like format for easy parsing
    final params = qrData.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    return 'parkease://ticket?$params';
  }

  /// Generate QR code data for an exit receipt
  static String generateReceiptQRData({
    required String ticketId,
    required String vehicleNumber,
    required DateTime entryTime,
    required DateTime exitTime,
    required double amount,
    String? transactionId,
  }) {
    final Map<String, dynamic> qrData = {
      'ticketId': ticketId,
      'vehicle': vehicleNumber,
      'entry': entryTime.toIso8601String(),
      'exit': exitTime.toIso8601String(),
      'amount': amount.toStringAsFixed(2),
    };

    if (transactionId != null && transactionId.isNotEmpty) {
      qrData['txn'] = transactionId;
    }

    // Convert to URL-like format for easy parsing
    final params = qrData.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    return 'parkease://receipt?$params';
  }

  /// Generate proper ESC/POS QR code commands for thermal printer
  static List<int> generateESCPOSQRCode(String data, {int size = 6}) {
    List<int> bytes = [];

    // Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // QR Code: Select the model
    // [Name]: Select the QR code model
    // [Format]: GS ( k pL pH cn fn n1 n2
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // QR Code: Set the size of module
    // [Name]: Set the size of the QR code module
    // [Format]: GS ( k pL pH cn fn n
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);

    // QR Code: Set the error correction level
    // [Name]: Set QR code error correction level
    // [Format]: GS ( k pL pH cn fn n
    // n = 48: Error correction level L (7%)
    // n = 49: Error correction level M (15%)
    // n = 50: Error correction level Q (25%)
    // n = 51: Error correction level H (30%)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // QR Code: Store the data in the symbol storage area
    // [Name]: Store QR code data
    // [Format]: GS ( k pL pH cn fn data
    final dataBytes = data.codeUnits;
    final pL = (dataBytes.length + 3) % 256;
    final pH = (dataBytes.length + 3) ~/ 256;

    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(dataBytes);

    // QR Code: Print the symbol data in the symbol storage area
    // [Name]: Print QR code
    // [Format]: GS ( k pL pH cn fn
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    // Back to left alignment
    bytes.addAll([0x1B, 0x61, 0x00]);

    // Line feed
    bytes.addAll([0x0A]);

    return bytes;
  }

  /// Generate simplified ticket info for printers that don't support QR codes
  static String generateFallbackTicketInfo(String data) {
    // Extract key info from the QR data URL
    try {
      final uri = Uri.parse(data);
      final params = uri.queryParameters;

      final ticketId = params['ticketId'] ?? 'N/A';
      final vehicle = params['vehicle'] ?? 'N/A';

      // Return a simple text representation with the key info
      return '''
--------------------------------
Scan Code: $ticketId
Vehicle: $vehicle
--------------------------------''';
    } catch (e) {
      // If parsing fails, just return the ticket ID portion
      return '''
--------------------------------
Ticket Reference:
$data
--------------------------------''';
    }
  }
}