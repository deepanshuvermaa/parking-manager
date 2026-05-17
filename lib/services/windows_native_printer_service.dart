import 'dart:io';
import 'dart:typed_data';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'usb_debug_logger.dart';
import 'escpos_formatter_service.dart';

/// Windows Native USB Printer Service
/// Uses Win32 APIs to send raw bytes to thermal printers
/// Supports ESC/POS thermal printers connected via USB
class WindowsNativePrinterService {
  static final UsbDebugLogger _logger = UsbDebugLogger();
  static int? _printerHandle;
  static String? _printerName;

  // SharedPreferences keys
  static const String PREF_PRINTER_NAME = 'windows_printer_name';
  static const String PREF_AUTO_CONNECT = 'windows_auto_connect';

  /// Check if connected
  static bool get isConnected => _printerHandle != null;

  /// Get connected printer name
  static String? get connectedPrinterName => _printerName;

  /// List available printers
  static Future<List<String>> listPrinters() async {
    if (!Platform.isWindows) {
      _logger.warning('Windows native printing only available on Windows');
      return [];
    }

    try {
      _logger.info('========== SCANNING WINDOWS PRINTERS ==========');

      final printers = <String>[];
      final pcbNeeded = calloc<DWORD>();
      final pcReturned = calloc<DWORD>();

      // First call to get size
      EnumPrinters(
        PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
        ffi.nullptr,
        4, // PRINTER_INFO_4
        ffi.nullptr,
        0,
        pcbNeeded,
        pcReturned,
      );

      final bytesNeeded = pcbNeeded.value;

      if (bytesNeeded > 0) {
        final buffer = calloc<ffi.Uint8>(bytesNeeded);

        // Second call to get data
        final result = EnumPrinters(
          PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
          ffi.nullptr,
          4,
          buffer.cast(),
          bytesNeeded,
          pcbNeeded,
          pcReturned,
        );

        if (result != 0) {
          final count = pcReturned.value;
          _logger.success('Found $count printers');

          final printerInfo = buffer.cast<PRINTER_INFO_4>();

          for (var i = 0; i < count; i++) {
            final printer = printerInfo.elementAt(i).ref;
            final name = printer.pPrinterName.toDartString();
            printers.add(name);
            _logger.debug('📱 Printer: $name');
          }
        }

        calloc.free(buffer);
      } else {
        _logger.warning('No printers found');
      }

      calloc.free(pcbNeeded);
      calloc.free(pcReturned);

      _logger.info('==============================================');
      return printers;
    } catch (e, stackTrace) {
      _logger.error('Error scanning printers: $e', stackTrace: stackTrace.toString());
      return [];
    }
  }

