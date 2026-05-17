import 'dart:io';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'usb_debug_logger.dart';

/// Desktop USB/System Printer Service
/// Handles printing on Windows/Mac/Linux using system printers
/// Supports USB thermal printers and regular printers
/// Full logging support for debugging
class DesktopPrinterService {
  static final UsbDebugLogger _logger = UsbDebugLogger();
  static Printer? _selectedPrinter;
  static const String PREF_PRINTER_NAME = 'desktop_printer_name';
  static const String PREF_AUTO_CONNECT = 'printer_auto_connect';

  /// Check if running on desktop platform
  static bool get isDesktop {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get list of available printers
  static Future<List<Printer>> getAvailablePrinters() async {
    if (!isDesktop) {
      _logger.warning('Not running on desktop platform');
      return [];
    }

    try {
      _logger.info('========== SCANNING DESKTOP PRINTERS ==========');
      _logger.info('Platform: ${Platform.operatingSystem}');

      final printers = await Printing.listPrinters();
      _logger.success('Found ${printers.length} printers');

      for (var printer in printers) {
        _logger.debug('📱 Printer: ${printer.name}');
        _logger.debug('   URL: ${printer.url}');
        _logger.debug('   Is Available: ${printer.isAvailable}');
        _logger.debug('   Is Default: ${printer.isDefault}');
      }

      _logger.info('==============================================');
      return printers;
    } catch (e, stackTrace) {
      _logger.error('Error scanning printers: $e', stackTrace: stackTrace.toString());
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
      if (printers.isEmpty) return null;
      return printers.firstWhere(
        (p) => p.name == savedName,
        orElse: () => printers.first,
      );
    } catch (e) {
      print('Error getting saved printer: $e');
      return null;
    }
  }

  /// Select and save a printer
  static Future<void> selectPrinter(Printer printer) async {
    try {
      _logger.info('========== SELECTING PRINTER ==========');
      _logger.info('Printer: ${printer.name}');

      _selectedPrinter = printer;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_PRINTER_NAME, printer.name);

      _logger.success('✅ Printer selected and saved');
      _logger.debug('URL: ${printer.url}');
      _logger.debug('Available: ${printer.isAvailable}');
      _logger.info('======================================');
    } catch (e, stackTrace) {
      _logger.error('Error selecting printer: $e', stackTrace: stackTrace.toString());
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
    if (!isDesktop) {
      _logger.error('Not running on desktop platform');
      return false;
    }

    try {
      _logger.info('========== DESKTOP PRINT REQUEST ==========');
      _logger.info('Receipt length: ${receiptText.length} characters');

      // Ensure we have a printer
      if (_selectedPrinter == null) {
        _logger.warning('No printer selected, attempting auto-connect...');
        final connected = await autoConnect();
        if (!connected) {
          _logger.error('❌ No printer connected');
          _logger.warning('Please select a printer first');
          return false;
        }
        _logger.success('Auto-connected to printer');
      }

      _logger.info('Printer: ${_selectedPrinter!.name}');
      _logger.debug('Creating PDF from text...');

      // Create PDF from text (for thermal printer compatibility)
      final pdf = await _createTextPDF(receiptText);
      _logger.debug('PDF created (${pdf.lengthInBytes} bytes)');

      // Print to the selected printer
      _logger.info('Sending to printer...');
      await Printing.directPrintPdf(
        printer: _selectedPrinter!,
        onLayout: (_) => pdf,
      );

      _logger.success('✅ Print job sent successfully');
      _logger.info('==========================================');
      return true;
    } catch (e, stackTrace) {
      _logger.error('❌ Print error: $e', stackTrace: stackTrace.toString());
      _logger.warning('Possible causes:');
      _logger.warning('  - Printer is offline or disconnected');
      _logger.warning('  - Printer driver issues');
      _logger.warning('  - Permission issues');
      _logger.info('==========================================');
      return false;
    }
  }

  /// Create PDF from receipt text
  static Future<Uint8List> _createTextPDF(String text) async {
    final pdf = pw.Document();

    // Use monospace font for receipt-like appearance
    final font = await PdfGoogleFonts.robotoMonoRegular();
    final fontBold = await PdfGoogleFonts.robotoMonoBold();

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
              // Remove ALL ESC/POS command sequences
              String cleanLine = line;

              // Remove ESC-based commands: ESC + any character + optional parameter
              cleanLine = cleanLine.replaceAll(RegExp(r'\x1B.{1,2}'), '');

              // Remove GS-based size commands: GS + ! + size byte
              cleanLine = cleanLine.replaceAll(RegExp(r'\x1D\x21[\x00-\xFF]'), '');

              // Remove any remaining control characters
              cleanLine = cleanLine.replaceAll(RegExp(r'[\x00-\x1F]'), '');

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
