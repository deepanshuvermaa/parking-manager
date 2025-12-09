import 'dart:io';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop USB/System Printer Service
/// Handles printing on Windows/Mac/Linux using system printers
/// Supports USB thermal printers and regular printers
class DesktopPrinterService {
  static Printer? _selectedPrinter;
  static const String PREF_PRINTER_NAME = 'desktop_printer_name';
  static const String PREF_AUTO_CONNECT = 'printer_auto_connect';

  /// Check if running on desktop platform
  static bool get isDesktop {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get list of available printers
  static Future<List<Printer>> getAvailablePrinters() async {
    if (!isDesktop) return [];

    try {
      final printers = await Printing.listPrinters();
      return printers;
    } catch (e) {
      print('Error getting printers: $e');
      return [];
    }
  }

  /// Save selected printer
  static Future<bool> savePrinter(Printer printer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_PRINTER_NAME, printer.name);
      _selectedPrinter = printer;
      return true;
    } catch (e) {
      print('Error saving printer: $e');
      return false;
    }
  }

  /// Get saved printer
  static Future<Printer?> getSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(PREF_PRINTER_NAME);

      if (savedName == null) return null;

      final printers = await getAvailablePrinters();
      return printers.firstWhere(
        (p) => p.name == savedName,
        orElse: () => printers.isNotEmpty ? printers.first : null as Printer,
      );
    } catch (e) {
      print('Error getting saved printer: $e');
      return null;
    }
  }

  /// Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoConnect = prefs.getBool(PREF_AUTO_CONNECT) ?? false;

      if (!autoConnect) return false;

      final printer = await getSavedPrinter();
      if (printer != null) {
        _selectedPrinter = printer;
        return true;
      }

      return false;
    } catch (e) {
      print('Error auto-connecting: $e');
      return false;
    }
  }

  /// Check if printer is connected
  static Future<bool> isConnected() async {
    if (_selectedPrinter == null) {
      await autoConnect();
    }
    return _selectedPrinter != null;
  }

  /// Print text receipt (for thermal printers)
  static Future<bool> printText(String receiptText) async {
    if (!isDesktop) return false;

    try {
      // Ensure we have a printer
      if (_selectedPrinter == null) {
        final connected = await autoConnect();
        if (!connected) {
          print('No printer connected');
          return false;
        }
      }

      // Create PDF from text (for thermal printer compatibility)
      final pdf = await _createTextPDF(receiptText);

      // Print to the selected printer
      await Printing.directPrintPdf(
        printer: _selectedPrinter!,
        onLayout: (_) => pdf,
      );

      return true;
    } catch (e) {
      print('Error printing: $e');
      return false;
    }
  }

  /// Create PDF from receipt text
  static Future<Uint8List> _createTextPDF(String text) async {
    final pdf = pw.Document();

    // Use monospace font for receipt-like appearance
    final font = await PdfGoogleFonts.courierRegular();
    final fontBold = await PdfGoogleFonts.courierBold();

    // Split text into lines
    final lines = text.split('\n');

    // Detect if line should be bold (simple detection based on ESC codes)
    bool isBoldLine(String line) {
      // Check if line contains our bold markers or is short and uppercase
      return line.toUpperCase() == line && line.trim().length < 30;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm thermal paper
        margin: pw.EdgeInsets.all(5),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lines.map((line) {
              // Remove ESC/POS codes (they won't render in PDF)
              final cleanLine = line.replaceAll(RegExp(r'[\x00-\x1F]'), '');

              return pw.Text(
                cleanLine,
                style: pw.TextStyle(
                  font: isBoldLine(line) ? fontBold : font,
                  fontSize: 9,
                  fontWeight: isBoldLine(line) ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              );
            }).toList(),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print test page
  static Future<bool> printTest() async {
    const testText = '''
================================
      PRINTER TEST
================================
Date: Test Print
--------------------------------
This is a test receipt to check
if your USB printer is working
correctly.
--------------------------------
Characters: ABCDEFGHIJKLMNOPQR
Numbers: 0123456789
Symbols: !@#\$%^&*()_+-=[]{}
================================
    TEST SUCCESSFUL
================================
''';

    return await printText(testText);
  }

  /// Disconnect printer
  static Future<void> disconnect() async {
    _selectedPrinter = null;
  }

  /// Get printer status
  static Future<Map<String, dynamic>> getPrinterStatus() async {
    return {
      'connected': _selectedPrinter != null,
      'printer_name': _selectedPrinter?.name ?? 'Not connected',
      'is_default': _selectedPrinter?.isDefault ?? false,
    };
  }
}