  /// Connect to printer
  static Future<bool> connect(String printerName) async {
    if (!Platform.isWindows) {
      _logger.error('Windows native printing only available on Windows');
      return false;
    }

    try {
      _logger.info('');
      _logger.info('🔥🔥🔥 WINDOWS USB PRINTER CONNECTION START 🔥🔥🔥');
      _logger.info('========================================');
      _logger.info('Printer: $printerName');
      _logger.info('========================================');

      // Disconnect existing connection
      if (_printerHandle != null) {
        _logger.warning('Closing existing connection...');
        await disconnect();
      }

      _logger.info('Opening printer connection...');

      final name = printerName.toNativeUtf16();
      final handle = calloc<HANDLE>();

      final result = OpenPrinter(name, handle, ffi.nullptr);

      calloc.free(name);

      if (result == 0) {
        _logger.error('❌ Failed to open printer');
        _logger.warning('Error code: ${GetLastError()}');
        calloc.free(handle);
        return false;
      }

      _printerHandle = handle.value;
      _printerName = printerName;

      calloc.free(handle);

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_PRINTER_NAME, printerName);

      _logger.success('✅ Connected successfully');
      _logger.info('');
      _logger.success('🎉🎉🎉 CONNECTION SUCCESSFUL! 🎉🎉🎉');
      _logger.success('========================================');
      _logger.success('Printer: $printerName');
      _logger.success('Status: READY TO PRINT');
      _logger.success('========================================');
      _logger.info('');

      return true;
    } catch (e, stackTrace) {
      _logger.error('');
      _logger.error('💥💥💥 CRITICAL CONNECTION ERROR 💥💥💥');
      _logger.error('========================================');
      _logger.error('Error: $e', stackTrace: stackTrace.toString());
      _logger.error('========================================');
      _logger.error('');
      return false;
    }
  }

  /// Print raw bytes
  static Future<bool> printBytes(Uint8List bytes) async {
    if (!Platform.isWindows) {
      _logger.error('Windows native printing only available on Windows');
      return false;
    }

    if (_printerHandle == null) {
      _logger.error('Not connected to printer');
      return false;
    }

    try {
      _logger.info('========== WINDOWS PRINT REQUEST ==========');
      _logger.info('Printer: $_printerName');
      _logger.info('Data size: ${bytes.length} bytes');

      // Start document
      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref.pDocName = 'Receipt'.toNativeUtf16();
      docInfo.ref.pOutputFile = ffi.nullptr;
      docInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      _logger.debug('Starting print job...');
      final jobId = StartDocPrinter(_printerHandle!, 1, docInfo.cast());

      if (jobId == 0) {
        _logger.error('❌ Failed to start document');
        _logger.warning('Error code: ${GetLastError()}');
        calloc.free(docInfo.ref.pDocName);
        calloc.free(docInfo.ref.pDatatype);
        calloc.free(docInfo);
        return false;
      }

      _logger.debug('Print job started (ID: $jobId)');
      _logger.debug('Starting page...');

      StartPagePrinter(_printerHandle!);

      // Write data
      final written = calloc<DWORD>();
      final data = calloc<ffi.Uint8>(bytes.length);

      for (var i = 0; i < bytes.length; i++) {
        data.elementAt(i).value = bytes[i];
      }

      _logger.debug('Writing ${bytes.length} bytes...');

      final writeResult = WritePrinter(
        _printerHandle!,
        data.cast(),
        bytes.length,
        written,
      );

      final bytesWritten = written.value;
      _logger.debug('Bytes written: $bytesWritten');

      // End page and document
      EndPagePrinter(_printerHandle!);
      EndDocPrinter(_printerHandle!);

      // Cleanup
      calloc.free(data);
      calloc.free(written);
      calloc.free(docInfo.ref.pDocName);
      calloc.free(docInfo.ref.pDatatype);
      calloc.free(docInfo);

      if (writeResult != 0 && bytesWritten == bytes.length) {
        _logger.success('✅ ${bytesWritten} bytes sent successfully');
        _logger.info('===========================================');
        return true;
      } else {
        _logger.error('❌ Write failed');
        _logger.warning('Error code: ${GetLastError()}');
        _logger.info('===========================================');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('❌ Print error: $e', stackTrace: stackTrace.toString());
      _logger.info('===========================================');
      return false;
    }
  }

  /// Print text (converts to ESC/POS bytes)
  static Future<bool> printText(String text) async {
    try {
      _logger.info('Converting text to ESC/POS format...');
      _logger.debug('Text length: ${text.length} characters');

      final List<int> bytes = [];

      // ESC @ - Initialize printer
      bytes.addAll([27, 64]);

      // Add text
      bytes.addAll(text.codeUnits);

      // Line feeds
      bytes.addAll([10, 10, 10]);

      // Paper cut
      bytes.addAll([29, 86, 0]);

      _logger.debug('Converted to ${bytes.length} bytes');

      return await printBytes(Uint8List.fromList(bytes));
    } catch (e, stackTrace) {
      _logger.error('Text conversion error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Print ESC/POS formatted receipt
  static Future<bool> printReceipt(List<int> escPosBytes) async {
    try {
      _logger.info('========== RECEIPT PRINT ==========');
      _logger.info('Receipt size: ${escPosBytes.length} bytes');
      _logger.debug('Contains ESC/POS commands: Yes');

      final bytes = Uint8List.fromList(escPosBytes);
      final success = await printBytes(bytes);

      if (success) {
        _logger.success('✅ Receipt printed successfully');
      } else {
        _logger.error('❌ Receipt print failed');
      }

      _logger.info('===================================');
      return success;
    } catch (e, stackTrace) {
      _logger.error('Receipt print error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Print parking receipt using ESC/POS formatter
  static Future<bool> printParkingReceipt({
    required String businessName,
    required String vehicleNumber,
    required DateTime entryTime,
    DateTime? exitTime,
    required double amount,
    String? receiptNo,
    String? parkingSlot,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      _logger.info('========== PRINTING PARKING RECEIPT ==========');
      _logger.info('Generating ESC/POS formatted receipt...');

      final bytes = await EscPosFormatterService.formatParkingReceipt(
        businessName: businessName,
        vehicleNumber: vehicleNumber,
        entryTime: entryTime,
        exitTime: exitTime,
        amount: amount,
        receiptNo: receiptNo,
        parkingSlot: parkingSlot,
        paperSize: paperSize,
      );

      _logger.success('✅ ESC/POS receipt generated (${bytes.length} bytes)');
      return await printReceipt(bytes);
    } catch (e, stackTrace) {
      _logger.error('Parking receipt error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Print test receipt using ESC/POS formatter
  static Future<bool> printTestReceipt({
    String businessName = 'Test Business',
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      _logger.info('========== PRINTING TEST RECEIPT ==========');
      _logger.info('Generating ESC/POS formatted test receipt...');

      final bytes = await EscPosFormatterService.formatTestReceipt(
        businessName: businessName,
        paperSize: paperSize,
      );

      _logger.success('✅ ESC/POS test receipt generated (${bytes.length} bytes)');
      return await printReceipt(bytes);
    } catch (e, stackTrace) {
      _logger.error('Test receipt error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Disconnect
  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;

    try {
      if (_printerHandle != null) {
        _logger.info('Disconnecting from printer...');
        ClosePrinter(_printerHandle!);
        _printerHandle = null;
        _printerName = null;
        _logger.success('Printer disconnected');
      }
    } catch (e, stackTrace) {
      _logger.error('Disconnect error: $e', stackTrace: stackTrace.toString());
      _printerHandle = null;
      _printerName = null;
    }
  }

  /// Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    if (!Platform.isWindows) return false;

    try {
      _logger.info('Attempting auto-connect...');

      final prefs = await SharedPreferences.getInstance();
      final autoConnect = prefs.getBool(PREF_AUTO_CONNECT) ?? false;

      if (!autoConnect) {
        _logger.debug('Auto-connect is disabled');
        return false;
      }

      final savedPrinterName = prefs.getString(PREF_PRINTER_NAME);
      if (savedPrinterName == null) {
        _logger.warning('No saved printer');
        return false;
      }

      _logger.info('Connecting to saved printer: $savedPrinterName');
      return await connect(savedPrinterName);
    } catch (e, stackTrace) {
      _logger.error('Auto-connect error: $e', stackTrace: stackTrace.toString());
      return false;
    }
  }

  /// Enable/disable auto-connect
  static Future<void> setAutoConnect(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PREF_AUTO_CONNECT, enabled);
    _logger.info('Auto-connect ${enabled ? "enabled" : "disabled"}');
  }
}
